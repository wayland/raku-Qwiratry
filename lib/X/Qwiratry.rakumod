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

Base exception for operator evaluation failures.

=end pod
class X::Qwiratry::Operator is X::Qwiratry::Walker {
	has $.query-ast;
	has Str $.operator-type = 'Unknown';

	# Set once an install suggestion has already been emitted to $*ERR, so that
	# the default (uncaught) handler does not print the message a second time.
	# The full message remains available to programmatic handlers via .message.
	has Bool $.reported is rw = False;

	method gist(--> Str) {
		my $ast-info = $.query-ast.defined ?? $.query-ast.^name !! 'undefined';
		"X::Qwiratry::Operator: $.message (operator-type: $.operator-type, query-ast: $ast-info)"
	}
}

=begin pod

Raised when a format parser or renderer implementation cannot be loaded.

=end pod
class X::Qwiratry::Format::NotFound is X::Qwiratry::Operator {
	has Str $.format is required;
	has Str $.parse-or-render is required;

	method gist(--> Str) {
		return '' if self.reported;
		my $module-name = 'Qwiratry::Format::' ~ $!format;
		my $class-name = $module-name ~ '::' ~ $!parse-or-render.tc;
		"X::Qwiratry::Format::NotFound: Format implementation $class-name not found (format: $!format, operation: $!parse-or-render)"
	}
}

=begin pod

Raised when reading from or writing to a location fails.

C<$.location> is the location string from the query. Optional C<$.resolved> is
the filesystem path after scheme/tilde expansion (useful when C<$.location> is
relative). The gist also includes C<$*CWD> so relative-path failures are easier
to diagnose under C<temp $*CWD> or threaded CWD changes.

=end pod
class X::Qwiratry::IO::LocationError is X::Qwiratry::Operator {
	has Str $.location is required;
	has Str $.reason is required;
	has Str $.resolved;

	method gist(--> Str) {
		return '' if self.reported;
		my $msg = "X::Qwiratry::IO::LocationError: Location error for '$!location' (reason: $!reason)";
		$msg ~= "; resolved '$!resolved'"
			if $!resolved.defined && $!resolved ne $!location;
		$msg ~= "; cwd '$*CWD'";
		$msg
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

Exception thrown when mold ordering cannot be resolved due to conflicts.
This exception is thrown during mold ordering when molds have
equal priority, specificity, and tie-breaker values, making it impossible
to determine a deterministic order.

=end pod
class X::Qwiratry::MoldOrderingConflict is X::Qwiratry::Walker {
	# List of mold names involved in the conflict
	has @.mold-names is required;
    
	# Additional context about why the conflict occurred
	has Str $.conflict-details = '';
    
	# Override gist to provide detailed conflict information
	method gist(--> Str) {
		my $molds = @.mold-names.join(', ');
		my $details = $.conflict-details ?? " ($.conflict-details)" !! '';
		"X::Qwiratry::MoldOrderingConflict: $.message\n" ~
		"  Molds: $molds\n" ~
		"  Solution: Set explicit :tie-breaker values on conflicting molds to resolve the ordering ambiguity.$details"
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
This exception is thrown when a transformer or mold has a returns(Type) trait
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

Control-flow exception for mold actions. When thrown from a mold C<do>
block, the transformer continues with the next matching mold instead of
using the current result.

=end pod
class X::Qwiratry::NextMold is X::Qwiratry::Walker {
	method gist(--> Str) {
		"X::Qwiratry::NextMold: $.message (walker-type: $.walker-type)"
	}
}

=begin pod

Base exception for Cursor movement / argument errors.

=end pod
class X::Qwiratry::Cursor is X::Qwiratry::Walker {
	method gist(--> Str) {
		"X::Qwiratry::Cursor: $.message (walker-type: $.walker-type)"
	}
}

=begin pod

Both C<:axis> and C<:sector> were passed to a Cursor scroll method.

=end pod
class X::Qwiratry::Cursor::ConflictingDirection is X::Qwiratry::Cursor {
	method gist(--> Str) {
		"X::Qwiratry::Cursor::ConflictingDirection: $.message"
	}
}

=begin pod

Negative step (or Range endpoint) used with C<:sector>.

=end pod
class X::Qwiratry::Cursor::NegativeSectorStep is X::Qwiratry::Cursor {
	method gist(--> Str) {
		"X::Qwiratry::Cursor::NegativeSectorStep: $.message"
	}
}

=begin pod

Unsupported Axis, Sector, or scroll operation for this Cursor.

=end pod
class X::Qwiratry::Cursor::Unsupported is X::Qwiratry::Cursor {
	method gist(--> Str) {
		"X::Qwiratry::Cursor::Unsupported: $.message"
	}
}

=begin pod

Invalid Range for a count-taking C<fetch-*> method.

=end pod
class X::Qwiratry::Cursor::InvalidRange is X::Qwiratry::Cursor {
	method gist(--> Str) {
		"X::Qwiratry::Cursor::InvalidRange: $.message"
	}
}
