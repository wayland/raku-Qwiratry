#| QueryIterator role extending Iterator for incremental result streaming
#|
#| This role extends Raku's Iterator role and provides the contract for
#| producing query results incrementally via the pull-one() method.
#| QueryIterator receives a Context via constructor for per-traversal
#| state management, enabling coordination between Walker, Query, and Strategy.
#|
#| Lifecycle:
#|   - Created by Walker::Plan.iterator() or Walker.iterator()
#|   - One instance per traversal/result stream
#|   - Independent instances from same plan do not share mutable state
#|   - Exhausted when pull-one() returns IterationEnd
#|
#| Usage:
#|   Concrete classes implementing QueryIterator must:
#|   - Accept Context via constructor (required)
#|   - Implement pull-one() to return next result or IterationEnd
#|   - Maintain traversal state (stacks, queues, cursor positions)
#|
#| Example:
#|   class SimpleQueryIterator does QueryIterator {
#|       has @.items;
#|       has Int $!index = 0;
#|       
#|       method pull-one() {
#|           return IterationEnd if $!index >= @!items.elems;
#|           @!items[$!index++]
#|       }
#|   }
unit module Qwiratry::QueryIterator;

use Qwiratry::Context;

#| Role for pull-based streaming of query results.
#| Extends Iterator for compatibility with Raku's iteration protocol.
#| Concrete implementations provide actual traversal logic.
role QueryIterator does Iterator is export {
    #| The Context object for this traversal, containing mutable per-traversal state.
    #| Must be provided via constructor. Enables coordination between
    #| Walker, Strategy hooks, and the iterator during traversal.
    has Context $.context is required;
    
    #| Return the next matching result, or IterationEnd if exhausted.
    #| 
    #| This is a stub method - concrete implementations MUST override this
    #| to provide actual iteration logic. The default implementation
    #| immediately returns IterationEnd (empty iterator).
    #|
    #| Contract:
    #|   - Returns: Any value (the next result) or IterationEnd (exhausted)
    #|   - After returning IterationEnd once, must consistently return IterationEnd
    #|   - Should support lazy evaluation when possible
    #|   - May coordinate with Context for state management
    #|
    #| @returns Mu - Next result value, or IterationEnd if no more results
    method pull-one(--> Mu) {
        # Default implementation: empty iterator
        # Concrete classes MUST override this method
        IterationEnd
    }
}
