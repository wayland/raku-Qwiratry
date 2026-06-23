=begin pod

=head1 Overview

Lazy evaluators for relational join operators.

=end pod
unit module Qwiratry::Query::Evaluator::Join;

use Qwiratry::Operator::Set;
use Qwiratry::Query::Evaluator::Lazy;
use Qwiratry::Query::Evaluator::Union;

my constant union-evaluator = UnionEvaluator.new;

=begin pod

=head2 C<role JoinIteratorBase>

=begin code :lang<raku>
role JoinIteratorBase does LazyEvaluator
=end code

Defines C<JoinIteratorBase>.

=end pod
role JoinIteratorBase does LazyEvaluator {
	has Mu $.left is required;
	has Mu $.right is required;
	has &.condition;

	=begin pod

	=head2 C<method rows-match>

	=begin code :lang<raku>
	method rows-match(Mu $left, Mu $right --> Bool)
	=end code

	Documents C<method rows-match>.

	=item C<$left>

	The C<$left> parameter.

	=item C<$right>

	The C<$right> parameter.

	=end pod
	method rows-match(Mu $left, Mu $right --> Bool) {
		&!condition.defined
			?? &!condition($left, $right)
			!! self.relation-common.join-on-common-keys($left, $right)
	}

	=begin pod

	=head2 C<method merge-rows>

	=begin code :lang<raku>
	method merge-rows(Associative $left, Associative $right --> Hash)
	=end code

	Documents C<method merge-rows>.

	=item C<$left>

	The C<$left> parameter.

	=item C<$right>

	The C<$right> parameter.

	=end pod
	method merge-rows(Associative $left, Associative $right --> Hash) {
		self.relation-common.merge-rows($left, $right)
	}
}

=begin pod

=head2 C<class NaturalJoinIterator>

=begin code :lang<raku>
class NaturalJoinIterator does Iterator does JoinIteratorBase is export
=end code

Defines C<NaturalJoinIterator>.

=end pod
class NaturalJoinIterator does Iterator does JoinIteratorBase is export {
	has Iterator $!left-iter;
	has Mu $!current-left;
	has Iterator $!right-iter;

	=begin pod

	=head2 C<method pull-one>

	=begin code :lang<raku>
	method pull-one
	=end code

	Documents C<method pull-one>.

	=end pod
	method pull-one {
		loop {
			unless $!current-left.defined {
				$!left-iter //= self.iterator-for($.left);
				$!current-left = self.pull-next($!left-iter);
				$!current-left ~~ IterationEnd and return IterationEnd;
				next unless $!current-left ~~ Associative;
				$!right-iter = self.iterator-for($.right);
			}
			my $rrow = self.pull-next($!right-iter);
			if $rrow ~~ IterationEnd {
				$!current-left = Nil;
				$!right-iter = Nil;
				next;
			}
			next unless $rrow ~~ Associative;
			self.rows-match($!current-left, $rrow)
				and return self.merge-rows($!current-left, $rrow);
		}
	}
}

=begin pod

=head2 C<class LeftOuterJoinIterator>

=begin code :lang<raku>
class LeftOuterJoinIterator does Iterator does JoinIteratorBase is export
=end code

Defines C<LeftOuterJoinIterator>.

=end pod
class LeftOuterJoinIterator does Iterator does JoinIteratorBase is export {
	has Iterator $!left-iter;
	has Mu $!current-left;
	has Iterator $!right-iter;
	has @!pending;

	=begin pod

	=head2 C<method pull-one>

	=begin code :lang<raku>
	method pull-one
	=end code

	Documents C<method pull-one>.

	=end pod
	method pull-one {
		@!pending and return @!pending.shift;
		loop {
			$!left-iter //= self.iterator-for($.left);
			$!current-left = self.pull-next($!left-iter);
			$!current-left ~~ IterationEnd and return IterationEnd;

			my @matches;
			$!right-iter = self.iterator-for($.right);
			loop {
				my $rrow = self.pull-next($!right-iter);
				last if $rrow ~~ IterationEnd;
				self.rows-match($!current-left, $rrow)
					and @matches.push(self.merge-rows($!current-left, $rrow));
			}
			if @matches {
				@!pending = @matches;
				return @!pending.shift;
			}
			return %($!current-left);
		}
	}
}

=begin pod

=head2 C<class RightOuterJoinIterator>

=begin code :lang<raku>
class RightOuterJoinIterator does Iterator does JoinIteratorBase is export
=end code

Defines C<RightOuterJoinIterator>.

=end pod
class RightOuterJoinIterator does Iterator does JoinIteratorBase is export {
	has Iterator $!right-iter;
	has Mu $!current-right;
	has Iterator $!left-iter;
	has @!pending;

	=begin pod

	=head2 C<method pull-one>

	=begin code :lang<raku>
	method pull-one
	=end code

	Documents C<method pull-one>.

	=end pod
	method pull-one {
		@!pending and return @!pending.shift;
		loop {
			$!right-iter //= self.iterator-for($.right);
			$!current-right = self.pull-next($!right-iter);
			$!current-right ~~ IterationEnd and return IterationEnd;

			my @matches;
			$!left-iter = self.iterator-for($.left);
			loop {
				my $lrow = self.pull-next($!left-iter);
				last if $lrow ~~ IterationEnd;
				self.rows-match($lrow, $!current-right)
					and @matches.push(self.merge-rows($lrow, $!current-right));
			}
			if @matches {
				@!pending = @matches;
				return @!pending.shift;
			}
			return %($!current-right);
		}
	}
}

=begin pod

=head2 C<class LeftSemijoinIterator>

=begin code :lang<raku>
class LeftSemijoinIterator does Iterator does JoinIteratorBase is export
=end code

Defines C<LeftSemijoinIterator>.

=end pod
class LeftSemijoinIterator does Iterator does JoinIteratorBase is export {
	has Iterator $!left-iter;

	=begin pod

	=head2 C<method pull-one>

	=begin code :lang<raku>
	method pull-one
	=end code

	Documents C<method pull-one>.

	=end pod
	method pull-one {
		$!left-iter //= self.iterator-for($.left);
		loop {
			my $lrow = self.pull-next($!left-iter);
			$lrow ~~ IterationEnd and return IterationEnd;
			my $right-iter = self.iterator-for($.right);
			loop {
				my $rrow = self.pull-next($right-iter);
				last if $rrow ~~ IterationEnd;
				self.rows-match($lrow, $rrow) and return %($lrow);
			}
		}
	}
}

=begin pod

=head2 C<class LeftAntijoinIterator>

=begin code :lang<raku>
class LeftAntijoinIterator does Iterator does JoinIteratorBase is export
=end code

Defines C<LeftAntijoinIterator>.

=end pod
class LeftAntijoinIterator does Iterator does JoinIteratorBase is export {
	has Iterator $!left-iter;

	=begin pod

	=head2 C<method pull-one>

	=begin code :lang<raku>
	method pull-one
	=end code

	Documents C<method pull-one>.

	=end pod
	method pull-one {
		$!left-iter //= self.iterator-for($.left);
		loop {
			my $lrow = self.pull-next($!left-iter);
			$lrow ~~ IterationEnd and return IterationEnd;
			my $matched = False;
			my $right-iter = self.iterator-for($.right);
			loop {
				my $rrow = self.pull-next($right-iter);
				last if $rrow ~~ IterationEnd;
				if self.rows-match($lrow, $rrow) {
					$matched = True;
					last;
				}
			}
			$matched or return %($lrow);
		}
	}
}

=begin pod

=head2 C<class CrossJoinIterator>

=begin code :lang<raku>
class CrossJoinIterator does Iterator does JoinIteratorBase is export
=end code

Defines C<CrossJoinIterator>.

=end pod
class CrossJoinIterator does Iterator does JoinIteratorBase is export {
	has Iterator $!left-iter;
	has Mu $!current-left;
	has Iterator $!right-iter;

	=begin pod

	=head2 C<method pull-one>

	=begin code :lang<raku>
	method pull-one
	=end code

	Documents C<method pull-one>.

	=end pod
	method pull-one {
		loop {
			unless $!current-left.defined {
				$!left-iter //= self.iterator-for($.left);
				$!current-left = self.pull-next($!left-iter);
				$!current-left ~~ IterationEnd and return IterationEnd;
				$!right-iter = self.iterator-for($.right);
			}
			my $rrow = self.pull-next($!right-iter);
			if $rrow ~~ IterationEnd {
				$!current-left = Nil;
				$!right-iter = Nil;
				next;
			}
			return self.merge-rows($!current-left, $rrow);
		}
	}
}

=begin pod

=head2 C<role JoinEvaluator>

=begin code :lang<raku>
role JoinEvaluator does LazyEvaluator
=end code

Defines C<JoinEvaluator>.

=end pod
role JoinEvaluator does LazyEvaluator {
	=begin pod

	=head2 C<method condition-for>

	=begin code :lang<raku>
	method condition-for(Mu $query)
	=end code

	Documents C<method condition-for>.

	=item C<$query>

	The C<$query> parameter.

	=end pod
	method condition-for(Mu $query) {
		$query.condition.defined ?? $query.condition !! Nil
	}
}

=begin pod

=head2 C<class InnerJoinEvaluator>

=begin code :lang<raku>
class InnerJoinEvaluator does JoinEvaluator is export
=end code

Defines C<InnerJoinEvaluator>.

=end pod
class InnerJoinEvaluator does JoinEvaluator is export {
	=begin pod

	=head2 C<method select-seq>

	=begin code :lang<raku>
	method select-seq(InnerJoinOperator $query, Mu $origin, :&relation-source! --> Seq)
	=end code

	Documents C<method select-seq>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=item C<&relation-source>

	The C<&relation-source> parameter.

	=end pod
	method select-seq(InnerJoinOperator $query, Mu $origin, :&relation-source! --> Seq) {
		my &cond = self.condition-for($query);
		self.lazy(
			relation-source($query.left, $origin),
			relation-source($query.right, $origin),
			&cond,
		)
	}

	=begin pod

	=head2 C<method lazy>

	=begin code :lang<raku>
	method lazy($left, $right, &condition --> Seq)
	=end code

	Documents C<method lazy>.

	=item C<$left>

	The C<$left> parameter.

	=item C<$right>

	The C<$right> parameter.

	=item C<&condition>

	The C<&condition> parameter.

	=end pod
	method lazy($left, $right, &condition --> Seq) {
		self.seq-from-iterator(NaturalJoinIterator.new(:$left, :$right, :&condition))
	}
}

=begin pod

=head2 C<class LeftOuterJoinEvaluator>

=begin code :lang<raku>
class LeftOuterJoinEvaluator does JoinEvaluator is export
=end code

Defines C<LeftOuterJoinEvaluator>.

=end pod
class LeftOuterJoinEvaluator does JoinEvaluator is export {
	=begin pod

	=head2 C<method select-seq>

	=begin code :lang<raku>
	method select-seq(LeftOuterJoinOperator $query, Mu $origin, :&relation-source! --> Seq)
	=end code

	Documents C<method select-seq>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=item C<&relation-source>

	The C<&relation-source> parameter.

	=end pod
	method select-seq(LeftOuterJoinOperator $query, Mu $origin, :&relation-source! --> Seq) {
		my &cond = self.condition-for($query);
		self.lazy(
			relation-source($query.left, $origin),
			relation-source($query.right, $origin),
			&cond,
		)
	}

	=begin pod

	=head2 C<method lazy>

	=begin code :lang<raku>
	method lazy($left, $right, &condition --> Seq)
	=end code

	Documents C<method lazy>.

	=item C<$left>

	The C<$left> parameter.

	=item C<$right>

	The C<$right> parameter.

	=item C<&condition>

	The C<&condition> parameter.

	=end pod
	method lazy($left, $right, &condition --> Seq) {
		self.seq-from-iterator(LeftOuterJoinIterator.new(:$left, :$right, :&condition))
	}
}

=begin pod

=head2 C<class RightOuterJoinEvaluator>

=begin code :lang<raku>
class RightOuterJoinEvaluator does JoinEvaluator is export
=end code

Defines C<RightOuterJoinEvaluator>.

=end pod
class RightOuterJoinEvaluator does JoinEvaluator is export {
	=begin pod

	=head2 C<method select-seq>

	=begin code :lang<raku>
	method select-seq(RightOuterJoinOperator $query, Mu $origin, :&relation-source! --> Seq)
	=end code

	Documents C<method select-seq>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=item C<&relation-source>

	The C<&relation-source> parameter.

	=end pod
	method select-seq(RightOuterJoinOperator $query, Mu $origin, :&relation-source! --> Seq) {
		my &cond = self.condition-for($query);
		self.lazy(
			relation-source($query.left, $origin),
			relation-source($query.right, $origin),
			&cond,
		)
	}

	=begin pod

	=head2 C<method lazy>

	=begin code :lang<raku>
	method lazy($left, $right, &condition --> Seq)
	=end code

	Documents C<method lazy>.

	=item C<$left>

	The C<$left> parameter.

	=item C<$right>

	The C<$right> parameter.

	=item C<&condition>

	The C<&condition> parameter.

	=end pod
	method lazy($left, $right, &condition --> Seq) {
		self.seq-from-iterator(RightOuterJoinIterator.new(:$left, :$right, :&condition))
	}
}

=begin pod

=head2 C<class LeftSemijoinEvaluator>

=begin code :lang<raku>
class LeftSemijoinEvaluator does JoinEvaluator is export
=end code

Defines C<LeftSemijoinEvaluator>.

=end pod
class LeftSemijoinEvaluator does JoinEvaluator is export {
	=begin pod

	=head2 C<method select-seq>

	=begin code :lang<raku>
	method select-seq(LeftSemijoinOperator $query, Mu $origin, :&relation-source! --> Seq)
	=end code

	Documents C<method select-seq>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=item C<&relation-source>

	The C<&relation-source> parameter.

	=end pod
	method select-seq(LeftSemijoinOperator $query, Mu $origin, :&relation-source! --> Seq) {
		my &cond = self.condition-for($query);
		self.lazy(
			relation-source($query.left, $origin),
			relation-source($query.right, $origin),
			&cond,
		)
	}

	=begin pod

	=head2 C<method lazy>

	=begin code :lang<raku>
	method lazy($left, $right, &condition --> Seq)
	=end code

	Documents C<method lazy>.

	=item C<$left>

	The C<$left> parameter.

	=item C<$right>

	The C<$right> parameter.

	=item C<&condition>

	The C<&condition> parameter.

	=end pod
	method lazy($left, $right, &condition --> Seq) {
		self.seq-from-iterator(LeftSemijoinIterator.new(:$left, :$right, :&condition))
	}
}

=begin pod

=head2 C<class RightSemijoinEvaluator>

=begin code :lang<raku>
class RightSemijoinEvaluator does JoinEvaluator is export
=end code

Defines C<RightSemijoinEvaluator>.

=end pod
class RightSemijoinEvaluator does JoinEvaluator is export {
	=begin pod

	=head2 C<method select-seq>

	=begin code :lang<raku>
	method select-seq(RightSemijoinOperator $query, Mu $origin, :&relation-source! --> Seq)
	=end code

	Documents C<method select-seq>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=item C<&relation-source>

	The C<&relation-source> parameter.

	=end pod
	method select-seq(RightSemijoinOperator $query, Mu $origin, :&relation-source! --> Seq) {
		my &cond = self.condition-for($query);
		self.lazy(
			relation-source($query.right, $origin),
			relation-source($query.left, $origin),
			&cond,
		)
	}

	=begin pod

	=head2 C<method lazy>

	=begin code :lang<raku>
	method lazy($left, $right, &condition --> Seq)
	=end code

	Documents C<method lazy>.

	=item C<$left>

	The C<$left> parameter.

	=item C<$right>

	The C<$right> parameter.

	=item C<&condition>

	The C<&condition> parameter.

	=end pod
	method lazy($left, $right, &condition --> Seq) {
		self.seq-from-iterator(LeftSemijoinIterator.new(:$left, :$right, :&condition))
	}
}

=begin pod

=head2 C<class LeftAntijoinEvaluator>

=begin code :lang<raku>
class LeftAntijoinEvaluator does JoinEvaluator is export
=end code

Defines C<LeftAntijoinEvaluator>.

=end pod
class LeftAntijoinEvaluator does JoinEvaluator is export {
	=begin pod

	=head2 C<method select-seq>

	=begin code :lang<raku>
	method select-seq(LeftAntijoinOperator $query, Mu $origin, :&relation-source! --> Seq)
	=end code

	Documents C<method select-seq>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=item C<&relation-source>

	The C<&relation-source> parameter.

	=end pod
	method select-seq(LeftAntijoinOperator $query, Mu $origin, :&relation-source! --> Seq) {
		my &cond = self.condition-for($query);
		self.lazy(
			relation-source($query.left, $origin),
			relation-source($query.right, $origin),
			&cond,
		)
	}

	=begin pod

	=head2 C<method lazy>

	=begin code :lang<raku>
	method lazy($left, $right, &condition --> Seq)
	=end code

	Documents C<method lazy>.

	=item C<$left>

	The C<$left> parameter.

	=item C<$right>

	The C<$right> parameter.

	=item C<&condition>

	The C<&condition> parameter.

	=end pod
	method lazy($left, $right, &condition --> Seq) {
		self.seq-from-iterator(LeftAntijoinIterator.new(:$left, :$right, :&condition))
	}
}

=begin pod

=head2 C<class RightAntijoinEvaluator>

=begin code :lang<raku>
class RightAntijoinEvaluator does JoinEvaluator is export
=end code

Defines C<RightAntijoinEvaluator>.

=end pod
class RightAntijoinEvaluator does JoinEvaluator is export {
	=begin pod

	=head2 C<method select-seq>

	=begin code :lang<raku>
	method select-seq(RightAntijoinOperator $query, Mu $origin, :&relation-source! --> Seq)
	=end code

	Documents C<method select-seq>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=item C<&relation-source>

	The C<&relation-source> parameter.

	=end pod
	method select-seq(RightAntijoinOperator $query, Mu $origin, :&relation-source! --> Seq) {
		my &cond = self.condition-for($query);
		self.lazy(
			relation-source($query.right, $origin),
			relation-source($query.left, $origin),
			&cond,
		)
	}

	=begin pod

	=head2 C<method lazy>

	=begin code :lang<raku>
	method lazy($left, $right, &condition --> Seq)
	=end code

	Documents C<method lazy>.

	=item C<$left>

	The C<$left> parameter.

	=item C<$right>

	The C<$right> parameter.

	=item C<&condition>

	The C<&condition> parameter.

	=end pod
	method lazy($left, $right, &condition --> Seq) {
		self.seq-from-iterator(LeftAntijoinIterator.new(:$left, :$right, :&condition))
	}
}

=begin pod

=head2 C<class FullOuterJoinEvaluator>

=begin code :lang<raku>
class FullOuterJoinEvaluator does JoinEvaluator is export
=end code

Defines C<FullOuterJoinEvaluator>.

=end pod
class FullOuterJoinEvaluator does JoinEvaluator is export {
	=begin pod

	=head2 C<method select-seq>

	=begin code :lang<raku>
	method select-seq(FullOuterJoinOperator $query, Mu $origin, :&relation-source! --> Seq)
	=end code

	Documents C<method select-seq>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=item C<&relation-source>

	The C<&relation-source> parameter.

	=end pod
	method select-seq(FullOuterJoinOperator $query, Mu $origin, :&relation-source! --> Seq) {
		my &cond = self.condition-for($query);
		my $left = relation-source($query.left, $origin);
		my $right = relation-source($query.right, $origin);
		self.lazy($left, $right, &cond)
	}

	=begin pod

	=head2 C<method lazy>

	=begin code :lang<raku>
	method lazy($left, $right, &condition --> Seq)
	=end code

	Documents C<method lazy>.

	=item C<$left>

	The C<$left> parameter.

	=item C<$right>

	The C<$right> parameter.

	=item C<&condition>

	The C<&condition> parameter.

	=end pod
	method lazy($left, $right, &condition --> Seq) {
		my $inner = InnerJoinEvaluator.new;
		my $left-anti = LeftAntijoinEvaluator.new;
		union-evaluator.lazy(
			$inner.lazy($left, $right, &condition),
			$left-anti.lazy($left, $right, &condition),
			$left-anti.lazy($right, $left, &condition),
		)
	}
}

=begin pod

=head2 C<class CrossJoinEvaluator>

=begin code :lang<raku>
class CrossJoinEvaluator does JoinEvaluator is export
=end code

Defines C<CrossJoinEvaluator>.

=end pod
class CrossJoinEvaluator does JoinEvaluator is export {
	=begin pod

	=head2 C<method select-seq>

	=begin code :lang<raku>
	method select-seq(CrossJoinOperator $query, Mu $origin, :&relation-source! --> Seq)
	=end code

	Documents C<method select-seq>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=item C<&relation-source>

	The C<&relation-source> parameter.

	=end pod
	method select-seq(CrossJoinOperator $query, Mu $origin, :&relation-source! --> Seq) {
		self.lazy(
			relation-source($query.left, $origin),
			relation-source($query.right, $origin),
		)
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
		self.seq-from-iterator(CrossJoinIterator.new(:$left, :$right))
	}
}
