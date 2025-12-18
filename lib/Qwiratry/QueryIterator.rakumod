#| QueryIterator role extending Iterator for incremental result streaming
#|
#| This role extends Raku's Iterator role and provides the contract for
#| producing query results incrementally via the next() method.
#| QueryIterator receives a Context via constructor for per-traversal
#| state management, enabling coordination between Walker, Query, and Strategy.
#|
#| Lifecycle:
#|   - Created by Walker::Plan.iterator() or Walker.iterator()
#|   - One instance per traversal/result stream
#|   - Independent instances from same plan do not share mutable state
#|   - Exhausted when next() returns Nil
#|
#| Comparison with regular Raku Iterator:
#|   | Aspect                  | Regular Iterator | QueryIterator |
#|   |-------------------------|------------------|---------------|
#|   | Underlying state        | Internal closure | Shared Context |
#|   | Backtracking support    | No               | Yes            |
#|   | Multi-phase execution   | No               | Yes            |
#|   | Integration             | Standalone       | Walker/Query/Strategy |
#|
#| Usage:
#|   Concrete classes implementing QueryIterator must:
#|   - Accept Context via constructor (required)
#|   - Implement next() to return next result or Nil when exhausted
#|   - Maintain traversal state (stacks, queues, cursor positions)
#|
#| Example:
#|   class SimpleQueryIterator does QueryIterator {
#|       has @.items;
#|       has Int $!index = 0;
#|       
#|       method next(--> Mu) {
#|           return Nil if $!index >= @!items.elems;
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
    
    #| Return the next matching result, or Nil if exhausted.
    #| 
    #| This is the primary iteration method per the Qwiratry specification.
    #| Concrete implementations MUST override this to provide actual
    #| iteration logic.
    #|
    #| Contract:
    #|   - Returns: Any value (the next result) or Nil (exhausted)
    #|   - After returning Nil once, must consistently return Nil
    #|   - Should support lazy evaluation when possible
    #|   - May coordinate with Context for state management
    #|   - May support backtracking per Walker logic
    #|
    #| @returns Mu - Next result value, or Nil if no more results
    method next(--> Mu) { ... }
    
    #| Bridge method for Raku's Iterator protocol.
    #|
    #| Maps next() to pull-one() for compatibility with Raku's
    #| iteration primitives (for loops, .list, etc.).
    #|
    #| @returns Mu - Next result value, or IterationEnd if exhausted
    method pull-one(--> Mu) {
        my $result = self.next;
        $result.defined ?? $result !! IterationEnd
    }
}
