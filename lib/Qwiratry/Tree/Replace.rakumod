=begin pod

In-place node replacement for tree-shaped data during C<TreeRewrite> transforms.

=end pod
unit module Qwiratry::Tree::Replace;

use Qwiratry::Query::Match;

=begin pod

Replace C<$old> with C<$new> under C<$root>. Returns True when replacement succeeded.

=end pod
our sub replace-node-in-tree(Mu $old, Mu $new, Mu $root --> Bool) is export {
    return False unless $old.defined && $new.defined && $root.defined;

    if $old === $root {
        return merge-into-container($root, $new);
    }

    my $parent = find-parent-in-tree($old, $root);
    return False unless $parent.defined;
    replace-in-parent($parent, $old, $new);
}

sub replace-in-parent(Mu $parent, Mu $old, Mu $new --> Bool) {
    if $parent ~~ Positional {
        for 0..^$parent.elems -> $i {
            next unless $parent[$i] === $old;
            $parent[$i] = $new;
            return True;
        }
    }
    if $parent ~~ Associative {
        if $parent<children> ~~ Positional {
            for 0..^$parent<children>.elems -> $i {
                next unless $parent<children>[$i] === $old;
                $parent<children>[$i] = $new;
                return True;
            }
        }
        for $parent.keys -> $key {
            next unless $parent{$key} === $old;
            $parent{$key} = $new;
            return True;
        }
    }
    False
}

sub merge-into-container(Mu $container, Mu $new --> Bool) {
    if $container ~~ Associative && $new ~~ Associative {
        for $new.keys -> $key {
            $container{$key} = $new{$key};
        }
        return True;
    }
    if $container ~~ Positional && $new ~~ Positional {
        $container.splice(0, $container.elems, |$new.list);
        return True;
    }
    False
}
