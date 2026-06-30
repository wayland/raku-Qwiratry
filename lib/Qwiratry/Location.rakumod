=begin pod

Location implementation factory.

Use L<make> with an operation type and location string to obtain a concrete
implementation object:

=begin code
Qwiratry::Location.make(:type<Source>, :location<./data.json>)
Qwiratry::Location.make(:type<Destination>, :location<file:///tmp/out.json>)
=end code

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
	has %!scheme-registry;
	has $!scheme-registry-discovered = False;

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
		$name.contains('::') and $name = $name.split('::').[*-1];
		$name.tc
	}

	=begin pod

	Normalize backend labels to module-name form.

	=end pod
	method normalize-backend-name(Str $backend --> Str) {
		my $name = $backend.subst(/\.rakumod$/, '');
		$name.contains('::') and $name = $name.split('::').[*-1];
		$name.lc.split(/<[-_]>+/).map(*.tc).join
	}

	=begin pod

	Register URI C<@schemes> as handled by location backend C<$backend>.

	=end pod
	method register-schemes(Str :$backend!, :$schemes! --> Nil) {
		unless self.DEFINITE {
			self.instance.register-schemes(:$backend, :$schemes);
			return Nil;
		}
		my $backend-name = self!backend-name-label($backend);
		my @scheme-list = $schemes ~~ Positional ?? $schemes.list !! ($schemes,);
		for @scheme-list -> $scheme {
			%!scheme-registry{self!normalize-scheme($scheme)} = $backend-name;
		}
		Nil
	}

	=begin pod

	Return the registered backend for URI C<$scheme>, if one is known.

	=end pod
	method backend-name-for-scheme(Str $scheme --> Any) {
		self.DEFINITE or return self.instance.backend-name-for-scheme($scheme);
		self!discover-scheme-registry;
		%!scheme-registry{self!normalize-scheme($scheme)}
	}

	=begin pod

	Return the backend label implied by a location string.

	=end pod
	method backend-name-from-location(Str $location --> Str) {
		if $location ~~ /^ (<[A..Za..z]> <[\w+.\-]>* ) '://' / {
			my $scheme = self!normalize-scheme(~$0);
			return self.backend-name-for-scheme($scheme)
				// self.canonical-backend-name(self.normalize-backend-name($scheme));
		}
		self!looks-like-local-path($location) and return 'File';
		self!invalid-location($location);
	}

	=begin pod

	Return the fully qualified backend module name for C<$backend>.

	=end pod
	method backend-module-name(Str $backend --> Str) {
		'Qwiratry::Location::' ~ self.canonical-backend-name($backend)
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

	# Normalize URI schemes for registry lookup.
	method !normalize-scheme(Str $scheme --> Str) {
		$scheme.lc
	}

	# Derive a backend label while preserving explicit acronym casing.
	method !backend-name-label(Str $backend --> Str) {
		my $name = $backend.subst(/\.rakumod$/, '');
		$name.contains('::') and $name = $name.split('::').[*-1];
		$name
	}

	# Load discoverable location modules once so they can register URI schemes.
	method !discover-scheme-registry(--> Nil) {
		return if $!scheme-registry-discovered;
		$!scheme-registry-discovered = True;

		for self.find-module-pattern(:globs([BACKEND-GLOB]), :paths(@LIB-PATHS)) -> $module {
			my $backend = self!backend-name-from-module($module);
			next unless $backend.defined;
			next if $backend eq 'Base';
			try {
				self.load-library(:module-name($module), :return-type(True));
				CATCH { default { } }
			}
		}
		Nil
	}

	=begin pod

	Return the backend module label, preserving discovered module casing.

	=end pod
	method canonical-backend-name(Str $backend --> Str) {
		self.DEFINITE or return self.instance.canonical-backend-name($backend);
		my $requested = self!backend-name-label($backend);
		my $normalized = self.normalize-backend-name($requested);

		for self.find-module-pattern(:globs([BACKEND-GLOB]), :paths(@LIB-PATHS)) -> $module {
			my $candidate = self!backend-name-from-module($module);
			next unless $candidate.defined;
			return $candidate if $candidate.lc eq $requested.lc || $candidate.lc eq $normalized.lc;
		}

		$normalized
	}

	# Derive a backend label from a discovered backend module FQCN.
	method !backend-name-from-module(Str $module --> Str) {
		$module.split('::').elems == 3 or return Nil;
		my $backend = $module.split('::')[2];
		$backend eq 'Base' and return Nil;
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
		(self.normalize-type-name($type), self.canonical-backend-name($backend))
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
		!($base =:= Nil) && $implementation ~~ $base and return $implementation;
		False
	}

	=begin pod

	Return sorted backend labels for implementations of operation C<$type>.

	=end pod
	method backends(Str :$type! --> List) {
		self.DEFINITE or return self.instance.backends(:$type);
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
		self.DEFINITE or return self.instance.ensure-location(:$type, :$location);
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
