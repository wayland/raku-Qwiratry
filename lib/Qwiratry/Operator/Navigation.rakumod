=begin pod

=head1 Overview

Navigation query operators as immutable RakuAST nodes.

Operators declare L<NavigationOperator> capability and are interpreted by Walkers
during planning. Execution semantics (tree vs table vs graph) are Walker-specific.

The query slang lowers navigation syntax such as child, descendant, sibling, and
attribute axes into these node classes. Each node stores only the structural
pieces of the query: an optional C<subject>, a selector or key, and any adverbs.
Walkers and L<Qwiratry::Query::Match> provide the domain-specific meaning.

=head1 Operator Families

C<NavigationOperatorNode> covers axis operators that select related nodes using
a selector. C<AttributeOperator> reads a named attribute or column. C<RootOperator>
anchors a pipeline at the original query root or an explicit subject.

=end pod
unit module Qwiratry::Operator::Navigation;

use Qwiratry::Operator::Capability;

role NavigationOperatorNode does NavigationOperator does OperatorBase {
	has Mu $.subject;
	has Mu $.selector is required;
	has $.adverbs;

	method operator-name(--> Str) { self.^name }

	=begin pod

	=head1 Methods

	=head2 C<describe()>

	=begin code
	method describe(--> Str)
	=end code

	Returns a compact debug label containing the selector, optional subject, and
	adverbs captured by the slang.

	=end pod
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

	=begin pod

	=head2 C<AttributeOperator.describe()>

	=begin code
	method describe(--> Str)
	=end code

	Returns a debug label for an attribute-axis node, including the key and any
	explicit subject.

	=end pod
	method describe(--> Str) {
		my $key = $!key.defined ?? $!key.gist !! 'Nil';
		my $sub = $!subject.defined ?? " subject={$!subject.gist}" !! '';
		"AttributeOperator(key: $key$sub)"
	}
}

class RootOperator is RakuAST::Node does NavigationOperator does OperatorBase is export {
	has Mu $.subject;

	=begin pod

	=head2 C<RootOperator.describe()>

	=begin code
	method describe(--> Str)
	=end code

	Returns a debug label for a root anchor. When C<subject> is present, the root
	operator evaluates from that subject instead of the traversal origin.

	=end pod
	method describe(--> Str) {
		my $sub = $!subject.defined ?? " subject={$!subject.gist}" !! '';
		"RootOperator$sub"
	}
}
