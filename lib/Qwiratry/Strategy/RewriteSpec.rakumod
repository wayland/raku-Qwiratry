=begin pod

Stub role marking rewrite specifications returned from Strategy hooks.

Distinguishes future rewrite payloads from L<ControlSignal|Qwiratry::Strategy::ControlSignal>
return values. Concrete rewrite types will implement this role in a later feature.

=end pod
unit module Qwiratry::Strategy::RewriteSpec;

=begin pod

Marker role for rewrite return values from C<on-match> and C<after> hooks.

No methods are required today; implementations will be added when rewrite
functionality is fully specified.

=end pod
role RewriteSpec is export {
	# Marker role - no methods required
	# Concrete implementations will define rewrite specifications in future features
}
