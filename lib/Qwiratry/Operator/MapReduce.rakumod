=begin pod

Map-reduce query operators as immutable AST nodes.

Selection (C<σ>), sort (C<⇅>), map (C<».>), and reduce (C<⌿>) filter,
order, transform, and aggregate query results.

=end pod
unit module Qwiratry::Operator::MapReduce;

use Qwiratry::Operator::Capability;

role MapReduceOperatorNode does MapReduceOperator does OperatorBase {
	has Mu $.subject;

	method mapreduce-describe(Str $detail --> Str) {
		my $sub = $!subject.defined ?? " subject={$!subject.gist}" !! '';
		"{self.^name}($detail$sub)"
	}
}

class SelectionOperator is RakuAST::Node does MapReduceOperator does OperatorBase is export {
	has Mu $.subject;
	has Mu $.predicate is required;

	method describe(--> Str) {
		my $sub = $!subject.defined ?? " subject={$!subject.gist}" !! '';
		"SelectionOperator(predicate$sub)"
	}
}

class SortOperator is RakuAST::Node does MapReduceOperatorNode is export {
	has Mu $.key-function is required;

	method describe(--> Str) {
		self.mapreduce-describe('key-function')
	}
}

class MapOperator is RakuAST::Node does MapReduceOperatorNode is export {
	has Mu $.transform is required;

	method describe(--> Str) {
		self.mapreduce-describe('transform')
	}
}

class ReduceOperator is RakuAST::Node does MapReduceOperatorNode is export {
	has Mu $.operation is required;

	method describe(--> Str) {
		self.mapreduce-describe('operation')
	}
}
