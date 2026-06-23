=begin pod

=head1 Overview

Eager evaluators for map-reduce query operators.

=end pod
unit module Qwiratry::Query::Evaluator::MapReduce;

use Qwiratry::Operator::Navigation;
use Qwiratry::Operator::Capability;
use Qwiratry::Operator::Set;
use Qwiratry::Operator::MapReduce;
use Qwiratry::Operator::IO;
use Qwiratry::Query::Evaluator::Eager;
use Qwiratry::Table;

role MapReduceEagerEvaluator does EagerEvaluator {
	has &.select-list is required;

	method select-list-for(Mu $query, Mu $origin --> List) {
		&!select-list($query, $origin)
	}

	method mapreduce-items(Mu $query, Mu $origin --> List) {
		if $query.subject.defined {
			if $query.subject ~~ NavigationOperator | RootOperator | SetOperator | MapReduceOperator {
				return self.select-list-for($query.subject, $origin);
			}
			if $query.subject ~~ AdaptorOperator {
				return $origin ~~ Positional ?? $origin.list !! ($origin,);
			}
			if $query.subject ~~ Positional {
				return $query.subject.list;
			}
			return ($query.subject,);
		}
		if $origin ~~ Qwiratry::Table::Catalog {
			return $origin.active-rows;
		}
		if $origin ~~ Positional {
			return $origin.list;
		}
		($origin,)
	}

	method code-result(&code, Mu $item --> Mu) {
		try {
			if &code.arity == 1 {
				code($item);
			}
			else {
				with $item { code() }
			}
		} orelse $item
	}

	method reduce-with(&op, Mu $acc, Mu $item --> Mu) {
		try {
			if &op.arity == 2 {
				op($acc, $item);
			}
			elsif &op.arity == 1 {
				op($item);
			}
			else {
				with $acc { with $item { op() } }
			}
		} orelse $acc
	}
}

class SortEvaluator does MapReduceEagerEvaluator is export {
	method eager(SortOperator $query, Mu $origin --> List) {
		my @items = self.mapreduce-items($query, $origin);
		my &key = $query.key-function;
		@items.sort(-> $a, $b {
			self.code-result(&key, $a) cmp self.code-result(&key, $b)
		}).List
	}
}

class MapEvaluator does MapReduceEagerEvaluator is export {
	method eager(MapOperator $query, Mu $origin --> List) {
		my @items = self.mapreduce-items($query, $origin);
		my &transform = $query.transform;
		@items.map(-> $item { self.code-result(&transform, $item) }).List
	}
}

class ReduceEvaluator does MapReduceEagerEvaluator is export {
	method eager(ReduceOperator $query, Mu $origin --> List) {
		my @items = self.mapreduce-items($query, $origin);
		@items or return ();
		my &op = $query.operation;
		my $acc = @items.shift;
		for @items -> $item {
			$acc = self.reduce-with(&op, $acc, $item);
		}
		($acc,)
	}
}
