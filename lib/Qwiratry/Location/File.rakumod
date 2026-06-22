=begin pod

=head1 Overview

Local file location implementation.

Defines C<Qwiratry::Location::File::Source> and
C<Qwiratry::Location::File::Destination>, the built-in backend loaded through
L<Qwiratry::Location.make>.

The backend accepts both C<file://> URLs and local path strings. Source reads
return text, destination writes coerce content to text and create parent
directories before writing.

=end pod
use X::Qwiratry;
use Qwiratry::Location::Base;

class Qwiratry::Location::File::Source is Qwiratry::Location::Base::Source {

	=begin pod

	=head1 Methods

	=head2 C<read(Str $location)>

	=begin code
	method read(Str $location --> Str)
	=end code

	=head3 Parameters

	=item C<$location>

	 The location string or URI handled by the backend.


	Reads and returns the file contents for C<$location>.

	Missing files are reported as L<X::Qwiratry::IO::LocationError> with the
	original location string and source operator context, so pipeline diagnostics
	point back to the user's query.

	=end pod
	method read(Str $location --> Str) {
		my $path = self!path-from-location($location);
		unless $path.IO.e {
			X::Qwiratry::IO::LocationError.new(
				:message("I/O location not found: $location"),
				:location($location),
				:reason('File not found'),
				:operator-type('SourceOperator'),
			).throw;
		}
		$path.IO.slurp
	}

	# Converts a file URI or plain path location into a filesystem path.
	method !path-from-location(Str $location --> Str) {
		$location.subst(/^ 'file://' /, '')
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

	The destination creates parent directories as needed. Returning the content
	keeps destination operators usable at the end of a pipeline without changing
	the value visible to callers.

	=end pod
	method write(Str $location, Mu $content --> Mu) {
		my $text = $content ~~ Str ?? $content !! ~$content;
		my $path = self!path-from-location($location);
		$path.IO.parent.mkdir unless $path.IO.parent.d;
		spurt $path, $text;
		$content
	}

	# Converts a file URI or plain path location into a filesystem path.
	method !path-from-location(Str $location --> Str) {
		$location.subst(/^ 'file://' /, '')
	}
}
