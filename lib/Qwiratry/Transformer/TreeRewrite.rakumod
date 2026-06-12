=begin pod

TreeRewrite role for in-place rewriting transformations

This role provides the `does TreeRewrite` trait that enables transformers
to mutate input data structures in-place. When a transformer does TreeRewrite,
the APPLY method behavior is modified to allow immediate node replacement.

=end pod
unit module Qwiratry::Transformer::TreeRewrite;

=begin pod

TreeRewrite role that modifies APPLY behavior for in-place rewriting.

When a transformer does TreeRewrite, it can mutate input nodes directly.
The APPLY method will use `make` to immediately replace the current node.

=end pod
role TreeRewrite is export {
	# This role is a marker - the actual behavior is implemented
	# in the Transformer class when TreeRewrite is detected
	# The role itself doesn't need to define methods, as the
	# mutation behavior is handled by the transformer's APPLY method
	# when $.mutates-input is True
}

