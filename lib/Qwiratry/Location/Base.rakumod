=begin pod

Abstract base classes for location I/O implementations.

Concrete location modules inherit from these operation contracts and override the
operation-specific method.

=end pod
class Qwiratry::Location::Base::Source {

	=begin pod

	Read text from C<$location>; implementations must override.

	=end pod
	method read(Str $location --> Str) {
		die "read not implemented by {self.^name}";
	}
}

class Qwiratry::Location::Base::Destination {

	=begin pod

	Write C<$content> to C<$location>; implementations must override.

	=end pod
	method write(Str $location, Mu $content --> Mu) {
		die "write not implemented by {self.^name}";
	}
}
