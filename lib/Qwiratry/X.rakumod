#| Exception hierarchy for Walker infrastructure
#| This module provides exception classes for error handling in the
#| Walker infrastructure, including base exception X::Qwiratry::Walker
#| and specific exception X::Qwiratry::UnknownQueryElement.
unit module Qwiratry::X;

#| Base exception class for all Walker-related errors.
#| Provides common attributes for error reporting and debugging.
class X::Qwiratry::Walker is Exception is export {
    #| Human-readable error message describing what went wrong
    has Str $.message is required;
    
    #| Type identifier of the walker that threw this exception
    has Str $.walker-type = 'Unknown';
    
    #| Override gist to provide informative string representation
    method gist(--> Str) {
        "X::Qwiratry::Walker: $.message (walker-type: $.walker-type)"
    }
}

#| Exception thrown when a Walker cannot interpret a Query AST element.
#| This exception is thrown by Walker.plan() when it encounters a query
#| element it does not know how to handle.
class X::Qwiratry::UnknownQueryElement is X::Qwiratry::Walker is export {
    #| The Query AST node that could not be interpreted
    has $.query-ast;
    
    #| Override gist to include query AST information
    method gist(--> Str) {
        my $ast-info = $.query-ast.defined ?? $.query-ast.^name !! 'undefined';
        "X::Qwiratry::UnknownQueryElement: $.message (walker-type: $.walker-type, query-ast: $ast-info)"
    }
}
