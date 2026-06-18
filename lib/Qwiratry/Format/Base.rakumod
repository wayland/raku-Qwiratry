=begin pod

Abstract base classes for format implementations.

Concrete format modules inherit from these operation contracts and override the
operation-specific method.

=end pod
class Qwiratry::Format::Base::Parse {

	=begin pod

	Parse external text into structured data; implementations must override.

	=end pod
	method parse(Str $input-string --> Mu) {
		die "parse not implemented by {self.^name}";
	}
}

class Qwiratry::Format::Base::Render {

	=begin pod

	Render structured data to external text; implementations must override.

	=end pod
	method render(Mu $data, Associative :%options --> Str) {
		die "render not implemented by {self.^name}";
	}
}
