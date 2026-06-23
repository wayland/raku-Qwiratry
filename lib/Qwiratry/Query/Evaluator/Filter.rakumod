=begin pod

=head1 Overview

Lazy evaluator for predicate-based selection/filtering.

=end pod
unit module Qwiratry::Query::Evaluator::Filter;

use Qwiratry::Operator::MapReduce;
use Qwiratry::Query::Evaluator::Lazy;

class FilterIterator does Iterator does LazyEvaluator is export {
	has Iterator $!iter is built;
	has $!matcher is built;

	method pull-one {
		loop {
			my $item = self.pull-next($!iter);
			$item ~~ IterationEnd and return IterationEnd;
			$!matcher($item) and return $item;
		}
	}
}

class SelectionEvaluator does LazyEvaluator is export {
	method select-seq(
		SelectionOperator $query,
		Mu $origin,
		:&selection-relation-source!,
		:&selection-predicate-matches!,
		--> Seq
	) {
		my $source = selection-relation-source($query, $origin);
		my &pred = $query.predicate;
		self.lazy($source, -> $base { selection-predicate-matches(&pred, $base) })
	}

	method lazy($source, &match --> Seq) {
		my $inner = self.iterator-for($source);
		self.seq-from-iterator(FilterIterator.new(:iter($inner), :matcher(&match)))
	}
}
