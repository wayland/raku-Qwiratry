=begin pod

=head1 Overview

Shared interface for eager query evaluators.

Eager evaluators return materialized C<List> values. Family-specific roles add
only the helper methods they need.

=end pod
unit module Qwiratry::Query::Evaluator::Eager;

use Qwiratry::Query::RelationCommon;

=begin pod

=head2 C<role EagerEvaluator>

=begin code :lang<raku>
role EagerEvaluator is export
=end code

Defines C<EagerEvaluator>.

=end pod
role EagerEvaluator is export {
	=begin pod

	=head2 C<method relation-common>

	=begin code :lang<raku>
	method relation-common()
	=end code

	Documents C<method relation-common>.

	=end pod
	method relation-common() {
		Qwiratry::Query::RelationCommon.instance
	}

	=begin pod

	=head2 C<method eager>

	=begin code :lang<raku>
	method eager(Mu $query, Mu $origin --> List)
	=end code

	Documents C<method eager>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method eager(Mu $query, Mu $origin --> List) { ... }
}

=begin pod

=head2 C<role RecursiveEagerEvaluator>

=begin code :lang<raku>
role RecursiveEagerEvaluator does EagerEvaluator is export
=end code

Defines C<RecursiveEagerEvaluator>.

=end pod
role RecursiveEagerEvaluator does EagerEvaluator is export {
	has &.select-list is required;
	has &.select-relation is required;

	=begin pod

	=head2 C<method select-list-for>

	=begin code :lang<raku>
	method select-list-for(Mu $query, Mu $origin --> List)
	=end code

	Documents C<method select-list-for>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method select-list-for(Mu $query, Mu $origin --> List) {
		&!select-list($query, $origin)
	}

	=begin pod

	=head2 C<method select-relation-for>

	=begin code :lang<raku>
	method select-relation-for(Mu $operand, Mu $origin --> List)
	=end code

	Documents C<method select-relation-for>.

	=item C<$operand>

	The C<$operand> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method select-relation-for(Mu $operand, Mu $origin --> List) {
		&!select-relation($operand, $origin)
	}
}
