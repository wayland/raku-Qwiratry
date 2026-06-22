=begin pod

=head1 Overview

Marker role for rewrite specifications returned from strategy hooks.

Strategy hooks can return control signals today, and future rewrite features need
a separate type channel for payloads that describe structural edits. C<RewriteSpec>
is that channel: walkers can distinguish "control traversal" from "apply this
rewrite" without depending on a concrete rewrite class.

=end pod
unit module Qwiratry::Strategy::RewriteSpec;

=begin pod

=head1 Role

No methods are required yet. Concrete rewrite specifications will compose this
role when the rewrite protocol is fully specified.

=end pod
role RewriteSpec is export {
	# Marker role - no methods required
	# Concrete implementations will define rewrite specifications in future features
}
