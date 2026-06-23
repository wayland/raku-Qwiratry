=begin pod

=head1 Overview

Shared mechanics for lazy query evaluators.

Evaluator classes use these helpers to turn iterators into C<Seq> values,
normalize replay-sensitive sources, and pull from mixed source types.

=end pod
unit module Qwiratry::Query::Evaluator::Lazy;

use Qwiratry::Query::Relational;

class ListIterator does Iterator is export {
	has Mu @.items is required;
	has Int $!idx = 0;

	method pull-one {
		$!idx >= @.items and return IterationEnd;
		@.items[$!idx++]
	}
}

role LazyEvaluator is export {
	method relational() {
		Qwiratry::Query::Relational.instance
	}

	method prepare-sources(+@sources) {
		@sources.map(-> $source {
			$source ~~ Seq ?? $source.cache !! $source
		})
	}

	method iterator-for(Mu $source --> Iterator) {
		$source ~~ Iterator and return $source;
		if $source ~~ Seq {
			return $source.iterator;
		}
		$source.list.iterator;
	}

	method seq-from-iterator(Iterator $iter --> Seq) {
		Seq.new($iter)
	}

	method lazy-from-list(@items --> Seq) {
		@items or return ().Seq;
		self.seq-from-iterator(ListIterator.new(items => @items))
	}

	method source-list(Mu $source --> List) {
		$source ~~ Seq | List | Array and return $source.list;
		if $source ~~ Positional {
			return $source.list;
		}
		return gather {
			my $iter = self.iterator-for($source);
			loop {
				my $item = self.pull-next($iter);
				last if $item ~~ IterationEnd;
				take $item;
			}
		}.List;
	}

	#| Advance past IterationEnd, returning the next value or IterationEnd.
	method pull-next(Iterator $iter) {
		my $item = $iter.pull-one;
		$item ~~ IterationEnd ?? IterationEnd !! $item
	}
}

class BasicLazyEvaluator does LazyEvaluator is export { }
