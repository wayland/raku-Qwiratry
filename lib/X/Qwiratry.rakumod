=begin pod

Exception hierarchy for Qwiratry infrastructure
This module provides exception classes for error handling in the
Qwiratry infrastructure, including Qwiratry::Walker-related exceptions and
Transformer-related exceptions.

=end pod

=begin pod

Base exception class for all Qwiratry::Walker-related errors.
Provides common attributes for error reporting and debugging.

=end pod
class X::Qwiratry::Walker is Exception {
	# Human-readable error message describing what went wrong
	has Str $.message is required;
    
	# Type identifier of the walker that threw this exception
	has Str $.walker-type = 'Unknown';
    
	# Override gist to provide informative string representation
	method gist(--> Str) {
		"X::Qwiratry::Walker: $.message (walker-type: $.walker-type)"
	}
}

=begin pod

Exception thrown when a Qwiratry::Walker cannot interpret a Query AST element.
This exception is thrown by Qwiratry::Walker.plan() when it encounters a query
element it does not know how to handle.

=end pod
class X::Qwiratry::UnknownQueryElement is X::Qwiratry::Walker {
	# The Query AST node that could not be interpreted
	has $.query-ast;
    
	# Override gist to include query AST information
	method gist(--> Str) {
		my $ast-info = $.query-ast.defined ?? $.query-ast.^name !! 'undefined';
		"X::Qwiratry::UnknownQueryElement: $.message (walker-type: $.walker-type, query-ast: $ast-info)"
	}
}

=begin pod

Exception thrown when template ordering cannot be resolved due to conflicts.
This exception is thrown during template ordering when templates have
equal priority, specificity, and tie-breaker values, making it impossible
to determine a deterministic order.

=end pod
class X::Qwiratry::TemplateOrderingConflict is X::Qwiratry::Walker {
	# List of template names involved in the conflict
	has @.template-names is required;
    
	# Additional context about why the conflict occurred
	has Str $.conflict-details = '';
    
	# Override gist to provide detailed conflict information
	method gist(--> Str) {
		my $templates = @.template-names.join(', ');
		my $details = $.conflict-details ?? " ($.conflict-details)" !! '';
		"X::Qwiratry::TemplateOrderingConflict: $.message\n" ~
		"  Templates: $templates\n" ~
		"  Solution: Set explicit :tie-breaker values on conflicting templates to resolve the ordering ambiguity.$details"
	}
}

=begin pod

Exception thrown when no Qwiratry::Walker can be found for a given data type.
This exception is thrown when attempting to transform data but no
appropriate Qwiratry::Walker is available in the registry for the data's type.

=end pod
class X::Qwiratry::NoWalkerFound is X::Qwiratry::Walker {
	# The type of data for which no Walker was found
	has Mu $.data-type is required;
    
	# Override gist to include data type information
	method gist(--> Str) {
		my $type-name = $.data-type.^name;
		"X::Qwiratry::NoWalkerFound: $.message (data-type: $type-name)"
	}
}

=begin pod

Exception thrown when a transformation result does not match the returns(Type) trait constraint.
This exception is thrown when a transformer or template has a returns(Type) trait
but the actual result does not conform to the specified type.

=end pod
class X::Qwiratry::TypeCheck is X::Qwiratry::Walker {
	# The expected type from returns(Type) trait
	has Mu $.expected is required;
    
	# The actual type of the result
	has Mu $.got is required;
    
	# Override gist to include type information
	method gist(--> Str) {
		my $expected-name = $.expected.^name;
		my $got-name = $.got.^name;
		"X::Qwiratry::TypeCheck: $.message (expected: $expected-name, got: $got-name)"
	}
}

=begin pod

Control-flow exception for template actions. When thrown from a template C<do>
block, the transformer continues with the next matching template instead of
using the current result.

=end pod
class X::Qwiratry::NextTemplate is X::Qwiratry::Walker {
	method gist(--> Str) {
		"X::Qwiratry::NextTemplate: $.message (walker-type: $.walker-type)"
	}
}
