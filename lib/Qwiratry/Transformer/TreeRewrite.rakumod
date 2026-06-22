=begin pod

=head1 Overview

Marker role for in-place tree rewriting transformers.

A transformer that composes C<TreeRewrite> opts into mutating the input tree
instead of only producing transformed output. L<Qwiratry::Transformer> detects
the role at composition time, records the C<tree-rewrite> trait metadata, and
enables C<make> to replace the current node through L<Qwiratry::Tree::Replace>
during mold execution.

The role has no methods because the behavior belongs to the transformer's
runtime application path. Keeping the marker separate makes the opt-in visible
in transformer declarations without adding a second inheritance hierarchy.

=end pod
unit module Qwiratry::Transformer::TreeRewrite;

=begin pod

=head1 Role

C<TreeRewrite> is composed by transformer classes that want C<make> to update
the active transform root in place when a mold action emits a replacement value.

=end pod
role TreeRewrite is export {
	# This role is a marker - the actual behavior is implemented
	# in the Transformer class when TreeRewrite is detected
	# The role itself doesn't need to define methods, as the
	# mutation behavior is handled by the transformer's APPLY method
	# when $.mutates-input is True
}

