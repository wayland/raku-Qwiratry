=begin pod

Set-theory and relational-algebra query operators as immutable AST nodes.

=end pod
unit module Qwiratry::Operator::Set;

use Qwiratry::Operator::Capability;

role BinarySetOperatorNode does SetOperator does OperatorBase {
	has Mu $.left is required;
	has Mu $.right is required;

	method operator-name(--> Str) { self.^name }

	method describe(--> Str) {
		my $left-name = $!left.can('describe') ?? $!left.describe !! $!left.^name;
		my $right-name = $!right.can('describe') ?? $!right.describe !! $!right.^name;
		"{self.operator-name}(left: $left-name, right: $right-name)"
	}
}

role JoinOperatorNode does BinarySetOperatorNode {
	has Mu $.condition;
}

role UnarySetOperatorNode does SetOperator does OperatorBase {
	method operator-name(--> Str) { self.^name }
}

class UnionOperator is RakuAST::Node does BinarySetOperatorNode is export { }

class IntersectionOperator is RakuAST::Node does BinarySetOperatorNode is export { }

class SetDifferenceOperator is RakuAST::Node does BinarySetOperatorNode is export { }

class SymmetricDifferenceOperator is RakuAST::Node does BinarySetOperatorNode is export { }

class ElementOfOperator is RakuAST::Node does SetOperator does OperatorBase is export {
	has Mu $.element is required;
	has Mu $.collection is required;

	method describe(--> Str) {
		"ElementOfOperator(element: {$!element.gist}, collection: {$!collection.gist})"
	}
}

class ContainsOperator is RakuAST::Node does SetOperator does OperatorBase is export {
	has Mu $.collection is required;
	has Mu $.element is required;

	method describe(--> Str) {
		"ContainsOperator(collection: {$!collection.gist}, element: {$!element.gist})"
	}
}

class SubsetOperator is RakuAST::Node does BinarySetOperatorNode is export { }

class SubsetOrEqualOperator is RakuAST::Node does BinarySetOperatorNode is export { }

class IdentityOperator is RakuAST::Node does BinarySetOperatorNode is export { }

class ProjectionOperator is RakuAST::Node does SetOperator does OperatorBase is export {
	has Mu $.relation is required;
	has @.columns is required;

	method describe(--> Str) {
		"ProjectionOperator(columns: {@!columns.raku}, relation: {$!relation.gist})"
	}
}

class RenameOperator is RakuAST::Node does SetOperator does OperatorBase is export {
	has Mu $.relation is required;
	has %.renames is required;

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

class DivisionOperator is RakuAST::Node does BinarySetOperatorNode is export { }

class CrossJoinOperator is RakuAST::Node does BinarySetOperatorNode is export { }
