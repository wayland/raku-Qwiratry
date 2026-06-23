=begin pod

=head1 Overview

Lazy evaluators for relational join operators.

=end pod
unit module Qwiratry::Query::Evaluator::Join;

use Qwiratry::Operator::Set;
use Qwiratry::Query::Evaluator::Lazy;
use Qwiratry::Query::Evaluator::Union;

my constant union-evaluator = UnionEvaluator.new;

class NaturalJoinIterator does Iterator does LazyEvaluator is export {
	has Mu $.left is required;
	has Mu $.right is required;
	has &.condition;
	has Iterator $!left-iter;
	has Mu $!current-left;
	has Iterator $!right-iter;

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
			my $matches = &!condition.defined
				?? &!condition($!current-left, $rrow)
				!! self.relational.join-on-common-keys($!current-left, $rrow);
			$matches and return self.relational.merge-rows($!current-left, $rrow);
		}
	}
}

class LeftOuterJoinIterator does Iterator does LazyEvaluator is export {
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
			$!left-iter //= self.iterator-for($.left);
			$!current-left = self.pull-next($!left-iter);
			$!current-left ~~ IterationEnd and return IterationEnd;

			my @matches;
			$!right-iter = self.iterator-for($.right);
			loop {
				my $rrow = self.pull-next($!right-iter);
				last if $rrow ~~ IterationEnd;
				my $ok = &!condition.defined
					?? &!condition($!current-left, $rrow)
					!! self.relational.join-on-common-keys($!current-left, $rrow);
				$ok and @matches.push(self.relational.merge-rows($!current-left, $rrow));
			}
			if @matches {
				@!pending = @matches;
				return @!pending.shift;
			}
			return %($!current-left);
		}
	}
}

class RightOuterJoinIterator does Iterator does LazyEvaluator is export {
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
			$!right-iter //= self.iterator-for($.right);
			$!current-right = self.pull-next($!right-iter);
			$!current-right ~~ IterationEnd and return IterationEnd;

			my @matches;
			$!left-iter = self.iterator-for($.left);
			loop {
				my $lrow = self.pull-next($!left-iter);
				last if $lrow ~~ IterationEnd;
				my $ok = &!condition.defined
					?? &!condition($lrow, $!current-right)
					!! self.relational.join-on-common-keys($lrow, $!current-right);
				$ok and @matches.push(self.relational.merge-rows($lrow, $!current-right));
			}
			if @matches {
				@!pending = @matches;
				return @!pending.shift;
			}
			return %($!current-right);
		}
	}
}

class LeftSemijoinIterator does Iterator does LazyEvaluator is export {
	has Mu $.left is required;
	has Mu $.right is required;
	has &.condition;
	has Iterator $!left-iter;

	method pull-one {
		$!left-iter //= self.iterator-for($.left);
		loop {
			my $lrow = self.pull-next($!left-iter);
			$lrow ~~ IterationEnd and return IterationEnd;
			my $right-iter = self.iterator-for($.right);
			loop {
				my $rrow = self.pull-next($right-iter);
				last if $rrow ~~ IterationEnd;
				my $ok = &!condition.defined
					?? &!condition($lrow, $rrow)
					!! self.relational.join-on-common-keys($lrow, $rrow);
				$ok and return %($lrow);
			}
		}
	}
}

class LeftAntijoinIterator does Iterator does LazyEvaluator is export {
	has Mu $.left is required;
	has Mu $.right is required;
	has &.condition;
	has Iterator $!left-iter;

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
				my $ok = &!condition.defined
					?? &!condition($lrow, $rrow)
					!! self.relational.join-on-common-keys($lrow, $rrow);
				if $ok {
					$matched = True;
					last;
				}
			}
			$matched or return %($lrow);
		}
	}
}

class CrossJoinIterator does Iterator does LazyEvaluator is export {
	has Mu $.left is required;
	has Mu $.right is required;
	has Iterator $!left-iter;
	has Mu $!current-left;
	has Iterator $!right-iter;

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
			return self.relational.merge-rows($!current-left, $rrow);
		}
	}
}

role JoinEvaluator does LazyEvaluator {
	method condition-for(Mu $query) {
		$query.condition.defined ?? $query.condition !! Nil
	}

	method lazy-natural-join($left, $right, &condition --> Seq) {
		self.lazy-seq(NaturalJoinIterator.new(:$left, :$right, :&condition))
	}

	method lazy-left-outer-join($left, $right, &condition --> Seq) {
		self.lazy-seq(LeftOuterJoinIterator.new(:$left, :$right, :&condition))
	}

	method lazy-right-outer-join($left, $right, &condition --> Seq) {
		self.lazy-seq(RightOuterJoinIterator.new(:$left, :$right, :&condition))
	}

	method lazy-left-semijoin($left, $right, &condition --> Seq) {
		self.lazy-seq(LeftSemijoinIterator.new(:$left, :$right, :&condition))
	}

	method lazy-left-antijoin($left, $right, &condition --> Seq) {
		self.lazy-seq(LeftAntijoinIterator.new(:$left, :$right, :&condition))
	}

	method lazy-cross-join($left, $right --> Seq) {
		self.lazy-seq(CrossJoinIterator.new(:$left, :$right))
	}
}

class InnerJoinEvaluator does JoinEvaluator is export {
	method select-seq(InnerJoinOperator $query, Mu $origin, :&relation-source! --> Seq) {
		my &cond = self.condition-for($query);
		self.lazy-natural-join(
			relation-source($query.left, $origin),
			relation-source($query.right, $origin),
			&cond,
		)
	}
}

class LeftOuterJoinEvaluator does JoinEvaluator is export {
	method select-seq(LeftOuterJoinOperator $query, Mu $origin, :&relation-source! --> Seq) {
		my &cond = self.condition-for($query);
		self.lazy-left-outer-join(
			relation-source($query.left, $origin),
			relation-source($query.right, $origin),
			&cond,
		)
	}
}

class RightOuterJoinEvaluator does JoinEvaluator is export {
	method select-seq(RightOuterJoinOperator $query, Mu $origin, :&relation-source! --> Seq) {
		my &cond = self.condition-for($query);
		self.lazy-right-outer-join(
			relation-source($query.left, $origin),
			relation-source($query.right, $origin),
			&cond,
		)
	}
}

class FullOuterJoinEvaluator does JoinEvaluator is export {
	method select-seq(FullOuterJoinOperator $query, Mu $origin, :&relation-source! --> Seq) {
		my &cond = self.condition-for($query);
		my $left = relation-source($query.left, $origin);
		my $right = relation-source($query.right, $origin);
		union-evaluator.lazy-union(
			self.lazy-natural-join($left, $right, &cond),
			self.lazy-left-antijoin($left, $right, &cond),
			self.lazy-left-antijoin($right, $left, &cond),
		)
	}
}

class LeftSemijoinEvaluator does JoinEvaluator is export {
	method select-seq(LeftSemijoinOperator $query, Mu $origin, :&relation-source! --> Seq) {
		my &cond = self.condition-for($query);
		self.lazy-left-semijoin(
			relation-source($query.left, $origin),
			relation-source($query.right, $origin),
			&cond,
		)
	}
}

class RightSemijoinEvaluator does JoinEvaluator is export {
	method select-seq(RightSemijoinOperator $query, Mu $origin, :&relation-source! --> Seq) {
		my &cond = self.condition-for($query);
		self.lazy-left-semijoin(
			relation-source($query.right, $origin),
			relation-source($query.left, $origin),
			&cond,
		)
	}
}

class LeftAntijoinEvaluator does JoinEvaluator is export {
	method select-seq(LeftAntijoinOperator $query, Mu $origin, :&relation-source! --> Seq) {
		my &cond = self.condition-for($query);
		self.lazy-left-antijoin(
			relation-source($query.left, $origin),
			relation-source($query.right, $origin),
			&cond,
		)
	}
}

class RightAntijoinEvaluator does JoinEvaluator is export {
	method select-seq(RightAntijoinOperator $query, Mu $origin, :&relation-source! --> Seq) {
		my &cond = self.condition-for($query);
		self.lazy-left-antijoin(
			relation-source($query.right, $origin),
			relation-source($query.left, $origin),
			&cond,
		)
	}
}

class CrossJoinEvaluator does JoinEvaluator is export {
	method select-seq(CrossJoinOperator $query, Mu $origin, :&relation-source! --> Seq) {
		self.lazy-cross-join(
			relation-source($query.left, $origin),
			relation-source($query.right, $origin),
		)
	}
}
