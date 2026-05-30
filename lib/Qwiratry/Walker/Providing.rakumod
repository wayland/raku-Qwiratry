=begin pod

"Providing" trait for domain metadata

This module implements the `is providing<domain-name>` compile-time trait
that attaches advisory domain metadata to root objects, containers, or declarations.
The metadata is discoverable at runtime via introspection and guides
Walker selection and planning for multi-domain queries.

Example usage:
  my $table is providing<sql> = SQL::Table.new(...);
  my $hybrid is providing<sql json> = ...;

=end pod
unit module Qwiratry::Walker::Providing;

=begin pod

Module-level registry for "providing" trait metadata.
Keyed by object identity (WHICH) for runtime discovery.

=end pod

our %PROVIDING-METADATA;

=begin pod

Compile-time trait that attaches domain metadata to declarands.

Stores domain names (Array[Str]) in the declarand's meta-object
for runtime discovery by Master Walkers and Slangs.

The trait does not alter runtime semantics, method dispatch, or type identity.
It exists solely to guide Walker selection and planning.

Example:
  my $table is providing<sql> = SQL::Table.new(...);
  my $hybrid is providing<sql json> = ...;

=end pod
multi sub trait_mod:<is>(Variable $declarand, :$providing) is export {
    # Extract domain names from trait arguments
    # $providing contains the domain names (from providing<sql json> syntax)
    # - Single domain: providing<sql> → $providing is Str "sql"
    # - Multiple domains: providing<sql json> → $providing is List ("sql", "json")
    my @domain-names;
    if $providing ~~ Positional {
        # Multiple domains: List/Array
        @domain-names = $providing.map(*.Str);
    } elsif $providing.defined {
        # Single domain: Str
        @domain-names = [$providing.Str];
    } else {
        # No domains provided (shouldn't happen, but handle gracefully)
        @domain-names = [];
    }
    
    # Store metadata in a module-level registry keyed by declarand identity
    # This ensures metadata is discoverable at runtime via providing-domains()
    # We use WHICH to get a unique identifier for the declarand
    # For variables, we need to store it by the variable's container identity
    # The declarand is the Variable object, but we need to store it so we can
    # retrieve it later from the actual variable instance
    # 
    # Note: The Variable declarand at compile time has a different WHICH than
    # the Scalar container at runtime. We store by Variable declarand identity
    # and use a fallback mechanism in providing-domains() to match them.
    %PROVIDING-METADATA{$declarand.WHICH} = @domain-names;
}

=begin pod

Discover domain metadata from an object or variable at runtime.

Returns Array[Str] of domain names if metadata exists, Nil otherwise.
Uses the module-level registry to access stored metadata.

For variables with "providing" trait, pass the variable itself (container).
The function will also try to get the container from a value using .VAR.

Example:
  my $table is providing<sql> = SQL::Table.new(...);
  my @domains = providing-domains($table);  # Returns ['sql']

=end pod
sub providing-domains(Mu $obj) is export {
    # First, try to get the container if this is a value
    # For variables, .VAR returns the Scalar container
    my $container = try { $obj.VAR } // $obj;
    
    # Look up metadata in the registry using container identity
    my $key = $container.WHICH;
    if %PROVIDING-METADATA{$key}:exists {
        my $result = %PROVIDING-METADATA{$key};
        return $result if $result;
    }
    
    # If direct lookup fails, do not guess from unrelated registry entries.
    # Fall back to trait introspection on the object itself.
    try {
        my @traits = $obj.^traits;
        for @traits -> $trait {
            if $trait.^name eq 'providing' {
                return $trait.arguments.map(*.Str).Array;
            }
        }
    }

    Nil
}
