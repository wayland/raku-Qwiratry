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

class X::Qwiratry::IO::FormatNotFound is X::Qwiratry::Operator is export {
    has Str $.format is required;
    has Str $.parse-or-render is required;

    method gist(--> Str) {
        my $module-name = "Qwiratry::IO::{$!parse-or-render.tc}::{$!format}";
        "X::Qwiratry::IO::FormatNotFound: Format module $module-name not found (format: $!format, operation: $!parse-or-render)"
    }
}

class X::Qwiratry::IO::LocationError is X::Qwiratry::Operator is export {
    has Str $.location is required;
    has Str $.reason is required;

    method gist(--> Str) {
        "X::Qwiratry::IO::LocationError: Location error for '$!location' (reason: $!reason)"
    }
}
