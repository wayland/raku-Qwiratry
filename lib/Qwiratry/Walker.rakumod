#| Walker role and Walker::Plan role for query execution planning
#|
#| This module provides the core infrastructure roles for query execution:
#|   - Walker::Plan: Represents a precomputed execution strategy
#|   - Walker: Encapsulates how a query is executed over a data structure
#|
#| Lifecycle:
#|   Walker creates Walker::Plan via plan() method
#|   Walker::Plan creates QueryIterator instances via iterator() method
#|   QueryIterator produces results incrementally via pull-one()
unit module Qwiratry::Walker;

use Qwiratry::Context;
use Qwiratry::QueryIterator;

#| Walker::Plan role - precomputed execution strategy for a specific query and root.
#|
#| Represents an execution plan created by Walker.plan(). Plans are reusable
#| and can produce multiple independent QueryIterator instances. Plans must
#| not mutate the original Query AST.
#|
#| Required methods (must be implemented by concrete classes):
#|   - iterator() → QueryIterator
#|   - query() → RakuAST::Node (or Mu for flexibility)
#|   - describe() → Str
#|
#| Optional methods (have default implementations):
#|   - optimise(&modification) → Walker::Plan
#|   - subplans() → Array
#|   - capabilities() → Hash
#|
#| Example concrete implementation:
#|   class MyPlan does Walker::Plan {
#|       has $.query-ast;
#|       has $.root;
#|       
#|       method iterator(--> QueryIterator) {
#|           my $ctx = MyContext.new;
#|           MyIterator.new(context => $ctx, plan => self);
#|       }
#|       method query() { $!query-ast }
#|       method describe(--> Str) { "MyPlan for {$!query-ast.^name}" }
#|   }
role Walker::Plan is export {
    #| Create a fresh QueryIterator for this plan.
    #|
    #| Each call creates an independent iterator with its own Context.
    #| Multiple iterators from the same plan do not share mutable state.
    #|
    #| @returns QueryIterator - A new iterator ready to produce results
    method iterator(--> QueryIterator) { ... }
    
    #| Return the Query AST used to create this plan.
    #|
    #| The returned AST should be treated as immutable. Plans must not
    #| mutate the original Query AST in observable ways.
    #|
    #| @returns Mu - The Query AST (typically RakuAST::Node)
    method query(--> Mu) { ... }
    
    #| Return a human-readable description of the execution strategy.
    #|
    #| Useful for debugging, profiling, and explain-plan functionality.
    #|
    #| @returns Str - Description of the plan
    method describe(--> Str) { ... }
    
    #| Apply an optimization transformation to the plan.
    #|
    #| The callback receives this plan and returns a modified version.
    #| Implementations should return a new plan instance unless in-place
    #| modification is safe.
    #|
    #| Default implementation returns self unchanged.
    #|
    #| @param &modification - Callback: Walker::Plan → Walker::Plan
    #| @returns Walker::Plan - The optimized plan (may be same or new instance)
    method optimise(&modification --> Walker::Plan) {
        # Default: return self unchanged
        # Concrete implementations may apply the modification
        self
    }
    
    #| Return subplans for composite plan structures.
    #|
    #| For composite walkers that combine multiple sub-walkers (e.g., union,
    #| intersection), this returns the component plans.
    #|
    #| Default implementation returns empty array (non-composite plan).
    #|
    #| @returns Array - Array of Walker::Plan instances (empty for simple plans)
    method subplans() {
        # Default: no subplans (simple, non-composite plan)
        []
    }
    
    #| Return capability metadata for this plan.
    #|
    #| Provides structured information about plan capabilities for introspection.
    #| Format: { capability-name => { enabled => Bool, ... }, ... }
    #|
    #| Example: { lazy => { enabled => True, type => "incremental" } }
    #|
    #| Default implementation returns empty hash.
    #|
    #| @returns Hash - Capability metadata
    method capabilities(--> Hash) {
        # Default: no special capabilities declared
        {}
    }
}

#| Walker role - encapsulates how a query is executed over a data structure.
#|
#| Walker is the main entry point for query execution. It creates execution
#| plans via plan() and can produce iterators via iterator() or start().
#|
#| Required methods (must be implemented by concrete classes):
#|   - plan($query, $root) → Walker::Plan
#|
#| Optional methods (have default implementations):
#|   - iterator($q) → QueryIterator (uses stored root)
#|   - start($query, $root) → QueryIterator
#|   - PRE-PASS($ctx) - Hook called before traversal
#|   - POST-PASS($ctx) - Hook called after traversal
#|   - capabilities() → Hash
#|   - supports($query) → Bool
#|
#| Example concrete implementation:
#|   class TreeWalker does Walker {
#|       has $.root;
#|       
#|       method plan(Mu $query, Mu $root --> Walker::Plan) {
#|           TreePlan.new(query-ast => $query, root => $root);
#|       }
#|   }
role Walker is export {
    #| Create an execution plan for the given query and root.
    #|
    #| This is the primary method for query execution. The plan encapsulates
    #| the execution strategy and can produce multiple iterators.
    #|
    #| Must throw X::Qwiratry::UnknownQueryElement if the query cannot be
    #| interpreted by this walker.
    #|
    #| @param $query - The Query AST (typically RakuAST::Node)
    #| @param $root - The root data structure to query
    #| @returns Walker::Plan - Execution plan for the query
    #| @throws X::Qwiratry::UnknownQueryElement if query cannot be interpreted
    method plan(Mu $query, Mu $root --> Walker::Plan) { ... }
    
    #| Convenience method to create an iterator using stored root.
    #|
    #| Equivalent to self.plan($q, $root).iterator where $root is stored
    #| in the walker instance. Concrete implementations must store the root
    #| to use this method.
    #|
    #| Default implementation calls plan() with the query and stored root.
    #|
    #| @param $q - The Query AST
    #| @returns QueryIterator - Ready to produce results
    method iterator(Mu $q --> QueryIterator) { ... }
    
    #| Convenience method combining plan() and iterator().
    #|
    #| Default implementation: self.plan($query, $root).iterator
    #|
    #| @param $query - The Query AST
    #| @param $root - The root data structure (must be defined)
    #| @returns QueryIterator - Ready to produce results
    method start(Mu $query, Mu:D $root --> QueryIterator) {
        self.plan($query, $root).iterator
    }
    
    #| Hook called before traversal begins.
    #|
    #| Override to initialize Context state, set up resources, or perform
    #| pre-traversal validation. Called once per traversal.
    #|
    #| Default implementation: no-op
    #|
    #| @param $ctx - The Context for this traversal
    method PRE-PASS(Context $ctx) {
        # Default: no-op
    }
    
    #| Hook called after traversal completes.
    #|
    #| Override to finalize Context state, clean up resources, or perform
    #| post-traversal processing. Called once per traversal.
    #|
    #| Default implementation: no-op
    #|
    #| @param $ctx - The Context for this traversal
    method POST-PASS(Context $ctx) {
        # Default: no-op
    }
    
    #| Return capability metadata for this walker.
    #|
    #| Provides structured information about walker capabilities.
    #| Format: { capability-name => { enabled => Bool, ... }, ... }
    #|
    #| Default implementation returns empty hash.
    #|
    #| @returns Hash - Capability metadata
    method capabilities(--> Hash) {
        # Default: no special capabilities declared
        {}
    }
    
    #| Check if this walker can interpret the given query.
    #|
    #| Useful for query routing in composite walker scenarios.
    #|
    #| Default implementation returns False (conservative).
    #|
    #| @param $query - The Query AST to check
    #| @returns Bool - True if walker can interpret query
    method supports(Mu $query --> Bool) {
        # Default: conservative - assume cannot support
        False
    }
}
