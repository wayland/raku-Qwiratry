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

use Qwiratry::Format;
use Qwiratry::Location;
use Qwiratry::Operator::Capability;
use Qwiratry::Operator::PipelineStep;
use X::Qwiratry;

role AdaptorOperatorNode does OperatorBase {
	has Mu $.subject;

	submethod TWEAK(:$subject) {
		$subject.defined and $!subject = $subject;
	}

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
		my $sub = $!subject.defined ?? " subject={$!subject.^name}" !! '';
		"{self.^name}($detail$sub)"
	}
}

role FormatOperatorNode does FormatOperator does AdaptorOperatorNode {
}

role LocationOperatorNode does LocationOperator does AdaptorOperatorNode {
}

class SourceOperator is RakuAST::Node does LocationOperator does OperatorBase is export {
	has Str $.location is required;

	submethod BUILD(Str :$!location!) {
		Qwiratry::Location.ensure-location(:type<Source>, :location($!location));
	}

	=begin pod

	=head2 C<SourceOperator.describe()>

	=begin code
	method describe(--> Str)
	=end code

	Returns a debug label containing the source location.

	=end pod
	method describe(--> Str) {
		"SourceOperator(location: '$!location')"
	}

	=begin pod

	=head2 C<SourceOperator.evaluate(:$origin, :&execute)>

	=begin code
	method evaluate(Mu :$origin, :&execute)
	=end code

	=head3 Parameters

	=item C<$origin>

	 The root or originating value for evaluating the operator subject.

	=item C<&execute>

	 The callback used to evaluate this operator's subject before adapting it.


	Reads text from the configured location. C<$origin> and C<&execute> are
	accepted for pipeline compatibility but are not needed by source nodes.

	=end pod
	method evaluate(Mu :$origin, :&execute) {
		read-location($!location)
	}
}

class ParseOperator is RakuAST::Node does FormatOperatorNode is export {
	has Str $.format is required;

	submethod TWEAK {
		Qwiratry::Format.ensure-format(:type<Parse>, :format($!format));
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
	configured format implementation.

	=end pod
	method evaluate(Mu :$origin, :&execute) {
		my $text = execute($!subject // $origin, :$origin);
		parse-data($!format, $text)
	}
}

class RenderOperator is RakuAST::Node does FormatOperatorNode is export {
	has Str $.format is required;
	has %.options;

	submethod TWEAK {
		Qwiratry::Format.ensure-format(:type<Render>, :format($!format));
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

	=end pod
	method evaluate(Mu :$origin, :&execute) {
		my $data = execute($!subject // $origin, :$origin);
		render-data($!format, $data, %.options)
	}
}

class DestinationOperator is RakuAST::Node does LocationOperatorNode is export {
	has Str $.location is required;

	submethod BUILD(Str :$!location!) {
		Qwiratry::Location.ensure-location(:type<Destination>, :location($!location));
	}

	=begin pod

	=head2 C<DestinationOperator.describe()>

	=begin code
	method describe(--> Str)
	=end code

	Returns a debug label containing the destination location and any upstream
	subject.

	=end pod
	method describe(--> Str) {
		self.adaptor-describe("location: '$!location'")
	}

	=begin pod

	=head2 C<DestinationOperator.evaluate(:$origin, :&execute)>

	=begin code
	method evaluate(Mu :$origin, :&execute)
	=end code

	=head3 Parameters

	=item C<$origin>

	 The root or originating value for evaluating the operator subject.

	=item C<&execute>

	 The callback used to evaluate this operator's subject before adapting it.


	Evaluates the subject (or pipeline origin), writes it to the configured
	location, and returns the written content for pipeline pass-through.

	=end pod
	method evaluate(Mu :$origin, :&execute) {
		my $content = execute($!subject // $origin, :$origin);
		write-location($!location, $content);
		$content
	}
}
