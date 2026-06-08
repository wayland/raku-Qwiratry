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

Module-level storage for "providing" trait metadata.
Runtime lookups use variable container WHICH keys; pending entries are bound lazily
on first providing-domains() call (compile-time Variable identity != Scalar).

=end pod

our %PROVIDING-METADATA;
our %PROVIDING-SCHEMA;
our @PROVIDING-PENDING;  # queue of space-joined domain name strings

sub normalize-providing-domains($providing --> List) {
    my @raw = do given $providing {
        when Positional { $providing.map({ ~$_ }) }
        when Str { (~$providing).split(/\s+/) }
        default { $providing.defined ?? (~$providing).split(/\s+/) !! () }
    };
    @raw.grep(*.chars).List;
}

sub providing-container($obj is raw) {
    return $obj if $obj ~~ Positional || $obj ~~ Associative;
    my $container = try { $obj.VAR } // $obj;
    return $container if $container ~~ Positional || $container ~~ Associative;
    $obj
}

sub bind-providing-domains($obj is raw, @domains) {
    my $key = providing-container($obj).WHICH;
    %PROVIDING-METADATA{$key} = @domains.clone;
}

=begin pod

Look up bound domain metadata without consuming the pending queue.

Used by Master Walker handover detection on roots that may lack the trait.

=end pod
sub cached-providing-domains($obj is raw) is export {
    my $key = providing-container($obj).WHICH;

    if %PROVIDING-METADATA{$key}:exists {
        my $result = %PROVIDING-METADATA{$key};
        return $result if $result;
    }

    Nil
}

=begin pod

Discover domain metadata from an object or variable at runtime.

Returns Array[Str] of domain names if metadata exists, Nil otherwise.

=end pod
sub providing-domains($obj is raw) is export {
    my $key = providing-container($obj).WHICH;

    if %PROVIDING-METADATA{$key}:exists {
        my $result = %PROVIDING-METADATA{$key};
        return $result if $result;
    }

    if @PROVIDING-PENDING {
        my @domains = @PROVIDING-PENDING.shift.split(/\s+/);
        bind-providing-domains($obj, @domains);
        return @domains if @domains;
    }

    Nil
}

=begin pod

Bind structured table schema metadata to a container (tables, foreign keys).

=end pod
our sub bind-providing-schema(Mu $obj is raw, Associative $schema) is export {
    my $key = providing-container($obj).WHICH;
    %PROVIDING-SCHEMA{$key} = %$schema;
}

=begin pod

Look up schema metadata attached via L<bind-providing-schema>.

=end pod
our sub providing-schema(Mu $obj is raw --> Mu) is export {
    my $key = providing-container($obj).WHICH;
    %PROVIDING-SCHEMA{$key} if %PROVIDING-SCHEMA{$key}:exists;
}

multi sub trait_mod:<is>(Variable $declarand, :$providing) is export {
    my @domain-names = normalize-providing-domains($providing);
    @PROVIDING-PENDING.push(@domain-names.join(' '));
}
