=begin pod

Set-theory query operators as immutable AST nodes.

Union, intersection, and set difference combine results from sub-queries.

=end pod
unit module Qwiratry::Operator::Set;

use Qwiratry::Operator::Capability;

role SetOperatorNode does SetOperator does OperatorBase {
    has Mu $.left is required;
    has Mu $.right is required;

    method operator-name(--> Str) { self.^name }

    method describe(--> Str) {
        "{self.operator-name}(left: {$!left.gist}, right: {$!right.gist})"
    }
}

class UnionOperator is RakuAST::Node does SetOperatorNode is export { }

class IntersectionOperator is RakuAST::Node does SetOperatorNode is export { }

class SetDifferenceOperator is RakuAST::Node does SetOperatorNode is export { }
