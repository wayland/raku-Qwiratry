=begin pod

=head1 Overview

Table Walker for flat row collections (scan/index domain).

Treats a Positional of Associative rows as a table and evaluates queries
row-by-row without descending into nested tree structures.

The factory selects this walker for positional data whose first row is
associative and does not look like a tree node. It also works with
L<Qwiratry::Table::Catalog>, where the active row set and foreign-key metadata
come from the catalog rather than a plain list.

Plans are reusable and iterators are lazy. With no strategy attached, iteration
delegates to L<Qwiratry::Query::Match.select>; with a strategy attached, the
walker scans rows explicitly so it can call strategy hooks around each row.

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
use Qwiratry::Table;
use Qwiratry::Strategy::Traversal;
use Qwiratry::Strategy::ControlSignal;
use X::Qwiratry;

my constant traversal = Qwiratry::Strategy::Traversal.instance;

class Qwiratry::Walker::Implementation::Table does Qwiratry::Walker is export {
	my class TableContext does Context {
		has Int $.rows-scanned is rw = 0;
		has $.finish-result is rw;
	}

	my class TableIterator does QueryIterator {
		has Mu $.root is required is built;
		has Mu $.query-ast is required is built;
		has Iterator $!matches;

		submethod TWEAK {
			$!matches = select($!query-ast, $!root).iterator;
		}

		method pull-one(--> Mu) {
			my $next = $!matches.pull-one;
			given $next {
				when IterationEnd { return IterationEnd; }
				default {
					$.context.defined and $.context.rows-scanned++;
					$next
				}
			}
		}
	}

	my class StrategyTableIterator does QueryIterator {
		has Mu $.root is required is built;
		has Mu $.query-ast is required is built;
		has Mu $!rows;
		has Int $!index = 0;
		has Bool $!finished = False;
		has Bool $!finish-invoked = False;

		submethod TWEAK {
			$!rows = $!root ~~ Qwiratry::Table::Catalog
				?? $!root.active-rows
				!! $!root;
		}

		# Invokes finish hooks once and marks table iteration as complete.
		method !stop-traversal() {
			unless $!finish-invoked {
				traversal.invoke-finish($!root, $.context);
				$!finish-invoked = True;
			}
			$!finished = True;
		}

		method pull-one(--> Mu) {
			if $!finished {
				return IterationEnd;
			}

			while $!index < $!rows.elems {
				my $row = $!rows[$!index++];
				my $state = TraversalState.new;

				my $before = traversal.run-before($row, $.context, $state);
				if $state.stopped {
					self!stop-traversal;
					$before ~~ ControlSignal && $before != SKIP_ELEMENT and return $row;
					return IterationEnd;
				}
				next if $before ~~ ControlSignal && $before == SKIP_ELEMENT;

				traversal.run-on-match($row, $!query-ast, $!root, $.context, $state);
				if $state.stopped {
					self!stop-traversal;
					node-matches($!query-ast, $row, :origin($!root)) and return $row;
					return IterationEnd;
				}

				traversal.run-after($row, $.context, $state);
				if $state.stopped {
					self!stop-traversal;
				}

				next unless node-matches($!query-ast, $row, :origin($!root));
				$.context.defined and $.context.rows-scanned++;
				return $row;
			}

			unless $!finish-invoked {
				traversal.invoke-finish($!root, $.context);
				$!finish-invoked = True;
			}
			$!finished = True;
			IterationEnd;
		}
	}

	my class TablePlan does Qwiratry::Walker::Plan {
		has Mu $.query-ast is required;
		has Mu $.root is required;
		has $.walker is required;

		method iterator(--> QueryIterator) {
			my $ctx = TableContext.new(strategy => $!walker.strategy);
			if $ctx.strategy.defined {
				return StrategyTableIterator.new(
					:root($!root),
					:query-ast($!query-ast),
					:context($ctx),
				);
			}
			TableIterator.new(
				:root($!root),
				:query-ast($!query-ast),
				:context($ctx),
			);
		}

		method query(--> Mu) { $!query-ast }

		method describe(--> Str) { "TablePlan({$!query-ast.^name})" }

		method capabilities(--> Associative) {
			Qwiratry::Walker::Capabilities.instance.merge(
				Qwiratry::Walker::Capabilities.instance.navigation(:enabled(True), 'table'),
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


	Builds a reusable table execution plan for C<$query> and C<$root>.

	Unsupported query nodes raise L<X::Qwiratry::UnknownQueryElement> at planning
	time. The returned plan records the query, root, and walker so each iterator
	can create its own table context.

	=end pod
	method plan(Mu $query, Mu:D $root --> Qwiratry::Walker::Plan) {
		unless self.supports($query) {
			X::Qwiratry::UnknownQueryElement.new(
				message => "Table walker cannot plan query of type {$query.^name}",
				walker-type => self.^name,
				:query-ast($query),
			).throw;
		}
		TablePlan.new(:query-ast($query), :root($root), :walker(self));
	}

	=begin pod

	=head2 C<iterator(Qwiratry::Walker::Plan $plan)>

	=begin code
	method iterator(Qwiratry::Walker::Plan $plan --> QueryIterator)
	=end code

	=head3 Parameters

	=item C<$plan>

	 The execution plan to turn into a fresh query iterator.


	Returns a fresh iterator from an existing table plan.

	Each iterator owns its C<TableContext>, including row counters and strategy
	state, so repeated iteration over the same plan is independent.

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


	Returns true for query node families the table walker can evaluate:
	navigation, set, map-reduce, and root operators.

	=end pod
	method supports(Mu $query --> Bool) {
		$query ~~ RootOperator and return True;
		$query ~~ NavigationOperator and return True;
		$query ~~ SetOperator and return True;
		$query ~~ MapReduceOperator and return True;
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

	Returns capability metadata used by planner and introspection code. The table
	walker advertises table navigation and incremental lazy scanning.

	=end pod
	method capabilities(--> Associative) {
		Qwiratry::Walker::Capabilities.instance.merge(
			Qwiratry::Walker::Capabilities.instance.navigation(:enabled(True), 'table'),
			Qwiratry::Walker::Capabilities.instance.lazy(:enabled(True), :type('incremental')),
		)
	}
}
