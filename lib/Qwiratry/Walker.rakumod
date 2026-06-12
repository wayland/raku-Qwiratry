=begin pod

Qwiratry::Walker role and Qwiratry::Walker::Plan role for query execution planning

This module provides the core infrastructure roles for query execution:
  - Qwiratry::Walker::Plan: Represents a precomputed execution strategy
  - Qwiratry::Walker: Encapsulates how a query is executed over a data structure

Lifecycle:
  Qwiratry::Walker creates Qwiratry::Walker::Plan via plan() method
  Qwiratry::Walker creates QueryIterator from Qwiratry::Walker::Plan via iterator() method
  QueryIterator produces results incrementally via next()

=end pod
use Qwiratry::Context;
use Qwiratry::QueryIterator;
use Qwiratry::Walker::Capabilities;

=begin pod

Qwiratry::Walker::Plan role - precomputed execution strategy for a specific query and root.

Represents an execution plan created by Qwiratry::Walker.plan(). Plans are reusable
and can produce multiple independent QueryIterator instances. Plans must
not mutate the original Query AST.

Required methods (must be implemented by concrete classes):
  - iterator() → QueryIterator
  - query() → RakuAST::Node
  - describe() → Str

Optional methods (have default implementations):
  - optimise(&modification) → Qwiratry::Walker::Plan
  - subplans() → Array[Qwiratry::Walker::Plan]
  - capabilities() → Associative

Example concrete implementation:
  class MyPlan does Qwiratry::Walker::Plan {
      has RakuAST::Node $.query-ast;
      has $.root;
      
      method iterator(--> QueryIterator) {
          my $ctx = MyContext.new;
          MyIterator.new(context => $ctx, plan => self);
      }
      method query(--> RakuAST::Node) { $!query-ast }
      method describe(--> Str) { "MyPlan for {$!query-ast.^name}" }
  }

=end pod
role Qwiratry::Walker::Plan {
	=begin pod

	Produce a QueryIterator for this plan.

	Each call creates an independent iterator with its own Context.
	Multiple iterators from the same plan do not share mutable state.

	@returns QueryIterator - A new iterator ready to produce results

	=end pod
	method iterator(--> QueryIterator) { ... }
    
	=begin pod

	Return the Query AST that this plan represents.

	The returned AST should be treated as immutable. Plans must not
	mutate the original Query AST in observable ways.

	@returns RakuAST::Node - The Query AST

	=end pod
	method query(--> Mu) { ... }
    
	=begin pod

	Return a human-readable description of the execution strategy.

	Useful for debugging, profiling, and explain-plan functionality.

	@returns Str - Description of the plan

	=end pod
	method describe(--> Str) { ... }
    
	=begin pod

	Apply an optimization transformation to the plan.

	The callback receives this plan and returns a modified version.
	Implementations should return a new plan instance unless in-place
	modification is safe.

	Default implementation returns self unchanged.

	@param &modification - Callback: Qwiratry::Walker::Plan → Qwiratry::Walker::Plan
	@returns Qwiratry::Walker::Plan - The optimized plan (may be same or new instance)

	=end pod
	method optimise(&modification) {
		# Default: return self unchanged
		# Concrete implementations may apply the modification
		self
	}
    
	=begin pod

	Return subplans for composite plan structures.

	For composite walkers that combine multiple sub-walkers (e.g., union,
	intersection), this returns the component plans.

	Default implementation returns empty array (non-composite plan).

	@returns Array[Qwiratry::Walker::Plan] - Array of Qwiratry::Walker::Plan instances (empty for simple plans)

	=end pod
	method subplans(--> Array[Qwiratry::Walker::Plan]) {
		# Default: no subplans (simple, non-composite plan)
		Array[Qwiratry::Walker::Plan].new
	}
    
	=begin pod

	Return capability metadata for this plan.

	Provides structured information about plan capabilities for introspection.
	Format: { capability-name => { enabled => Bool, ... }, ... }

	Example: { lazy => { enabled => True, type => "incremental" } }

	Common capabilities: supports-lazy, supports-backtracking, supports-streaming

	Default implementation returns empty hash.

	@returns Associative - Capability metadata

	=end pod
	method capabilities(--> Associative) {
		default-plan-capabilities()
	}
}

=begin pod

Qwiratry::Walker role - encapsulates how a query is executed over a data structure.

Qwiratry::Walker is the main entry point for query execution. It creates execution
plans via plan() and can produce iterators via iterator() or start().

Required methods (must be implemented by concrete classes):
  - plan(RakuAST::Node $query, Mu $root) → Qwiratry::Walker::Plan
  - iterator(Qwiratry::Walker::Plan $plan) → QueryIterator

Optional methods (have default implementations):
  - start($query, $root) → QueryIterator (convenience: plan + iterator)
  - PRE-PASS($ctx) - Hook called before traversal
  - POST-PASS($ctx) - Hook called after traversal
  - capabilities() → Associative
  - supports($query) → Bool

Strategy Integration:
  - Qwiratry::Walker can be constructed with a Strategy: Qwiratry::Walker.new(:$strategy)
  - Strategy is stored in Context when creating iterators
  - Concrete QueryIterator implementations should call Strategy hooks
    during traversal via $ctx.strategy

Example concrete implementation:
  class TreeWalker does Qwiratry::Walker {
      method plan(RakuAST::Node $query, Mu:D $root --> Qwiratry::Walker::Plan) {
          TreePlan.new(query-ast => $query, root => $root);
      }
      method iterator(Qwiratry::Walker::Plan $plan --> QueryIterator) {
          my $ctx = TreeContext.new(strategy => $.strategy);
          TreeIterator.new(context => $ctx, plan => self);
      }
  }

=end pod
role Qwiratry::Walker does Iterable {
	=begin pod

	The default Strategy for this Walker (may be undefined).

	Set via constructor: Qwiratry::Walker.new(:$strategy)
	If undefined, no Strategy hooks will be called during traversal.
	The Strategy is copied to Context when creating iterators, allowing
	QueryIterator implementations to access it via $ctx.strategy.

	Type: Should be Qwiratry::Strategy (left untyped to avoid circular dependency).

	=end pod
	has $.strategy;
    
	=begin pod

	Analyse the Query AST and root data structure, produce an optimised execution plan.

	This method creates a Qwiratry::Walker::Plan - a precomputed execution strategy.
	The plan can then produce multiple independent QueryIterator instances
	via plan.iterator() or walker.iterator(plan).

	Responsibilities (MAY):
	- Analyse AST structure (operators, blocks, predicates)
	- Decide traversal order and strategy (DFS, BFS, index scan, join order)
	- Identify sub-expressions for predicate pushdown or backend delegation
	- Precompute metadata used during execution

	Constraints:
	- MUST NOT mutate the shared Query AST in observable ways
	- MAY copy or rewrite AST fragments into the Plan
	- MUST return a reusable Qwiratry::Walker::Plan
	- MUST throw X::Qwiratry::UnknownQueryElement if query cannot be interpreted

	@param $query - The Query AST (RakuAST::Node)
	@param $root - The root data structure to query
	@returns Qwiratry::Walker::Plan - Precomputed execution strategy for the query
	@throws X::Qwiratry::UnknownQueryElement if query cannot be interpreted

	=end pod
	method plan(Mu $query, Mu:D $root --> Qwiratry::Walker::Plan) { ... }
    
	=begin pod

	Produce a new incremental result stream from an existing execution plan.

	Creates a fresh Context, initialises traversal state, and returns
	a QueryIterator that yields results lazily.

	Multiple iterators MAY be created from the same plan.
	Iterators MUST NOT share mutable traversal state.

	@param $plan - The execution plan to iterate
	@returns QueryIterator - Ready to produce results

	=end pod
	method iterator(Qwiratry::Walker::Plan $plan --> QueryIterator) { ... }
    
	=begin pod

	One-shot execution entrypoint (convenience method).

	Equivalent to: self.plan($query, $root).iterator
	via self.iterator(self.plan($query, $root))

	@param $query - The Query AST (RakuAST::Node)
	@param $root - The root data structure (must be defined)
	@returns QueryIterator - Ready to produce results

	=end pod
	method start(Mu $query, Mu:D $root --> QueryIterator) {
		self.iterator(self.plan($query, $root))
	}
    
	=begin pod

	Hook called before a traversal pass begins.

	Override to initialize global traversal state, prepare caches or
	indexes, or initialize multi-pass bookkeeping. Called once per pass.

	Default implementation: no-op

	@param $ctx - The Context for this traversal

	=end pod
	method PRE-PASS(Context $ctx) {
		# Default: no-op
	}
    
	=begin pod

	Hook called after a traversal pass completes.

	Override to collect diagnostics, decide whether to trigger another
	pass, or finalize results/clean up resources. Called once per pass.

	Default implementation: no-op

	@param $ctx - The Context for this traversal

	=end pod
	method POST-PASS(Context $ctx) {
		# Default: no-op
	}
    
	=begin pod

	Return capability metadata for this walker.

	Provides structured information about walker capabilities:
	- supports-lazy
	- supports-backtracking
	- supports-rewrite
	- supports-multi-phase
	- supports-streaming

	Used by Transformers, Composite Walkers, and debugging/profiling tools.

	Default implementation returns empty hash.

	@returns Associative - Capability metadata

	=end pod
	method capabilities(--> Associative) {
		default-walker-capabilities()
	}
    
	=begin pod

	Check if this walker can interpret the given query.

	Returns whether this Walker can interpret the given AST.
	Useful for Walker selection/delegation in hybrid or master walkers.

	Default implementation returns False (conservative).

	@param $query - The Query AST to check
	@returns Bool - True if walker can interpret query

	=end pod
	method supports(Mu $query --> Bool) {
		# Default: conservative - assume cannot support
		False
	}
}
