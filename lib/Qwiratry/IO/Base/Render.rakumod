=begin pod

Abstract base class for render implementations.

Concrete format renderers inherit from this class and override L<render>.

=end pod
class Qwiratry::IO::Base::Render {

	=begin pod

	Render structured data to external text; implementations must override.

	=end pod
	method render(Mu $data, Associative :%options --> Str) {
		die "render not implemented by {self.^name}";
	}
}
