=begin pod

Navigation query operators as immutable RakuAST nodes.

Operators declare L<NavigationOperator> capability and are interpreted by Walkers
during planning. Execution semantics (tree vs table vs graph) are Walker-specific.

=end pod
unit module Qwiratry::Operator::Navigation;

use Qwiratry::Operator::Capability;

role NavigationOperatorNode does NavigationOperator does OperatorBase {
	has Mu $.subject;
	has Mu $.selector is required;
	has $.adverbs;

	method operator-name(--> Str) { self.^name }

	method describe(--> Str) {
		my $sel = $!selector.defined ?? $!selector.gist !! 'Nil';
		my $sub = $!subject.defined ?? " subject={$!subject.gist}" !! '';
		my $adv = $!adverbs.defined ?? " adverbs={$!adverbs.raku}" !! '';
		"{self.operator-name}(selector: $sel$sub$adv)"
	}
}

class ChildOperator is RakuAST::Node does NavigationOperatorNode is export { }

class ParentOperator is RakuAST::Node does NavigationOperatorNode is export { }

class DescendantOperator is RakuAST::Node does NavigationOperatorNode is export { }

class AncestorOperator is RakuAST::Node does NavigationOperatorNode is export { }

class FollowingSiblingOperator is RakuAST::Node does NavigationOperatorNode is export { }

class PrecedingSiblingOperator is RakuAST::Node does NavigationOperatorNode is export { }

class FollowingOperator is RakuAST::Node does NavigationOperatorNode is export { }

class PrecedingOperator is RakuAST::Node does NavigationOperatorNode is export { }

class AttributeOperator is RakuAST::Node does NavigationOperator does OperatorBase is export {
	has Mu $.subject;
	has Mu $.key is required;

	method describe(--> Str) {
		my $key = $!key.defined ?? $!key.gist !! 'Nil';
		my $sub = $!subject.defined ?? " subject={$!subject.gist}" !! '';
		"AttributeOperator(key: $key$sub)"
	}
}

class RootOperator is RakuAST::Node does NavigationOperator does OperatorBase is export {
	has Mu $.subject;

	method describe(--> Str) {
		my $sub = $!subject.defined ?? " subject={$!subject.gist}" !! '';
		"RootOperator$sub"
	}
}
