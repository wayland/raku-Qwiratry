=begin pod

Map-reduce query operators as immutable AST nodes.

Selection (C<σ>) filters query results with a predicate block.

=end pod
unit module Qwiratry::Operator::MapReduce;

use Qwiratry::Operator::Capability;

class SelectionOperator is RakuAST::Node does MapReduceOperator does OperatorBase is export {
    has Mu $.subject is required;
    has Mu $.predicate is required;

    method describe(--> Str) {
        "SelectionOperator(subject: {$!subject.gist})"
    }
}
