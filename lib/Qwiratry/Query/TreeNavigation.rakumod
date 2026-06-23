=begin pod

=head1 Overview

Shared tree traversal helpers for query matching and navigation evaluators.

=end pod
unit module Qwiratry::Query::TreeNavigation;

role TreeNavigation is export {
	method tree-children(Mu $node --> List) {
		$node ~~ Positional and return $node.list;
		if $node ~~ Associative {
			if $node<children> ~~ Positional {
				return $node<children>.list;
			}
		}
		()
	}

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

class BasicTreeNavigation does TreeNavigation is export { }
