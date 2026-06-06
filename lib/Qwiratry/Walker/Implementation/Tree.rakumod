=begin pod

Default tree Walker for depth-first, top-down traversal of Raku data structures.

Interprets navigation Query AST nodes for tree-shaped data (Positional children,
Associative attributes). Used by L<Qwiratry::Walker::Factory> when no specialized
Walker is registered.

=end pod

use Qwiratry::Walker;
use Qwiratry::QueryIterator;
use Qwiratry::Context;
use Qwiratry::Operator::Navigation;
use Qwiratry::Operator::Capability;
use Qwiratry::Query::Match;
use X::Qwiratry;

unit class Qwiratry::Walker::Implementation::Tree does Qwiratry::Walker {
    my class TreeContext does Context {
        has Int $.nodes-visited is rw = 0;
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

    my class TreePlan does Qwiratry::Walker::Plan {
        has Mu $.query-ast is required;
        has Mu $.root is required;
        has $.walker is required;

        method iterator(--> QueryIterator) {
            TreeIterator.new(
                :root($!root),
                :query-ast($!query-ast),
                :context(TreeContext.new),
            );
        }

        method query(--> Mu) { $!query-ast }

        method describe(--> Str) { "TreePlan({$!query-ast.^name})" }

        method capabilities(--> Associative) {
            {
                navigation => { enabled => True, domain => 'tree' },
                lazy => { enabled => True, type => 'incremental' },
            }
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
        False;
    }

    method capabilities(--> Associative) {
        {
            navigation => { enabled => True, domains => ['tree'] },
            'supports-rewrite' => { enabled => False },
        }
    }
}
