=begin pod

=head1 Overview

Context role for per-traversal mutable state.

Concrete walkers compose this role into their private context classes to share
state between a query iterator and L<Qwiratry::Strategy> hooks. A context is
created fresh for a traversal or iterator, then carried through pre-visit,
match, follow, post-visit, finish, and continuation decisions.

The role deliberately standardizes only C<$.strategy>. Counters, memo tables,
queues, intermediate results, and walker-specific flags belong on the concrete
context class that knows how traversal is implemented.

=head1 Lifecycle

=item Created fresh for each traversal pass or result iterator.

=item Shared between the walker, query iterator, and strategy hooks within that
 single traversal.

=item Not shared across separate traversals or independent iterators.

=item May be reused by a walker across phases when the walker deliberately
 implements a multi-phase traversal.

=head1 Usage

Concrete classes implementing C<Context> define their own attributes for
counters, memoisation tables, queues, intermediate results, or other mutable
state needed during traversal. The role acts as a common type marker so walker,
iterator, and strategy code can agree on the state container.

=head1 Example

=begin code
class MyContext does Context {
    has Int $.visit-count is rw = 0;
    has @.results;
}
=end code

=end pod
unit module Qwiratry::Context;

=begin pod

=head1 Role

C<Context> is a marker plus the shared strategy slot. A typical implementation
adds the traversal state it needs:

=begin code
class TreeContext does Context {
    has Int $.nodes-visited is rw = 0;
    has $.finish-result is rw;
}
=end code

=end pod
role Context is export {
	=begin pod

	=head2 C<strategy>

	The strategy instance for this traversal, or C<Nil> when traversal is running
	without hooks.

	Walkers set this when creating the context. The same strategy instance is
	available to all hooks in a traversal, enabling shared state through the
	context. It is intentionally untyped to avoid a circular dependency with
	L<Qwiratry::Strategy>.

	=end pod
	has $.strategy;
    
	# Concrete implementations define their own attributes for:
	# - Counters and accumulators
	# - Memoisation tables
	# - Queues and stacks for traversal
	# - Intermediate results
	# - Any other mutable per-traversal state
}
