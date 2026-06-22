=begin pod

=head1 Overview

Pull-based iterator role for incremental query result streaming.

C<QueryIterator> composes Raku's C<Iterator> role and adds a required
L<Qwiratry::Context> slot. Walkers create one query iterator per result stream,
usually from a reusable plan, so each traversal has independent mutable state.

Concrete iterators implement C<pull-one> with their traversal cursor, stack,
queue, or backend cursor. Exhaustion is signaled with C<IterationEnd>, matching
the normal Raku iterator protocol.

=head1 Lifecycle

=item Created by C<Qwiratry::Walker::Plan.iterator> or C<Qwiratry::Walker.iterator>.

=item One instance represents one traversal or result stream.

=item Independent iterators from the same plan do not share mutable state.

=item An iterator is exhausted when C<pull-one> returns C<IterationEnd>.

=head1 Comparison With C<Iterator>

C<QueryIterator> is still a normal Raku iterator, but its role in Qwiratry is
more specific:

=begin table
Aspect                | Regular Iterator | QueryIterator
Underlying state      | Internal closure  | Shared Context
Backtracking support  | No                | Walker-dependent
Multi-phase execution | No                | Supported through Context/Walker
Integration           | Standalone        | Walker, Query, and Strategy
=end table

=head1 Implementing

Concrete classes composing C<QueryIterator> must accept a
L<Qwiratry::Context> via construction, implement C<pull-one> to return the next
result or C<IterationEnd>, and maintain any traversal state they need, such as
stacks, queues, cursor positions, or backend handles.

=head1 Contract

=item C<context> is required at construction time and stores the traversal state
 container shared with walker and strategy code.

=item C<pull-one> returns either any next result value or C<IterationEnd> when no
 more values are available.

=item After returning C<IterationEnd> once, C<pull-one> should continue returning
 C<IterationEnd>.

=item Callers that store a pulled value should test exhaustion with
 C<$value ~~ IterationEnd>, not identity comparison.

=item Implementations should stay lazy when possible.

=item Implementations may coordinate with C<$.context> for traversal state,
 strategy hooks, backtracking, or multi-pass execution.

=head1 Example

=begin code
class SimpleQueryIterator does QueryIterator {
    has @.items;
    has Int $!index = 0;

    method pull-one(--> Mu) {
        return IterationEnd if $!index >= @!items.elems;
        @!items[$!index++]
    }
}
=end code

=end pod
unit module Qwiratry::QueryIterator;

use Qwiratry::Context;

=begin pod

=head1 Role

C<QueryIterator> is the common result-stream contract used by walkers,
strategies, and transformer traversal.

=end pod
role QueryIterator does Iterator is export {
	=begin pod

	=head2 C<context>

	The context object for this traversal.

	Concrete iterators use it for mutable per-traversal state and to expose the
	active strategy to walker/strategy coordination code.

	=head3 Attribute

	C<context> must do L<Qwiratry::Context>. It is required because walkers and
	strategies use it as the shared state container for one traversal.

	=end pod
	has Context $.context is required;
    
	=begin pod

	=head2 C<pull-one()>

	=begin code
	method pull-one(--> Mu)
	=end code

	Returns the next matching result, or C<IterationEnd> when exhausted.

	Concrete implementations override this method. After returning
	C<IterationEnd>, they should continue returning C<IterationEnd>. Callers that
	store a pulled value should test exhaustion with C<$value ~~ IterationEnd>.

	Implementations should stay lazy when possible and may coordinate with
	C<$.context> for traversal state, strategy hooks, backtracking, or multi-pass
	execution.

	=head3 Return Value

	Returns the next result value, which may be any defined or undefined Raku
	value meaningful to the query, or C<IterationEnd> when exhausted.

	=end pod
	method pull-one(--> Mu) {
		# Default implementation: empty iterator
		# Concrete classes MUST override this method
		IterationEnd
	}

	=begin pod

	Spec alias for C<pull-one> (Walker core infrastructure FR-004).

	Returns the next matching result, or C<Nil> when exhausted.

	=end pod
	method next(--> Mu) {
		my $value = self.pull-one;
		$value ~~ IterationEnd ?? Nil !! $value
	}
}
