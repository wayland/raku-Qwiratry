=begin pod

Provides trait for domain metadata

This module implements the `provides<domain-name>` compile-time trait
that attaches advisory domain metadata to root objects, containers, or declarations.
The metadata is discoverable at runtime via introspection and guides
Walker selection and planning for multi-domain queries.

Example usage:
  my $table provides<sql> = SQL::Table.new(...);
  my $hybrid provides<sql json> = ...;

=end pod
unit module Qwiratry::Provides;

=begin pod

Module-level registry for provides trait metadata.
Keyed by object identity (WHICH) for runtime discovery.

=end pod
our %PROVIDES-METADATA;

=begin pod

Compile-time trait that attaches domain metadata to declarands.

Stores domain names (Array[Str]) in the declarand's meta-object
for runtime discovery by Master Walkers and Slangs.

The trait does not alter runtime semantics, method dispatch, or type identity.
It exists solely to guide Walker selection and planning.

Example:
  my $table provides<sql> = SQL::Table.new(...);
  my $hybrid provides<sql json> = ...;

=end pod
sub trait_mod:<provides>($declarand, *@domains) is export {
    # Extract domain names from trait arguments
    # @domains contains the domain names as strings
    my @domain-names = @domains.map(*.Str);
    
    # Store metadata in a module-level registry keyed by declarand identity
    # This ensures metadata is discoverable at runtime via provides-domains()
    # We use WHICH to get a unique identifier for the declarand
    %PROVIDES-METADATA{$declarand.WHICH} = @domain-names;
}

=begin pod

Discover domain metadata from an object or variable at runtime.

Returns Array[Str] of domain names if metadata exists, Nil otherwise.
Uses the module-level registry to access stored metadata.

For variables with provides trait, pass the variable itself (container).
The function will also try to get the container from a value using .VAR.

Example:
  my $table provides<sql> = SQL::Table.new(...);
  my @domains = provides-domains($table);  # Returns ['sql']

=end pod
sub provides-domains(Mu $obj) is export {
    # First, try to get the container if this is a value
    # For variables, .VAR returns the Scalar container
    my $container = try { $obj.VAR } // $obj;
    
    # Look up metadata in the registry using container identity
    my $key = $container.WHICH;
    if %PROVIDES-METADATA{$key}:exists {
        return %PROVIDES-METADATA{$key};
    }
    
    # Also check via .^traits introspection as fallback
    # This allows discovery even if registry lookup fails
    try {
        my @traits = $obj.^traits;
        for @traits -> $trait {
            if $trait.^name eq 'provides' {
                # Extract domain names from trait
                # This is a fallback mechanism
                return $trait.arguments.map(*.Str).Array;
            }
        }
    }
    
    Nil
}

