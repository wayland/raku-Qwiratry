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
	return if %*ENV<QWIRATRY_SKIP_INSTALL_SUGGESTIONS>;

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
	$exception.reported = True if $exception.can('reported');
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
	my $output = try {
		my $proc = run 'zef', 'search', $module, :out, :err;
		my $text = $proc.out.slurp(:close);
		$proc.err.slurp(:close);
		$text;
	};
	return Str unless $output.defined;

	# zef renders results as a numbered, pipe-delimited table; a data row starts
	# with an integer id. The third column holds the package identity, e.g.
	# "JSON::Fast:ver<0.20>:auth<zef:timo>" — we want just the module name and an
	# exact (case-insensitive) match, so "JSON::Fast" is not confused with
	# "JSON::Fast::Hyper".
	for $output.lines -> $line {
		next unless $line ~~ / ^ \s* \d+ \s* '|' /;
		my @cols = $line.split('|');
		next unless @cols >= 3;
		my $package = @cols[2].trim;
		next unless $package;

		my $name = $package;
		$package ~~ / ^ (.+?) ':' [ 'ver' | 'auth' | 'api' ] '<' / and $name = ~$0;
		return $name if $name.lc eq $module.lc;
	}
	Str
}
