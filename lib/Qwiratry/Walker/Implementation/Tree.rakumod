=begin pod

=head1 Overview

Default tree Walker for depth-first, top-down traversal of Raku data structures.

Interprets navigation Query AST nodes for tree-shaped data (Positional children,
Associative attributes). Invokes L<Qwiratry::Strategy> hooks when a strategy is
attached to the Walker.

This walker is selected for ordinary nested Raku data by
L<Qwiratry::Walker::Factory>. Planning validates that the query is in the
operator families the tree evaluator understands, then returns a reusable
C<TreePlan>. Iteration is lazy: each plan creates a fresh context and iterator,
and results are pulled one at a time.

When a strategy is attached, the strategy-aware iterator performs an explicit
depth-first traversal so it can call C<before>, C<on-match>, C<should-follow>,
C<after>, and C<finish> at the right points. Without a strategy, the iterator
delegates directly to L<Qwiratry::Query::Runtime.select>.

=end pod

use Qwiratry::Walker;
use Qwiratry::Walker::Capabilities;
use Qwiratry::QueryIterator;
use Qwiratry::Context;
use Qwiratry::Operator::Navigation;
use Qwiratry::Operator::Capability;
use Qwiratry::Operator::Set;
use Qwiratry::Operator::MapReduce;
use Qwiratry::Query::Runtime;
use Qwiratry::Query::TreeNavigation;
use Qwiratry::Strategy::Traversal;
use Qwiratry::Strategy::ControlSignal;
use X::Qwiratry;

my constant traversal = Qwiratry::Strategy::Traversal.instance;
my constant query-runtime = Qwiratry::Query::Runtime.instance;
my constant tree-navigation = BasicTreeNavigation.new;

class Qwiratry::Walker::Implementation::Tree does Qwiratry::Walker is export {
	my class TreeContext does Context {
		has Int $.nodes-visited is rw = 0;
		has $.finish-result is rw;
	}

	my class TreeIterator does QueryIterator {
		has Mu $.root is required is built;
		has Mu $.query-ast is built;
		has Iterator $!matches;

		submethod TWEAK {
			$!matches = query-runtime.select($!query-ast, $!root).iterator;
		}

		method pull-one(--> Mu) {
			my $next = $!matches.pull-one;
			given $next {
				when IterationEnd { return IterationEnd; }
				default {
					$.context.defined and $.context.nodes-visited++;
					$next
				}
			}
		}
	}

	my class StrategyTreeIterator does QueryIterator {
		has Mu $.root is required is built;
		has Mu $.query-ast is required is built;
		has @!stack;
		has @!yield-queue;
		has TraversalState $!state = TraversalState.new;
		has Bool $!finished = False;
		has Bool $!finish-invoked = False;

		submethod TWEAK {
			$!root.defined and @!stack = [$!root];
		}

		# Stops tree iteration, invokes finish hooks once, and marks the iterator finished.
		method !stop-traversal() {
			@!stack = ();
			unless $!finish-invoked {
				traversal.invoke-finish($!root, $.context);
				$!finish-invoked = True;
			}
			$!finished = True;
		}

		# Runs traversal hooks for one element and queues matching nodes for yielding.
		method !visit-element(Mu $element, :$yield = True --> Mu) {
			$!state.clear-skip;

			my $before = traversal.run-before($element, $.context, $!state);
			if $!state.stopped {
				self!stop-traversal;
				return $yield ?? $element !! IterationEnd;
			}
			if $before ~~ ControlSignal && $before == SKIP_ELEMENT {
				return $yield ?? $element !! Nil;
			}

			if query-runtime.node-matches($!query-ast, $element, :origin($!root)) {
				@!yield-queue.push($element);
				$.context.defined and $.context.nodes-visited++;
			}

			traversal.run-on-match($element, $!query-ast, $!root, $.context, $!state);
			if $!state.stopped {
				self!stop-traversal;
				return $yield ?? $element !! IterationEnd;
			}

			unless $!state.should-skip-expand {
				for tree-navigation.tree-children($element) -> $child {
					next unless traversal.should-follow($element, 'child', $child, $.context);
					@!stack.push($child);
				}
			}

			traversal.run-after($element, $.context, $!state);
			if $!state.stopped {
				self!stop-traversal;
			}

			return $yield ?? $element !! Nil;
		}

		method pull-one(--> Mu) {
			if $!finished && @!stack.elems == 0 && @!yield-queue.elems == 0 {
				return IterationEnd;
			}

			if @!yield-queue.elems > 0 {
				return @!yield-queue.shift;
			}

			while @!stack.elems > 0 {
				my $element = @!stack.shift;
				self!visit-element($element);
				if @!yield-queue.elems > 0 {
					return @!yield-queue.shift;
				}
				last if $!state.stopped;
			}

			unless $!finish-invoked {
				traversal.invoke-finish($!root, $.context);
				$!finish-invoked = True;
			}
			$!finished = True;
			IterationEnd;
		}
	}

	my class TreePlan does Qwiratry::Walker::Plan {
		has Mu $.query-ast is required;
		has Mu $.root is required;
		has $.walker is required;

		method iterator(--> QueryIterator) {
			my $ctx = TreeContext.new(strategy => $!walker.strategy);
			if $ctx.strategy.defined {
				return StrategyTreeIterator.new(
					:root($!root),
					:query-ast($!query-ast),
					:context($ctx),
				);
			}
			TreeIterator.new(
				:root($!root),
				:query-ast($!query-ast),
				:context($ctx),
			);
		}

		method query(--> Mu) { $!query-ast }

		method describe(--> Str) { "TreePlan({$!query-ast.^name})" }

		method capabilities(--> Associative) {
			Qwiratry::Walker::Capabilities.instance.merge(
				Qwiratry::Walker::Capabilities.instance.navigation(:enabled(True), 'tree'),
				Qwiratry::Walker::Capabilities.instance.lazy(:enabled(True), :type('incremental')),
			)
		}
	}

	=begin pod

	=head1 Methods

	=head2 C<plan(Mu $query, Mu:D $root)>

	=begin code
	method plan(Mu $query, Mu:D $root --> Qwiratry::Walker::Plan)
	=end code

	=head3 Parameters

	=item C<$query>

	 The query AST or operator node being planned or tested.

	=item C<$root>

	 The traversal root that provides the data context for the delegated plan.


	Builds a reusable tree execution plan for C<$query> and C<$root>.

	Unsupported query nodes raise L<X::Qwiratry::UnknownQueryElement> before any
	iteration begins, giving callers a planning-time diagnostic instead of a lazy
	failure mid-stream.

	=end pod
	method plan(Mu $query, Mu:D $root --> Qwiratry::Walker::Plan) {
		unless self.supports($query) {
			X::Qwiratry::UnknownQueryElement.new(
				message => "Tree walker cannot plan query of type {$query.^name}",
				walker-type => self.^name,
				:query-ast($query),
			).throw;
		}
		TreePlan.new(:query-ast($query), :root($root), :walker(self));
	}

	=begin pod

	=head2 C<iterator(Qwiratry::Walker::Plan $plan)>

	=begin code
	method iterator(Qwiratry::Walker::Plan $plan --> QueryIterator)
	=end code

	=head3 Parameters

	=item C<$plan>

	 The execution plan to turn into a fresh query iterator.


	Returns a new iterator from an existing plan.

	The plan owns the query/root pair; every iterator receives its own
	C<TreeContext>, so multiple iterations over the same plan do not share
	counters or strategy state.

	=end pod
	method iterator(Qwiratry::Walker::Plan $plan --> QueryIterator) {
		$plan.iterator;
	}

	=begin pod

	=head2 C<supports(Mu $query)>

	=begin code
	method supports(Mu $query --> Bool)
	=end code

	=head3 Parameters

	=item C<$query>

	 The query AST or operator node being planned or tested.


	Returns true for query node families the tree walker can evaluate:
	navigation, set, map-reduce, root, and union-list query forms.

	=end pod
	method supports(Mu $query --> Bool) {
		$query ~~ RootOperator and return True;
		$query ~~ NavigationOperator and return True;
		$query ~~ SetOperator and return True;
		$query ~~ MapReduceOperator and return True;
		$query.WHAT === Array || $query.WHAT === List and return True;
		False;
	}

	=begin pod

	=head2 C<POST-PASS(Context $ctx)>

	=begin code
	method POST-PASS(Context $ctx)
	=end code

	=head3 Parameters

	=item C<$ctx>

	 The traversal context carrying walker and strategy state.


	Runs the strategy continuation hook after traversal, recording optional test
	instrumentation fields when the context supports them.

	=end pod
	method POST-PASS(Context $ctx) {
		if $ctx.strategy.defined {
			my $should-continue = $ctx.strategy.should-continue($ctx.strategy, $ctx);
			$ctx.can('should-continue-calls') and $ctx.should-continue-calls++;
			$ctx.can('should-continue-result') and $ctx.should-continue-result = $should-continue;
		}
	}

	=begin pod

	=head2 C<capabilities()>

	=begin code
	method capabilities(--> Associative)
	=end code

	Returns capability metadata used by planner and introspection code. The tree
	walker advertises tree navigation, incremental laziness, and rewrite support.

	=end pod
	method capabilities(--> Associative) {
		Qwiratry::Walker::Capabilities.instance.merge(
			Qwiratry::Walker::Capabilities.instance.navigation(:enabled(True), 'tree'),
			Qwiratry::Walker::Capabilities.instance.lazy(:enabled(True), :type('incremental')),
			%(supports-rewrite => %(enabled => True)),
		)
	}
}

