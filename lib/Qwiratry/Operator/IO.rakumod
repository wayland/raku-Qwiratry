=begin pod

I/O query operators as immutable AST nodes.

Source (C<⮳>), parse (C<↱>), render (C<↴>), and destination (C<⮷>) read,
parse, render, and write external data.

=end pod
unit module Qwiratry::Operator::IO;

use Qwiratry::Format;
use Qwiratry::Location;
use Qwiratry::Operator::Capability;
use Qwiratry::Operator::PipelineStep;
use Qwiratry::Exception::Operator;

role AdaptorOperatorNode does OperatorBase {
	has Mu $.subject;

	submethod TWEAK(:$subject) {
		$!subject = $subject if $subject.defined;
	}

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

	method describe(--> Str) {
		"SourceOperator(location: '$!location')"
	}

	method evaluate(Mu :$origin, :&execute) {
		read-location($!location)
	}
}

class ParseOperator is RakuAST::Node does FormatOperatorNode is export {
	has Str $.format is required;

	submethod TWEAK {
		Qwiratry::Format.ensure-format(:type<Parse>, :format($!format));
	}

	method describe(--> Str) {
		self.adaptor-describe("format: '{$!format.lc}'")
	}

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

	method describe(--> Str) {
		self.adaptor-describe("format: '{$!format.lc}', options: {%.options.raku}")
	}

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

	method describe(--> Str) {
		self.adaptor-describe("location: '$!location'")
	}

	method evaluate(Mu :$origin, :&execute) {
		my $content = execute($!subject // $origin, :$origin);
		write-location($!location, $content);
		$content
	}
}
