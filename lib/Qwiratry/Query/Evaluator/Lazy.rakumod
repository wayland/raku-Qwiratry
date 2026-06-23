=begin pod

=head1 Overview

Shared mechanics for lazy query evaluators.

Evaluator classes use these helpers to turn iterators into C<Seq> values,
normalize replay-sensitive sources, and pull from mixed source types.

=end pod
unit module Qwiratry::Query::Evaluator::Lazy;

use Qwiratry::Query::RelationCommon;

=begin pod

=head2 C<class ListIterator>

=begin code :lang<raku>
class ListIterator does Iterator is export
=end code

Defines C<ListIterator>.

=end pod
class ListIterator does Iterator is export {
	has Mu @.items is required;
	has Int $!idx = 0;

	=begin pod

	=head2 C<method pull-one>

	=begin code :lang<raku>
	method pull-one
	=end code

	Documents C<method pull-one>.

	=end pod
	method pull-one {
		$!idx >= @.items and return IterationEnd;
		@.items[$!idx++]
	}
}

=begin pod

=head2 C<role LazyEvaluator>

=begin code :lang<raku>
role LazyEvaluator is export
=end code

Defines C<LazyEvaluator>.

=end pod
role LazyEvaluator is export {
	=begin pod

	=head2 C<method relation-common>

	=begin code :lang<raku>
	method relation-common()
	=end code

	Documents C<method relation-common>.

	=end pod
	method relation-common() {
		Qwiratry::Query::RelationCommon.instance
	}

	=begin pod

	=head2 C<method prepare-sources>

	=begin code :lang<raku>
	method prepare-sources(+@sources)
	=end code

	Documents C<method prepare-sources>.

	=item C<@sources>

	The C<@sources> parameter.

	=end pod
	method prepare-sources(+@sources) {
		@sources.map(-> $source {
			$source ~~ Seq ?? $source.cache !! $source
		})
	}

	=begin pod

	=head2 C<method iterator-for>

	=begin code :lang<raku>
	method iterator-for(Mu $source --> Iterator)
	=end code

	Documents C<method iterator-for>.

	=item C<$source>

	The C<$source> parameter.

	=end pod
	method iterator-for(Mu $source --> Iterator) {
		$source ~~ Iterator and return $source;
		if $source ~~ Seq {
			return $source.iterator;
		}
		$source.list.iterator;
	}

	=begin pod

	=head2 C<method seq-from-iterator>

	=begin code :lang<raku>
	method seq-from-iterator(Iterator $iter --> Seq)
	=end code

	Documents C<method seq-from-iterator>.

	=item C<$iter>

	The C<$iter> parameter.

	=end pod
	method seq-from-iterator(Iterator $iter --> Seq) {
		Seq.new($iter)
	}

	=begin pod

	=head2 C<method lazy-from-list>

	=begin code :lang<raku>
	method lazy-from-list(@items --> Seq)
	=end code

	Documents C<method lazy-from-list>.

	=item C<@items>

	The C<@items> parameter.

	=end pod
	method lazy-from-list(@items --> Seq) {
		@items or return ().Seq;
		self.seq-from-iterator(ListIterator.new(items => @items))
	}

	=begin pod

	=head2 C<method source-list>

	=begin code :lang<raku>
	method source-list(Mu $source --> List)
	=end code

	Documents C<method source-list>.

	=item C<$source>

	The C<$source> parameter.

	=end pod
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
	=begin pod

	=head2 C<method pull-next>

	=begin code :lang<raku>
	method pull-next(Iterator $iter)
	=end code

	Documents C<method pull-next>.

	=item C<$iter>

	The C<$iter> parameter.

	=end pod
	method pull-next(Iterator $iter) {
		my $item = $iter.pull-one;
		$item ~~ IterationEnd ?? IterationEnd !! $item
	}
}

=begin pod

=head2 C<class BasicLazyEvaluator>

=begin code :lang<raku>
class BasicLazyEvaluator does LazyEvaluator is export
=end code

Defines C<BasicLazyEvaluator>.

=end pod
class BasicLazyEvaluator does LazyEvaluator is export { }
