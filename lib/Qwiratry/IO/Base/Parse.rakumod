=begin pod

Abstract base class for parse implementations.

Concrete format parsers inherit from this class and override L<parse>.

=end pod
class Qwiratry::IO::Base::Parse {

	=begin pod

	Parse external text into structured data; implementations must override.

	=end pod
	method parse(Str $input-string --> Mu) {
		die "parse not implemented by {self.^name}";
	}
}
