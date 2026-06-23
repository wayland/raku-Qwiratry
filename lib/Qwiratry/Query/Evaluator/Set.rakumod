=begin pod

=head1 Overview

Lazy evaluators for set operations other than union.

=end pod
unit module Qwiratry::Query::Evaluator::Set;

use Qwiratry::Operator::Set;
use Qwiratry::Query::Evaluator::Lazy;

class IntersectionIterator does Iterator does LazyEvaluator is export {
	has Mu $.left is required;
	has Mu $.right is required;
	has Iterator $!left-iter;
	has @!right-list;
	has Bool $!right-ready = False;

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

class SetDifferenceIterator does Iterator does LazyEvaluator is export {
	has Mu $.left is required;
	has Mu $.right is required;
	has Iterator $!left-iter;
	has @!right-list;
	has Bool $!right-ready = False;

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

class IntersectionEvaluator does LazyEvaluator is export {
	method select-seq(IntersectionOperator $query, Mu $origin, :&relation-source! --> Seq) {
		self.lazy(
			relation-source($query.left, $origin),
			relation-source($query.right, $origin),
		)
	}

	method topic-matches(IntersectionOperator $query, Mu $node, Mu :$origin, :&topic-matches! --> Bool) {
		topic-matches($query.left, $node, :$origin)
			&& topic-matches($query.right, $node, :$origin)
	}

	method lazy($left, $right --> Seq) {
		self.seq-from-iterator(IntersectionIterator.new(:$left, :$right))
	}
}

class SetDifferenceEvaluator does LazyEvaluator is export {
	method select-seq(SetDifferenceOperator $query, Mu $origin, :&relation-source! --> Seq) {
		self.lazy(
			relation-source($query.left, $origin),
			relation-source($query.right, $origin),
		)
	}

	method topic-matches(SetDifferenceOperator $query, Mu $node, Mu :$origin, :&topic-matches! --> Bool) {
		topic-matches($query.left, $node, :$origin)
			&& !topic-matches($query.right, $node, :$origin)
	}

	method lazy($left, $right --> Seq) {
		self.seq-from-iterator(SetDifferenceIterator.new(:$left, :$right))
	}
}

class SymmetricDifferenceEvaluator does LazyEvaluator is export {
	method select-seq(SymmetricDifferenceOperator $query, Mu $origin, :&relation-source! --> Seq) {
		self.lazy(
			relation-source($query.left, $origin),
			relation-source($query.right, $origin),
		)
	}

	method topic-matches(SymmetricDifferenceOperator $query, Mu $node, Mu :$origin, :&topic-matches! --> Bool) {
		my $left = topic-matches($query.left, $node, :$origin);
		my $right = topic-matches($query.right, $node, :$origin);
		($left && !$right) || (!$left && $right)
	}

	method lazy($left, $right --> Seq) {
		my @right-list = self.source-list($right);
		my @left-list = self.source-list($left);
		my @items = gather {
			for @left-list -> $row {
				unless self.relation-common.row-in-list($row, @right-list) {
					take $row;
				}
			}
			for @right-list -> $row {
				unless self.relation-common.row-in-list($row, @left-list) {
					take $row;
				}
			}
		};
		self.lazy-from-list(@items)
	}
}
