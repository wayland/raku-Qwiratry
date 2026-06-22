=begin pod

Extract navigation Query AST values from mold C<when> blocks.

When blocks such as C<when { $_ ⪪⪪ <item> }> build navigation operators at
runtime with C<$_> as the subject. A sentinel L<NavQueryTopic|Qwiratry::Query::Match::NavQueryTopic>
stands in for C<$_> during extraction so the query can be stored on the mold
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
		$result ~~ NavigationOperator and return $result;
		Nil
	}

	=begin pod

	Return True when C<$when-block> always evaluates to the same navigation operator
	shape (varying only in the C<$_> subject).

	=end pod
	method is-pure-navigation-when(Block $when-block --> Bool) {
		my $with-topic = self.from-when-block($when-block);
		$with-topic.defined or return False;

		my $with-scalar = try { $when-block(42) };
		$with-scalar ~~ NavigationOperator or return False;
		$with-scalar.^name eq $with-topic.^name or return False;
		self!selectors-equivalent($with-topic, $with-scalar) or return False;
		True
	}

	=begin pod

	Split a mold C<when> blockoid AST into navigation query and predicate parts.

	=end pod
	method split-from-blockoid(Mu $blockoid-cap --> Hash) {
		$blockoid-cap.defined or return %();
		my $body = try $blockoid-cap.ast;
		$body.defined or return %();
		self!split-when-navigation-ast($body);
	}

	=begin pod

	Compare navigation selectors from two operators for structural equivalence.

	=end pod
	method !selectors-equivalent(Mu $a, Mu $b --> Bool) {
		$a.can('selector') && $b.can('selector') or return False;
		my $left = $a.selector;
		my $right = $b.selector;
		!$left.defined && !$right.defined and return True;
		$left.defined && $right.defined or return False;
		$left ~~ Str && $right ~~ Str and return $left eqv $right;
		$left.gist eq $right.gist
	}

	=begin pod

	Resolve the operator name from a RakuAST infix node.

	=end pod
	method !infix-name(Mu $infix --> Str) {
		$infix.can('operator') and return $infix.operator;
		try $infix.name // ~$infix
	}

	=begin pod

	Return True when the infix operator is a Qwiratry navigation operator.

	=end pod
	method !infix-is-navigation(Mu $infix --> Bool) {
		$infix.defined or return False;
		my $name = self!infix-name($infix);
		$name.defined or return False;
		so $name eq any(@NAV-INFIX)
	}

	=begin pod

	Return True when the infix operator is logical conjunction (C<&&> / C<and>).

	=end pod
	method !infix-is-conjunction(Mu $infix --> Bool) {
		$infix.defined or return False;
		my $name = self!infix-name($infix);
		$name.defined or return False;
		so $name eq any(<&& and>)
	}

	=begin pod

	Extract the single expression from a C<when> block body AST, if unambiguous.

	=end pod
	method !when-body-expression(Mu $body --> Mu) {
		if $body.WHAT.^name eq 'RakuAST::Blockoid' {
			my $inner = try $body.statement-list;
			$inner.defined and return self!when-body-expression($inner);
		}
		if $body ~~ RakuAST::StatementList {
			my @stmts = $body.statements;
			@stmts == 1 or return Nil;
			my $stmt = @stmts[0];
			$stmt.can('expression') and return $stmt.expression;
		}
		Nil
	}

	=begin pod

	Return True when C<$expr> is a navigation infix application in RakuAST form.

	=end pod
	method !is-navigation-expr(Mu $expr --> Bool) {
		$expr.defined or return False;
		return True if $expr.WHAT.^name eq 'RakuAST::ApplyInfix'
			&& self!infix-is-navigation($expr.infix);
		False
	}

	=begin pod

	Split a C<when> body into navigation query and optional predicate AST fragments.

	=end pod
	method !split-when-navigation-ast(Mu $body --> Hash) {
		my $expr = self!when-body-expression($body);
		$expr.defined or return %();

		if $expr.WHAT.^name eq 'RakuAST::ApplyInfix' && self!infix-is-conjunction($expr.infix) {
			my $left = $expr.left;
			my $right = $expr.right;
			if self!is-navigation-expr($left) {
				return %(query => $left, predicate => $right);
			}
		}

		self!is-navigation-expr($expr) and return %(query => $expr);
		%()
	}
}
