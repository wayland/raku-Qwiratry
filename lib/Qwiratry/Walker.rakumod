#| Walker role and Walker::Plan role for query execution planning
#|
#| This module provides the core infrastructure roles for query execution:
#|   - Walker::Plan: Represents a precomputed execution strategy
#|   - Walker: Encapsulates how a query is executed over a data structure
#|
#| Lifecycle:
#|   Walker creates Walker::Plan via plan() method
#|   Walker creates QueryIterator from Walker::Plan via iterator() method
#|   QueryIterator produces results incrementally via next()
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
#|   - query() → RakuAST::Node
#|   - describe() → Str
#|
#| Optional methods (have default implementations):
#|   - optimise(&modification) → Walker::Plan
#|   - subplans() → Array[Walker::Plan]
#|   - capabilities() → Associative
#|
#| Example concrete implementation:
#|   class MyPlan does Walker::Plan {
#|       has RakuAST::Node $.query-ast;
#|       has $.root;
#|       
#|       method iterator(--> QueryIterator) {
#|           my $ctx = MyContext.new;
#|           MyIterator.new(context => $ctx, plan => self);
#|       }
#|       method query(--> RakuAST::Node) { $!query-ast }
#|       method describe(--> Str) { "MyPlan for {$!query-ast.^name}" }
#|   }
role Walker::Plan is export {
    #| Produce a QueryIterator for this plan.
    #|
    #| Each call creates an independent iterator with its own Context.
    #| Multiple iterators from the same plan do not share mutable state.
    #|
    #| @returns QueryIterator - A new iterator ready to produce results
    method iterator(--> QueryIterator) { ... }
    
    #| Return the Query AST that this plan represents.
    #|
    #| The returned AST should be treated as immutable. Plans must not
    #| mutate the original Query AST in observable ways.
    #|
    #| @returns RakuAST::Node - The Query AST
    method query(--> RakuAST::Node) { ... }
    
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
    method optimise(&modification) {
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
    #| @returns Array[Walker::Plan] - Array of Walker::Plan instances (empty for simple plans)
    method subplans(--> Array[Walker::Plan]) {
        # Default: no subplans (simple, non-composite plan)
        Array[Walker::Plan].new
    }
    
    #| Return capability metadata for this plan.
    #|
    #| Provides structured information about plan capabilities for introspection.
    #| Format: { capability-name => { enabled => Bool, ... }, ... }
    #|
    #| Example: { lazy => { enabled => True, type => "incremental" } }
    #|
    #|Common capabilities: supports-lazy, supports-backtracking, supports-streaming
    #|
    #| Default implementation returns empty hash.
    #|
    #| @returns Associative - Capability metadata
    method capabilities(--> Associative) {
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
#|   - plan(RakuAST::Node $query, Mu $root) → Walker::Plan
#|   - iterator(Walker::Plan $plan) → QueryIterator
#|
#| Optional methods (have default implementations):
#|   - start($query, $root) → QueryIterator (convenience: plan + iterator)
#|   - PRE-PASS($ctx) - Hook called before traversal
#|   - POST-PASS($ctx) - Hook called after traversal
#|   - capabilities() → Associative
#|   - supports($query) → Bool
#|
#| Strategy Integration:
#|   - Walker can be constructed with a Strategy: Walker.new(:$strategy)
#|   - Strategy is stored in Context when creating iterators
#|   - Concrete QueryIterator implementations should call Strategy hooks
#|     during traversal via $ctx.strategy
#|
#| Example concrete implementation:
#|   class TreeWalker does Walker {
#|       method plan(RakuAST::Node $query, Mu:D $root --> Walker::Plan) {
#|           TreePlan.new(query-ast => $query, root => $root);
#|       }
#|       method iterator(Walker::Plan $plan --> QueryIterator) {
#|           my $ctx = TreeContext.new(strategy => $.strategy);
#|           TreeIterator.new(context => $ctx, plan => self);
#|       }
#|   }
role Walker does Iterable is export {
    #| The default Strategy for this Walker (may be undefined).
    #|
    #| Set via constructor: Walker.new(:$strategy)
    #| If undefined, no Strategy hooks will be called during traversal.
    #| The Strategy is copied to Context when creating iterators, allowing
    #| QueryIterator implementations to access it via $ctx.strategy.
    #|
    #| Type: Should be Qwiratry::Strategy (left untyped to avoid circular dependency).
    has $.strategy;
    
    #| Analyse the Query AST and root data structure, produce an optimised execution plan.
    #|
    #| This method creates a Walker::Plan - a precomputed execution strategy.
    #| The plan can then produce multiple independent QueryIterator instances
    #| via plan.iterator() or walker.iterator(plan).
    #|
    #| Responsibilities (MAY):
    #|   - Analyse AST structure (operators, blocks, predicates)
    #|   - Decide traversal order and strategy (DFS, BFS, index scan, join order)
    #|   - Identify sub-expressions for predicate pushdown or backend delegation
    #|   - Precompute metadata used during execution
    #|
    #| Constraints:
    #|   - MUST NOT mutate the shared Query AST in observable ways
    #|   - MAY copy or rewrite AST fragments into the Plan
    #|   - MUST return a reusable Walker::Plan
    #|   - MUST throw X::Qwiratry::UnknownQueryElement if query cannot be interpreted
    #|
    #| @param $query - The Query AST (RakuAST::Node)
    #| @param $root - The root data structure to query
    #| @returns Walker::Plan - Precomputed execution strategy for the query
    #| @throws X::Qwiratry::UnknownQueryElement if query cannot be interpreted
    method plan(RakuAST::Node $query, Mu:D $root --> Walker::Plan) { ... }
    
    #| Produce a new incremental result stream from an existing execution plan.
    #|
    #| Creates a fresh Context, initialises traversal state, and returns
    #| a QueryIterator that yields results lazily.
    #|
    #| Multiple iterators MAY be created from the same plan.
    #| Iterators MUST NOT share mutable traversal state.
    #|
    #| @param $plan - The execution plan to iterate
    #| @returns QueryIterator - Ready to produce results
    method iterator(Walker::Plan $plan --> QueryIterator) { ... }
    
    #| One-shot execution entrypoint (convenience method).
    #|
    #| Equivalent to: self.plan($query, $root).iterator
    #| via self.iterator(self.plan($query, $root))
    #|
    #| @param $query - The Query AST (RakuAST::Node)
    #| @param $root - The root data structure (must be defined)
    #| @returns QueryIterator - Ready to produce results
    method start(RakuAST::Node $query, Mu:D $root --> QueryIterator) {
        self.iterator(self.plan($query, $root))
    }
    
    #| Hook called before a traversal pass begins.
    #|
    #| Override to initialize global traversal state, prepare caches or
    #| indexes, or initialize multi-pass bookkeeping. Called once per pass.
    #|
    #| Default implementation: no-op
    #|
    #| @param $ctx - The Context for this traversal
    method PRE-PASS(Context $ctx) {
        # Default: no-op
    }
    
    #| Hook called after a traversal pass completes.
    #|
    #| Override to collect diagnostics, decide whether to trigger another
    #| pass, or finalize results/clean up resources. Called once per pass.
    #|
    #| Default implementation: no-op
    #|
    #| @param $ctx - The Context for this traversal
    method POST-PASS(Context $ctx) {
        # Default: no-op
    }
    
    #| Return capability metadata for this walker.
    #|
    #| Provides structured information about walker capabilities:
    #|   - supports-lazy
    #|   - supports-backtracking
    #|   - supports-rewrite
    #|   - supports-multi-phase
    #|   - supports-streaming
    #|
    #| Used by Transformers, Composite Walkers, and debugging/profiling tools.
    #|
    #| Default implementation returns empty hash.
    #|
    #| @returns Associative - Capability metadata
    method capabilities(--> Associative) {
        # Default: no special capabilities declared
        {}
    }
    
    #| Check if this walker can interpret the given query.
    #|
    #| Returns whether this Walker can interpret the given AST.
    #| Useful for Walker selection/delegation in hybrid or master walkers.
    #|
    #| Default implementation returns False (conservative).
    #|
    #| @param $query - The Query AST to check
    #| @returns Bool - True if walker can interpret query
    method supports(RakuAST::Node $query --> Bool) {
        # Default: conservative - assume cannot support
        False
    }
}
