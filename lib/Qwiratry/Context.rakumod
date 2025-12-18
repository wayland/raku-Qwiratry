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
role Context is export {
    # This is intentionally an empty marker role.
    # Concrete implementations define their own attributes for:
    # - Counters and accumulators
    # - Memoisation tables
    # - Queues and stacks for traversal
    # - Intermediate results
    # - Any other mutable per-traversal state
}
