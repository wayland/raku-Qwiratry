=begin pod

Structured capability metadata for L<Qwiratry::Walker> and L<Qwiratry::Walker::Plan>.

Builds nested capability hashes (lazy, streaming, navigation) per FR-016 of the
walker core infrastructure spec.

=end pod
unit module Qwiratry::Walker::Capabilities;

=begin pod

Build a lazy-evaluation capability entry.

=end pod
our sub lazy-capability(
	Bool :$enabled = False,
	Str :$type = 'none',
) is export {
	%(lazy => %(enabled => $enabled, type => $type))
}

=begin pod

Build a streaming capability entry.

=end pod
our sub streaming-capability(Bool :$enabled = False) is export {
	%(streaming => %(enabled => $enabled))
}

=begin pod

Build a navigation capability entry, optionally listing supported domains.

=end pod
our sub navigation-capability(
	Bool :$enabled = True,
	|domains,
) is export {
	my @names = domains.grep(*.defined);
	return %(navigation => %(enabled => $enabled)) unless @names;
	%(navigation => %(enabled => $enabled, domains => @names))
}

=begin pod

Deep-merge capability hashes, combining nested entries for the same top-level key.

=end pod
our sub merge-capabilities(*@parts --> Associative) is export {
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
our sub default-walker-capabilities(--> Associative) is export {
	merge-capabilities(
		lazy-capability(:enabled(False)),
		streaming-capability(:enabled(False)),
	)
}

=begin pod

Default plan capabilities, with optional lazy settings and extra merged parts.

=end pod
our sub default-plan-capabilities(
	Bool :$lazy-enabled = False,
	Str :$lazy-type = 'none',
	|extra,
) is export {
	merge-capabilities(
		lazy-capability(:enabled($lazy-enabled), :type($lazy-type)),
		|extra,
	)
}

=begin pod

Copy lazy settings from a walker's capabilities into plan defaults.

=end pod
our sub plan-capabilities-from-walker($walker --> Associative) is export {
	default-plan-capabilities(
		:lazy-enabled($walker.capabilities<lazy><enabled> // False),
		:lazy-type($walker.capabilities<lazy><type> // 'none'),
	)
}
