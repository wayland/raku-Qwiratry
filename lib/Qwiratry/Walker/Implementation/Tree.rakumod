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
use X::Qwiratry;

unit class Qwiratry::Walker::Implementation::Tree does Qwiratry::Walker {
    my class TreeContext does Context {
        has Int $.nodes-visited is rw = 0;
    }

    my class TreeIterator does QueryIterator {
        has Mu $.root is required;
        has Mu $.query-ast;
        has @!stack;
        has Bool $!started = False;
        has Bool $!skip-root = False;

        submethod BUILD(:$!root, :$!query-ast, :$!context) {
            @!stack = ();
            $!skip-root = $!query-ast ~~ DescendantOperator;
        }

        method !push-children(Mu $node) {
            my @children;
            if $node ~~ Positional {
                @children = $node.list;
            }
            elsif $node ~~ Associative {
                @children = $node.values.list;
            }
            for @children.reverse -> $child {
                @!stack.push($child);
            }
        }

        method pull-one(--> Mu) {
            unless $!started {
                $!started = True;
                if $!query-ast ~~ RootOperator {
                    $.context.nodes-visited++;
                    return $!root;
                }
                @!stack.push($!root);
            }

            while @!stack {
                my $node = @!stack.pop;
                $.context.nodes-visited++;
                self!push-children($node);
                next if $!skip-root && $node === $!root;
                return $node;
            }

            IterationEnd;
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
