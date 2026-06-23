=begin pod

=head1 Overview

Lazy evaluator for C<UnionOperator>.

This module keeps the runtime behavior for union queries beside the iterator
that implements pull-driven union traversal.

=end pod
unit module Qwiratry::Query::Evaluator::Union;

use Qwiratry::Operator::Set;
use Qwiratry::Query::Evaluator::Lazy;

=begin pod

=head2 C<class UnionIterator>

=begin code :lang<raku>
class UnionIterator does Iterator does LazyEvaluator is export
=end code

Defines C<UnionIterator>.

=end pod
class UnionIterator does Iterator does LazyEvaluator is export {
	has Mu @.sources is required;
	has Int $!source-idx = 0;
	has Iterator $!iter;
	has Mu @!seen;

	=begin pod

	=head2 C<method pull-one>

	=begin code :lang<raku>
	method pull-one
	=end code

	Documents C<method pull-one>.

	=end pod
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
			next if self.relation-common.node-in-list($row, @!seen);
			@!seen.push($row);
			return $row;
		}
	}
}

=begin pod

=head2 C<class UnionEvaluator>

=begin code :lang<raku>
class UnionEvaluator does LazyEvaluator is export
=end code

Defines C<UnionEvaluator>.

=end pod
class UnionEvaluator does LazyEvaluator is export {
	=begin pod

	=head2 C<method select-seq>

	=begin code :lang<raku>
	method select-seq(UnionOperator $query, Mu $origin, :&relation-source! --> Seq)
	=end code

	Documents C<method select-seq>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=item C<&relation-source>

	The C<&relation-source> parameter.

	=end pod
	method select-seq(UnionOperator $query, Mu $origin, :&relation-source! --> Seq) {
		self.lazy(
			relation-source($query.left, $origin),
			relation-source($query.right, $origin),
		)
	}

	=begin pod

	=head2 C<method topic-matches>

	=begin code :lang<raku>
	method topic-matches(UnionOperator $query, Mu $node, Mu :$origin, :&topic-matches! --> Bool)
	=end code

	Documents C<method topic-matches>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$node>

	The C<$node> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=item C<&topic-matches>

	The C<&topic-matches> parameter.

	=end pod
	method topic-matches(UnionOperator $query, Mu $node, Mu :$origin, :&topic-matches! --> Bool) {
		topic-matches($query.left, $node, :$origin)
			|| topic-matches($query.right, $node, :$origin)
	}

	=begin pod

	=head2 C<method lazy>

	=begin code :lang<raku>
	method lazy(+@sources --> Seq)
	=end code

	Documents C<method lazy>.

	=item C<@sources>

	The C<@sources> parameter.

	=end pod
	method lazy(+@sources --> Seq) {
		my Mu @prepared = self.prepare-sources(|@sources);
		self.seq-from-iterator(UnionIterator.new(sources => Array.new(@prepared)))
	}
}
