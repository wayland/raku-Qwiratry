#!/usr/bin/env raku

use v6.d;
use Fez::Bundle;
use JSON::Fast;

sub meta-provides(Str:D $meta-path --> Hash) {
    my %meta = from-json($meta-path.IO.slurp);
    %meta<provides> // {};
}

sub normalized-entries(@entries --> SetHash) {
    my @clean = @entries.map({ .Str.subst(/^ './'/, '') });
    my @roots = '', |@clean.grep(*.ends-with('/META6.json')).map({
        .substr(0, .chars - 'META6.json'.chars)
    });

    my SetHash $normalized .= new;
    for @clean -> $entry {
        $normalized{$entry}++;
        for @roots -> $root {
            next unless $root.chars && $entry.starts-with($root);
            $normalized{$entry.substr($root.chars)}++;
        }
    }

    $normalized;
}

sub fez-manifest(--> SetHash) {
    normalized-entries(bundle('.', :dry-run));
}

sub archive-manifest(Str:D $archive-path --> SetHash) {
    my $proc = run 'tar', '--list', '-f', $archive-path, :out, :err;
    unless $proc.exitcode == 0 {
        die "Could not list archive {$archive-path}:\n" ~ $proc.err.slurp(:close);
    }

    normalized-entries($proc.out.slurp(:close).lines);
}

sub MAIN(
    Str :$meta = 'META6.json',
    Str :$archive,
) {
    my %provides = meta-provides($meta);
    my SetHash $entries = $archive.defined
        ?? archive-manifest($archive)
        !! fez-manifest();

    my @missing = %provides.sort(*.key).grep(-> $provide {
        !$entries{$provide.value}
    });

    if @missing {
        note "Missing files for META6.json provides:";
        for @missing -> $provide {
            note "  {$provide.key} => {$provide.value}";
        }
        exit 1;
    }

    say "OK: all {%provides.elems} META6.json provides files are present.";
}
