=begin pod

Structured capability metadata for L<Qwiratry::Walker> and L<Qwiratry::Walker::Plan>.

Implements FR-016 from the Walker core infrastructure spec: nested hashes such as
C<{ lazy => { enabled => True, type => "incremental" } }>.

=end pod
unit module Qwiratry::Walker::Capabilities;

our sub lazy-capability(
    Bool :$enabled = False,
    Str :$type = 'none',
) is export {
    %(lazy => %(enabled => $enabled, type => $type))
}

our sub streaming-capability(Bool :$enabled = False) is export {
    %(streaming => %(enabled => $enabled))
}

our sub navigation-capability(
    Bool :$enabled = True,
    |domains,
) is export {
    my @names = domains.grep(*.defined);
    return %(navigation => %(enabled => $enabled)) unless @names;
    %(navigation => %(enabled => $enabled, domains => @names))
}

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

our sub default-walker-capabilities(--> Associative) is export {
    merge-capabilities(
        lazy-capability(:enabled(False)),
        streaming-capability(:enabled(False)),
    )
}

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

our sub plan-capabilities-from-walker($walker --> Associative) is export {
    default-plan-capabilities(
        :lazy-enabled($walker.capabilities<lazy><enabled> // False),
        :lazy-type($walker.capabilities<lazy><type> // 'none'),
    )
}
