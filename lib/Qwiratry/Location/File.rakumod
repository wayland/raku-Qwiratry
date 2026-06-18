=begin pod

Local file location implementation.

Defines source and destination implementations loaded through
L<Qwiratry::Location.make>.

=end pod
use Qwiratry::Exception::Operator;
use Qwiratry::Location::Base;

class Qwiratry::Location::File::Source is Qwiratry::Location::Base::Source {

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

	method !path-from-location(Str $location --> Str) {
		$location.subst(/^ 'file://' /, '')
	}
}

class Qwiratry::Location::File::Destination is Qwiratry::Location::Base::Destination {

	method write(Str $location, Mu $content --> Mu) {
		my $text = $content ~~ Str ?? $content !! ~$content;
		my $path = self!path-from-location($location);
		$path.IO.parent.mkdir unless $path.IO.parent.d;
		spurt $path, $text;
		$content
	}

	method !path-from-location(Str $location --> Str) {
		$location.subst(/^ 'file://' /, '')
	}
}
