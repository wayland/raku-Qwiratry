=begin pod

Context role for per-traversal mutable state

Context is a marker role implemented by concrete classes to store mutable
state during query traversal. It serves as a type marker for the traversal
state container.

Lifecycle:
  - Created fresh for each traversal pass
  - Shared between Qwiratry::Walker and Strategy hooks within a single traversal
  - Not shared across separate traversals or iterators
  - May be reused for multi-phase walkers (if design requires)

Usage:
  Concrete classes implementing Context define their own attributes
  for storing counters, memoisation tables, queues, intermediate results,
  or any other mutable state needed during traversal.

Example:
  class MyContext does Context {
      has Int $.visit-count is rw = 0;
      has @.results;
  }

=end pod
unit module Qwiratry::Context;

=begin pod

Marker role for per-traversal mutable state.
Concrete classes implementing this role define their own attributes.

The Strategy instance for this traversal is stored in $.strategy.
This allows Strategy hooks to access the same Context instance
throughout the traversal, enabling state sharing between hooks.

=end pod
role Context is export {
	=begin pod

	The Strategy instance for this traversal (may be undefined).

	Set by Qwiratry::Walker when creating Context for a traversal.
	If undefined, no Strategy hooks will be called during traversal.
	The same Strategy instance is shared across all hooks in a single traversal.

	Type: Should be Qwiratry::Strategy (left untyped to avoid circular dependency).

	=end pod
	has $.strategy;
    
	# Concrete implementations define their own attributes for:
	# - Counters and accumulators
	# - Memoisation tables
	# - Queues and stacks for traversal
	# - Intermediate results
	# - Any other mutable per-traversal state
}
