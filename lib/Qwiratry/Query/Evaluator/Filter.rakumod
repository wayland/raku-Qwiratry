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

=begin pod

=head2 C<class FilterIterator>

=begin code :lang<raku>
class FilterIterator does Iterator does LazyEvaluator is export
=end code

Defines C<FilterIterator>.

=end pod
class FilterIterator does Iterator does LazyEvaluator is export {
	has Iterator $!iter is built;
	has $!matcher is built;

	=begin pod

	=head2 C<method pull-one>

	=begin code :lang<raku>
	method pull-one
	=end code

	Documents C<method pull-one>.

	=end pod
	method pull-one {
		loop {
			my $item = self.pull-next($!iter);
			$item ~~ IterationEnd and return IterationEnd;
			$!matcher($item) and return $item;
		}
	}
}

=begin pod

=head2 C<class SelectionEvaluator>

=begin code :lang<raku>
class SelectionEvaluator does LazyEvaluator is export
=end code

Defines C<SelectionEvaluator>.

=end pod
class SelectionEvaluator does LazyEvaluator is export {
	=begin pod

	=head2 C<method select-seq>

	=begin code :lang<raku>
	method select-seq(
	SelectionOperator $query,
	Mu $origin,
	:&select-seq!,
	--> Seq
	)
	=end code

	Documents C<method select-seq>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=item C<&select-seq>

	The C<&select-seq> parameter.

	=end pod
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

	=begin pod

	=head2 C<method lazy>

	=begin code :lang<raku>
	method lazy($source, &match --> Seq)
	=end code

	Documents C<method lazy>.

	=item C<$source>

	The C<$source> parameter.

	=item C<&match>

	The C<&match> parameter.

	=end pod
	method lazy($source, &match --> Seq) {
		my $inner = self.iterator-for($source);
		self.seq-from-iterator(FilterIterator.new(:iter($inner), :matcher(&match)))
	}

	=begin pod

	=head2 C<method selection-predicate-matches>

	=begin code :lang<raku>
	method selection-predicate-matches(&pred, Mu $base --> Bool)
	=end code

	Documents C<method selection-predicate-matches>.

	=item C<&pred>

	The C<&pred> parameter.

	=item C<$base>

	The C<$base> parameter.

	=end pod
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

	=begin pod

	=head2 C<method relation-row-snapshot>

	=begin code :lang<raku>
	method relation-row-snapshot(Mu $source)
	=end code

	Documents C<method relation-row-snapshot>.

	=item C<$source>

	The C<$source> parameter.

	=end pod
	method relation-row-snapshot(Mu $source) {
		$source ~~ Positional and return Array.new($source.list);
		$source
	}

	=begin pod

	=head2 C<method selection-relation-source>

	=begin code :lang<raku>
	method selection-relation-source(SelectionOperator $query, Mu $origin, :&select-seq!)
	=end code

	Documents C<method selection-relation-source>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=item C<&select-seq>

	The C<&select-seq> parameter.

	=end pod
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
