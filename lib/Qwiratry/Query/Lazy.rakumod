=begin pod

=head1 Overview

Lazy, pull-driven query evaluation for set and relational operators.

C<select-seq> yields results incrementally so joins and set operations do not
materialize full intermediate relations before the first row is consumed.

This module is the lazy backend used by L<Qwiratry::Query::Match>. It exposes
small constructors that wrap purpose-built iterator classes in C<Seq> objects.
The public functions preserve relational semantics while delaying work until the
caller pulls the next result.

Some operations still snapshot one side of a relation when membership checks
require it. The goal is not "never materialize"; it is to avoid building every
intermediate result before the first downstream consumer can run.

=end pod
unit module Qwiratry::Query::Lazy;

use Qwiratry::Operator::Navigation;
use Qwiratry::Operator::Set;
use Qwiratry::Operator::MapReduce;
use Qwiratry::Operator::IO;
use Qwiratry::Query::Relational;

my sub relational() { Qwiratry::Query::Relational.instance }

sub iterator-for(Mu $source --> Iterator) {
	$source ~~ Iterator and return $source;
	if $source ~~ Seq {
		return $source.iterator;
	}
	$source.list.iterator;
}

sub lazy-seq(Iterator $iter --> Seq) {
	Seq.new($iter)
}

sub source-list(Mu $source --> List) {
	$source ~~ Seq | List | Array and return $source.list;
	if $source ~~ Positional {
		return $source.list;
	}
	return gather {
		my $iter = iterator-for($source);
		loop {
			my $item = pull-next($iter);
			last if $item ~~ IterationEnd;
			take $item;
		}
	}.List;
}

#| Advance past IterationEnd, returning the next value or IterationEnd.
sub pull-next(Iterator $iter) {
	my $item = $iter.pull-one;
	$item ~~ IterationEnd ?? IterationEnd !! $item
}

class ListIterator does Iterator {
	has Mu @.items is required;
	has Int $!idx = 0;

	method pull-one {
		$!idx >= @.items and return IterationEnd;
		@.items[$!idx++]
	}
}

sub source-iterator(Mu $source --> Iterator) {
	ListIterator.new(items => source-list($source))
}

class UnionIterator does Iterator {
	has Mu @.sources is required;
	has Int $!source-idx = 0;
	has Iterator $!iter;
	has Mu @!seen;

	method pull-one {
		loop {
			unless $!iter.defined {
				$!source-idx >= @.sources and return IterationEnd;
				my $src = @.sources[$!source-idx++];
				$!iter = iterator-for($src);
			}
			my $row = pull-next($!iter);
			if $row ~~ IterationEnd {
				$!iter = Nil;
				next;
			}
			next if relational.node-in-list($row, @!seen);
			@!seen.push($row);
			return $row;
		}
	}
}

class IntersectionIterator does Iterator {
	has Mu $.left is required;
	has Mu $.right is required;
	has Iterator $!left-iter;
	has @!right-list;
	has Bool $!right-ready = False;

	method pull-one {
		$!left-iter //= iterator-for($.left);
		unless $!right-ready {
			@!right-list = source-list($.right);
			$!right-ready = True;
		}
		loop {
			my $lrow = pull-next($!left-iter);
			$lrow ~~ IterationEnd and return IterationEnd;
			relational.node-in-list($lrow, @!right-list) and return $lrow;
		}
	}
}

class SetDifferenceIterator does Iterator {
	has Mu $.left is required;
	has Mu $.right is required;
	has Iterator $!left-iter;
	has @!right-list;
	has Bool $!right-ready = False;

	method pull-one {
		$!left-iter //= iterator-for($.left);
		unless $!right-ready {
			@!right-list = source-list($.right);
			$!right-ready = True;
		}
		loop {
			my $lrow = pull-next($!left-iter);
			$lrow ~~ IterationEnd and return IterationEnd;
			relational.row-in-list($lrow, @!right-list) or return $lrow;
		}
	}
}

our sub lazy-from-list(@items --> Seq) is export {
	@items or return ().Seq;
	lazy-seq ListIterator.new(items => @items)
}

class NaturalJoinIterator does Iterator {
	has Mu $.left is required;
	has Mu $.right is required;
	has &.condition;
	has Iterator $!left-iter;
	has Mu $!current-left;
	has Iterator $!right-iter;

	method pull-one {
		loop {
			unless $!current-left.defined {
				$!left-iter //= iterator-for($.left);
				$!current-left = pull-next($!left-iter);
				$!current-left ~~ IterationEnd and return IterationEnd;
				next unless $!current-left ~~ Associative;
				$!right-iter = iterator-for($.right);
			}
			my $rrow = pull-next($!right-iter);
			if $rrow ~~ IterationEnd {
				$!current-left = Nil;
				$!right-iter = Nil;
				next;
			}
			next unless $rrow ~~ Associative;
			my $matches = &!condition.defined
				?? &!condition($!current-left, $rrow)
				!! relational.join-on-common-keys($!current-left, $rrow);
			$matches and return relational.merge-rows($!current-left, $rrow);
		}
	}
}

class LeftOuterJoinIterator does Iterator {
	has Mu $.left is required;
	has Mu $.right is required;
	has &.condition;
	has Iterator $!left-iter;
	has Mu $!current-left;
	has Iterator $!right-iter;
	has @!pending;

	method pull-one {
		@!pending and return @!pending.shift;
		loop {
			$!left-iter //= iterator-for($.left);
			$!current-left = pull-next($!left-iter);
			$!current-left ~~ IterationEnd and return IterationEnd;

			my @matches;
			$!right-iter = iterator-for($.right);
			loop {
				my $rrow = pull-next($!right-iter);
				last if $rrow ~~ IterationEnd;
				my $ok = &!condition.defined
					?? &!condition($!current-left, $rrow)
					!! relational.join-on-common-keys($!current-left, $rrow);
				$ok and @matches.push(relational.merge-rows($!current-left, $rrow));
			}
			if @matches {
				@!pending = @matches;
				return @!pending.shift;
			}
			return %($!current-left);
		}
	}
}

class RightOuterJoinIterator does Iterator {
	has Mu $.left is required;
	has Mu $.right is required;
	has &.condition;
	has Iterator $!right-iter;
	has Mu $!current-right;
	has Iterator $!left-iter;
	has @!pending;

	method pull-one {
		@!pending and return @!pending.shift;
		loop {
			$!right-iter //= iterator-for($.right);
			$!current-right = pull-next($!right-iter);
			$!current-right ~~ IterationEnd and return IterationEnd;

			my @matches;
			$!left-iter = iterator-for($.left);
			loop {
				my $lrow = pull-next($!left-iter);
				last if $lrow ~~ IterationEnd;
				my $ok = &!condition.defined
					?? &!condition($lrow, $!current-right)
					!! relational.join-on-common-keys($lrow, $!current-right);
				$ok and @matches.push(relational.merge-rows($lrow, $!current-right));
			}
			if @matches {
				@!pending = @matches;
				return @!pending.shift;
			}
			return %($!current-right);
		}
	}
}

class LeftSemijoinIterator does Iterator {
	has Mu $.left is required;
	has Mu $.right is required;
	has &.condition;
	has Iterator $!left-iter;

	method pull-one {
		$!left-iter //= iterator-for($.left);
		loop {
			my $lrow = pull-next($!left-iter);
			$lrow ~~ IterationEnd and return IterationEnd;
			my $right-iter = iterator-for($.right);
			loop {
				my $rrow = pull-next($right-iter);
				last if $rrow ~~ IterationEnd;
				my $ok = &!condition.defined
					?? &!condition($lrow, $rrow)
					!! relational.join-on-common-keys($lrow, $rrow);
				$ok and return %($lrow);
			}
		}
	}
}

class LeftAntijoinIterator does Iterator {
	has Mu $.left is required;
	has Mu $.right is required;
	has &.condition;
	has Iterator $!left-iter;

	method pull-one {
		$!left-iter //= iterator-for($.left);
		loop {
			my $lrow = pull-next($!left-iter);
			$lrow ~~ IterationEnd and return IterationEnd;
			my $matched = False;
			my $right-iter = iterator-for($.right);
			loop {
				my $rrow = pull-next($right-iter);
				last if $rrow ~~ IterationEnd;
				my $ok = &!condition.defined
					?? &!condition($lrow, $rrow)
					!! relational.join-on-common-keys($lrow, $rrow);
				if $ok {
					$matched = True;
					last;
				}
			}
			$matched or return %($lrow);
		}
	}
}

class CrossJoinIterator does Iterator {
	has Mu $.left is required;
	has Mu $.right is required;
	has Iterator $!left-iter;
	has Mu $!current-left;
	has Iterator $!right-iter;

	method pull-one {
		loop {
			unless $!current-left.defined {
				$!left-iter //= iterator-for($.left);
				$!current-left = pull-next($!left-iter);
				$!current-left ~~ IterationEnd and return IterationEnd;
				$!right-iter = iterator-for($.right);
			}
			my $rrow = pull-next($!right-iter);
			if $rrow ~~ IterationEnd {
				$!current-left = Nil;
				$!right-iter = Nil;
				next;
			}
			return relational.merge-rows($!current-left, $rrow);
		}
	}
}

class ProjectionIterator does Iterator {
	has Mu $.rows is required;
	has Mu @.columns is required;
	has Iterator $!iter;

	method pull-one {
		$!iter //= iterator-for($.rows);
		loop {
			my $row = pull-next($!iter);
			$row ~~ IterationEnd and return IterationEnd;
			return $row ~~ Associative ?? relational.project-row($row, @.columns) !! $row;
		}
	}
}

class RenameIterator does Iterator {
	has Mu $.rows is required;
	has %.renames is required;
	has Iterator $!iter;

	method pull-one {
		$!iter //= iterator-for($.rows);
		loop {
			my $row = pull-next($!iter);
			$row ~~ IterationEnd and return IterationEnd;
			return $row ~~ Associative ?? relational.rename-row($row, %.renames) !! $row;
		}
	}
}

=begin pod

=head1 Exported Constructors

=head2 C<lazy-natural-join($left, $right, &condition)>

    our sub lazy-natural-join($left, $right, &condition --> Seq)

Returns a lazy sequence of merged rows from the left and right sources.

When C<&condition> is defined it decides row compatibility; otherwise rows
join on common associative keys.

=end pod
our sub lazy-natural-join($left, $right, &condition) is export {
	lazy-seq NaturalJoinIterator.new(:$left, :$right, :&condition)
}

=begin pod

=head2 C<lazy-left-outer-join($left, $right, &condition)>

    our sub lazy-left-outer-join($left, $right, &condition --> Seq)

Returns matching joined rows plus unmatched left rows.

=end pod
our sub lazy-left-outer-join($left, $right, &condition) is export {
	lazy-seq LeftOuterJoinIterator.new(:$left, :$right, :&condition)
}

=begin pod

=head2 C<lazy-right-outer-join($left, $right, &condition)>

    our sub lazy-right-outer-join($left, $right, &condition --> Seq)

Returns matching joined rows plus unmatched right rows.

=end pod
our sub lazy-right-outer-join($left, $right, &condition) is export {
	lazy-seq RightOuterJoinIterator.new(:$left, :$right, :&condition)
}

=begin pod

=head2 C<lazy-left-semijoin($left, $right, &condition)>

    our sub lazy-left-semijoin($left, $right, &condition --> Seq)

Returns left rows that have at least one matching right row.

=end pod
our sub lazy-left-semijoin($left, $right, &condition) is export {
	lazy-seq LeftSemijoinIterator.new(:$left, :$right, :&condition)
}

=begin pod

=head2 C<lazy-left-antijoin($left, $right, &condition)>

    our sub lazy-left-antijoin($left, $right, &condition --> Seq)

Returns left rows that have no matching right row.

=end pod
our sub lazy-left-antijoin($left, $right, &condition) is export {
	lazy-seq LeftAntijoinIterator.new(:$left, :$right, :&condition)
}

=begin pod

=head2 C<lazy-cross-join($left, $right)>

    our sub lazy-cross-join($left, $right --> Seq)

Returns the Cartesian product of two row sources as merged rows.

=end pod
our sub lazy-cross-join($left, $right) is export {
	lazy-seq CrossJoinIterator.new(:$left, :$right)
}

=begin pod

=head2 C<lazy-union(+@sources)>

    our sub lazy-union(+@sources --> Seq)

Returns unique rows from each source in source order.

Seen-row tracking is identity/value aware through
L<Qwiratry::Query::Relational>, so duplicates are suppressed as rows are
pulled.

=end pod
our sub lazy-union(+@sources) is export {
	my Mu @prepared = @sources.map(-> $source {
		$source ~~ Seq ?? $source.cache !! $source
	});
	lazy-seq UnionIterator.new(sources => Array.new(@prepared))
}

=begin pod

=head2 C<lazy-intersection($left, $right)>

    our sub lazy-intersection($left, $right --> Seq)

Returns rows from C<$left> that are present in C<$right>.

=end pod
our sub lazy-intersection($left, $right) is export {
	lazy-seq IntersectionIterator.new(:$left, :$right)
}

=begin pod

=head2 C<lazy-set-difference($left, $right)>

    our sub lazy-set-difference($left, $right --> Seq)

Returns rows from C<$left> that are not present in C<$right>.

=end pod
our sub lazy-set-difference($left, $right) is export {
	lazy-seq SetDifferenceIterator.new(:$left, :$right)
}

=begin pod

=head2 C<lazy-symmetric-difference($left, $right)>

    our sub lazy-symmetric-difference($left, $right --> Seq)

Returns rows present in exactly one of the two sources.

This operation snapshots both sides before yielding because each side must be
compared against the other.

=end pod
our sub lazy-symmetric-difference($left, $right) is export {
	my @right-list = iterator-for($right).list;
	my @left-list = iterator-for($left).list;
	my @items = gather {
		for @left-list -> $row {
			unless relational.row-in-list($row, @right-list) {
				take $row;
			}
		}
		for @right-list -> $row {
			unless relational.row-in-list($row, @left-list) {
				take $row;
			}
		}
	};
	lazy-seq ListIterator.new(items => @items)
}

=begin pod

=head2 C<lazy-projection($rows, @columns)>

    our sub lazy-projection($rows, @columns --> Seq)

Returns rows projected to the requested columns, passing through
non-associative values unchanged.

=end pod
our sub lazy-projection($rows, @columns) is export {
	lazy-seq ProjectionIterator.new(:$rows, :@columns)
}

class FilterIterator does Iterator {
	has Iterator $!iter;
	has $!matcher;

	method BUILD(Iterator :$iter!, :$matcher!) {
		$!iter = $iter;
		$!matcher = $matcher;
	}

	method pull-one {
		loop {
			my $item = pull-next($!iter);
			$item ~~ IterationEnd and return IterationEnd;
			$!matcher($item) and return $item;
		}
	}
}

=begin pod

=head2 C<lazy-filter($source, &match)>

    our sub lazy-filter($source, &match --> Seq)

Returns items from C<$source> for which C<&match> is true.

=end pod
our sub lazy-filter($source, &match) is export {
	my $inner = iterator-for($source);
	lazy-seq FilterIterator.new(:iter($inner), :matcher(&match))
}

=begin pod

=head2 C<lazy-rename($rows, %renames)>

    our sub lazy-rename($rows, %renames --> Seq)

Returns rows with associative keys renamed according to C<%renames>, passing
through non-associative values unchanged.

=end pod
our sub lazy-rename($rows, %renames) is export {
	lazy-seq RenameIterator.new(:$rows, :%renames)
}

sub row-key(Mu $row --> Str) {
	if $row ~~ Associative {
		my @parts;
		for $row.keys.sort -> $key {
			@parts.push("$key=" ~($row{$key}));
		}
		return @parts.join('|');
	}
	$row ~~ Mu and return ~$row.WHICH;
	~$row
}
