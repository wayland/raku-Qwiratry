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

C<SelectionOperator>, C<SortOperator>, C<MapOperator>, and C<ReduceOperator>
share C<MapReduceOperatorNode>, which stores an optional subject and describes
the single callable field specific to the operation.

=end pod
unit module Qwiratry::Operator::MapReduce;

use Qwiratry::Operator::Capability;

role MapReduceOperatorNode does MapReduceOperator does OperatorBase does ChainedOperator {
	=begin pod

	=head1 Methods

	=head2 C<mapreduce-type()>

	=begin code
	method mapreduce-type(--> Str)
	=end code

	Returns the operator-specific callable field label used in debug output.

	=end pod
	method mapreduce-type(--> Str) { ... }

	=begin pod

	=head2 C<describe()>

	=begin code
	method describe(--> Str)
	=end code

	Builds a compact debug label for operators whose interesting payload is a
	callable field such as a sort key, transform, or reduction operation.

	=end pod
	method describe(--> Str) {
		my $detail = self.mapreduce-type;
		my $sub = self.subject-description;
		"{self.^name}($detail$sub)"
	}
}

class SelectionOperator is RakuAST::Node does MapReduceOperatorNode does LazyEvaluatedOperator is export {
	has Mu $.predicate is required;

	=begin pod

	=head2 C<SelectionOperator.mapreduce-type()>

	=begin code
	method mapreduce-type(--> Str)
	=end code

	Returns the selection predicate field label.

	=end pod
	method mapreduce-type(--> Str) {
		'predicate'
	}
}

class SortOperator is RakuAST::Node does MapReduceOperatorNode does EagerEvaluatedOperator is export {
	has Mu $.key-function is required;

	=begin pod

	=head2 C<SortOperator.mapreduce-type()>

	=begin code
	method mapreduce-type(--> Str)
	=end code

	Returns the sort-key field label.

	=end pod
	method mapreduce-type(--> Str) {
		'key-function'
	}
}

class MapOperator is RakuAST::Node does MapReduceOperatorNode does EagerEvaluatedOperator is export {
	has Mu $.transform is required;

	=begin pod

	=head2 C<MapOperator.mapreduce-type()>

	=begin code
	method mapreduce-type(--> Str)
	=end code

	Returns the transform field label.

	=end pod
	method mapreduce-type(--> Str) {
		'transform'
	}
}

class ReduceOperator is RakuAST::Node does MapReduceOperatorNode does EagerEvaluatedOperator is export {
	has Mu $.operation is required;

	=begin pod

	=head2 C<ReduceOperator.mapreduce-type()>

	=begin code
	method mapreduce-type(--> Str)
	=end code

	Returns the reduction operation field label.

	=end pod
	method mapreduce-type(--> Str) {
		'operation'
	}
}
