=begin pod

=head1 Overview

Eager evaluators for relational predicate and division operators.

=end pod
unit module Qwiratry::Query::Evaluator::Relational;

use Qwiratry::Operator::Set;
use Qwiratry::Query::Evaluator::Eager;

role RelationalEagerEvaluator does RecursiveEagerEvaluator {
	method is-subset-of(@left, @right --> Bool) {
		for @left -> $lrow {
			self.relation-common.row-in-list($lrow, @right) or return False;
		}
		True
	}

	method collections-equal(@left, @right --> Bool) {
		@left.elems == @right.elems or return False;
		for @left -> $lrow {
			self.relation-common.row-in-list($lrow, @right) or return False;
		}
		True
	}

	method relational-division(@left, @right) {
		@right or return ();
		my @result;
		for @left -> $candidate {
			my $ok = True;
			for @right -> $rrow {
				my $found = @left.grep(-> $lrow {
					self.relation-common.row-equal($lrow, $candidate) || (
						self.relation-common.common-keys($lrow, $rrow).so
						&& self.relation-common.join-on-common-keys($lrow, $rrow)
					)
				}).so;
				unless $found {
					$ok = False;
					last;
				}
			}
			$ok and @result.push($candidate);
		}
		@result
	}
}

class ElementOfEvaluator does RelationalEagerEvaluator is export {
	method eager(ElementOfOperator $query, Mu $origin --> List) {
		my @collection = self.select-list-for($query.collection, $origin);
		my @elements = self.select-list-for($query.element, $origin);
		my @results;
		for @elements -> $elem {
			self.relation-common.row-in-list($elem, @collection) and @results.push($elem);
		}
		@results
	}
}

class ContainsEvaluator does RelationalEagerEvaluator is export {
	method eager(ContainsOperator $query, Mu $origin --> List) {
		my @collection = self.select-list-for($query.collection, $origin);
		my @elements = self.select-list-for($query.element, $origin);
		@collection.grep(-> $row {
			@elements.grep(-> $elem { self.relation-common.row-equal($elem, $row) }).so
		}).List
	}
}

class SubsetEvaluator does RelationalEagerEvaluator is export {
	method eager(SubsetOperator $query, Mu $origin --> List) {
		my @left = self.select-list-for($query.left, $origin);
		my @right = self.select-list-for($query.right, $origin);
		self.is-subset-of(@left, @right)
			&& !self.collections-equal(@left, @right)
			?? @left.List !! ()
	}
}

class SubsetOrEqualEvaluator does RelationalEagerEvaluator is export {
	method eager(SubsetOrEqualOperator $query, Mu $origin --> List) {
		my @left = self.select-list-for($query.left, $origin);
		my @right = self.select-list-for($query.right, $origin);
		self.is-subset-of(@left, @right) ?? @left.List !! ()
	}
}

class IdentityEvaluator does RelationalEagerEvaluator is export {
	method eager(IdentityOperator $query, Mu $origin --> List) {
		my @left = self.select-relation-for($query.left, $origin);
		my @right = self.select-relation-for($query.right, $origin);
		self.collections-equal(@left, @right) ?? @left.List !! ()
	}
}

class DivisionEvaluator does RelationalEagerEvaluator is export {
	method eager(DivisionOperator $query, Mu $origin --> List) {
		my @left = self.select-relation-for($query.left, $origin);
		my @right = self.select-relation-for($query.right, $origin);
		self.relational-division(@left, @right).List
	}
}
