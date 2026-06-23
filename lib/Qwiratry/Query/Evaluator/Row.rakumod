=begin pod

=head1 Overview

Lazy evaluators for row-shaping relational operators.

=end pod
unit module Qwiratry::Query::Evaluator::Row;

use Qwiratry::Operator::Set;
use Qwiratry::Query::Evaluator::Lazy;

role RowShapingEvaluator does LazyEvaluator {
	method project-row(Associative $row, @columns) {
		my %proj;
		for @columns -> $col {
			my $name = self!normalize-col-name($col);
			$row{$name}:exists and %proj{$name} = $row{$name};
		}
		%proj
	}

	method rename-row(Associative $row, %renames) {
		my %result = %($row);
		for %renames.pairs -> $p {
			if %result{$p.key}:exists {
				%result{$p.value} = %result.delete($p.key);
			}
		}
		%result
	}

	method !normalize-col-name(Mu $col --> Str) {
		$col ~~ Str and return $col;
		if $col ~~ List && $col.elems == 1 {
			return self!normalize-col-name($col[0]);
		}
		my $name = ~$col;
		$name.starts-with('<') && $name.ends-with('>') and $name = $name.substr(1, *-2);
		$name
	}
}

class ProjectionIterator does Iterator does RowShapingEvaluator is export {
	has Mu $.rows is required;
	has Mu @.columns is required;
	has Iterator $!iter;

	method pull-one {
		$!iter //= self.iterator-for($.rows);
		loop {
			my $row = self.pull-next($!iter);
			$row ~~ IterationEnd and return IterationEnd;
			return $row ~~ Associative ?? self.project-row($row, @.columns) !! $row;
		}
	}
}

class RenameIterator does Iterator does RowShapingEvaluator is export {
	has Mu $.rows is required;
	has %.renames is required;
	has Iterator $!iter;

	method pull-one {
		$!iter //= self.iterator-for($.rows);
		loop {
			my $row = self.pull-next($!iter);
			$row ~~ IterationEnd and return IterationEnd;
			return $row ~~ Associative ?? self.rename-row($row, %.renames) !! $row;
		}
	}
}

class ProjectionEvaluator does LazyEvaluator is export {
	method select-seq(ProjectionOperator $query, Mu $origin, :&relation-source! --> Seq) {
		self.lazy(
			relation-source($query.relation, $origin),
			$query.columns,
		)
	}

	method lazy($rows, @columns --> Seq) {
		self.seq-from-iterator(ProjectionIterator.new(:$rows, :@columns))
	}
}

class RenameEvaluator does LazyEvaluator is export {
	method select-seq(RenameOperator $query, Mu $origin, :&relation-source! --> Seq) {
		self.lazy(
			relation-source($query.relation, $origin),
			$query.renames,
		)
	}

	method lazy($rows, %renames --> Seq) {
		self.seq-from-iterator(RenameIterator.new(:$rows, :%renames))
	}
}
