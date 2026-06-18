=begin pod

Operator-specific exceptions extending L<X::Qwiratry::Walker>.

=end pod
unit module Qwiratry::Exception::Operator;

use X::Qwiratry;

class X::Qwiratry::Operator is X::Qwiratry::Walker is export {
	has $.query-ast;
	has Str $.operator-type = 'Unknown';

	method gist(--> Str) {
		my $ast-info = $.query-ast.defined ?? $.query-ast.^name !! 'undefined';
		"X::Qwiratry::Operator: $.message (operator-type: $.operator-type, query-ast: $ast-info)"
	}
}

class X::Qwiratry::Format::NotFound is X::Qwiratry::Operator is export {
	has Str $.format is required;
	has Str $.parse-or-render is required;

	method gist(--> Str) {
		my $module-name = 'Qwiratry::Format::' ~ $!format;
		my $class-name = $module-name ~ '::' ~ $!parse-or-render.tc;
		"X::Qwiratry::Format::NotFound: Format implementation $class-name not found (format: $!format, operation: $!parse-or-render)"
	}
}

our sub format-not-found(
	Str :$message!,
	Str :$format!,
	Str :$parse-or-render!,
	Str :$operator-type!,
) is export {
	::('X::Qwiratry::Format::NotFound').new(
		:$message,
		:$format,
		:$parse-or-render,
		:$operator-type,
	)
}

class X::Qwiratry::IO::LocationError is X::Qwiratry::Operator is export {
	has Str $.location is required;
	has Str $.reason is required;

	method gist(--> Str) {
		"X::Qwiratry::IO::LocationError: Location error for '$!location' (reason: $!reason)"
	}
}
