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

Ordinary files also support optional streaming: C<read-pull> yields fixed-size
C<Str> chunks, and C<open-sink-push> returns a sink with C<write-chunk>/C<close> for
incremental writes.

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

class Qwiratry::Location::File::Sink {
	has IO::Handle $.handle is required;

	method write-chunk(Str:D $chunk --> Nil) {
		$!handle.print($chunk);
	}

	method close(--> Nil) {
		$!handle.close;
	}
}

class Qwiratry::Location::File::Source is Qwiratry::Location::Base::SourceWalkable does Qwiratry::Location::Base::SourcePull {

	=begin pod

	=head1 Methods

	=head2 C<read-walkable(Str $location)>

	=begin code
	method read-walkable(Str $location --> Mu)
	=end code

	=head3 Parameters

	=item C<$location>

	 The location string or URI handled by the backend.


	Reads C<$location>. Ordinary files return their text contents. Directories
	return an C<IO::Path> root that L<Qwiratry::Tree::Navigator::Filesystem>
	can navigate with the usual sector operators. When the location's final
	segment is a glob, returns a C<List> of matching C<IO::Path> entries.

	Missing paths and globs that match nothing are reported as
	L<X::Qwiratry::IO::LocationError> with the original location string and
	source operator context, so pipeline diagnostics point back to the user's
	query.

	=end pod
	method read-walkable(Str $location --> Mu) {
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

	=begin pod

	=head2 C<read-pull(Str:D $location)>

	=begin code
	method read-pull(Str:D $location --> Iterator:D)
	=end code

	=head3 Parameters

	=item C<$location>

	 The location string or URI handled by the backend.


	Reads an ordinary file as a pull iterator of fixed-size C<Str> chunks.

	Each chunk is up to 4096 characters. Glob locations and directories are not
	streamed; they raise L<X::Qwiratry::IO::LocationError>.

	=end pod
	method read-pull(Str:D $location --> Iterator:D) {
		my $path = path-from-location($location);
		if path-has-glob($path) {
			X::Qwiratry::IO::LocationError.new(
				:message("Glob locations cannot be read as text chunks: $location"),
				:location($location),
				:resolved(~$path.IO.absolute),
				:reason('Invalid location format'),
				:operator-type('SourceOperator'),
			).throw;
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
		if $io.d {
			X::Qwiratry::IO::LocationError.new(
				:message("Directory locations cannot be read as text chunks: $location"),
				:location($location),
				:resolved(~$io.absolute),
				:reason('Invalid location format'),
				:operator-type('SourceOperator'),
			).throw;
		}

		my $handle = $io.open(:r);
		my constant $chunk-size = 4096;
		Seq.from-loop({
			my $chunk := $handle.readchars($chunk-size);
			# readchars returns '' at EOF; close and end the iterator.
			if $chunk.chars {
				$chunk
			}
			else {
				$handle.close;
				IterationEnd
			}
		}).iterator
	}
}

class Qwiratry::Location::File::Destination is Qwiratry::Location::Base::DestinationWalkable does Qwiratry::Location::Base::DestinationPush {

	=begin pod

	=head2 C<write-walkable(Str $location, Mu $content)>

	=begin code
	method write-walkable(Str $location, Mu $content --> Mu)
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
	method write-walkable(Str $location, Mu $content --> Mu) {
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

	=begin pod

	=head2 C<open-sink-push(Str:D $location)>

	=begin code
	method open-sink-push(Str:D $location --> Mu)
	=end code

	=head3 Parameters

	=item C<$location>

	 The location string or URI handled by the backend.


	Opens an incremental file sink for C<$location>.

	Glob patterns are rejected. Parent directories are created as needed. The
	returned C<Qwiratry::Location::File::Sink> supports C<write-chunk> and
	C<close>.

	=end pod
	method open-sink-push(Str:D $location --> Mu) {
		my $path = path-from-location($location);
		if path-has-glob($path) {
			X::Qwiratry::IO::LocationError.new(
				:message("Glob locations cannot be write destinations: $location"),
				:location($location),
				:reason('Invalid location format'),
				:operator-type('DestinationOperator'),
			).throw;
		}
		$path.IO.parent.d or $path.IO.parent.mkdir;
		Qwiratry::Location::File::Sink.new(:handle($path.IO.open(:w)))
	}
}
