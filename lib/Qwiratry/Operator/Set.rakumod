=begin pod

=head1 Overview

Set-theory and relational-algebra query operators as immutable AST nodes.

The query slang lowers union, intersection, difference, joins, projection, and
rename forms into these small RakuAST node classes. The nodes carry operands and
metadata only; L<Qwiratry::Query::Match>, L<Qwiratry::Query::Lazy>, and table
helpers decide how to evaluate them for the current data domain.

=head1 Operator Families

Binary operators store C<left> and C<right> operands. Join operators add an
optional C<condition> callable. Projection and rename operators store relational
metadata used when the selected rows are associative values.

=end pod
unit module Qwiratry::Operator::Set;

use Qwiratry::Operator::Capability;

role BinarySetOperatorNode does SetOperator does OperatorBase {
	has Mu $.left is required;
	has Mu $.right is required;

	method operator-name(--> Str) { self.^name }

	=begin pod

	=head1 Methods

	=head2 C<describe()>

	=begin code
	method describe(--> Str)
	=end code

	Returns a compact debug label showing the operator and its two operands.

	Operands that provide their own C<describe> method are asked to describe
	themselves, so nested queries remain readable in diagnostics and explain-style
	output.

	=end pod
	method describe(--> Str) {
		my $left-name = $!left.can('describe') ?? $!left.describe !! $!left.^name;
		my $right-name = $!right.can('describe') ?? $!right.describe !! $!right.^name;
		"{self.operator-name}(left: $left-name, right: $right-name)"
	}
}

role JoinOperatorNode does BinarySetOperatorNode does LazyEvaluatedOperator {
	has Mu $.condition;
}

role UnarySetOperatorNode does SetOperator does OperatorBase {
	method operator-name(--> Str) { self.^name }
}

class UnionOperator is RakuAST::Node does BinarySetOperatorNode does LazyEvaluatedOperator is export { }

class IntersectionOperator is RakuAST::Node does BinarySetOperatorNode does LazyEvaluatedOperator is export { }

class SetDifferenceOperator is RakuAST::Node does BinarySetOperatorNode does LazyEvaluatedOperator is export { }

class SymmetricDifferenceOperator is RakuAST::Node does BinarySetOperatorNode does LazyEvaluatedOperator is export { }

class ElementOfOperator is RakuAST::Node does SetOperator does OperatorBase does EagerEvaluatedOperator is export {
	has Mu $.element is required;
	has Mu $.collection is required;

	=begin pod

	=head2 C<ElementOfOperator.describe()>

	=begin code
	method describe(--> Str)
	=end code

	Returns a debug label for membership tests where C<element> is checked
	against C<collection>.

	=end pod
	method describe(--> Str) {
		"ElementOfOperator(element: {$!element.gist}, collection: {$!collection.gist})"
	}
}

class ContainsOperator is RakuAST::Node does SetOperator does OperatorBase does EagerEvaluatedOperator is export {
	has Mu $.collection is required;
	has Mu $.element is required;

	=begin pod

	=head2 C<ContainsOperator.describe()>

	=begin code
	method describe(--> Str)
	=end code

	Returns a debug label for containment tests where C<collection> is checked
	for C<element>.

	=end pod
	method describe(--> Str) {
		"ContainsOperator(collection: {$!collection.gist}, element: {$!element.gist})"
	}
}

class SubsetOperator is RakuAST::Node does BinarySetOperatorNode does EagerEvaluatedOperator is export { }

class SubsetOrEqualOperator is RakuAST::Node does BinarySetOperatorNode does EagerEvaluatedOperator is export { }

class IdentityOperator is RakuAST::Node does BinarySetOperatorNode does EagerEvaluatedOperator is export { }

class ProjectionOperator is RakuAST::Node does SetOperator does OperatorBase does LazyEvaluatedOperator is export {
	has Mu $.relation is required;
	has @.columns is required;

	=begin pod

	=head2 C<ProjectionOperator.describe()>

	=begin code
	method describe(--> Str)
	=end code

	Returns a debug label including the projected columns and source relation.

	=end pod
	method describe(--> Str) {
		"ProjectionOperator(columns: {@!columns.raku}, relation: {$!relation.gist})"
	}
}

class RenameOperator is RakuAST::Node does SetOperator does OperatorBase does LazyEvaluatedOperator is export {
	has Mu $.relation is required;
	has %.renames is required;

	=begin pod

	=head2 C<RenameOperator.describe()>

	=begin code
	method describe(--> Str)
	=end code

	Returns a debug label including the requested column renames and source
	relation.

	=end pod
	method describe(--> Str) {
		"RenameOperator(renames: {%!renames.raku}, relation: {$!relation.gist})"
	}
}

class InnerJoinOperator is RakuAST::Node does JoinOperatorNode is export { }

class LeftOuterJoinOperator is RakuAST::Node does JoinOperatorNode is export { }

class RightOuterJoinOperator is RakuAST::Node does JoinOperatorNode is export { }

class FullOuterJoinOperator is RakuAST::Node does JoinOperatorNode is export { }

class LeftSemijoinOperator is RakuAST::Node does JoinOperatorNode is export { }

class RightSemijoinOperator is RakuAST::Node does JoinOperatorNode is export { }

class LeftAntijoinOperator is RakuAST::Node does JoinOperatorNode is export { }

class RightAntijoinOperator is RakuAST::Node does JoinOperatorNode is export { }

class DivisionOperator is RakuAST::Node does BinarySetOperatorNode does EagerEvaluatedOperator is export { }

class CrossJoinOperator is RakuAST::Node does BinarySetOperatorNode does LazyEvaluatedOperator is export { }
