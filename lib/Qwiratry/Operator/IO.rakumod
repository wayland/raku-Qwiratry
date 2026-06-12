=begin pod

I/O query operators as immutable AST nodes.

Source (C<⮳>), parse (C<↱>), render (C<↴>), and destination (C<⮷>) read,
parse, render, and write external data.

=end pod
unit module Qwiratry::Operator::IO;

use Qwiratry::IO::Parse;
use Qwiratry::IO::Render;
use Qwiratry::Operator::Capability;
use Qwiratry::Operator::PipelineStep;
use Qwiratry::Exception::Operator;

role IOOperatorNode does IOOperator does OperatorBase {
	has Mu $.subject;

	submethod TWEAK(:$subject) {
		$!subject = $subject if $subject.defined;
	}

	method io-describe(Str $detail --> Str) {
		my $sub = $!subject.defined ?? " subject={$!subject.^name}" !! '';
		"{self.^name}($detail$sub)"
	}
}

sub validate-location(Str $location --> Str) is export {
	return $location if $location.starts-with(any('http://', 'https://', 'file://'));
	return $location if $location.starts-with('/') || $location.starts-with('./')
		|| ($location !~~ /^\w+:\/\// && $location.contains('.'));
	return $location if $location ~~ /^[\w\.\-\/]+$/;
	X::Qwiratry::IO::LocationError.new(
		:message("Invalid I/O location: $location"),
		:location($location),
		:reason('Invalid location format'),
		:operator-type('IOOperator'),
	).throw;
}

class SourceOperator is RakuAST::Node does IOOperator does OperatorBase is export {
	has Str $.location is required;

	submethod BUILD(Str :$!location!) {
		validate-location($!location);
	}

	method describe(--> Str) {
		"SourceOperator(location: '$!location')"
	}

	method evaluate(Mu :$origin, :&execute) {
		read-location($!location)
	}
}

class ParseOperator is RakuAST::Node does IOOperatorNode is export {
	has Str $.format is required;

	submethod TWEAK {
		Qwiratry::IO::Parse.instance.ensure-format($!format);
	}

	method describe(--> Str) {
		self.io-describe("format: '{$!format.lc}'")
	}

	method evaluate(Mu :$origin, :&execute) {
		my $text = execute($!subject // $origin, :$origin);
		parse-data($!format, $text)
	}
}

class RenderOperator is RakuAST::Node does IOOperatorNode is export {
	has Str $.format is required;
	has %.options;

	submethod TWEAK {
		Qwiratry::IO::Render.instance.ensure-format($!format);
	}

	method describe(--> Str) {
		self.io-describe("format: '{$!format.lc}', options: {%.options.raku}")
	}

	method evaluate(Mu :$origin, :&execute) {
		my $data = execute($!subject // $origin, :$origin);
		render-data($!format, $data, %.options)
	}
}

class DestinationOperator is RakuAST::Node does IOOperatorNode is export {
	has Str $.location is required;

	submethod BUILD(Str :$!location!) {
		validate-location($!location);
	}

	method describe(--> Str) {
		self.io-describe("location: '$!location'")
	}

	method evaluate(Mu :$origin, :&execute) {
		my $content = execute($!subject // $origin, :$origin);
		write-location($!location, $content);
		$content
	}
}
