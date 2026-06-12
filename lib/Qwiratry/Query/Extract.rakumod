=begin pod

Extract navigation Query AST values from template C<when> blocks.

When blocks such as C<when { $_ ⪪⪪ <item> }> build navigation operators at
runtime with C<$_> as the subject. A sentinel L<NavQueryTopic|Qwiratry::Query::Match::NavQueryTopic>
stands in for C<$_> during extraction so the query can be stored on the template
for specificity scoring and matching.

=end pod
use v6.e.PREVIEW;

use Qwiratry::Operator::Navigation;
use Qwiratry::Operator::Capability;
use Qwiratry::Query::Match;

class Qwiratry::Query::Extract {

	my constant @NAV-INFIX = «⪪ ⪫ ⪪⪪ ⪫⪫ ⪨ ⪩ ⪨⪨ ⪩⪩ ⥷»;

	my $instance;

	=begin pod

	Return the shared Extract service instance.

	=end pod
	method instance(--> Qwiratry::Query::Extract) {
		$instance //= self.new
	}

	=begin pod

	Run C<$when-block> with L<NavQueryTopic> as C<$_> and return a navigation
	operator when the block body is a pure query expression.

	=end pod
	method from-when-block(Block $when-block --> Mu) {
		my $result = try { $when-block(NavQueryTopic.new) };
		return $result if $result ~~ NavigationOperator;
		Nil
	}

	=begin pod

	Return True when C<$when-block> always evaluates to the same navigation operator
	shape (varying only in the C<$_> subject).

	=end pod
	method is-pure-navigation-when(Block $when-block --> Bool) {
		my $with-topic = self.from-when-block($when-block);
		return False unless $with-topic.defined;

		my $with-scalar = try { $when-block(42) };
		return False unless $with-scalar ~~ NavigationOperator;
		return False unless $with-scalar.^name eq $with-topic.^name;
		return False unless self!selectors-equivalent($with-topic, $with-scalar);
		True
	}

	=begin pod

	Split a template C<when> blockoid AST into navigation query and predicate parts.

	=end pod
	method split-from-blockoid(Mu $blockoid-cap --> Hash) {
		return %() unless $blockoid-cap.defined;
		my $body = try $blockoid-cap.ast;
		return %() unless $body.defined;
		self!split-when-navigation-ast($body);
	}

	=begin pod

	Compare navigation selectors from two operators for structural equivalence.

	=end pod
	method !selectors-equivalent(Mu $a, Mu $b --> Bool) {
		return False unless $a.can('selector') && $b.can('selector');
		my $left = $a.selector;
		my $right = $b.selector;
		return True if !$left.defined && !$right.defined;
		return False unless $left.defined && $right.defined;
		return $left eqv $right if $left ~~ Str && $right ~~ Str;
		$left.gist eq $right.gist
	}

	=begin pod

	Resolve the operator name from a RakuAST infix node.

	=end pod
	method !infix-name(Mu $infix --> Str) {
		return $infix.operator if $infix.can('operator');
		try $infix.name // ~$infix
	}

	=begin pod

	Return True when the infix operator is a Qwiratry navigation operator.

	=end pod
	method !infix-is-navigation(Mu $infix --> Bool) {
		return False unless $infix.defined;
		my $name = self!infix-name($infix);
		return False unless $name.defined;
		so $name eq any(@NAV-INFIX)
	}

	=begin pod

	Return True when the infix operator is logical conjunction (C<&&> / C<and>).

	=end pod
	method !infix-is-conjunction(Mu $infix --> Bool) {
		return False unless $infix.defined;
		my $name = self!infix-name($infix);
		return False unless $name.defined;
		so $name eq any(<&& and>)
	}

	=begin pod

	Extract the single expression from a C<when> block body AST, if unambiguous.

	=end pod
	method !when-body-expression(Mu $body --> Mu) {
		if $body.WHAT.^name eq 'RakuAST::Blockoid' {
			my $inner = try $body.statement-list;
			return self!when-body-expression($inner) if $inner.defined;
		}
		if $body ~~ RakuAST::StatementList {
			my @stmts = $body.statements;
			return Nil unless @stmts == 1;
			my $stmt = @stmts[0];
			return $stmt.expression if $stmt.can('expression');
		}
		Nil
	}

	=begin pod

	Return True when C<$expr> is a navigation infix application in RakuAST form.

	=end pod
	method !is-navigation-expr(Mu $expr --> Bool) {
		return False unless $expr.defined;
		return True if $expr.WHAT.^name eq 'RakuAST::ApplyInfix'
			&& self!infix-is-navigation($expr.infix);
		False
	}

	=begin pod

	Split a C<when> body into navigation query and optional predicate AST fragments.

	=end pod
	method !split-when-navigation-ast(Mu $body --> Hash) {
		my $expr = self!when-body-expression($body);
		return %() unless $expr.defined;

		if $expr.WHAT.^name eq 'RakuAST::ApplyInfix' && self!infix-is-conjunction($expr.infix) {
			my $left = $expr.left;
			my $right = $expr.right;
			if self!is-navigation-expr($left) {
				return %(query => $left, predicate => $right);
			}
		}

		return %(query => $expr) if self!is-navigation-expr($expr);
		%()
	}
}
