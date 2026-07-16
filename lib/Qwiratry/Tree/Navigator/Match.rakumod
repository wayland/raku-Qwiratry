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

	=begin code
	method supported-types(--> List)
	=end code

	=end pod
	method supported-types(--> List) {
		(Match,)
	}

	=begin pod

	=head2 C<tree-children>

	=begin code
	multi method tree-children(Match $node --> List)
	=end code

	Expose direct Match children from hash or list captures.

	=end pod
	multi method tree-children(Match $node --> List) {

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
