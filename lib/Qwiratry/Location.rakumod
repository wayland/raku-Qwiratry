=begin pod

Location implementation factory.

Use L<make> with an operation type and location string to obtain a concrete
implementation object:

  Qwiratry::Location.make(:type<Source>, :location<./data.json>)
  Qwiratry::Location.make(:type<Destination>, :location<file:///tmp/out.json>)

Location modules live under C<Qwiratry::Location::<BACKEND>> and define
operation classes such as C<Qwiratry::Location::File::Source> and
C<Qwiratry::Location::File::Destination>.

=end pod
use Implementation::Loader;
use X::Qwiratry;
use Qwiratry::Location::Base;

class Qwiratry::Location does Implementation::Loader {

	constant @LIB-PATHS = 'lib';
	constant BACKEND-GLOB = 'Qwiratry::Location::*';

	has %!implementation-cache;
	has %!backend-list-cache;

	my $instance;

	=begin pod

	Return the shared location factory instance.

	=end pod
	method instance() {
		$instance //= self.new
	}

	=begin pod

	Normalize operation type labels (for example C<source> or C<Destination>).

	=end pod
	method normalize-type-name(Str $type --> Str) {
		my $name = $type.subst(/\.rakumod$/, '');
		$name = $name.split('::').[*-1] if $name.contains('::');
		$name.tc
	}

	=begin pod

	Normalize backend labels to module-name form.

	=end pod
	method normalize-backend-name(Str $backend --> Str) {
		my $name = $backend.subst(/\.rakumod$/, '');
		$name = $name.split('::').[*-1] if $name.contains('::');
		$name.lc.split(/<[-_]>+/).map(*.tc).join
	}

	=begin pod

	Return the backend label implied by a location string.

	=end pod
	method backend-name-from-location(Str $location --> Str) {
		if $location ~~ /^ (<[A..Za..z]> <[\w+.\-]>* ) '://' / {
			return self.normalize-backend-name(~$0);
		}
		return 'File' if self!looks-like-local-path($location);
		self!invalid-location($location);
	}

	=begin pod

	Return the fully qualified backend module name for C<$backend>.

	=end pod
	method backend-module-name(Str $backend --> Str) {
		'Qwiratry::Location::' ~ self.normalize-backend-name($backend)
	}

	=begin pod

	Return the fully qualified implementation class name for C<$type> and C<$backend>.

	=end pod
	method backend-class-name(Str $type, Str $backend --> Str) {
		self.backend-module-name($backend) ~ '::' ~ self.normalize-type-name($type)
	}

	# Return the abstract base class name for an operation type.
	method !base-class-name(Str $type --> Str) {
		'Qwiratry::Location::Base::' ~ self.normalize-type-name($type)
	}

	# Derive a backend label from a discovered backend module FQCN.
	method !backend-name-from-module(Str $module --> Str) {
		return Nil unless $module.split('::').elems == 3;
		my $backend = self.normalize-backend-name($module.split('::')[2]);
		return Nil if $backend eq 'Base';
		$backend
	}

	# Accept local path forms without requiring a scheme.
	method !looks-like-local-path(Str $location --> Bool) {
		$location.starts-with('/') || $location.starts-with('./')
			|| ($location !~~ /^\w+:\/\// && $location.contains('.'))
			|| $location ~~ /^[\w\.\-\/]+$/
	}

	# Throw a consistent location error for syntactically invalid locations.
	method !invalid-location(Str $location) {
		X::Qwiratry::IO::LocationError.new(
			:message("Invalid I/O location: $location"),
			:location($location),
			:reason('Invalid location format'),
			:operator-type('AdaptorOperator'),
		).throw;
	}

	# Normalize the operation and backend pair used by factory dispatch.
	method !type-and-backend-names(Str $type, Str $backend --> List) {
		(self.normalize-type-name($type), self.normalize-backend-name($backend))
	}

	# Load a backend module, resolve its operation class, and verify inheritance.
	method !implementation-type(Str $type, Str $backend) {
		my $module = self.backend-module-name($backend);
		my $class-name = self.backend-class-name($type, $backend);
		my $base-class = self!base-class-name($type);
		my $implementation = try {
			self.load-library(
				:module-name($module),
				:type($class-name),
				:return-type(True),
			);
		};
		my $base = try { ::($base-class) };
		return $implementation if !($base =:= Nil) && $implementation ~~ $base;
		False
	}

	=begin pod

	Return sorted backend labels for implementations of operation C<$type>.

	=end pod
	method backends(Str :$type! --> List) {
		return self.instance.backends(:$type) unless self.DEFINITE;
		my $type-name = self.normalize-type-name($type);
		unless %!backend-list-cache{$type-name}:exists {
			%!backend-list-cache{$type-name} = self.find-module-pattern(
				:globs([BACKEND-GLOB]),
				:paths(@LIB-PATHS),
			).map({ self!backend-name-from-module($_) })
			.grep(*.defined)
			.grep({
				my $implementation = self!implementation-type($type-name, $_);
				!($implementation =:= False)
			})
			.sort.Array;
		}
		%!backend-list-cache{$type-name}.list
	}

	=begin pod

	Verify that an implementation exists for C<$type> and C<$location>; throw otherwise.

	=end pod
	method ensure-location(Str :$type!, Str :$location! --> Str) {
		return self.instance.ensure-location(:$type, :$location) unless self.DEFINITE;
		my $type-name = self.normalize-type-name($type);
		my $backend-name = self.backend-name-from-location($location);
		my $class = self.backend-class-name($type-name, $backend-name);
		unless $backend-name (elem) self.backends(:type($type-name)) {
			X::Qwiratry::IO::LocationError.new(
				:message("$type-name location implementation not found for $location"),
				:location($location),
				:reason("Location backend not found: $backend-name"),
				:operator-type("{$type-name}Operator"),
			).throw;
		}
		$class
	}

	# Load (or return cached) implementation instance for operation type and backend.
	method !implementation(Str $type, Str $location) {
		my $backend = self.backend-name-from-location($location);
		my ($type-name, $backend-name) = self!type-and-backend-names($type, $backend);
		my $key = "$type-name|$backend-name";
		unless %!implementation-cache{$key}:exists {
			self.ensure-location(:type($type-name), :$location);
			%!implementation-cache{$key} = self!implementation-type($type-name, $backend-name).new;
		}
		%!implementation-cache{$key}
	}

	=begin pod

	Return the concrete implementation for operation C<$type> and C<$location>.

	=end pod
	method make(Str :$type!, Str :$location!) {
		self.instance!implementation($type, $location)
	}
}
