=begin pod

=head1 Overview

Eager evaluators for relational predicate and division operators.

=end pod
unit module Qwiratry::Query::Evaluator::Relational;

use Qwiratry::Operator::Set;
use Qwiratry::Query::Evaluator::Eager;

role RelationalEagerEvaluator does RecursiveEagerEvaluator { }

class ElementOfEvaluator does RelationalEagerEvaluator is export {
	method eager(ElementOfOperator $query, Mu $origin --> List) {
		my @collection = self.select-list-for($query.collection, $origin);
		my @elements = self.select-list-for($query.element, $origin);
		my @results;
		for @elements -> $elem {
			self.relational.row-in-list($elem, @collection) and @results.push($elem);
		}
		@results
	}
}

class ContainsEvaluator does RelationalEagerEvaluator is export {
	method eager(ContainsOperator $query, Mu $origin --> List) {
		my @collection = self.select-list-for($query.collection, $origin);
		my @elements = self.select-list-for($query.element, $origin);
		@collection.grep(-> $row {
			@elements.grep(-> $elem { self.relational.row-equal($elem, $row) }).so
		}).List
	}
}

class SubsetEvaluator does RelationalEagerEvaluator is export {
	method eager(SubsetOperator $query, Mu $origin --> List) {
		my @left = self.select-list-for($query.left, $origin);
		my @right = self.select-list-for($query.right, $origin);
		self.relational.is-subset-of(@left, @right)
			&& !self.relational.collections-equal(@left, @right)
			?? @left.List !! ()
	}
}

class SubsetOrEqualEvaluator does RelationalEagerEvaluator is export {
	method eager(SubsetOrEqualOperator $query, Mu $origin --> List) {
		my @left = self.select-list-for($query.left, $origin);
		my @right = self.select-list-for($query.right, $origin);
		self.relational.is-subset-of(@left, @right) ?? @left.List !! ()
	}
}

class IdentityEvaluator does RelationalEagerEvaluator is export {
	method eager(IdentityOperator $query, Mu $origin --> List) {
		my @left = self.select-relation-for($query.left, $origin);
		my @right = self.select-relation-for($query.right, $origin);
		self.relational.collections-equal(@left, @right) ?? @left.List !! ()
	}
}

class DivisionEvaluator does RelationalEagerEvaluator is export {
	method eager(DivisionOperator $query, Mu $origin --> List) {
		my @left = self.select-relation-for($query.left, $origin);
		my @right = self.select-relation-for($query.right, $origin);
		self.relational.relational-division(@left, @right).List
	}
}
