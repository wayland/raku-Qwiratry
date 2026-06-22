=begin pod

=head1 Overview

Abstract base classes for format implementations.

L<Qwiratry::Format> discovers concrete format modules dynamically and verifies
that each operation class inherits from the matching base class here. A format
module normally provides C<::Parse> and/or C<::Render> classes under its format
namespace, for example C<Qwiratry::Format::MyFormat::Parse>.

These classes are contracts rather than useful implementations. The default
methods throw so an incomplete plugin fails at the first attempted parse or
render instead of silently returning an invalid value.

=end pod
class Qwiratry::Format::Base::Parse {

	=begin pod

	=head1 Methods

	=head2 C<parse(Str $input-string)>

	=begin code
	method parse(Str $input-string --> Mu)
	=end code

	=head3 Parameters

	=item C<$input-string>

	 The external text to parse into Qwiratry data.


	Parses external text into structured Raku data.

	Concrete parsers override this method. Callers normally reach it through
	L<Qwiratry::Operator::IO::ParseOperator> or
	C<Qwiratry::Format.make(:type<Parse>, :format(...))>.

	=end pod
	method parse(Str $input-string --> Mu) {
		die "parse not implemented by {self.^name}";
	}
}

class Qwiratry::Format::Base::Render {

	=begin pod

	=head2 C<render(Mu $data, Associative :%options)>

	=begin code
	method render(Mu $data, Associative :%options --> Str)
	=end code

	=head3 Parameters

	=item C<$data>

	 The input data, root value, or rendered value handled by this operation.

	=item C<%options>

	 Named format options, such as rendering preferences.


	Renders structured Raku data to external text.

	Concrete renderers override this method and may interpret C<%options> in a
	format-specific way. The pipeline normalizes lazy query results before calling
	the renderer.

	=end pod
	method render(Mu $data, Associative :%options --> Str) {
		die "render not implemented by {self.^name}";
	}
}
