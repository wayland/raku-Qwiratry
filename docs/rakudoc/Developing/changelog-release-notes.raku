#!/usr/bin/env raku
use v6.e.PREVIEW;

sub MAIN(
	Str:D $version,
	IO() :$changelog = 'docs/rakudoc/Developing/Changelog.rakudoc'.IO,
) {
	my $emit = False;

	for $changelog.lines -> $line {
		if $line.starts-with("=head1 $version ") {
			$emit = True;
			next;
		}

		last if $emit && $line.starts-with('=head1 ');
		next unless $emit;

		given $line {
			when /^ '=head2 ' (.*) / { say "## $0" }
			when /^ '=item ' (.*) / { say "- $0" }
			when /^ '=' / { }
			default { say $line }
		}
	}
}
