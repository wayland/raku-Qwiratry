=begin pod

=head1 Overview

Map-reduce query operators as immutable AST nodes.

Selection (C<σ>), sort (C<⇅>), map (C<».>), and reduce (C<⌿>) filter,
order, transform, and aggregate query results.

The query slang captures user-supplied callables and optional subjects in these
nodes. Evaluation is intentionally outside the node classes: walkers and
L<Qwiratry::Query::Match> decide which stream of items is being filtered,
sorted, mapped, or reduced.

=head1 Operator Families

C<SelectionOperator> stores a predicate. The other map-reduce operators share
C<MapReduceOperatorNode>, which stores an optional subject and a single callable
field specific to the operation.

=end pod
unit module Qwiratry::Operator::MapReduce;

use Qwiratry::Operator::Capability;

role MapReduceOperatorNode does MapReduceOperator does OperatorBase does ChainedOperator {
	=begin pod

	=head1 Methods

	=head2 C<mapreduce-describe(Str $detail)>

	=begin code
	method mapreduce-describe(Str $detail --> Str)
	=end code

	=head3 Parameters

	=item C<$detail>

	 The operator-specific detail string to include in the description.


	Builds a compact debug label for operators whose interesting payload is a
	callable field such as a sort key, transform, or reduction operation.

	=end pod
	method mapreduce-describe(Str $detail --> Str) {
		my $sub = self.subject-description;
		"{self.^name}($detail$sub)"
	}
}

class SelectionOperator is RakuAST::Node does MapReduceOperator does OperatorBase does ChainedOperator is export {
	has Mu $.predicate is required;

	=begin pod

	=head2 C<SelectionOperator.describe()>

	=begin code
	method describe(--> Str)
	=end code

	Returns a debug label for a selection predicate and any explicit subject.

	=end pod
	method describe(--> Str) {
		my $sub = self.subject-description;
		"SelectionOperator(predicate$sub)"
	}
}

class SortOperator is RakuAST::Node does MapReduceOperatorNode is export {
	has Mu $.key-function is required;

	=begin pod

	=head2 C<SortOperator.describe()>

	=begin code
	method describe(--> Str)
	=end code

	Returns a debug label for sort-key evaluation.

	=end pod
	method describe(--> Str) {
		self.mapreduce-describe('key-function')
	}
}

class MapOperator is RakuAST::Node does MapReduceOperatorNode is export {
	has Mu $.transform is required;

	=begin pod

	=head2 C<MapOperator.describe()>

	=begin code
	method describe(--> Str)
	=end code

	Returns a debug label for per-item transformation.

	=end pod
	method describe(--> Str) {
		self.mapreduce-describe('transform')
	}
}

class ReduceOperator is RakuAST::Node does MapReduceOperatorNode is export {
	has Mu $.operation is required;

	=begin pod

	=head2 C<ReduceOperator.describe()>

	=begin code
	method describe(--> Str)
	=end code

	Returns a debug label for reduction.

	=end pod
	method describe(--> Str) {
		self.mapreduce-describe('operation')
	}
}
