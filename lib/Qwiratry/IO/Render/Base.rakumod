=begin pod

Base class for format-specific render modules.

Subclasses implement C<render> to serialize in-memory data to text.

=end pod
unit class Qwiratry::IO::Render::Base;

=begin pod

Render structured data to external text; subclasses must override.

=end pod
method render(Mu $data, Associative :%options --> Str) {
	die "render not implemented by {self.^name}";
}
