=begin pod

=head1 Overview

Shared tree traversal helpers for query matching and navigation evaluators.

=end pod
unit module Qwiratry::Query::TreeNavigation;

=begin pod

=head2 C<role TreeNavigation>

=begin code :lang<raku>
role TreeNavigation is export
=end code

Defines C<TreeNavigation>.

=end pod
role TreeNavigation is export {
	=begin pod

	=head2 C<method tree-children>

	=begin code :lang<raku>
	method tree-children(Mu $node --> List)
	=end code

	Documents C<method tree-children>.

	=item C<$node>

	The C<$node> parameter.

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

	=head2 C<method find-parent-in-tree>

	=begin code :lang<raku>
	method find-parent-in-tree(Mu $node, Mu $current --> Mu)
	=end code

	Documents C<method find-parent-in-tree>.

	=item C<$node>

	The C<$node> parameter.

	=item C<$current>

	The C<$current> parameter.

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
}

=begin pod

=head2 C<class BasicTreeNavigation>

=begin code :lang<raku>
class BasicTreeNavigation does TreeNavigation is export
=end code

Defines C<BasicTreeNavigation>.

=end pod
class BasicTreeNavigation does TreeNavigation is export { }
