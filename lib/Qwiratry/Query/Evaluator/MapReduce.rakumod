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

=begin pod

=head2 C<role MapReduceEagerEvaluator>

=begin code :lang<raku>
role MapReduceEagerEvaluator does EagerEvaluator
=end code

Defines C<MapReduceEagerEvaluator>.

=end pod
role MapReduceEagerEvaluator does EagerEvaluator {
	has &.select-list is required;

	=begin pod

	=head2 C<method select-list-for>

	=begin code :lang<raku>
	method select-list-for(Mu $query, Mu $origin --> List)
	=end code

	Documents C<method select-list-for>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method select-list-for(Mu $query, Mu $origin --> List) {
		&!select-list($query, $origin)
	}

	=begin pod

	=head2 C<method mapreduce-items>

	=begin code :lang<raku>
	method mapreduce-items(Mu $query, Mu $origin --> List)
	=end code

	Documents C<method mapreduce-items>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
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

	=begin pod

	=head2 C<method code-result>

	=begin code :lang<raku>
	method code-result(&code, Mu $item --> Mu)
	=end code

	Documents C<method code-result>.

	=item C<&code>

	The C<&code> parameter.

	=item C<$item>

	The C<$item> parameter.

	=end pod
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

	=begin pod

	=head2 C<method reduce-with>

	=begin code :lang<raku>
	method reduce-with(&op, Mu $acc, Mu $item --> Mu)
	=end code

	Documents C<method reduce-with>.

	=item C<&op>

	The C<&op> parameter.

	=item C<$acc>

	The C<$acc> parameter.

	=item C<$item>

	The C<$item> parameter.

	=end pod
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

=begin pod

=head2 C<class SortEvaluator>

=begin code :lang<raku>
class SortEvaluator does MapReduceEagerEvaluator is export
=end code

Defines C<SortEvaluator>.

=end pod
class SortEvaluator does MapReduceEagerEvaluator is export {
	=begin pod

	=head2 C<method eager>

	=begin code :lang<raku>
	method eager(SortOperator $query, Mu $origin --> List)
	=end code

	Documents C<method eager>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method eager(SortOperator $query, Mu $origin --> List) {
		my @items = self.mapreduce-items($query, $origin);
		my &key = $query.key-function;
		@items.sort(-> $a, $b {
			self.code-result(&key, $a) cmp self.code-result(&key, $b)
		}).List
	}
}

=begin pod

=head2 C<class MapEvaluator>

=begin code :lang<raku>
class MapEvaluator does MapReduceEagerEvaluator is export
=end code

Defines C<MapEvaluator>.

=end pod
class MapEvaluator does MapReduceEagerEvaluator is export {
	=begin pod

	=head2 C<method eager>

	=begin code :lang<raku>
	method eager(MapOperator $query, Mu $origin --> List)
	=end code

	Documents C<method eager>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method eager(MapOperator $query, Mu $origin --> List) {
		my @items = self.mapreduce-items($query, $origin);
		my &transform = $query.transform;
		@items.map(-> $item { self.code-result(&transform, $item) }).List
	}
}

=begin pod

=head2 C<class ReduceEvaluator>

=begin code :lang<raku>
class ReduceEvaluator does MapReduceEagerEvaluator is export
=end code

Defines C<ReduceEvaluator>.

=end pod
class ReduceEvaluator does MapReduceEagerEvaluator is export {
	=begin pod

	=head2 C<method eager>

	=begin code :lang<raku>
	method eager(ReduceOperator $query, Mu $origin --> List)
	=end code

	Documents C<method eager>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
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
