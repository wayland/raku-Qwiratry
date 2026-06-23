=begin pod

=head1 Overview

Lazy evaluators for row-shaping relational operators.

=end pod
unit module Qwiratry::Query::Evaluator::Row;

use Qwiratry::Operator::Set;
use Qwiratry::Query::Evaluator::Lazy;

class ProjectionIterator does Iterator does LazyEvaluator is export {
	has Mu $.rows is required;
	has Mu @.columns is required;
	has Iterator $!iter;

	method pull-one {
		$!iter //= self.iterator-for($.rows);
		loop {
			my $row = self.pull-next($!iter);
			$row ~~ IterationEnd and return IterationEnd;
			return $row ~~ Associative ?? self.relational.project-row($row, @.columns) !! $row;
		}
	}
}

class RenameIterator does Iterator does LazyEvaluator is export {
	has Mu $.rows is required;
	has %.renames is required;
	has Iterator $!iter;

	method pull-one {
		$!iter //= self.iterator-for($.rows);
		loop {
			my $row = self.pull-next($!iter);
			$row ~~ IterationEnd and return IterationEnd;
			return $row ~~ Associative ?? self.relational.rename-row($row, %.renames) !! $row;
		}
	}
}

class ProjectionEvaluator does LazyEvaluator is export {
	method select-seq(ProjectionOperator $query, Mu $origin, :&relation-source! --> Seq) {
		self.lazy-projection(
			relation-source($query.relation, $origin),
			$query.columns,
		)
	}

	method lazy-projection($rows, @columns --> Seq) {
		self.lazy-seq(ProjectionIterator.new(:$rows, :@columns))
	}
}

class RenameEvaluator does LazyEvaluator is export {
	method select-seq(RenameOperator $query, Mu $origin, :&relation-source! --> Seq) {
		self.lazy-rename(
			relation-source($query.relation, $origin),
			$query.renames,
		)
	}

	method lazy-rename($rows, %renames --> Seq) {
		self.lazy-seq(RenameIterator.new(:$rows, :%renames))
	}
}
