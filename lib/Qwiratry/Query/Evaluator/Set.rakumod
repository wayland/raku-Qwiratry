=begin pod

=head1 Overview

Lazy evaluators for set operations other than union.

=end pod
unit module Qwiratry::Query::Evaluator::Set;

use Qwiratry::Operator::Set;
use Qwiratry::Query::Evaluator::Lazy;

=begin pod

=head2 C<class IntersectionIterator>

=begin code :lang<raku>
class IntersectionIterator does Iterator does LazyEvaluator is export
=end code

Defines C<IntersectionIterator>.

=end pod
class IntersectionIterator does Iterator does LazyEvaluator is export {
	has Mu $.left is required;
	has Mu $.right is required;
	has Iterator $!left-iter;
	has @!right-list;
	has Bool $!right-ready = False;

	=begin pod

	=head2 C<method pull-one>

	=begin code :lang<raku>
	method pull-one
	=end code

	Documents C<method pull-one>.

	=end pod
	method pull-one {
		$!left-iter //= self.iterator-for($.left);
		unless $!right-ready {
			@!right-list = self.source-list($.right);
			$!right-ready = True;
		}
		loop {
			my $lrow = self.pull-next($!left-iter);
			$lrow ~~ IterationEnd and return IterationEnd;
			self.relation-common.node-in-list($lrow, @!right-list) and return $lrow;
		}
	}
}

=begin pod

=head2 C<class SetDifferenceIterator>

=begin code :lang<raku>
class SetDifferenceIterator does Iterator does LazyEvaluator is export
=end code

Defines C<SetDifferenceIterator>.

=end pod
class SetDifferenceIterator does Iterator does LazyEvaluator is export {
	has Mu $.left is required;
	has Mu $.right is required;
	has Iterator $!left-iter;
	has @!right-list;
	has Bool $!right-ready = False;

	=begin pod

	=head2 C<method pull-one>

	=begin code :lang<raku>
	method pull-one
	=end code

	Documents C<method pull-one>.

	=end pod
	method pull-one {
		$!left-iter //= self.iterator-for($.left);
		unless $!right-ready {
			@!right-list = self.source-list($.right);
			$!right-ready = True;
		}
		loop {
			my $lrow = self.pull-next($!left-iter);
			$lrow ~~ IterationEnd and return IterationEnd;
			self.relation-common.row-in-list($lrow, @!right-list) or return $lrow;
		}
	}
}

=begin pod

=head2 C<class SymmetricDifferenceIterator>

=begin code :lang<raku>
class SymmetricDifferenceIterator does Iterator does LazyEvaluator is export
=end code

Defines C<SymmetricDifferenceIterator>.

=end pod
class SymmetricDifferenceIterator does Iterator does LazyEvaluator is export {
	has Mu $.left is required;
	has Mu $.right is required;
	has @!left-list;
	has @!right-list;
	has Bool $!ready = False;
	has Str $!phase = 'left';
	has Int $!idx = 0;

	# method !prepare
	#
	# Documents the private C<method !prepare> helper.
	method !prepare {
		$!ready and return;
		@!left-list = self.source-list($.left);
		@!right-list = self.source-list($.right);
		$!ready = True;
	}

	=begin pod

	=head2 C<method pull-one>

	=begin code :lang<raku>
	method pull-one
	=end code

	Documents C<method pull-one>.

	=end pod
	method pull-one {
		self!prepare;
		loop {
			if $!phase eq 'left' {
				if $!idx >= @!left-list {
					$!phase = 'right';
					$!idx = 0;
					next;
				}
				my $row = @!left-list[$!idx++];
				self.relation-common.row-in-list($row, @!right-list) or return $row;
				next;
			}

			$!idx >= @!right-list and return IterationEnd;
			my $row = @!right-list[$!idx++];
			self.relation-common.row-in-list($row, @!left-list) or return $row;
		}
	}
}

=begin pod

=head2 C<class IntersectionEvaluator>

=begin code :lang<raku>
class IntersectionEvaluator does LazyEvaluator is export
=end code

Defines C<IntersectionEvaluator>.

=end pod
class IntersectionEvaluator does LazyEvaluator is export {
	=begin pod

	=head2 C<method select-seq>

	=begin code :lang<raku>
	method select-seq(IntersectionOperator $query, Mu $origin, :&relation-source! --> Seq)
	=end code

	Documents C<method select-seq>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=item C<&relation-source>

	The C<&relation-source> parameter.

	=end pod
	method select-seq(IntersectionOperator $query, Mu $origin, :&relation-source! --> Seq) {
		self.lazy(
			relation-source($query.left, $origin),
			relation-source($query.right, $origin),
		)
	}

	=begin pod

	=head2 C<method topic-matches>

	=begin code :lang<raku>
	method topic-matches(IntersectionOperator $query, Mu $node, Mu :$origin, :&topic-matches! --> Bool)
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
	method topic-matches(IntersectionOperator $query, Mu $node, Mu :$origin, :&topic-matches! --> Bool) {
		topic-matches($query.left, $node, :$origin)
			&& topic-matches($query.right, $node, :$origin)
	}

	=begin pod

	=head2 C<method lazy>

	=begin code :lang<raku>
	method lazy($left, $right --> Seq)
	=end code

	Documents C<method lazy>.

	=item C<$left>

	The C<$left> parameter.

	=item C<$right>

	The C<$right> parameter.

	=end pod
	method lazy($left, $right --> Seq) {
		self.seq-from-iterator(IntersectionIterator.new(:$left, :$right))
	}
}

=begin pod

=head2 C<class SetDifferenceEvaluator>

=begin code :lang<raku>
class SetDifferenceEvaluator does LazyEvaluator is export
=end code

Defines C<SetDifferenceEvaluator>.

=end pod
class SetDifferenceEvaluator does LazyEvaluator is export {
	=begin pod

	=head2 C<method select-seq>

	=begin code :lang<raku>
	method select-seq(SetDifferenceOperator $query, Mu $origin, :&relation-source! --> Seq)
	=end code

	Documents C<method select-seq>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=item C<&relation-source>

	The C<&relation-source> parameter.

	=end pod
	method select-seq(SetDifferenceOperator $query, Mu $origin, :&relation-source! --> Seq) {
		self.lazy(
			relation-source($query.left, $origin),
			relation-source($query.right, $origin),
		)
	}

	=begin pod

	=head2 C<method topic-matches>

	=begin code :lang<raku>
	method topic-matches(SetDifferenceOperator $query, Mu $node, Mu :$origin, :&topic-matches! --> Bool)
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
	method topic-matches(SetDifferenceOperator $query, Mu $node, Mu :$origin, :&topic-matches! --> Bool) {
		topic-matches($query.left, $node, :$origin)
			&& !topic-matches($query.right, $node, :$origin)
	}

	=begin pod

	=head2 C<method lazy>

	=begin code :lang<raku>
	method lazy($left, $right --> Seq)
	=end code

	Documents C<method lazy>.

	=item C<$left>

	The C<$left> parameter.

	=item C<$right>

	The C<$right> parameter.

	=end pod
	method lazy($left, $right --> Seq) {
		self.seq-from-iterator(SetDifferenceIterator.new(:$left, :$right))
	}
}

=begin pod

=head2 C<class SymmetricDifferenceEvaluator>

=begin code :lang<raku>
class SymmetricDifferenceEvaluator does LazyEvaluator is export
=end code

Defines C<SymmetricDifferenceEvaluator>.

=end pod
class SymmetricDifferenceEvaluator does LazyEvaluator is export {
	=begin pod

	=head2 C<method select-seq>

	=begin code :lang<raku>
	method select-seq(SymmetricDifferenceOperator $query, Mu $origin, :&relation-source! --> Seq)
	=end code

	Documents C<method select-seq>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=item C<&relation-source>

	The C<&relation-source> parameter.

	=end pod
	method select-seq(SymmetricDifferenceOperator $query, Mu $origin, :&relation-source! --> Seq) {
		self.lazy(
			relation-source($query.left, $origin),
			relation-source($query.right, $origin),
		)
	}

	=begin pod

	=head2 C<method topic-matches>

	=begin code :lang<raku>
	method topic-matches(SymmetricDifferenceOperator $query, Mu $node, Mu :$origin, :&topic-matches! --> Bool)
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
	method topic-matches(SymmetricDifferenceOperator $query, Mu $node, Mu :$origin, :&topic-matches! --> Bool) {
		my $left = topic-matches($query.left, $node, :$origin);
		my $right = topic-matches($query.right, $node, :$origin);
		($left && !$right) || (!$left && $right)
	}

	=begin pod

	=head2 C<method lazy>

	=begin code :lang<raku>
	method lazy($left, $right --> Seq)
	=end code

	Documents C<method lazy>.

	=item C<$left>

	The C<$left> parameter.

	=item C<$right>

	The C<$right> parameter.

	=end pod
	method lazy($left, $right --> Seq) {
		self.seq-from-iterator(SymmetricDifferenceIterator.new(:$left, :$right))
	}
}
