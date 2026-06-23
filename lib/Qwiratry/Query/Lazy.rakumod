=begin pod

=head1 Overview

Compatibility facade for lazy query evaluators.

The evaluator modules own the operator-specific iterators and lazy mechanics.
This module preserves the existing exported constructor subs used by callers
that still depend on C<Qwiratry::Query::Lazy>.

=end pod
unit module Qwiratry::Query::Lazy;

use Qwiratry::Query::Evaluator::Lazy;
use Qwiratry::Query::Evaluator::Union;
use Qwiratry::Query::Evaluator::Set;
use Qwiratry::Query::Evaluator::Join;
use Qwiratry::Query::Evaluator::Row;
use Qwiratry::Query::Evaluator::Filter;

my constant lazy-evaluator = BasicLazyEvaluator.new;
my constant union-evaluator = UnionEvaluator.new;
my constant intersection-evaluator = IntersectionEvaluator.new;
my constant set-difference-evaluator = SetDifferenceEvaluator.new;
my constant symmetric-difference-evaluator = SymmetricDifferenceEvaluator.new;
my constant inner-join-evaluator = InnerJoinEvaluator.new;
my constant left-outer-join-evaluator = LeftOuterJoinEvaluator.new;
my constant right-outer-join-evaluator = RightOuterJoinEvaluator.new;
my constant left-semijoin-evaluator = LeftSemijoinEvaluator.new;
my constant left-antijoin-evaluator = LeftAntijoinEvaluator.new;
my constant cross-join-evaluator = CrossJoinEvaluator.new;
my constant projection-evaluator = ProjectionEvaluator.new;
my constant rename-evaluator = RenameEvaluator.new;
my constant selection-evaluator = SelectionEvaluator.new;

our sub lazy-from-list(@items --> Seq) is export {
	lazy-evaluator.lazy-from-list(@items)
}

our sub lazy-union(+@sources --> Seq) is export {
	union-evaluator.lazy(|@sources)
}

our sub lazy-intersection($left, $right --> Seq) is export {
	intersection-evaluator.lazy($left, $right)
}

our sub lazy-set-difference($left, $right --> Seq) is export {
	set-difference-evaluator.lazy($left, $right)
}

our sub lazy-symmetric-difference($left, $right --> Seq) is export {
	symmetric-difference-evaluator.lazy($left, $right)
}

our sub lazy-natural-join($left, $right, &condition --> Seq) is export {
	inner-join-evaluator.lazy($left, $right, &condition)
}

our sub lazy-left-outer-join($left, $right, &condition --> Seq) is export {
	left-outer-join-evaluator.lazy($left, $right, &condition)
}

our sub lazy-right-outer-join($left, $right, &condition --> Seq) is export {
	right-outer-join-evaluator.lazy($left, $right, &condition)
}

our sub lazy-left-semijoin($left, $right, &condition --> Seq) is export {
	left-semijoin-evaluator.lazy($left, $right, &condition)
}

our sub lazy-left-antijoin($left, $right, &condition --> Seq) is export {
	left-antijoin-evaluator.lazy($left, $right, &condition)
}

our sub lazy-cross-join($left, $right --> Seq) is export {
	cross-join-evaluator.lazy($left, $right)
}

our sub lazy-projection($rows, @columns --> Seq) is export {
	projection-evaluator.lazy($rows, @columns)
}

our sub lazy-rename($rows, %renames --> Seq) is export {
	rename-evaluator.lazy($rows, %renames)
}

our sub lazy-filter($source, &match --> Seq) is export {
	selection-evaluator.lazy($source, &match)
}
