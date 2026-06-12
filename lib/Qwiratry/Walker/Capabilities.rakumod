=begin pod

Structured capability metadata for L<Qwiratry::Walker> and L<Qwiratry::Walker::Plan>.

Builds nested capability hashes (lazy, streaming, navigation) per FR-016 of the
walker core infrastructure spec.

=end pod
unit class Qwiratry::Walker::Capabilities;

my $instance;

method instance(--> Qwiratry::Walker::Capabilities) {
	$instance //= self.new
}

method lazy(
	Bool :$enabled = False,
	Str :$type = 'none',
) {
	%(lazy => %(enabled => $enabled, type => $type))
}

method streaming(Bool :$enabled = False) {
	%(streaming => %(enabled => $enabled))
}

method navigation(
	Bool :$enabled = True,
	|domains,
) {
	my @names = domains.grep(*.defined);
	return %(navigation => %(enabled => $enabled)) unless @names;
	%(navigation => %(enabled => $enabled, domains => @names))
}

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

method default-walker(--> Associative) {
	self.merge(
		self.lazy(:enabled(False)),
		self.streaming(:enabled(False)),
	)
}

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

method from-walker($walker --> Associative) {
	self.default-plan(
		:lazy-enabled($walker.capabilities<lazy><enabled> // False),
		:lazy-type($walker.capabilities<lazy><type> // 'none'),
	)
}
