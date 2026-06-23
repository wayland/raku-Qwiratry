=begin pod

=head1 Overview

Lazy evaluator for C<UnionOperator>.

This module keeps the runtime behavior for union queries beside the iterator
that implements pull-driven union traversal.

=end pod
unit module Qwiratry::Query::Evaluator::Union;

use Qwiratry::Operator::Set;
use Qwiratry::Query::Evaluator::Lazy;

class UnionIterator does Iterator does LazyEvaluator is export {
	has Mu @.sources is required;
	has Int $!source-idx = 0;
	has Iterator $!iter;
	has Mu @!seen;

	method pull-one {
		loop {
			unless $!iter.defined {
				$!source-idx >= @.sources and return IterationEnd;
				my $src = @.sources[$!source-idx++];
				$!iter = self.iterator-for($src);
			}
			my $row = self.pull-next($!iter);
			if $row ~~ IterationEnd {
				$!iter = Nil;
				next;
			}
			next if self.relational.node-in-list($row, @!seen);
			@!seen.push($row);
			return $row;
		}
	}
}

class UnionEvaluator does LazyEvaluator is export {
	method select-seq(UnionOperator $query, Mu $origin, :&relation-source! --> Seq) {
		self.lazy(
			relation-source($query.left, $origin),
			relation-source($query.right, $origin),
		)
	}

	method lazy(+@sources --> Seq) {
		my Mu @prepared = self.prepare-sources(|@sources);
		self.seq-from-iterator(UnionIterator.new(sources => Array.new(@prepared)))
	}
}
