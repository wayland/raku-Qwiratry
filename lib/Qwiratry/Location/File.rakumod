=begin pod

=head1 Overview

Local file location implementation.

Defines C<Qwiratry::Location::File::Source> and
C<Qwiratry::Location::File::Destination>, the built-in backend loaded through
L<Qwiratry::Location.make>.

The backend accepts both C<file://> URLs and local path strings. A leading
C<~>, C<~/>, or C<~user/> is expanded to a home directory. Shell-style globs
in the final path segment (C<*>, C<?>, C<[…]>) expand to matching entries via
L<Glob::Grammar>. Source reads return text for ordinary files, an C<IO::Path>
directory root for directories, or a C<List> of C<IO::Path> nodes when a glob
matches more than one path (or exactly one directory). Destination writes coerce
content to text and create parent directories before writing.

=end pod
use Glob::Grammar;
use Glob::ToRegexActions;
use X::Qwiratry;
use Qwiratry::Location;
use Qwiratry::Location::Base;

Qwiratry::Location.register-schemes(:backend<File>, :schemes<file>);

# Resolve ~ / ~/ / ~user / ~user/ via $*HOME or getent passwd.
sub home-directory(Str $user --> IO::Path) {
	unless $user {
		$*HOME.defined or fail-home($user);
		return $*HOME;
	}
	my $proc = run 'getent', 'passwd', $user, :out, :err;
	if $proc.exitcode == 0 {
		my $line = $proc.out.slurp(:close).chomp;
		my $dir = $line.split(':')[5];
		return $dir.IO if $dir;
	}
	fail-home($user);
}

sub fail-home(Str $user) {
	X::Qwiratry::IO::LocationError.new(
		:message($user
			?? "Cannot resolve home directory for user '$user'"
			!! 'Home directory unavailable'),
		:location($user ?? "~$user" !! '~'),
		:reason('Home directory unavailable'),
		:operator-type('AdaptorOperator'),
	).throw;
}

# True when C<$path> contains glob metacharacters in its final segment.
sub path-has-glob(Str $path --> Bool) {
	my $slash = $path.rindex('/') // -1;
	my $pattern = $slash >= 0 ?? $path.substr($slash + 1) !! $path;
	so $pattern.contains('*' | '?' | '[' | ']')
}

# Compile a basename glob to an anchored regex source via Glob::Grammar.
sub glob-pattern(Str $glob --> Str) {
	state %cache;
	return %cache{$glob} if %cache{$glob}:exists;
	my $match = Glob::Grammar.parse($glob, actions => Glob::ToRegexActions.new);
	%cache{$glob} = $match ?? ~$match.made !! '';
	%cache{$glob}
}

# Expand a path whose final segment is a glob against that directory's entries.
sub expand-path-glob(Str $path --> List) {
	my $slash = $path.rindex('/');
	my ($parent, $pattern) = $slash >= 0
		?? ($path.substr(0, $slash), $path.substr($slash + 1))
		!! ('.', $path);

	my $dir = $parent.IO;
	unless $dir.d {
		X::Qwiratry::IO::LocationError.new(
			:message("I/O location not found: $path"),
			:location($path),
			:resolved(~$dir.absolute),
			:reason('File not found'),
			:operator-type('SourceOperator'),
		).throw;
	}

	my $regex = glob-pattern($pattern);
	return () unless $regex;

	gather {
		for $dir.dir -> $entry {
			take $entry if $entry.basename ~~ / <$regex> /;
		}
	}.sort(*.basename).list
}

# Strip file:// and expand ~ forms. Does not expand globs.
sub path-from-location(Str $location --> Str) {
	my $path = $location.subst(/^ 'file://' /, '');
	if $path eq '~' {
		return ~home-directory('');
	}
	elsif $path.starts-with('~/') {
		return home-directory('').add($path.substr(2)).absolute;
	}
	elsif $path ~~ /^ '~' $<user>=[<[\w.-]>+] [ '/' $<rest>=[.*] ]? $/ {
		my $home = home-directory(~$<user>);
		return ($<rest>.defined && ~$<rest>)
			?? $home.add(~$<rest>).absolute
			!! ~$home;
	}
	$path
}

class Qwiratry::Location::File::Source is Qwiratry::Location::Base::Source {

	=begin pod

	=head1 Methods

	=head2 C<read(Str $location)>

	=begin code
	method read(Str $location --> Mu)
	=end code

	=head3 Parameters

	=item C<$location>

	 The location string or URI handled by the backend.


	Reads C<$location>. Ordinary files return their text contents. Directories
	return an C<IO::Path> root that L<Qwiratry::Tree::Navigator::Filesystem>
	can navigate with the usual axis operators. When the location's final
	segment is a glob, returns a C<List> of matching C<IO::Path> entries.

	Missing paths and globs that match nothing are reported as
	L<X::Qwiratry::IO::LocationError> with the original location string and
	source operator context, so pipeline diagnostics point back to the user's
	query.

	=end pod
	method read(Str $location --> Mu) {
		my $path = path-from-location($location);
		if path-has-glob($path) {
			my @matches = expand-path-glob($path).List;
			unless @matches {
				X::Qwiratry::IO::LocationError.new(
					:message("I/O location not found: $location"),
					:location($location),
					:resolved(~$path.IO.absolute),
					:reason('Glob matched no files'),
					:operator-type('SourceOperator'),
				).throw;
			}
			return @matches;
		}

		my $io = $path.IO;
		unless $io.e {
			X::Qwiratry::IO::LocationError.new(
				:message("I/O location not found: $location"),
				:location($location),
				:resolved(~$io.absolute),
				:reason('File not found'),
				:operator-type('SourceOperator'),
			).throw;
		}
		return $io if $io.d;
		$io.slurp
	}
}

class Qwiratry::Location::File::Destination is Qwiratry::Location::Base::Destination {

	=begin pod

	=head2 C<write(Str $location, Mu $content)>

	=begin code
	method write(Str $location, Mu $content --> Mu)
	=end code

	=head3 Parameters

	=item C<$location>

	 The location string or URI handled by the backend.

	=item C<$content>

	 The content to write to the destination location.


	Writes C<$content> to C<$location> and returns the original content.

	Glob patterns in C<$location> are rejected. The destination creates parent
	directories as needed. Returning the content keeps destination operators
	usable at the end of a pipeline without changing the value visible to
	callers.

	=end pod
	method write(Str $location, Mu $content --> Mu) {
		my $path = path-from-location($location);
		if path-has-glob($path) {
			X::Qwiratry::IO::LocationError.new(
				:message("Glob locations cannot be write destinations: $location"),
				:location($location),
				:reason('Invalid location format'),
				:operator-type('DestinationOperator'),
			).throw;
		}
		my $text = $content ~~ Str ?? $content !! ~$content;
		$path.IO.parent.d or $path.IO.parent.mkdir;
		spurt $path, $text;
		$content
	}
}
