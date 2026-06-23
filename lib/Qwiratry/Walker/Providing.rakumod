=begin pod

Compile-time C<is providing<…>> trait and runtime domain/schema metadata.

Attaches advisory domain labels (e.g. C<table>, C<sql>) and optional table schema
to variables and containers. Walkers and L<Qwiratry::Table::Schema> read this
metadata for multi-domain query planning.

=end pod
class Qwiratry::Walker::Providing {

	my $instance;

	=begin pod

	Return the shared Providing registry instance.

	=end pod
	method instance(--> Qwiratry::Walker::Providing) {
		$instance //= self.new
	}

	has %!metadata;
	has %!schema;
	has @!pending;

	=begin pod

	Return the metadata key container (variable C<Scalar> or the object itself).

	=end pod
	method !container($obj is raw) {
		$obj ~~ Positional || $obj ~~ Associative and return $obj;
		if (my $var = try { $obj.VAR }) {
			return $var;
		}
		$obj
	}

	=begin pod

	Normalize trait argument (string, list, or scalar) to a list of domain names.

	=end pod
	method !normalize-domains($providing --> List) {
		my @raw = do given $providing {
			when Positional { $providing.map({ ~$_ }) }
			when Str { (~$providing).split(/\s+/) }
			default { $providing.defined ?? (~$providing).split(/\s+/) !! () }
		};
		@raw.grep(*.chars).List;
	}

	=begin pod

	Queue domain names from a compile-time C<is providing> trait for lazy binding.

	=end pod
	method queue-domains($providing) {
		my @domain-names = self!normalize-domains($providing);
		@!pending.push(@domain-names.join(' '));
	}

	=begin pod

	Store domain names for C<$obj> in the instance registry.

	=end pod
	method bind-domains($obj is raw, @domains) {
		my $key = self!container($obj).WHICH;
		%!metadata{$key} = @domains.clone;
	}

	=begin pod

	Look up bound domain metadata without consuming the pending compile-time queue.

	=end pod
	method cached-domains($obj is raw) {
		my $key = self!container($obj).WHICH;
		if %!metadata{$key}:exists {
			my $result = %!metadata{$key};
			$result and return $result;
		}
		Nil
	}

	=begin pod

	Discover domain metadata from an object or variable at runtime.

	Returns a list of domain name strings, or C<Nil> when none is bound.

	=end pod
	method domains($obj is raw) {
		my $key = self!container($obj).WHICH;

		if %!metadata{$key}:exists {
			my $result = %!metadata{$key};
			$result and return $result;
		}

		if @!pending {
			my @names = @!pending.shift.split(/\s+/);
			self.bind-domains($obj, @names);
			@names and return @names;
		}

		Nil
	}

	=begin pod

	Bind structured table schema metadata (tables, foreign keys) to a container.

	=end pod
	method bind-schema(Mu $obj is raw, Associative $schema) {
		my $key = self!container($obj).WHICH;
		%!schema{$key} = %$schema;
	}

	=begin pod

	Look up schema metadata attached via L<bind-schema>.

	=end pod
	method schema(Mu $obj is raw --> Mu) {
		my $key = self!container($obj).WHICH;
		return %!schema{$key}:exists ?? %!schema{$key} !! Nil;
	}
}

=begin pod

Compile-time trait modifier for C<is providing<domain …>> declarations.

Queues domain names for lazy binding on first L<domains> call.

=end pod
multi sub trait_mod:<is>(Variable $declarand, :$providing) is export {
	Qwiratry::Walker::Providing.instance.queue-domains($providing);
}

=begin pod

Discover domain metadata from an object (export wrapper for L<domains>).

=end pod
sub providing-domains($obj is raw) is export {
	Qwiratry::Walker::Providing.instance.domains($obj);
}
