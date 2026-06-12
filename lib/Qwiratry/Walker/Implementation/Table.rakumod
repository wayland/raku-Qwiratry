=begin pod

Table Walker for flat row collections (scan/index domain).

Treats a Positional of Associative rows as a table and evaluates queries
row-by-row without descending into nested tree structures.

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

unit class Qwiratry::Walker::Implementation::Table does Qwiratry::Walker {
	my class TableContext does Context {
		has Int $.rows-scanned is rw = 0;
		has $.finish-result is rw;
	}

	my class TableIterator does QueryIterator {
		has Mu $.root is required;
		has Mu $.query-ast is required;
		has Iterator $!matches;

		submethod BUILD(:$!root, :$!query-ast, :$!context) {
			$!matches = select($!query-ast, $!root).iterator;
		}

		method pull-one(--> Mu) {
			my $next = $!matches.pull-one;
			given $next {
				when IterationEnd { return IterationEnd; }
				default {
					$.context.rows-scanned++ if $.context.defined;
					$next
				}
			}
		}
	}

	my class StrategyTableIterator does QueryIterator {
		has Mu $.root is required;
		has Mu $.query-ast is required;
		has Mu $!rows;
		has Int $!index = 0;
		has Bool $!finished = False;
		has Bool $!finish-invoked = False;

		submethod BUILD(:$!root, :$!query-ast, :$!context) {
			$!rows = $!root ~~ Qwiratry::Table::Catalog
				?? $!root.active-rows
				!! $!root;
		}

		method !stop-traversal() {
			unless $!finish-invoked {
				invoke-finish($!root, $.context);
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
				my %state;

				my $before = run-before($row, $.context, %state);
				if stopped(%state) {
					self!stop-traversal;
					return $row if $before ~~ ControlSignal && $before != SKIP_ELEMENT;
					return IterationEnd;
				}
				next if $before ~~ ControlSignal && $before == SKIP_ELEMENT;

				run-on-match($row, $!query-ast, $!root, $.context, %state);
				if stopped(%state) {
					self!stop-traversal;
					return $row if node-matches($!query-ast, $row, :origin($!root));
					return IterationEnd;
				}

				run-after($row, $.context, %state);
				if stopped(%state) {
					self!stop-traversal;
				}

				next unless node-matches($!query-ast, $row, :origin($!root));
				$.context.rows-scanned++ if $.context.defined;
				return $row;
			}

			unless $!finish-invoked {
				invoke-finish($!root, $.context);
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

	method iterator(Qwiratry::Walker::Plan $plan --> QueryIterator) {
		$plan.iterator;
	}

	method supports(Mu $query --> Bool) {
		return True if $query ~~ RootOperator;
		return True if $query ~~ NavigationOperator;
		return True if $query ~~ SetOperator;
		return True if $query ~~ MapReduceOperator;
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
			Qwiratry::Walker::Capabilities.instance.navigation(:enabled(True), 'table'),
			Qwiratry::Walker::Capabilities.instance.lazy(:enabled(True), :type('incremental')),
		)
	}
}
