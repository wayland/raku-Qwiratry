=begin pod

=head1 Overview

RakuAST tree navigator.

RakuAST nodes are parsed and rendered by the Raku compiler. This module adapts
RakuAST nodes to Qwiratry's tree navigation protocol.

=end pod
use Qwiratry::Tree::Navigator::Base;

class Qwiratry::Tree::Navigator::RakuAST does Qwiratry::Tree::Navigator::Base {
	=begin pod

	=head2 C<supported-types()>

	=begin code
	method supported-types(--> List)
	=end code

	=end pod
	method supported-types(--> List) {
		(RakuAST::Node,)
	}

	=begin pod

	=head2 C<tree-children>

	=begin code
	multi method tree-children(RakuAST::Node $node --> List)
	=end code

	Uses C<visit-children> to expose direct RakuAST children.

	=end pod
	multi method tree-children(RakuAST::Node $node --> List) {
		if $node.can('visit-children') {
			return (gather $node.visit-children(-> $child { take $child })).list;
		}
		()
	}
}
