=begin pod

=head1 Overview

Lazy evaluator for predicate-based selection/filtering.

=end pod
unit module Qwiratry::Query::Evaluator::Filter;

use Qwiratry::Operator::Capability;
use Qwiratry::Operator::Navigation;
use Qwiratry::Operator::MapReduce;
use Qwiratry::Table;
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
		:&select-seq!,
		--> Seq
	) {
		my $source = self.selection-relation-source($query, $origin, :&select-seq);
		my &pred = $query.predicate;
		self.lazy($source, -> $base { self.selection-predicate-matches(&pred, $base) })
	}

	method lazy($source, &match --> Seq) {
		my $inner = self.iterator-for($source);
		self.seq-from-iterator(FilterIterator.new(:iter($inner), :matcher(&match)))
	}

	method selection-predicate-matches(&pred, Mu $base --> Bool) {
		my $result = try {
			if &pred.arity == 1 {
				pred($base).Bool;
			}
			else {
				(with $base { pred() }).Bool;
			}
		};
		return $result // False;
	}

	method relation-row-snapshot(Mu $source) {
		$source ~~ Positional and return Array.new($source.list);
		$source
	}

	method selection-relation-source(SelectionOperator $query, Mu $origin, :&select-seq!) {
		if $query.subject ~~ NavigationOperator | RootOperator {
			return select-seq($query.subject, $origin);
		}
		if $query.subject ~~ AdaptorOperator {
			return $origin ~~ Positional ?? $origin !! ($origin,);
		}
		if $query.subject ~~ Qwiratry::Table::Catalog {
			return $query.subject.active-rows;
		}
		if $query.subject ~~ Iterator {
			return $query.subject;
		}
		if $query.subject ~~ Positional {
			return self.relation-row-snapshot($query.subject);
		}
		if $query.subject.defined {
			return ($query.subject,);
		}
		if $origin ~~ Qwiratry::Table::Catalog {
			return $origin.active-rows;
		}
		if $origin ~~ Positional {
			return self.relation-row-snapshot($origin);
		}
		($origin,);
	}
}
