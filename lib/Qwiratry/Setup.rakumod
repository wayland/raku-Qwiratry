=begin pod

Interactive ecosystem setup for Qwiratry plugins.

C<qwiratry-setup> (see C<bin/qwiratry-setup>) discovers Format, Location, and
developer-tool distributions via C<zef search Qwiratry>, lets the user tick
what to install, then runs C<zef install>.

=end pod

unit module Qwiratry::Setup;

use Qwiratry::Suggest;

# Bundled with core Qwiratry — not offered as separate installs.
my constant @FORMAT-EXCLUDES = <Base JSONdemo CSVdemo>;
my constant @LOCATION-EXCLUDES = <Base File>;

#| Classify a canonical C<::>-form identity into C<format>, C<location>, C<dev>, or C<other>.
sub classify-identity(Str:D $identity --> Str) is export {
	my $name = canonical-identity($identity);

	$name ~~ /^ 'Qwiratry::Test' [ '::' .* ]? $/ and return 'dev';

	if $name ~~ /^ 'Qwiratry::Format::' $<leaf>=.+ $/ {
		~$<leaf> eq any(@FORMAT-EXCLUDES) and return 'other';
		return 'format';
	}
	if $name ~~ /^ 'Qwiratry::Location::' $<leaf>=.+ $/ {
		~$<leaf> eq any(@LOCATION-EXCLUDES) and return 'other';
		return 'location';
	}

	'other'
}

#| Short label for display (e.g. C<JSON> from C<Qwiratry::Format::JSON>).
sub display-label(Str:D $identity --> Str) is export {
	my $name = canonical-identity($identity);
	$name ~~ /^ 'Qwiratry::' [Format|Location] '::' $<leaf>=.+ $/ and return ~$<leaf>;
	$name ~~ /^ 'Qwiratry::Test' [ '::' $<rest>=.+ ]? $/
		and return $<rest>.defined ?? "Test::{$<rest>}" !! 'Test';
	$name
}

#| True when a CompUnit providing C<$provide> is already resolvable.
sub already-installed(Str:D $provide --> Bool) is export {
	try {
		$*REPO.resolve(
			CompUnit::DependencySpecification.new(:short-name($provide))
		) and return True;
	}
	False
}

#| Enrich and partition package records into format / location / dev / other.
#| Identities are assumed already canonical (C<::> form) from L<search-packages>.
sub classify-packages(@packages --> Hash) is export {
	my %groups = format => [], location => [], dev => [], other => [];
	for @packages -> %pkg {
		my $identity = canonical-identity(%pkg<identity>);
		my $cat = classify-identity($identity);
		%groups{$cat}.push(%(
			identity    => $identity,
			description => %pkg<description> // '',
			label       => display-label($identity),
			installed   => already-installed($identity),
		));
	}
	%groups
}

#| True when this package is a recommended default (JSON format or HTTP location).
sub is-recommended(%pkg --> Bool) is export {
	my $label = (%pkg<label> // display-label(%pkg<identity>)).lc;
	$label eq 'json' || $label eq 'http'
}

#| Build the C<zef install …> argument list from selected package records.
sub install-identities(@selected --> List) is export {
	@selected.map(*<identity>).unique(:as(*.lc)).List
}

#| Interactive checklist: toggle by numbers, C<all>, C<none>, C<done>.
#| Already-installed packages are shown as non-numbered C<[I]> rows and are not
#| part of the checklist. Pre-ticks apply only to packages that are not yet
#| installed.
sub checklist-prompt(
	Str:D $title,
	@packages,
	:@preselect = (),
	:$in = $*IN,
	:$out = $*OUT,
	--> List
) is export {
	!@packages.elems and return ();

	my @installed = @packages.grep(*.<installed>);
	my @choosable = @packages.grep({ !.<installed> });
	my %pre = @preselect.map({ .lc => True });
	my @selected = @choosable.map({ ?%pre{.<identity>.lc} });

	sub show-list(--> Nil) {
		$out.say('');
		for @installed -> %pkg {
			my $desc = %pkg<description> ?? " — {%pkg<description>}" !! '';
			$out.say(sprintf('  [I] %s (%s)%s',
				%pkg<label>, %pkg<identity>, $desc));
		}
		for @choosable.kv -> $i, %pkg {
			my $mark = @selected[$i] ?? 'x' !! ' ';
			my $desc = %pkg<description> ?? " — {%pkg<description>}" !! '';
			$out.say(sprintf('  [%s] %d. %s (%s)%s',
				$mark, $i + 1, %pkg<label>, %pkg<identity>, $desc));
		}
	}

	$out.say('');
	$out.say($title);

	!@choosable.elems and do {
		show-list();
		$out.say('  (all listed packages are already installed)');
		return ();
	};

	$out.say('  [I] = already installed (not selectable)');
	$out.say('  Commands: numbers to toggle (e.g. 1 3), all, none, done');

	loop {
		show-list();
		$out.print('> ');
		my $line = $in.get;
		!$line.defined and return ();
		$line .= trim;
		my $cmd = $line.lc;

		if $cmd eq any(<done d>) || $line eq '' {
			my @chosen;
			for @choosable.kv -> $i, %pkg {
				@selected[$i] and @chosen.push(%pkg);
			}
			return @chosen.List;
		}
		elsif $cmd eq any(<all a>) {
			@selected = True xx @choosable.elems;
		}
		elsif $cmd eq any(<none n>) {
			@selected = False xx @choosable.elems;
		}
		else {
			for $line.comb(/\d+/) -> $num {
				my $idx = $num.Int - 1;
				!(0 <= $idx < @choosable.elems) and next;
				@selected[$idx] = !@selected[$idx];
			}
		}
	}
}

#| Yes/no prompt; default C<False> when empty input.
sub yes-no-prompt(Str:D $question, Bool :$default = False, :$in = $*IN, :$out = $*OUT --> Bool) is export {
	my $hint = $default ?? 'Y/n' !! 'y/N';
	$out.print("$question [$hint] ");
	my $line = $in.get;
	!$line.defined and return $default;
	$line .= trim.lc;
	$line eq '' and return $default;
	$line eq any <y yes> and return True;
	$line eq any <n no> and return False;
	$default
}

#| Run C<zef install> for the given identities. Returns the process exit code.
sub run-zef-install(@identities, Bool :$dry-run = False, :$out = $*OUT, :$err = $*ERR --> Int) is export {
	!@identities.elems and return 0;
	my @cmd = 'zef', 'install', |@identities;
	$out.say(@cmd.map({ /\s/ ?? qq{"$_"} !! $_ }).join(' '));
	$dry-run and return 0;

	my $proc = run |@cmd, :out, :err;
	$out.print($proc.out.slurp(:close));
	$err.print($proc.err.slurp(:close));
	$proc.exitcode
}

#| Discover, prompt, and optionally install Qwiratry ecosystem packages.
sub run-setup(Bool :$dry-run = False, :$in = $*IN, :$out = $*OUT, :$err = $*ERR --> Int) is export {
	$out.say('Qwiratry setup');
	$out.say('==============');
	$out.say('This tool needs network access and a working `zef`.');
	!%*ENV<RAKUDO_RAKUAST> and $out.say('Qwiratry itself requires RAKUDO_RAKUAST=1 in your environment.');
	$out.say('');
	$out.say('Searching the ecosystem for Qwiratry packages…');
	$out.say('(Press Ctrl+C to cancel.)');

	my @raw = search-packages('Qwiratry');
	!@raw.elems and do {
		$err.say('No Qwiratry packages found (is zef available and online?).');
		$err.say('Bundled with core: Location::File, Format::JSONdemo, Format::CSVdemo.');
		return 1;
	};

	my %groups = classify-packages(@raw);
	my @formats = |%groups<format>;
	my @locations = |%groups<location>;
	my @dev = |%groups<dev>;

	$out.say("Found {@formats.elems} format(s), {@locations.elems} location(s), {@dev.elems} developer package(s).");
	$out.say('Core already bundles Location::File and demo formats (JSONdemo, CSVdemo).');

	my @preselect;
	(@formats.grep(&is-recommended) || @locations.grep(&is-recommended)) and do {
		yes-no-prompt(
			'Pre-select recommended plugins (JSON format + HTTP location when available)?',
			:default(True), :$in, :$out
		) and @preselect = (|@formats, |@locations).grep(&is-recommended).map(*<identity>);
	};

	my @chosen;
	if @locations.elems {
		@chosen.append(checklist-prompt(
			'Which Locations (sources/destinations) do you want to install?',
			@locations, :@preselect, :$in, :$out
		));
	}
	else {
		$out.say('');
		$out.say('No Location plugins found in the ecosystem; bundled File remains available.');
	}

	if @formats.elems {
		@chosen.append(checklist-prompt(
			'Which Formats do you wish to install?',
			@formats, :@preselect, :$in, :$out
		));
	}
	else {
		$out.say('');
		$out.say('No Format plugins found in the ecosystem; demo formats remain available.');
	}

	@dev.elems and do {
		$out.say('');
		$out.say('Developer tools (Qwiratry::Test, etc.) are for plugin authors and conformance tests.');
		yes-no-prompt('Install developer tools?', :default(False), :$in, :$out)
			and @chosen.append(@dev);
	};

	my @identities = install-identities(@chosen);
	$out.say('');
	if @identities.elems {
		$out.say('Selected packages:');
		for @identities -> $id {
			$out.say("  - $id");
		}
		$out.say('');
		$out.say('Install command:');
		$out.say('  zef install ' ~ @identities.join(' '));
	}
	else {
		$out.say('Nothing selected to install.');
		return 0;
	}

	$dry-run and do {
		$out.say('');
		$out.say('Dry run: not installing.');
		return 0;
	};

	!yes-no-prompt('Proceed with install?', :default(True), :$in, :$out) and do {
		$out.say('Cancelled.');
		return 0;
	};

	my $code = run-zef-install(@identities, :$out, :$err);
	if $code {
		$err.say("zef install failed with exit code $code.");
	}
	else {
		$out.say('Done.');
	}
	$code
}
