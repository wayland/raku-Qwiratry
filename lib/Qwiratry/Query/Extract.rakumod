=begin pod

Extract navigation Query AST values from template C<when> blocks.

=end pod
use v6.e.PREVIEW;

use Qwiratry::Operator::Navigation;
use Qwiratry::Operator::Capability;
use Qwiratry::Query::Match;

unit class Qwiratry::Query::Extract;

my constant @NAV-INFIX = «⪪ ⪫ ⪪⪪ ⪫⪫ ⪨ ⪩ ⪨⪨ ⪩⪩ ⥷»;

my $instance;

method instance(--> Qwiratry::Query::Extract) {
	$instance //= self.new
}

method from-when-block(Block $when-block --> Mu) {
	my $result = try { $when-block(NavQueryTopic.new) };
	return $result if $result ~~ NavigationOperator;
	Nil
}

method is-pure-navigation-when(Block $when-block --> Bool) {
	my $with-topic = self.from-when-block($when-block);
	return False unless $with-topic.defined;

	my $with-scalar = try { $when-block(42) };
	return False unless $with-scalar ~~ NavigationOperator;
	return False unless $with-scalar.^name eq $with-topic.^name;
	return False unless self!selectors-equivalent($with-topic, $with-scalar);
	True
}

method split-from-blockoid(Mu $blockoid-cap --> Hash) {
	return %() unless $blockoid-cap.defined;
	my $body = try $blockoid-cap.ast;
	return %() unless $body.defined;
	self!split-when-navigation-ast($body);
}

method !selectors-equivalent(Mu $a, Mu $b --> Bool) {
	return False unless $a.can('selector') && $b.can('selector');
	my $left = $a.selector;
	my $right = $b.selector;
	return True if !$left.defined && !$right.defined;
	return False unless $left.defined && $right.defined;
	return $left eqv $right if $left ~~ Str && $right ~~ Str;
	$left.gist eq $right.gist
}

method !infix-name(Mu $infix --> Str) {
	return $infix.operator if $infix.can('operator');
	try $infix.name // ~$infix
}

method !infix-is-navigation(Mu $infix --> Bool) {
	return False unless $infix.defined;
	my $name = self!infix-name($infix);
	return False unless $name.defined;
	so $name eq any(@NAV-INFIX)
}

method !infix-is-conjunction(Mu $infix --> Bool) {
	return False unless $infix.defined;
	my $name = self!infix-name($infix);
	return False unless $name.defined;
	so $name eq any(<&& and>)
}

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

method !is-navigation-expr(Mu $expr --> Bool) {
	return False unless $expr.defined;
	return True if $expr.WHAT.^name eq 'RakuAST::ApplyInfix'
		&& self!infix-is-navigation($expr.infix);
	False
}

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
