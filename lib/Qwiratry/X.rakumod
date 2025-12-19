#| Exception hierarchy for Qwiratry infrastructure
#| This module provides exception classes for error handling in the
#| Qwiratry infrastructure, including Walker-related exceptions and
#| Transformer-related exceptions.
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

#| Exception thrown when template ordering detects a conflict.
#| This exception is thrown by Transformer.ORDER-TEMPLATES() when two or more
#| templates have equal priority, specificity, and tie-breaker values and
#| could potentially match the same node, making the ordering ambiguous.
class X::Qwiratry::TemplateOrderingConflict is Exception is export {
    #| Human-readable error message describing the conflict
    has Str $.message is required;
    
    #| Names of the conflicting templates
    has @.template-names is required;
    
    #| Priority value that caused the conflict
    has Int $.priority;
    
    #| Specificity value that caused the conflict
    has Int $.specificity;
    
    #| Tie-breaker value that caused the conflict
    has Int $.tie-breaker;
    
    #| Override gist to provide informative string representation
    method gist(--> Str) {
        my $templates = @.template-names.join(', ');
        my $details = "priority=$.priority, specificity=$.specificity, tie-breaker=$.tie-breaker";
        "X::Qwiratry::TemplateOrderingConflict: $.message (templates: $templates, $details)"
    }
}

#| Exception thrown when no Walker can be found for a given data type.
#| This exception is thrown by Transformer.TRANSFORM() or WalkerFactory
#| when attempting to transform data but no appropriate Walker is available
#| for the data type.
class X::Qwiratry::NoWalkerFound is Exception is export {
    #| Human-readable error message describing what went wrong
    has Str $.message is required;
    
    #| The data type that could not be matched to a Walker
    has Str $.data-type is required;
    
    #| Available Walker types (if known)
    has @.available-walkers;
    
    #| Override gist to provide informative string representation
    method gist(--> Str) {
        my $available = @.available-walkers.elems > 0 
            ?? " (available: {@.available-walkers.join(', ')})"
            !! "";
        "X::Qwiratry::NoWalkerFound: $.message (data-type: $.data-type$available)"
    }
}
