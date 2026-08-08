=begin pod

=head1 Overview

I/O query operators as immutable AST nodes.

Source (C<⮳>), parse (C<↱>), render (C<↴>), and destination (C<⮷>) read,
parse, render, and write external data.

These nodes form adaptor pipelines around normal query operators. Source and
destination nodes resolve location backends through L<Qwiratry::Location>; parse
and render nodes resolve format implementations through L<Qwiratry::Format>.

Unlike navigation and relational operators, the I/O operators override
C<evaluate> because they have side effects or external data boundaries. They
still compose with the generic pipeline executor by accepting C<:$origin> and
C<:&execute>.

=end pod
unit module Qwiratry::Operator::IO;

use TypedIterator;
use Qwiratry::Format;
use Qwiratry::Format::Base;
use Qwiratry::Location;
use Qwiratry::Location::Base;
use Qwiratry::Operator::Capability;
use X::Qwiratry;

# Reject non-text advertised streams; for Mu/untyped, require each element ~~ Str.
sub require-text-chunk(Mu $pulled, Mu:U $advertised, Str:D :$operator-type --> Str:D) {
	unless $pulled ~~ Str {
		X::Qwiratry::IO::ElementType.new(
			:message('Adaptor expected a Str text chunk'),
			:expected(Str),
			:got($pulled),
			:advertised($advertised),
			:$operator-type,
		).throw;
	}
	$pulled
}

sub assert-text-stream(Iterator:D $chunks, Str:D :$operator-type --> Mu:U) {
	my $of = iterator-of($chunks);
	if $of !=== Mu && !of-is-text($of) {
		X::Qwiratry::IO::ElementType.new(
			:message('Adaptor expected a text-chunk TypedIterator (of Str)'),
			:expected(Str),
			:advertised($of),
			:$operator-type,
		).throw;
	}
	$of
}

# When .of is Mu (or plain Iterator), validate each pull is Str for text adaptors.
class TextChunkValidatingIterator does TypedIterator {
	has Iterator $!source;
	has Str $.operator-type is required;

	method new(Iterator:D $source, Str:D :$operator-type!) {
		self.bless(:$source, :$operator-type);
	}

	submethod BUILD(Iterator:D :$!source!, Str:D :$!operator-type!) {}

	method of(--> Mu:U) { Str }

	method pull-one() {
		my $pulled := $!source.pull-one;
		return $pulled if $pulled =:= IterationEnd;
		require-text-chunk($pulled, Mu, :operator-type($!operator-type));
	}
}

sub ensure-text-pull(Iterator:D $chunks, Str:D :$operator-type --> Iterator:D) {
	my $of = assert-text-stream($chunks, :$operator-type);
	return $chunks if of-is-text($of);
	TextChunkValidatingIterator.new($chunks, :$operator-type)
}

# Join a pull stream of text chunks into one Str for whole-value fallback.
sub join-text-chunks(Iterator:D $chunks --> Str) {
	my $of = assert-text-stream($chunks, :operator-type('ParseOperator'));
	my @parts;
	loop {
		my $pulled := $chunks.pull-one;
		last if $pulled =:= IterationEnd;
		@parts.push(require-text-chunk($pulled, $of, :operator-type('ParseOperator')));
	}
	@parts.join
}

=begin pod

Base role for I/O adaptor AST nodes that participate in pipeline evaluation.

=end pod
role AdaptorOperatorNode does OperatorBase {
	=begin pod

	=head1 Methods

	=head2 C<adaptor-describe(Str $detail)>

	=begin code
	method adaptor-describe(Str $detail --> Str)
	=end code

	=head3 Parameters

	=item C<$detail>

	 The operator-specific detail string to include in the description.


	Builds a compact debug label for adaptor operators, including operation
	details and any upstream subject in the pipeline.

	=end pod
	method adaptor-describe(Str $detail --> Str) {
		my $sub = self ~~ ChainedOperator ?? self.subject-description !! '';
		"{self.^name}($detail$sub)"
	}
}

=begin pod

Shared behavior for location-backed source and destination operators.

=end pod
role LocationOperatorNode does LocationOperator does AdaptorOperatorNode {
	has Str $.location is required is built;

	=begin pod

	=head2 C<TWEAK()>

	=begin code
	submethod TWEAK
	=end code

	Validate the configured location against the source or destination backend registry.

	=end pod
	submethod TWEAK {
		Qwiratry::Location.ensure-location(:type(self.location-type), :location($!location));
	}

	=begin pod

	=head2 C<describe()>

	=begin code
	method describe(--> Str)
	=end code

	Returns a debug label containing the location and, for chained location
	operators, any upstream subject.

	=end pod
	method describe(--> Str) {
		self.adaptor-describe("location: '$!location'")
	}

	=begin pod

	=head2 C<location-implementation()>

	=begin code
	method location-implementation
	=end code

	Return the loaded location backend implementation for this operator.

	=end pod
	method location-implementation {
		Qwiratry::Location.make(:type(self.location-type), :location(self.location))
	}

	=begin pod

	=head2 C<evaluate(:$origin, :&execute)>

	=begin code
	method evaluate(Mu :$origin, :&execute)
	=end code

	Reads source locations directly. Destination locations evaluate their subject
	or pipeline origin, write that content, and return it for pass-through.

	Sources always use whole-value C<read-walkable> here so directory roots, globs,
	and existing callers keep their current return shapes. Pull composition is
	chosen by C<ParseOperator> when both the source and parser support pull chunks.

	Push destinations prefer an incremental sink when the upstream value is
	a text-chunk C<Iterator> (C<TypedIterator.of> is C<Str>, or untyped C<Mu>
	with per-element C<Str> values); otherwise they fall back to whole-value
	C<write-walkable>. Non-text advertised streams and non-C<Str> elements raise
	L<X::Qwiratry::IO::ElementType>. Streamed destination pass-through is
	single-consumer: the returned value is the consumed iterator, which is
	exhausted after writing.

	=end pod
	method evaluate(Mu :$origin, :&execute) {
		my $implementation = self.location-implementation;

		if self.location-type eq 'Source' {
			return $implementation.read-walkable(self.location);
		}

		# Prefer the chained subject; do not use // with $origin here — a defined
		# but empty List origin would be wrong, and bare C<execute(...)> must call
		# the pipeline callback (parameter), not be confused with other candidates.
		my $upstream = self.subject.defined ?? self.subject !! $origin;
		my $content = &execute($upstream, :$origin);
		if $implementation ~~ Qwiratry::Location::Base::DestinationPush
			&& $content ~~ Iterator
		{
			my $of = assert-text-stream($content, :operator-type('DestinationOperator'));
			my $sink = $implementation.open-sink-push(self.location);
			loop {
				my $pulled := $content.pull-one;
				last if $pulled =:= IterationEnd;
				$sink.write-chunk(
					require-text-chunk($pulled, $of, :operator-type('DestinationOperator'))
				);
			}
			$sink.close;
			return $content;
		}
		if $content ~~ Iterator {
			$content = join-text-chunks($content);
		}
		$implementation.write-walkable(self.location, $content);
		$content
	}
}

=begin pod

AST node for reading data from an external location.

=end pod
class SourceOperator is RakuAST::Node does LocationOperatorNode is export {
	=begin pod

	=head2 C<location-type()>

	=begin code
	method location-type(--> Str)
	=end code

	Identify this location operator as a source adapter.

	=end pod
	method location-type(--> Str) {
		'Source'
	}
}

=begin pod

AST node for writing evaluated pipeline data to an external location.

=end pod
class DestinationOperator is RakuAST::Node does LocationOperatorNode does ChainedOperator is export {
	=begin pod

	=head2 C<location-type()>

	=begin code
	method location-type(--> Str)
	=end code

	Identify this location operator as a destination adapter.

	=end pod
	method location-type(--> Str) {
		'Destination'
	}
}

=begin pod

Shared behavior for format-backed parse and render operators.

=end pod
role FormatOperatorNode does FormatOperator does AdaptorOperatorNode does ChainedOperator {
	has Str $.format is required is built;

	=begin pod

	=head2 C<TWEAK()>

	=begin code
	submethod TWEAK
	=end code

	Validate the configured format against the parse or render format registry.

	=end pod
	submethod TWEAK {
		Qwiratry::Format.ensure-format(:type(self.format-type), :format($!format));
	}

	# Evaluate this format operator's subject, falling back to the pipeline origin.
	method !execute-input(Mu $origin, &execute) {
		execute(self.subject // $origin, :$origin)
	}

	=begin pod

	=head2 C<format-input>

	=begin code
	multi method format-input(IO::Handle:D $handle, &execute)
	multi method format-input(Mu $origin, &execute)
	=end code

	Produce format-ready input. A raw C<IO::Handle> left-hand side (such as
	C<$*IN>) is resolved via C<!execute-input> then slurped (handle left open).
	Otherwise the subject is resolved via C<!execute-input> only.

	=end pod
	multi method format-input(IO::Handle:D $handle, &execute) {
		self!execute-input($handle, &execute).slurp
	}

	multi method format-input(Mu $origin, &execute) {
		self!execute-input($origin, &execute)
	}

	=begin pod

	=head2 C<format-implementation()>

	=begin code
	method format-implementation
	=end code

	Return the loaded format implementation for this operator.

	=end pod
	method format-implementation {
		Qwiratry::Format.make(:type(self.format-type), :format($!format))
	}
}

=begin pod

AST node for parsing text from the pipeline into structured data.

=end pod
class ParseOperator is RakuAST::Node does FormatOperatorNode is export {
	=begin pod

	=head2 C<format-type()>

	=begin code
	method format-type(--> Str)
	=end code

	Identify this format operator as a parser.

	=end pod
	method format-type(--> Str) {
		'Parse'
	}

	=begin pod

	=head2 C<ParseOperator.describe()>

	=begin code
	method describe(--> Str)
	=end code

	Returns a debug label containing the parse format and any upstream subject.

	=end pod
	method describe(--> Str) {
		self.adaptor-describe("format: '{$!format.lc}'")
	}

	=begin pod

	=head2 C<ParseOperator.evaluate(:$origin, :&execute)>

	=begin code
	method evaluate(Mu :$origin, :&execute)
	=end code

	=head3 Parameters

	=item C<$origin>

	 The root or originating value for evaluating the operator subject.

	=item C<&execute>

	 The callback used to evaluate this operator's subject before adapting it.


	Evaluates the subject (or pipeline origin) to text and parses it with the
	configured format implementation. C<format-input> slurps an C<IO::Handle>
	left-hand side when present.

	When both the format does C<ParsePull> and the subject is a
	C<SourceOperator> whose backend does C<SourcePull>, prefers
	C<read-pull> + C<parse-pull>. A bare text-chunk C<Iterator> input also
	uses C<parse-pull> when available; otherwise chunks are joined for
	C<parse-walkable>. Non-text C<TypedIterator.of> values and non-C<Str>
	elements raise L<X::Qwiratry::IO::ElementType>.

	=end pod
	method evaluate(Mu :$origin, :&execute) {
		my $implementation = self.format-implementation;

		if $implementation ~~ Qwiratry::Format::Base::ParsePull
			&& (self.subject // $origin) ~~ SourceOperator
		{
			my $source-op = self.subject // $origin;
			my $source-impl = $source-op.location-implementation;
			if $source-impl ~~ Qwiratry::Location::Base::SourcePull {
				return $implementation.parse-pull(
					ensure-text-pull(
						$source-impl.read-pull($source-op.location),
						:operator-type('ParseOperator'),
					),
				);
			}
		}

		my $input = self.format-input($origin, &execute);
		if $implementation ~~ Qwiratry::Format::Base::ParsePull
			&& $input ~~ Iterator
		{
			return $implementation.parse-pull(
				ensure-text-pull($input, :operator-type('ParseOperator')),
			);
		}
		if $input ~~ Iterator {
			$input = join-text-chunks($input);
		}
		$implementation.parse-walkable($input)
	}
}

=begin pod

AST node for rendering structured pipeline data into text.

=end pod
class RenderOperator is RakuAST::Node does FormatOperatorNode is export {
	has %.options;

	=begin pod

	=head2 C<format-type()>

	=begin code
	method format-type(--> Str)
	=end code

	Identify this format operator as a renderer.

	=end pod
	method format-type(--> Str) {
		'Render'
	}

	=begin pod

	=head2 C<RenderOperator.describe()>

	=begin code
	method describe(--> Str)
	=end code

	Returns a debug label containing the render format, options, and any upstream
	subject.

	=end pod
	method describe(--> Str) {
		self.adaptor-describe("format: '{$!format.lc}', options: {%.options.raku}")
	}

	=begin pod

	=head2 C<RenderOperator.evaluate(:$origin, :&execute)>

	=begin code
	method evaluate(Mu :$origin, :&execute)
	=end code

	=head3 Parameters

	=item C<$origin>

	 The root or originating value for evaluating the operator subject.

	=item C<&execute>

	 The callback used to evaluate this operator's subject before adapting it.


	Evaluates the subject (or pipeline origin) to data and renders it with the
	configured format implementation and options.

	When the format does C<RenderPull>, calls C<render-pull> without
	forcing a lazy C<Seq> into a list. Walkable renderers still normalize
	C<Seq> inputs to a list before C<render-walkable>.

	=end pod
	method evaluate(Mu :$origin, :&execute) {
		my $implementation = self.format-implementation;
		my $data = self.format-input($origin, &execute);
		my %opts = %(%.options // %());
		if $implementation ~~ Qwiratry::Format::Base::RenderPull {
			return $implementation.render-pull($data, |%opts);
		}
		my $payload = $data ~~ Seq ?? $data.list !! $data;
		$implementation.render-walkable($payload, |%opts)
	}
}

