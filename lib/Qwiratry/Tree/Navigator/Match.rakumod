=begin pod

=head1 Overview

Match tree navigator.

Matches are the result of a grammar, and are suited to be transformed into a 
variety of things, possibly into RakuAST nodes, or whatever the next stage in 
compilation is.  This module adapts Match nodes to Qwiratry's tree navigation 
protocol.

=end pod
use Qwiratry::Tree::Navigator::Base;

class Qwiratry::Tree::Navigator::Match does Qwiratry::Tree::Navigator::Base {
	=begin pod

	=head2 C<supported-types()>

	=end pod
	method supported-types(--> List) {
		(Match,)
	}

	=begin pod

	=head2 C<tree-children(Match $node)>

	Uses C<visit-children> to expose direct RakuAST children.

	=end pod
	method tree-children(Match $node --> List) {
		given $node {
			when .has('hash') {
				return (gather .<hash>(-> $child { take $child })).list;
				return 
			}
			when .has('list') {
				return .list;
			}
			default {
				return ();
			}
		}
	}
}
