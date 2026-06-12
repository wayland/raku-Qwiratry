=begin pod

Compile-time C<is providing<…>> trait and runtime domain/schema metadata.

Attaches advisory domain labels (e.g. C<table>, C<sql>) and optional table schema
to variables and containers. Walkers and L<Qwiratry::Table::Schema> read this
metadata for multi-domain query planning.

=end pod
unit module Qwiratry::Walker::Providing;

=begin pod

Module-level registries for domain names and schema hashes, keyed by container WHICH.

Pending trait applications are queued at compile time and bound on first lookup.

=end pod

our %PROVIDING-METADATA;
our %PROVIDING-SCHEMA;
our @PROVIDING-PENDING;  # queue of space-joined domain name strings

=begin pod

Normalize trait argument (string, list, or scalar) to a list of domain names.

=end pod
sub normalize-providing-domains($providing --> List) {
	my @raw = do given $providing {
		when Positional { $providing.map({ ~$_ }) }
		when Str { (~$providing).split(/\s+/) }
		default { $providing.defined ?? (~$providing).split(/\s+/) !! () }
	};
	@raw.grep(*.chars).List;
}

=begin pod

Return the metadata key container (variable C<Scalar> or the object itself).

=end pod
sub providing-container($obj is raw) {
	return $obj if $obj ~~ Positional || $obj ~~ Associative;
	if (my $var = try { $obj.VAR }) {
		return $var;
	}
	$obj
}

=begin pod

Store domain names for C<$obj> in C<%PROVIDING-METADATA>.

=end pod
sub bind-providing-domains($obj is raw, @domains) {
	my $key = providing-container($obj).WHICH;
	%PROVIDING-METADATA{$key} = @domains.clone;
}

=begin pod

Look up bound domain metadata without consuming the pending compile-time queue.

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

Returns a list of domain name strings, or C<Nil> when none is bound.

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

Bind structured table schema metadata (tables, foreign keys) to a container.

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

=begin pod

Compile-time trait modifier for C<is providing<domain …>> declarations.

Queues domain names for lazy binding on first L<providing-domains> call.

=end pod
multi sub trait_mod:<is>(Variable $declarand, :$providing) is export {
	my @domain-names = normalize-providing-domains($providing);
	@PROVIDING-PENDING.push(@domain-names.join(' '));
}
