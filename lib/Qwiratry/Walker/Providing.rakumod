=begin pod

Compile-time C<is providing<…>> trait and runtime domain/schema metadata.

=end pod
unit class Qwiratry::Walker::Providing;

my $instance;

method instance(--> Qwiratry::Walker::Providing) {
	$instance //= self.new
}

has %!metadata;
has %!schema;
has @!pending;

method !container($obj is raw) {
	return $obj if $obj ~~ Positional || $obj ~~ Associative;
	if (my $var = try { $obj.VAR }) {
		return $var;
	}
	$obj
}

method !normalize-domains($providing --> List) {
	my @raw = do given $providing {
		when Positional { $providing.map({ ~$_ }) }
		when Str { (~$providing).split(/\s+/) }
		default { $providing.defined ?? (~$providing).split(/\s+/) !! () }
	};
	@raw.grep(*.chars).List;
}

method queue-domains($providing) {
	my @domain-names = self!normalize-domains($providing);
	@!pending.push(@domain-names.join(' '));
}

method bind-domains($obj is raw, @domains) {
	my $key = self!container($obj).WHICH;
	%!metadata{$key} = @domains.clone;
}

method cached-domains($obj is raw) {
	my $key = self!container($obj).WHICH;
	if %!metadata{$key}:exists {
		my $result = %!metadata{$key};
		return $result if $result;
	}
	Nil
}

method domains($obj is raw) {
	my $key = self!container($obj).WHICH;

	if %!metadata{$key}:exists {
		my $result = %!metadata{$key};
		return $result if $result;
	}

	if @!pending {
		my @names = @!pending.shift.split(/\s+/);
		self.bind-domains($obj, @names);
		return @names if @names;
	}

	Nil
}

method bind-schema(Mu $obj is raw, Associative $schema) {
	my $key = self!container($obj).WHICH;
	%!schema{$key} = %$schema;
}

method schema(Mu $obj is raw --> Mu) {
	my $key = self!container($obj).WHICH;
	%!schema{$key} if %!schema{$key}:exists;
}

multi sub trait_mod:<is>(Variable $declarand, :$providing) is export {
	Qwiratry::Walker::Providing.instance.queue-domains($providing);
}

sub providing-domains($obj is raw) is export {
	Qwiratry::Walker::Providing.instance.domains($obj);
}

sub cached-providing-domains($obj is raw) is export {
	Qwiratry::Walker::Providing.instance.cached-domains($obj);
}

our sub bind-providing-schema(Mu $obj is raw, Associative $schema) is export {
	Qwiratry::Walker::Providing.instance.bind-schema($obj, $schema);
}

sub providing-schema(Mu $obj is raw --> Mu) is export {
	Qwiratry::Walker::Providing.instance.schema($obj);
}
