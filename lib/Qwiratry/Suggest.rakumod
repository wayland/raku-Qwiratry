=begin pod

Best-effort install suggestions for missing Format/Location plugins.

When a Format or Location factory cannot resolve an implementation it raises the
usual C<X::Qwiratry::*> exception. Before that exception propagates, the factory
may call L<report-and-suggest> to help the user recover: it prints the original
error, then investigates whether any published distribution provides the missing
module, and finally prints a C<zef install> recommendation (or reports that no
package appears to provide it).

The behaviour is on by default and can be disabled by setting the environment
variable C<QWIRATRY_SKIP_INSTALL_SUGGESTIONS>.

L<search-packages> and L<parse-zef-search-output> are also used by
L<Qwiratry::Setup> for interactive plugin discovery.

=end pod

unit module Qwiratry::Suggest;

#| Emit a staged install suggestion for a missing C<$module> to C<$*ERR>, then
#| mark C<$exception> as reported so it is not printed twice when it propagates.
#|
#| Ordering (per the contract):
#|   1. the original error is emitted first (before any zef lookup);
#|   2. an "investigating" note is printed;
#|   3. the ecosystem is queried; and only then
#|   4. the install recommendation (or a "no package" line) is printed.
#|
#| Set C<QWIRATRY_SKIP_INSTALL_SUGGESTIONS> to disable entirely; when disabled
#| the exception is left untouched and propagates with its full message.
sub report-and-suggest(Exception:D $exception, Str:D $module --> Nil) is export {
	%*ENV<QWIRATRY_SKIP_INSTALL_SUGGESTIONS> and return;

	# 1. The error, before we call zef.
	$*ERR.say($exception.gist);

	# 2. Signal that a (potentially slow) lookup is starting.
	$*ERR.say('Investigating whether any package provides this…');

	# 3. + 4. Look up and recommend, using the ecosystem's own (correctly-cased)
	# spelling of the package rather than our normalized guess.
	with find-package($module) -> $package {
		$*ERR.say(qq{Run "zef install $package" to resolve this.});
	}
	else {
		$*ERR.say("No published package appears to provide $module.");
	}

	# Mark reported so the propagating exception's gist stays quiet.
	$exception.can('reported') and $exception.reported = True;
}

#| Strip C<:ver<…>> / C<:auth<…>> / C<:api<…>> suffixes from a zef Package cell.
sub bare-identity(Str:D $package --> Str) is export {
	my $name = $package;
	$package ~~ / ^ (.+?) ':' [ 'ver' | 'auth' | 'api' ] '<' / and $name = ~$0;
	canonical-identity($name)
}

#| Convert fez-style C<Qwiratry--Format--JSON> names to C<Qwiratry::Format::JSON>.
#| Identities that already use C<::> are returned unchanged.
sub canonical-identity(Str:D $identity --> Str) is export {
	$identity.contains('--') or return $identity;
	$identity.subst('--', '::', :g)
}

#| Parse C<zef search> table text into unique package records.
#|
#| Each record is a Hash with C<identity> (canonical C<::>-form module name) and
#| C<description>. Dedupes case-insensitively, keeping the first occurrence
#| (typically the newest version zef listed). Fez C<--> dist names are normalized
#| to C<::> so callers never see the filesystem-style spelling.
sub parse-zef-search-output(Str:D $output --> List) is export {
	my %seen;
	my @packages;
	for $output.lines -> $line {
		!($line ~~ / ^ \s* \d+ \s* '|' /) and next;
		my @cols = $line.split('|');
		!(@cols >= 3) and next;
		my $package = @cols[2].trim;
		!$package and next;
		my $identity = bare-identity($package);
		my $key = $identity.lc;
		(%seen{$key}:exists) and next;
		%seen{$key} = True;
		my $description = @cols >= 4 ?? @cols[3].trim !! '';
		@packages.push(%(
			identity    => $identity,
			description => $description,
		));
	}
	@packages.List
}

#| Best-effort C<zef search $query>; returns package records or an empty list.
#| Never throws: missing/offline zef is treated as no results.
sub search-packages(Str:D $query --> List) is export {
	my $output = try {
		my $proc = run 'zef', 'search', $query, :out, :err;
		my $text = $proc.out.slurp(:close);
		$proc.err.slurp(:close);
		$text;
	};
	!$output.defined and return ();
	parse-zef-search-output($output)
}

#| Best-effort search of the Raku ecosystem (via the C<zef> CLI) for a package
#| that provides C<$module>. C<zef search> matches case-insensitively, so a
#| normalized guess such as C<Qwiratry::Format::Yaml> still finds the published
#| C<Qwiratry::Format::YAML>; the returned name uses the ecosystem's own casing.
#|
#| Returns the matching module name (a C<Str>) or an undefined C<Str> when no
#| package provides it. Never throws: any failure (zef missing, offline, etc.)
#| is treated as "no result".
sub find-package(Str:D $module --> Str) is export {
	my $want = canonical-identity($module).lc;
	for search-packages($module) -> %pkg {
		%pkg<identity>.lc eq $want and return %pkg<identity>;
	}
	Str
}
