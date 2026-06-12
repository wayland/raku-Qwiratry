=begin pod

Default tree Walker for depth-first, top-down traversal of Raku data structures.

Interprets navigation Query AST nodes for tree-shaped data (Positional children,
Associative attributes). Invokes L<Qwiratry::Strategy> hooks when a strategy is
attached to the Walker.

=end pod

use Qwiratry::Walker;
use Qwiratry::Walker::Capabilities;
use Qwiratry::QueryIterator;
use Qwiratry::Context;
use Qwiratry::Operator::Navigation;
use Qwiratry::Operator::Capability;
use Qwiratry::Operator::Set;
use Qwiratry::Operator::MapReduce;
use Qwiratry::Query::Match;
use Qwiratry::Strategy::Traversal;
use Qwiratry::Strategy::ControlSignal;
use X::Qwiratry;

unit class Qwiratry::Walker::Implementation::Tree does Qwiratry::Walker {
	my class TreeContext does Context {
		has Int $.nodes-visited is rw = 0;
		has $.finish-result is rw;
	}

	my class TreeIterator does QueryIterator {
		has Mu $.root is required;
		has Mu $.query-ast;
		has Iterator $!matches;

		submethod BUILD(:$!root, :$!query-ast, :$!context) {
			$!matches = select($!query-ast, $!root).iterator;
		}

		method pull-one(--> Mu) {
			my $next = $!matches.pull-one;
			given $next {
				when IterationEnd { return IterationEnd; }
				default {
					$.context.nodes-visited++ if $.context.defined;
					$next
				}
			}
		}
	}

	my class StrategyTreeIterator does QueryIterator {
		has Mu $.root is required;
		has Mu $.query-ast is required;
		has @!stack;
		has @!yield-queue;
		has %!state;
		has Bool $!finished = False;
		has Bool $!finish-invoked = False;

		submethod BUILD(:$!root, :$!query-ast, :$!context) {
			@!stack = [$!root] if $!root.defined;
		}

		method !stop-traversal() {
			@!stack = ();
			unless $!finish-invoked {
				invoke-finish($!root, $.context);
				$!finish-invoked = True;
			}
			$!finished = True;
		}

		method !visit-element(Mu $element, :$yield = True --> Mu) {
			clear-skip(%!state);

			my $before = run-before($element, $.context, %!state);
			if stopped(%!state) {
				self!stop-traversal;
				return $yield ?? $element !! IterationEnd;
			}
			if $before ~~ ControlSignal && $before == SKIP_ELEMENT {
				return $yield ?? $element !! Nil;
			}

			if node-matches($!query-ast, $element, :origin($!root)) {
				@!yield-queue.push($element);
				$.context.nodes-visited++ if $.context.defined;
			}

			run-on-match($element, $!query-ast, $!root, $.context, %!state);
			if stopped(%!state) {
				self!stop-traversal;
				return $yield ?? $element !! IterationEnd;
			}

			unless skip-expand(%!state) {
				for tree-children($element) -> $child {
					next unless should-follow($element, 'child', $child, $.context);
					@!stack.push($child);
				}
			}

			run-after($element, $.context, %!state);
			if stopped(%!state) {
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
				last if stopped(%!state);
			}

			unless $!finish-invoked {
				invoke-finish($!root, $.context);
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

	method iterator(Qwiratry::Walker::Plan $plan --> QueryIterator) {
		$plan.iterator;
	}

	method supports(Mu $query --> Bool) {
		return True if $query ~~ RootOperator;
		return True if $query ~~ NavigationOperator;
		return True if $query ~~ SetOperator;
		return True if $query ~~ MapReduceOperator;
		return True if $query.WHAT === Array || $query.WHAT === List;
		False;
	}

	method POST-PASS(Context $ctx) {
		if $ctx.strategy.defined {
			my $should-continue = $ctx.strategy.should-continue($ctx.strategy, $ctx);
			$ctx.should-continue-calls++ if $ctx.can('should-continue-calls');
			$ctx.should-continue-result = $should-continue if $ctx.can('should-continue-result');
		}
	}

	method capabilities(--> Associative) {
		Qwiratry::Walker::Capabilities.instance.merge(
			Qwiratry::Walker::Capabilities.instance.navigation(:enabled(True), 'tree'),
			Qwiratry::Walker::Capabilities.instance.lazy(:enabled(True), :type('incremental')),
			%(supports-rewrite => %(enabled => True)),
		)
	}
}

sub tree-children(Mu $node --> List) {
	return $node.list if $node ~~ Positional;
	if $node ~~ Associative {
		if $node<children> ~~ Positional {
			return $node<children>.list;
		}
	}
	();
}
