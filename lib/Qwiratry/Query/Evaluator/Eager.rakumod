=begin pod

=head1 Overview

Shared interface for eager query evaluators.

Eager evaluators return materialized C<List> values. Family-specific roles add
only the helper methods they need.

=end pod
unit module Qwiratry::Query::Evaluator::Eager;

use Qwiratry::Query::Relational;

role EagerEvaluator is export {
	method relational() {
		Qwiratry::Query::Relational.instance
	}

	method eager(Mu $query, Mu $origin --> List) { ... }
}

role RecursiveEagerEvaluator does EagerEvaluator is export {
	has &.select-list is required;
	has &.select-relation is required;

	method select-list-for(Mu $query, Mu $origin --> List) {
		&!select-list($query, $origin)
	}

	method select-relation-for(Mu $operand, Mu $origin --> List) {
		&!select-relation($operand, $origin)
	}
}
