=begin pod

QueryIterator role extending Iterator for incremental result streaming

This role extends Raku's Iterator role and provides the contract for
producing query results incrementally via the pull-one() method.
QueryIterator receives a Context via constructor for per-traversal
state management, enabling coordination between Qwiratry::Walker, Query, and Strategy.

Lifecycle:
  - Created by Qwiratry::Walker::Plan.iterator() or Qwiratry::Walker.iterator()
  - One instance per traversal/result stream
  - Independent instances from same plan do not share mutable state
  - Exhausted when pull-one() returns IterationEnd

Comparison with regular Raku Iterator:
  | Aspect                  | Regular Iterator | QueryIterator |
  |-------------------------|------------------|---------------|
  | Underlying state        | Internal closure | Shared Context |
  | Backtracking support    | No               | Yes            |
  | Multi-phase execution   | No               | Yes            |
  | Integration             | Standalone       | Qwiratry::Walker/Query/Strategy |

Usage:
  Concrete classes implementing QueryIterator must:
  - Accept Context via constructor (required)
  - Implement pull-one() to return next result or IterationEnd when exhausted
  - Maintain traversal state (stacks, queues, cursor positions)

Example:
  class SimpleQueryIterator does QueryIterator {
      has @.items;
      has Int $!index = 0;
      
      method pull-one(--> Mu) {
          return IterationEnd if $!index >= @!items.elems;
          @!items[$!index++]
      }
  }

=end pod
unit module Qwiratry::QueryIterator;

use Qwiratry::Context;

=begin pod

Role for pull-based streaming of query results.
Extends Iterator for compatibility with Raku's iteration protocol.
Concrete implementations provide actual traversal logic via pull-one().

=end pod
role QueryIterator does Iterator is export {
	=begin pod

	The Context object for this traversal, containing mutable per-traversal state.
	Must be provided via constructor. Enables coordination between
	Qwiratry::Walker, Strategy hooks, and the iterator during traversal.

	=end pod
	has Context $.context is required;
    
	=begin pod

	Return the next matching result, or IterationEnd if exhausted.

	This is the standard Raku Iterator method. Concrete implementations
	MUST override this to provide actual iteration logic.

	Contract:
	- Returns: Any value (the next result) or IterationEnd (exhausted)
	- After returning IterationEnd once, must consistently return IterationEnd
	- Test exhaustion with `$value ~~ IterationEnd` (not `=:=`) when storing pull-one in a variable
	- Should support lazy evaluation when possible
	- May coordinate with Context for state management
	- May support backtracking per Qwiratry::Walker logic

	@returns Mu - Next result value, or IterationEnd if no more results

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
