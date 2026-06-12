=begin pod

In-place node replacement for tree-shaped data during C<TreeRewrite> transforms.

Locates a node under a root container and swaps it for a new value without
rebuilding the entire tree.

=end pod
use Qwiratry::Query::Match;

unit class Qwiratry::Tree::Replace;

my $instance;

=begin pod

Return the shared Tree::Replace service instance.

=end pod
method instance(--> Qwiratry::Tree::Replace) {
	$instance //= self.new
}

=begin pod

Replace C<$old> with C<$new> under C<$root>. Returns True when replacement succeeded.

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

Replace C<$old> with C<$new> in C<$parent> (positional slot, C<children>, or hash value).

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

When C<$old> is the root, merge C<$new> into the existing container in place.

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
