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
	my constant @QUERY-COMBINATOR-INFIX = «∪ ∩ ∖ ⊖»;

	my $instance;

	=begin pod

	Return the shared Extract service instance.

	=end pod
	method instance(--> Qwiratry::Query::Extract) {
		$instance //= self.new
	}

	=begin pod

	Run C<$when-block> with L<NavQueryTopic> as C<$_> and return a query
	operator when the block body is a pure query expression.

	=end pod
	method from-when-block(Block $when-block --> Mu) {
		my $result = try { $when-block(NavQueryTopic.new) };
		self!is-query-operator($result) and return $result;
		Nil
	}

	=begin pod

	Return True when C<$when-block> always evaluates to the same query operator
	shape (varying only in the C<$_> subject).

	=end pod
	method is-pure-query-when(Block $when-block --> Bool) {
		my $with-topic = self.from-when-block($when-block);
		$with-topic.defined or return False;

		my $with-scalar = try { $when-block(42) };
		self!is-query-operator($with-scalar) or return False;
		self!queries-equivalent($with-topic, $with-scalar)
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

	Compare query operators for the same structural shape and selectors.

	=end pod
	method !queries-equivalent(Mu $a, Mu $b --> Bool) {
		$a.^name eq $b.^name or return False;
		if $a ~~ NavigationOperator {
			self!selectors-equivalent($a, $b) or return False;
			if $a.can('subject') && $b.can('subject') {
				my $left = $a.subject;
				my $right = $b.subject;
				!$left.defined && !$right.defined and return True;
				$left.defined && $right.defined or return False;
				$left ~~ NavQueryTopic || $right ~~ NavQueryTopic and return True;
				$left ~~ NavigationOperator && $right ~~ NavigationOperator
					and return self!queries-equivalent($left, $right);
			}
			return True;
		}
		if $a ~~ SetOperator {
			$a.can('left') && $a.can('right') && $b.can('left') && $b.can('right')
				or return False;
			return self!queries-equivalent($a.left, $b.left)
				&& self!queries-equivalent($a.right, $b.right);
		}
		False
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

	Return True when the infix operator is boolean conjunction (C<&&> / C<and>).

	=end pod
	method !infix-is-boolean-conjunction(Mu $infix --> Bool) {
		$infix.defined or return False;
		my $name = self!infix-name($infix);
		$name.defined or return False;
		so $name eq any(<&& and>)
	}

	=begin pod

	Return True when the infix operator combines query result sets.

	=end pod
	method !infix-is-query-combinator(Mu $infix --> Bool) {
		$infix.defined or return False;
		my $name = self!infix-name($infix);
		$name.defined or return False;
		so $name eq any(@QUERY-COMBINATOR-INFIX)
	}

	=begin pod

	Return True when C<$value> is a query operator value.

	=end pod
	method !is-query-operator(Mu $value --> Bool) {
		$value ~~ NavigationOperator | MapReduceOperator | SetOperator
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

	Return the expression inside a single-expression parenthesized AST node.

	=end pod
	method !unwrap-expression(Mu $expr --> Mu) {
		$expr.defined or return Nil;
		if $expr.WHAT.^name eq 'RakuAST::Circumfix::Parentheses' {
			my $inner = try $expr.semilist;
			$inner.defined and return self!unwrap-expression($inner);
			my $first = try $expr.first;
			$first.defined and return self!unwrap-expression($first);
		}
		if $expr.WHAT.^name eq 'RakuAST::SemiList' {
			my @statements = try $expr.statements;
			if @statements == 1 {
				my $statement = @statements[0];
				my $expression = try $statement.expression;
				$expression.defined and return self!unwrap-expression($expression);
				return self!unwrap-expression($statement);
			}
			my $first = try $expr.first;
			$first.defined and return self!unwrap-expression($first);
		}
		$expr
	}

	=begin pod

	Return True when C<$expr> is a query expression in RakuAST form.

	=end pod
	method !is-query-expr(Mu $expr --> Bool) {
		my $core = self!unwrap-expression($expr);
		$core.defined or return False;
		return True if $core.WHAT.^name eq 'RakuAST::ApplyInfix'
			&& self!infix-is-navigation($core.infix);
		return True if $core.WHAT.^name eq 'RakuAST::ApplyInfix'
			&& self!infix-is-query-combinator($core.infix)
			&& self!is-query-expr($core.left)
			&& self!is-query-expr($core.right);
		if $core.WHAT.^name eq 'RakuAST::ApplyListInfix'
				&& self!infix-is-query-combinator($core.infix) {
			my @operands = try $core.operands;
			@operands.elems > 1 or return False;
			for @operands -> $operand {
				self!is-query-expr($operand) or return False;
			}
			return True;
		}
		False
	}

	=begin pod

	Split a C<when> body into navigation query and optional predicate AST fragments.

	=end pod
	method !split-when-navigation-ast(Mu $body --> Hash) {
		my $expr = self!unwrap-expression(self!when-body-expression($body));
		$expr.defined or return %();

		if $expr.WHAT.^name eq 'RakuAST::ApplyInfix'
				&& self!infix-is-boolean-conjunction($expr.infix) {
			my $left = self!unwrap-expression($expr.left);
			my $right = self!unwrap-expression($expr.right);
			if self!is-query-expr($left) {
				return %(query => $left, predicate => $right);
			}
		}

		self!is-query-expr($expr) and return %(query => $expr);
		%()
	}
}
