#| Context role for per-traversal mutable state
#| 
#| Context is a marker role implemented by concrete classes to store mutable
#| state during query traversal. It serves as a type marker for the traversal
#| state container.
#|
#| Lifecycle:
#|   - Created fresh for each traversal pass
#|   - Shared between Walker and Strategy hooks within a single traversal
#|   - Not shared across separate traversals or iterators
#|   - May be reused for multi-phase walkers (if design requires)
#|
#| Usage:
#|   Concrete classes implementing Context define their own attributes
#|   for storing counters, memoisation tables, queues, intermediate results,
#|   or any other mutable state needed during traversal.
#|
#| Example:
#|   class MyContext does Context {
#|       has Int $.visit-count is rw = 0;
#|       has @.results;
#|   }
unit module Qwiratry::Context;

#| Marker role for per-traversal mutable state.
#| Concrete classes implementing this role define their own attributes.
#|
#| The Strategy instance for this traversal is stored in $.strategy.
#| This allows Strategy hooks to access the same Context instance
#| throughout the traversal, enabling state sharing between hooks.
role Context is export {
    #| The Strategy instance for this traversal (may be undefined).
    #|
    #| Set by Walker when creating Context for a traversal.
    #| If undefined, no Strategy hooks will be called during traversal.
    #| The same Strategy instance is shared across all hooks in a single traversal.
    #|
    #| Type: Should be Qwiratry::Strategy (left untyped to avoid circular dependency).
    has $.strategy;
    
    # Concrete implementations define their own attributes for:
    # - Counters and accumulators
    # - Memoisation tables
    # - Queues and stacks for traversal
    # - Intermediate results
    # - Any other mutable per-traversal state
}
