=begin pod

=head1 Overview

Abstract base classes for format implementations.

L<Qwiratry::Format> discovers concrete format modules dynamically and verifies
that each operation class inherits from the matching walkable base class here.
A format module normally provides C<::Parse> and/or C<::Render> classes under
its format namespace, for example C<Qwiratry::Format::MyFormat::Parse>, which
inherit C<ParseWalkable> / C<RenderWalkable>.

Formats whose parser emits a custom tree model should also provide a
C<Qwiratry::Tree::Navigator::*> class that does
C<Qwiratry::Tree::Navigator::Base>.

These classes are contracts rather than useful implementations. The default
methods throw so an incomplete plugin fails at the first attempted parse or
render instead of silently returning an invalid value.

Optional pull roles add chunk-oriented capabilities alongside the walkable
whole-value path. "Streaming" as a capability means a pull (or, later, push)
path is available.

=end pod
class Qwiratry::Format::Base::ParseWalkable {

	=begin pod

	=head1 Methods

	=head2 C<parse-walkable(Str $input-string)>

	=begin code
	method parse-walkable(Str $input-string --> Mu)
	=end code

	=head3 Parameters

	=item C<$input-string>

	 The external text to parse into Qwiratry data.


	Parses a complete external text value into structured Raku data.

	Concrete parsers override this method. Callers normally reach it through
	L<Qwiratry::Operator::IO::ParseOperator> or
	C<Qwiratry::Format.make(:type<Parse>, :format(...))>.

	=end pod
	method parse-walkable(Str $input-string --> Mu) {
		die "parse-walkable not implemented by {self.^name}";
	}
}

class Qwiratry::Format::Base::RenderWalkable {

	=begin pod

	=head2 C<render-walkable(Mu $data, Associative :%options)>

	=begin code
	method render-walkable(Mu $data, Associative :%options --> Str)
	=end code

	=head3 Parameters

	=item C<$data>

	 The input data, root value, or rendered value handled by this operation.

	=item C<%options>

	 Named format options, such as rendering preferences.


	Renders structured Raku data to a complete external text value.

	Concrete renderers override this method and may interpret C<%options> in a
	format-specific way. Non-streaming render paths may normalize lazy query
	results before calling this method; pull renderers that also do
	C<RenderPull> receive data without that forced materialization.

	=end pod
	method render-walkable(Mu $data, Associative :%options --> Str) {
		die "render-walkable not implemented by {self.^name}";
	}
}

=begin pod

Optional capability for parsers that accept a pull stream of text chunks.

When a format parser does this role, L<Qwiratry::Operator::IO::ParseOperator>
prefers C<parse-pull> whenever its input is already a text-chunk
C<Iterator>. Otherwise the operator falls back to joining chunks (when needed)
and calling C<parse-walkable>.

=end pod
role Qwiratry::Format::Base::ParsePull {
	=begin pod

	=head2 C<parse-pull(Iterator:D $chunks, *%options)>

	=begin code
	method parse-pull(Iterator:D $chunks, *%options --> Mu)
	=end code

	=head3 Parameters

	=item C<$chunks>

	 Pull iterator of C<Str> text chunks.

	=item C<%options>

	 Optional format-specific named arguments.


	Parses a stream of text chunks into structured data.

	May return a single value or a lazy C<Seq>/C<Iterator> of top-level values.
	Concrete pull parsers override this method.

	=end pod
	method parse-pull(Iterator:D $chunks, *%options --> Mu) {
		die "parse-pull not implemented by {self.^name}";
	}
}

=begin pod

Optional capability for renderers that emit a pull stream of text chunks.

When a format renderer does this role, L<Qwiratry::Operator::IO::RenderOperator>
calls C<render-pull> and does not force upstream lazy sequences into a list.

=end pod
role Qwiratry::Format::Base::RenderPull {
	=begin pod

	=head2 C<render-pull(Mu $data, Associative :%options)>

	=begin code
	method render-pull(Mu $data, Associative :%options --> Iterator:D)
	=end code

	=head3 Parameters

	=item C<$data>

	 Structured data to render, possibly still lazy.

	=item C<%options>

	 Named format options, such as rendering preferences.


	Renders structured data as a pull iterator of C<Str> chunks.

	Concrete pull renderers override this method.

	=end pod
	method render-pull(Mu $data, Associative :%options --> Iterator:D) {
		die "render-pull not implemented by {self.^name}";
	}
}
