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

role LocationOperatorNode does LocationOperator does AdaptorOperatorNode {
	has Str $.location is required is built;

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

	=end pod
	method evaluate(Mu :$origin, :&execute) {
		my $implementation = self.location-implementation;

		if self.location-type eq 'Source' {
			return $implementation.read(self.location);
		}

		my $content = execute(self.subject // $origin, :$origin);
		$implementation.write(self.location, $content);
		$content
	}
}

class SourceOperator is RakuAST::Node does LocationOperatorNode is export {
	method location-type(--> Str) {
		'Source'
	}
}

class DestinationOperator is RakuAST::Node does LocationOperatorNode does ChainedOperator is export {
	method location-type(--> Str) {
		'Destination'
	}
}

role FormatOperatorNode does FormatOperator does AdaptorOperatorNode does ChainedOperator {
	has Str $.format is required is built;

	submethod TWEAK {
		Qwiratry::Format.ensure-format(:type(self.format-type), :format($!format));
	}

	method format-input(Mu $origin, &execute) {
		execute(self.subject // $origin, :$origin)
	}

	method format-implementation {
		Qwiratry::Format.make(:type(self.format-type), :format($!format))
	}
}

class ParseOperator is RakuAST::Node does FormatOperatorNode is export {
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
	configured format implementation.

	=end pod
	method evaluate(Mu :$origin, :&execute) {
		self.format-implementation.parse(self.format-input($origin, &execute))
	}
}

class RenderOperator is RakuAST::Node does FormatOperatorNode is export {
	has %.options;

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

	=end pod
	method evaluate(Mu :$origin, :&execute) {
		my $data = self.format-input($origin, &execute);
		my $payload = $data ~~ Seq ?? $data.list !! $data;
		self.format-implementation.render($payload, |%(%.options // %()))
	}
}

