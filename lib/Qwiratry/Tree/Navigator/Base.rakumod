=begin pod

=head1 Overview

Base role and default implementation for tree navigators.

Tree navigators adapt concrete tree-shaped values to Qwiratry's generic tree
navigation protocol. Custom navigators do C<Qwiratry::Tree::Navigator::Base>.

=end pod
role Qwiratry::Tree::Navigator::Base {
	=begin pod

	=head2 C<supported-types()>

	=begin code
	method supported-types(--> List)
	=end code

	Returns the types or roles this navigator handles. The base navigator
	handles ordinary Raku containers.

	=end pod
	method supported-types(--> List) {
		(Positional, Associative)
	}

	=begin pod

	=head2 C<supports(Mu $node)>

	=begin code
	method supports(Mu $node --> Bool)
	=end code

	Returns whether C<$node> matches one of C<supported-types>.

	=end pod
	method supports(Mu $node --> Bool) {
		for self.supported-types -> $type {
			$node ~~ $type and return True;
		}
		False
	}

	=begin pod

	=head2 C<tree-children(Mu $node)>

	=begin code
	method tree-children(Mu $node --> List)
	=end code

	Returns direct children for ordinary Raku tree-shaped values.

	=end pod
	method tree-children(Mu $node --> List) {
		$node ~~ Positional and return $node.list;
		if $node ~~ Associative {
			if $node<children> ~~ Positional {
				return $node<children>.list;
			}
		}
		()
	}

	=begin pod

	=head2 C<tree-parent(Mu $node, Mu :$origin)>

	=begin code
	method tree-parent(Mu $node, Mu :$origin --> Mu)
	=end code

	Returns a direct parent when the node model exposes one. Callers should fall
	back to context caches when this returns C<Nil>. When C<origin> is supplied,
	the default implementation walks from that root using this navigator's
	C<tree-children> method.

	=end pod
	method tree-parent(Mu $node, Mu :$origin --> Mu) {
		$node.can('parent') and return $node.parent;
		$origin.defined and return self.find-parent-in-tree($node, $origin);
		Nil
	}

	=begin pod

	=head2 C<find-parent-in-tree(Mu $node, Mu $current)>

	=begin code
	method find-parent-in-tree(Mu $node, Mu $current --> Mu)
	=end code

	Finds C<$node>'s direct parent by identity while walking from C<$current>.

	=end pod
	method find-parent-in-tree(Mu $node, Mu $current --> Mu) {
		$current.defined or return Nil;
		for self.tree-children($current) -> $child {
			$child === $node and return $current;
			my $found = self.find-parent-in-tree($node, $child);
			$found.defined and return $found;
		}
		Nil
	}

	=begin pod

	=head2 C<tree-attributes(Mu $node)>

	=begin code
	method tree-attributes(Mu $node --> Associative)
	=end code

	Returns attribute-like values when the node naturally exposes them.

	=end pod
	method tree-attributes(Mu $node --> Associative) {
		$node ~~ Associative and return $node;
		%()
	}
}
