=begin pod

=head1 Overview

Navigator-only format namespace for RakuAST.

RakuAST does not provide C<Parse> or C<Render> implementations here because the
Raku compiler owns parsing and rendering of Raku source. This module only adapts
RakuAST nodes to Qwiratry's tree navigation protocol.

=end pod
use Qwiratry::Format::Base;

class Qwiratry::Format::RakuAST::TreeNavigator does Qwiratry::Format::Base::TreeNavigator {
	=begin pod

	=head2 C<supported-types()>

	=end pod
	method supported-types(--> List) {
		(RakuAST::Node,)
	}

	=begin pod

	=head2 C<tree-children(Mu $node)>

	Uses C<visit-children> to expose direct RakuAST children.

	=end pod
	method tree-children(Mu $node --> List) {
		if $node ~~ RakuAST::Node && $node.can('visit-children') {
			return (gather $node.visit-children(-> $child { take $child })).list;
		}
		()
	}
}
