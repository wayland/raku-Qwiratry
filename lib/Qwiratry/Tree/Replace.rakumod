=begin pod

=head1 Overview

In-place node replacement for tree-shaped data during C<TreeRewrite> transforms.

Locates a node under a root container and swaps it for a new value without
rebuilding the entire tree.

L<Qwiratry::Mold.make> calls this service when a transformer composes
C<TreeRewrite>. Replacement is identity-based: the old node must be the exact
object currently present under the root, not merely an equal value. That keeps
rewrites predictable when multiple nodes have the same contents.

The service supports the container shapes used by the built-in tree walker:
positional children, associative C<children>, and direct associative values. If
the root itself is being replaced, compatible containers are mutated in place so
external references to the root remain valid.

=end pod
use Qwiratry::Query::Match;

class Qwiratry::Tree::Replace {

	my $instance;

	=begin pod

	=head1 Methods

	=head2 C<instance()>

	=begin code
	method instance(--> Qwiratry::Tree::Replace)
	=end code

	Returns the shared replacement service instance.

	=end pod
	method instance(--> Qwiratry::Tree::Replace) {
		$instance //= self.new
	}

	=begin pod

	=head2 C<replace-node(Mu $old, Mu $new, Mu $root)>

	=begin code
	method replace-node(Mu $old, Mu $new, Mu $root --> Bool)
	=end code

	=head3 Parameters

	=item C<$old>

	 The existing node or value to find in the tree.

	=item C<$new>

	 The replacement value to install in place of the old node.

	=item C<$root>

	 The traversal root that provides the data context for the plan.


	Replaces C<$old> with C<$new> under C<$root>.

	Returns true when a replacement occurred. Undefined inputs and nodes that
	cannot be found return false; callers can use that to decide whether a
	TreeRewrite mold actually mutated the input structure.

	=end pod
	method replace-node(Mu $old, Mu $new, Mu $root --> Bool) {
		return False unless $old.defined && $new.defined && $root.defined;

		if $old === $root {
			return self!merge-into-container($root, $new);
		}

		my $parent = find-parent-in-tree($old, $root);
		return False unless $parent.defined;
		self!replace-in-parent($parent, $old, $new);
	}

	=begin pod

	=head2 C<!replace-in-parent(Mu $parent, Mu $old, Mu $new)>

	=begin code
	method !replace-in-parent(Mu $parent, Mu $old, Mu $new --> Bool)
	=end code

	=head3 Parameters

	=item C<$parent>

	 The parent container inspected while searching for the node to replace.

	=item C<$old>

	 The existing node or value to find in the tree.

	=item C<$new>

	 The replacement value to install in place of the old node.


	Replaces C<$old> within a discovered parent container.

	The method handles positional slots, associative C<children> arrays, and
	direct hash values. It returns false when the parent has no supported slot for
	the old node.

	=end pod
	method !replace-in-parent(Mu $parent, Mu $old, Mu $new --> Bool) {
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

	=begin pod

	=head2 C<!merge-into-container(Mu $container, Mu $new)>

	=begin code
	method !merge-into-container(Mu $container, Mu $new --> Bool)
	=end code

	=head3 Parameters

	=item C<$container>

	 The mutable container that should receive the replacement contents.

	=item C<$new>

	 The replacement value to install in place of the old node.


	Merges a replacement into the root container when the root itself matched.

	Hash roots receive the new hash keys and values; positional roots are spliced
	to contain the new list. Other shape changes return false because they cannot
	preserve the original root object identity.

	=end pod
	method !merge-into-container(Mu $container, Mu $new --> Bool) {
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
}
