=begin pod

=head1 Overview

Core roles for query planning and execution.

Walkers separate planning from iteration. A L<Qwiratry::Walker> analyzes a query
and root data structure into a reusable L<Qwiratry::Walker::Plan>; the plan then
creates L<Qwiratry::QueryIterator> instances that stream results incrementally.

This split lets a planner validate unsupported query nodes early while allowing
multiple independent iterators to run from the same plan.

=end pod
use Qwiratry::Context;
use Qwiratry::QueryIterator;
use Qwiratry::Walker::Capabilities;

=begin pod

=head1 Plan Role

C<Qwiratry::Walker::Plan> represents a precomputed execution strategy for one
query/root pair.

Plans are reusable and should not mutate the original query AST in observable
ways. Concrete plans implement C<iterator>, C<query>, and C<describe>; composite
plans can also expose C<subplans> and richer capability metadata.

=head2 Required Methods

=item C<iterator() --> QueryIterator>

=item C<query() --> Mu>

=item C<describe() --> Str>

=head2 Optional Methods

=item C<optimise(&modification)>

=item C<subplans() --> Array[Qwiratry::Walker::Plan]>

=item C<capabilities() --> Associative>

=head2 Example

=begin code
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
=end code

=end pod
role Qwiratry::Walker::Plan {
	=begin pod

	=head2 C<iterator()>

	=begin code
	method iterator(--> QueryIterator)
	=end code

	Produces a query iterator for this plan.

	Each call should create an independent iterator with its own context and
	mutable traversal state.

	=end pod
	method iterator(--> QueryIterator) { ... }
    
	=begin pod

	=head2 C<query()>

	=begin code
	method query(--> Mu)
	=end code

	Returns the query AST represented by this plan.

	=end pod
	method query(--> Mu) { ... }
    
	=begin pod

	=head2 C<describe()>

	=begin code
	method describe(--> Str)
	=end code

	Returns a human-readable description for debugging, profiling, or
	explain-plan output.

	=end pod
	method describe(--> Str) { ... }
    
	=begin pod

	=head2 C<optimise(&modification)>

	=begin code
	method optimise(&modification)
	=end code

	=head3 Parameters

	=item C<&modification>

	 The callback that receives this plan and returns the optimized plan.

	Applies an optimization callback to the plan.

	The default implementation returns C<self>. Concrete plans can override this
	when they support plan rewriting.

	Concrete implementations should return a new plan unless in-place
	modification is known to be safe.

	=head3 Return Value

	Returns the optimized plan, which may be C<self> when no optimization is
	applied.

	=end pod
	method optimise(&modification) {
		# Default: return self unchanged
		# Concrete implementations may apply the modification
		self
	}
    
	=begin pod

	=head2 C<subplans()>

	=begin code
	method subplans(--> Array[Qwiratry::Walker::Plan])
	=end code

	Returns component plans for composite execution.

	Simple plans return an empty array.

	=end pod
	method subplans(--> Array[Qwiratry::Walker::Plan]) {
		# Default: no subplans (simple, non-composite plan)
		Array[Qwiratry::Walker::Plan].new
	}
    
	=begin pod

	=head2 C<capabilities()>

	=begin code
	method capabilities(--> Associative)
	=end code

	Returns structured capability metadata for introspection.

	The default delegates to L<Qwiratry::Walker::Capabilities.default-plan>.

	=head3 Metadata Shape

	Capability metadata is an associative value where each capability name maps
	to a structured value such as C<{ enabled => True, type => "incremental" }>.

	=head3 Common Capabilities

	=item C<lazy>

	The plan can produce results incrementally.

	=item C<backtracking>

	The plan or iterator can revisit earlier traversal state.

	=item C<streaming>

	The plan is suitable for streaming result consumers.

	=head3 Return Value

	Returns the plan capability metadata.

	=end pod
	method capabilities(--> Associative) {
		Qwiratry::Walker::Capabilities.instance.default-plan()
	}
}

=begin pod

=head1 Walker Role

C<Qwiratry::Walker> encapsulates how a query is executed over a data structure.

Concrete walkers implement C<plan> and C<iterator>. Optional methods have default
implementations that can be overridden for one-shot execution, traversal pass
hooks, capability metadata, and conservative support checks.

=head2 Required Methods

=item C<plan(Mu $query, Mu:D $root) --> Qwiratry::Walker::Plan>

=item C<iterator(Qwiratry::Walker::Plan $plan) --> QueryIterator>

=head2 Optional methods (have default implementations):

=item C<start($query, $root)>: convenience method for C<plan> followed by
 C<iterator>.

=item C<PRE-PASS($ctx)> and C<POST-PASS($ctx)>: traversal pass hooks.

=item C<capabilities()>: structured capability metadata.

=item C<supports($query)>: conservative walker-selection predicate.

=head2 Strategy Integration

=item C<Qwiratry::Walker> may be constructed with a strategy, for example
C<Qwiratry::Walker.new(:$strategy)>.

=item The strategy is stored in the context when creating iterators.

=item Concrete C<QueryIterator> implementations should call strategy hooks during
traversal via C<$ctx.strategy>.

=head2 Example

=begin code
class TreeWalker does Qwiratry::Walker {
    method plan(RakuAST::Node $query, Mu:D $root --> Qwiratry::Walker::Plan) {
        TreePlan.new(query-ast => $query, root => $root);
    }
    method iterator(Qwiratry::Walker::Plan $plan --> QueryIterator) {
        my $ctx = TreeContext.new(strategy => $.strategy);
        TreeIterator.new(context => $ctx, plan => self);
    }
}
=end code

=end pod
role Qwiratry::Walker does Iterable {
	=begin pod

	=head2 C<strategy>

	The default strategy for this walker, or C<Nil>.

	The slot is untyped to avoid a circular dependency with L<Qwiratry::Strategy>.

	=head3 Attribute

	C<strategy> is copied into traversal contexts so iterators can call strategy
	hooks during traversal. When it is undefined, no strategy hooks are called.

	=end pod
	has $.strategy;
    
	=begin pod

	=head2 C<plan(Mu $query, Mu:D $root)>

	=begin code
	method plan(Mu $query, Mu:D $root --> Qwiratry::Walker::Plan)
	=end code

	=head3 Parameters

	=item C<$query>

	 The query AST or query operator node to plan.

	=item C<$root>

	 The defined root data structure the query will run against.

	Analyzes a query/root pair and returns a reusable execution plan.

	=head3 Responsibilities

	=item Analyze AST structure, including operators, blocks, and predicates.

	=item Decide traversal order and strategy, such as DFS, BFS, index scan, or join
	 order.

	=item Identify sub-expressions for predicate pushdown or backend delegation.

	=item Precompute metadata used during execution.

	=head3 Constraints

	=item Must not mutate the shared query AST in observable ways.

	=item May copy or rewrite AST fragments into the plan.

	=item Must return a reusable C<Qwiratry::Walker::Plan>.

	=item Must throw L<X::Qwiratry::UnknownQueryElement> when the query cannot be
	 interpreted.

	=head3 Return Value

	Returns a reusable C<Qwiratry::Walker::Plan>. Throws
	L<X::Qwiratry::UnknownQueryElement> when the walker cannot interpret the
	query.

	=end pod
	method plan(Mu $query, Mu:D $root --> Qwiratry::Walker::Plan) { ... }
    
	=begin pod

	=head2 C<iterator(Qwiratry::Walker::Plan $plan)>

	=begin code
	method iterator(Qwiratry::Walker::Plan $plan --> QueryIterator)
	=end code

	=head3 Parameters

	=item C<$plan>

	 The execution plan produced by this walker or a compatible walker.

	Produces a fresh incremental result stream from an existing plan.

	=head3 Return Value

	Returns a C<QueryIterator> ready to produce results. Multiple iterators from
	the same reusable plan must not share mutable traversal state.

	=end pod
	method iterator(Qwiratry::Walker::Plan $plan --> QueryIterator) { ... }
    
	=begin pod

	=head2 C<start(Mu $query, Mu:D $root)>

	=begin code
	method start(Mu $query, Mu:D $root --> QueryIterator)
	=end code

	=head3 Parameters

	=item C<$query>

	 The query AST or operator node.

	=item C<$root>

	 The defined data structure to query.

	Convenience method that plans and immediately creates an iterator.

	=head3 Return Value

	Returns the iterator produced from C<self.iterator(self.plan($query, $root))>.

	=end pod
	method start(Mu $query, Mu:D $root --> QueryIterator) {
		self.iterator(self.plan($query, $root))
	}
    
	=begin pod

	=head2 C<PRE-PASS(Context $ctx)>

	=begin code
	method PRE-PASS(Context $ctx)
	=end code

	=head3 Parameters

	=item C<$ctx>

	 The context for this traversal pass.

	Hook called before a traversal pass begins. The default is a no-op.

	Override to initialize global traversal state, prepare caches or indexes, or
	initialize multi-pass bookkeeping. Called once per pass.

	=end pod
	method PRE-PASS(Context $ctx) {
		# Default: no-op
	}
    
	=begin pod

	=head2 C<POST-PASS(Context $ctx)>

	=begin code
	method POST-PASS(Context $ctx)
	=end code

	=head3 Parameters

	=item C<$ctx>

	 The context for this traversal pass after iteration completes.

	Hook called after a traversal pass completes. The default is a no-op.

	Override to collect diagnostics, decide whether to trigger another pass, or
	finalize results and clean up resources. Called once per pass.

	=end pod
	method POST-PASS(Context $ctx) {
		# Default: no-op
	}
    
	=begin pod

	=head2 C<capabilities()>

	=begin code
	method capabilities(--> Associative)
	=end code

	Returns structured capability metadata for transformer, master-walker, and
	introspection code.

	The default delegates to L<Qwiratry::Walker::Capabilities.default-walker>.

	=head3 Common Capabilities

	=item C<supports-lazy>

	The walker can produce results lazily.

	=item C<supports-backtracking>

	The walker can revisit earlier traversal state.

	=item C<supports-rewrite>

	The walker can participate in rewrite operations.

	=item C<supports-multi-phase>

	The walker can run multiple traversal phases or passes.

	=item C<supports-streaming>

	The walker can feed streaming consumers.

	=head3 Return Value

	Returns the walker capability metadata.

	=end pod
	method capabilities(--> Associative) {
		Qwiratry::Walker::Capabilities.instance.default-walker()
	}
    
	=begin pod

	=head2 C<supports(Mu $query)>

	=begin code
	method supports(Mu $query --> Bool)
	=end code

	=head3 Parameters

	=item C<$query>

	 The query AST or operator node being considered.

	Returns whether this walker can interpret C<$query>.

	The default is conservative and returns C<False>; concrete walkers override it
	for factory and master-walker selection.

	=head3 Return Value

	Returns C<True> when this walker can plan the query, otherwise C<False>.

	=end pod
	method supports(Mu $query --> Bool) {
		# Default: conservative - assume cannot support
		False
	}
}
