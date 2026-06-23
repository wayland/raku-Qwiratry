=begin pod

=head1 Overview

Eager evaluators for relational predicate and division operators.

=end pod
unit module Qwiratry::Query::Evaluator::Relational;

use Qwiratry::Operator::Set;
use Qwiratry::Query::Evaluator::Eager;

=begin pod

=head2 C<role RelationalEagerEvaluator>

=begin code :lang<raku>
role RelationalEagerEvaluator does RecursiveEagerEvaluator
=end code

Defines C<RelationalEagerEvaluator>.

=end pod
role RelationalEagerEvaluator does RecursiveEagerEvaluator {
	=begin pod

	=head2 C<method is-subset-of>

	=begin code :lang<raku>
	method is-subset-of(@left, @right --> Bool)
	=end code

	Documents C<method is-subset-of>.

	=item C<@left>

	The C<@left> parameter.

	=item C<@right>

	The C<@right> parameter.

	=end pod
	method is-subset-of(@left, @right --> Bool) {
		for @left -> $lrow {
			self.relation-common.row-in-list($lrow, @right) or return False;
		}
		True
	}

	=begin pod

	=head2 C<method collections-equal>

	=begin code :lang<raku>
	method collections-equal(@left, @right --> Bool)
	=end code

	Documents C<method collections-equal>.

	=item C<@left>

	The C<@left> parameter.

	=item C<@right>

	The C<@right> parameter.

	=end pod
	method collections-equal(@left, @right --> Bool) {
		@left.elems == @right.elems or return False;
		for @left -> $lrow {
			self.relation-common.row-in-list($lrow, @right) or return False;
		}
		True
	}

	=begin pod

	=head2 C<method relational-division>

	=begin code :lang<raku>
	method relational-division(@left, @right)
	=end code

	Documents C<method relational-division>.

	=item C<@left>

	The C<@left> parameter.

	=item C<@right>

	The C<@right> parameter.

	=end pod
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

=begin pod

=head2 C<class ElementOfEvaluator>

=begin code :lang<raku>
class ElementOfEvaluator does RelationalEagerEvaluator is export
=end code

Defines C<ElementOfEvaluator>.

=end pod
class ElementOfEvaluator does RelationalEagerEvaluator is export {
	=begin pod

	=head2 C<method eager>

	=begin code :lang<raku>
	method eager(ElementOfOperator $query, Mu $origin --> List)
	=end code

	Documents C<method eager>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
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

=begin pod

=head2 C<class ContainsEvaluator>

=begin code :lang<raku>
class ContainsEvaluator does RelationalEagerEvaluator is export
=end code

Defines C<ContainsEvaluator>.

=end pod
class ContainsEvaluator does RelationalEagerEvaluator is export {
	=begin pod

	=head2 C<method eager>

	=begin code :lang<raku>
	method eager(ContainsOperator $query, Mu $origin --> List)
	=end code

	Documents C<method eager>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method eager(ContainsOperator $query, Mu $origin --> List) {
		my @collection = self.select-list-for($query.collection, $origin);
		my @elements = self.select-list-for($query.element, $origin);
		@collection.grep(-> $row {
			@elements.grep(-> $elem { self.relation-common.row-equal($elem, $row) }).so
		}).List
	}
}

=begin pod

=head2 C<class SubsetEvaluator>

=begin code :lang<raku>
class SubsetEvaluator does RelationalEagerEvaluator is export
=end code

Defines C<SubsetEvaluator>.

=end pod
class SubsetEvaluator does RelationalEagerEvaluator is export {
	=begin pod

	=head2 C<method eager>

	=begin code :lang<raku>
	method eager(SubsetOperator $query, Mu $origin --> List)
	=end code

	Documents C<method eager>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method eager(SubsetOperator $query, Mu $origin --> List) {
		my @left = self.select-list-for($query.left, $origin);
		my @right = self.select-list-for($query.right, $origin);
		self.is-subset-of(@left, @right)
			&& !self.collections-equal(@left, @right)
			?? @left.List !! ()
	}
}

=begin pod

=head2 C<class SubsetOrEqualEvaluator>

=begin code :lang<raku>
class SubsetOrEqualEvaluator does RelationalEagerEvaluator is export
=end code

Defines C<SubsetOrEqualEvaluator>.

=end pod
class SubsetOrEqualEvaluator does RelationalEagerEvaluator is export {
	=begin pod

	=head2 C<method eager>

	=begin code :lang<raku>
	method eager(SubsetOrEqualOperator $query, Mu $origin --> List)
	=end code

	Documents C<method eager>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method eager(SubsetOrEqualOperator $query, Mu $origin --> List) {
		my @left = self.select-list-for($query.left, $origin);
		my @right = self.select-list-for($query.right, $origin);
		self.is-subset-of(@left, @right) ?? @left.List !! ()
	}
}

=begin pod

=head2 C<class IdentityEvaluator>

=begin code :lang<raku>
class IdentityEvaluator does RelationalEagerEvaluator is export
=end code

Defines C<IdentityEvaluator>.

=end pod
class IdentityEvaluator does RelationalEagerEvaluator is export {
	=begin pod

	=head2 C<method eager>

	=begin code :lang<raku>
	method eager(IdentityOperator $query, Mu $origin --> List)
	=end code

	Documents C<method eager>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method eager(IdentityOperator $query, Mu $origin --> List) {
		my @left = self.select-relation-for($query.left, $origin);
		my @right = self.select-relation-for($query.right, $origin);
		self.collections-equal(@left, @right) ?? @left.List !! ()
	}
}

=begin pod

=head2 C<class DivisionEvaluator>

=begin code :lang<raku>
class DivisionEvaluator does RelationalEagerEvaluator is export
=end code

Defines C<DivisionEvaluator>.

=end pod
class DivisionEvaluator does RelationalEagerEvaluator is export {
	=begin pod

	=head2 C<method eager>

	=begin code :lang<raku>
	method eager(DivisionOperator $query, Mu $origin --> List)
	=end code

	Documents C<method eager>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method eager(DivisionOperator $query, Mu $origin --> List) {
		my @left = self.select-relation-for($query.left, $origin);
		my @right = self.select-relation-for($query.right, $origin);
		self.relational-division(@left, @right).List
	}
}
