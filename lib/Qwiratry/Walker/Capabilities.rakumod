=begin pod

Structured capability metadata for L<Qwiratry::Walker> and L<Qwiratry::Walker::Plan>.

Builds nested capability hashes (lazy, streaming, navigation) per FR-016 of the
walker core infrastructure spec.

=end pod
unit class Qwiratry::Walker::Capabilities;

my $instance;

=begin pod

Return the shared Capabilities builder instance.

=end pod
method instance(--> Qwiratry::Walker::Capabilities) {
	$instance //= self.new
}

=begin pod

Build a lazy-evaluation capability entry.

=end pod
method lazy(
	Bool :$enabled = False,
	Str :$type = 'none',
) {
	%(lazy => %(enabled => $enabled, type => $type))
}

=begin pod

Build a streaming capability entry.

=end pod
method streaming(Bool :$enabled = False) {
	%(streaming => %(enabled => $enabled))
}

=begin pod

Build a navigation capability entry, optionally listing supported domains.

=end pod
method navigation(
	Bool :$enabled = True,
	|domains,
) {
	my @names = domains.grep(*.defined);
	return %(navigation => %(enabled => $enabled)) unless @names;
	%(navigation => %(enabled => $enabled, domains => @names))
}

=begin pod

Deep-merge capability hashes, combining nested entries for the same top-level key.

=end pod
method merge(*@parts --> Associative) {
	my %merged;
	for @parts -> $part {
		next unless $part.defined && $part ~~ Associative;
		for %($part).pairs -> $pair {
			if $pair.value ~~ Associative && %merged{$pair.key} ~~ Associative {
				my %inner = %(%merged{$pair.key});
				%inner{$_} = $pair.value{$_} for $pair.value.keys;
				%merged{$pair.key} = %inner;
			}
			else {
				%merged{$pair.key} = $pair.value;
			}
		}
	}
	%merged
}

=begin pod

Default walker capabilities: lazy and streaming disabled.

=end pod
method default-walker(--> Associative) {
	self.merge(
		self.lazy(:enabled(False)),
		self.streaming(:enabled(False)),
	)
}

=begin pod

Default plan capabilities, with optional lazy settings and extra merged parts.

=end pod
method default-plan(
	Bool :$lazy-enabled = False,
	Str :$lazy-type = 'none',
	|extra,
) {
	self.merge(
		self.lazy(:enabled($lazy-enabled), :type($lazy-type)),
		|extra,
	)
}

=begin pod

Copy lazy settings from a walker's capabilities into plan defaults.

=end pod
method from-walker($walker --> Associative) {
	self.default-plan(
		:lazy-enabled($walker.capabilities<lazy><enabled> // False),
		:lazy-type($walker.capabilities<lazy><type> // 'none'),
	)
}
