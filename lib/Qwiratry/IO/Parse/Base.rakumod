=begin pod

Base class for format-specific parse modules.

Subclasses implement C<parse> to turn external text into in-memory data.

=end pod
unit class Qwiratry::IO::Parse::Base;

=begin pod

Parse external text into structured data; subclasses must override.

=end pod
method parse(Str $text --> Mu) {
	die "parse not implemented by {self.^name}";
}
