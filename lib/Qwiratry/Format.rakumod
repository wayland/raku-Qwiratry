=begin pod

Format implementation factory.

Use L<make> with an operation type and format name to obtain a concrete
implementation object:

  Qwiratry::Format.make(:type<Parse>, :format<JSON>)
  Qwiratry::Format.make(:type<Render>, :format<JSON>)

Format modules live under C<Qwiratry::Format::<FORMAT>> and define operation
classes such as C<Qwiratry::Format::JSON::Parse> and C<Qwiratry::Format::JSON::Render>.

=end pod
use Implementation::Loader;
use Qwiratry::Exception::Operator;
use Qwiratry::Format::Base;

class Qwiratry::Format does Implementation::Loader {

	constant @LIB-PATHS = 'lib';
	constant FORMAT-GLOB = 'Qwiratry::Format::*';

	has %!implementation-cache;
	has %!format-list-cache;

	my $instance;

	=begin pod

	Return the shared format factory instance.

	=end pod
	method instance() {
		$instance //= self.new
	}

	=begin pod

	Normalize operation type labels (for example C<parse> or C<Render>).

	=end pod
	method normalize-type-name(Str $type --> Str) {
		my $name = $type.subst(/\.rakumod$/, '');
		$name = $name.split('::').[*-1] if $name.contains('::');
		$name.tc
	}

	=begin pod

	Normalize format labels (for example C<json> or C<Qwiratry::Format::JSON>).

	=end pod
	method normalize-format-name(Str $format --> Str) {
		my $name = $format.subst(/\.rakumod$/, '');
		$name = $name.split('::').[*-1] if $name.contains('::');
		$name.uc
	}

	=begin pod

	Return the fully qualified format module name for C<$format>.

	=end pod
	method format-module-name(Str $format --> Str) {
		'Qwiratry::Format::' ~ self.normalize-format-name($format)
	}

	=begin pod

	Return the fully qualified implementation class name for C<$type> and C<$format>.

	=end pod
	method format-class-name(Str $type, Str $format --> Str) {
		self.format-module-name($format) ~ '::' ~ self.normalize-type-name($type)
	}

	# Return the abstract base class name for an operation type.
	method !base-class-name(Str $type --> Str) {
		'Qwiratry::Format::Base::' ~ self.normalize-type-name($type)
	}

	# Derive a format label from a discovered format module FQCN.
	method !format-name-from-module(Str $module --> Str) {
		return Nil unless $module.split('::').elems == 3;
		my $format = self.normalize-format-name($module.split('::')[2]);
		return Nil if $format eq 'BASE';
		$format
	}

	# Normalize the operation and format pair used by factory dispatch.
	method !type-and-format-names(Str $type, Str $format --> List) {
		(self.normalize-type-name($type), self.normalize-format-name($format))
	}

	# Load a format module, resolve its operation class, and verify inheritance.
	method !implementation-type(Str $type, Str $format) {
		my $module = self.format-module-name($format);
		my $class-name = self.format-class-name($type, $format);
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

	Return sorted format labels for implementations of operation C<$type>.

	=end pod
	method formats(Str :$type! --> List) {
		return self.instance.formats(:$type) unless self.DEFINITE;
		my $type-name = self.normalize-type-name($type);
		unless %!format-list-cache{$type-name}:exists {
			%!format-list-cache{$type-name} = self.find-module-pattern(
				:globs([FORMAT-GLOB]),
				:paths(@LIB-PATHS),
			).map({ self!format-name-from-module($_) })
			.grep(*.defined)
			.grep({
				my $implementation = self!implementation-type($type-name, $_);
				!($implementation =:= False)
			})
			.sort.Array;
		}
		%!format-list-cache{$type-name}.list
	}

	=begin pod

	Verify that an implementation exists for C<$type> and C<$format>; throw otherwise.

	=end pod
	method ensure-format(Str :$type!, Str :$format! --> Str) {
		return self.instance.ensure-format(:$type, :$format) unless self.DEFINITE;
		my ($type-name, $format-name) = self!type-and-format-names($type, $format);
		my $class = self.format-class-name($type-name, $format-name);
		unless $format-name (elem) self.formats(:type($type-name)) {
			format-not-found(
				:message("$type-name format module not found for $format"),
				:format($format-name),
				:parse-or-render($type-name),
				:operator-type("{$type-name}Operator"),
			).throw;
		}
		$class
	}

	# Load (or return cached) implementation instance for operation type and format.
	method !implementation(Str $type, Str $format) {
		my ($type-name, $format-name) = self!type-and-format-names($type, $format);
		my $key = "$type-name|$format-name";
		unless %!implementation-cache{$key}:exists {
			self.ensure-format(:type($type-name), :format($format-name));
			%!implementation-cache{$key} = self!implementation-type($type-name, $format-name).new;
		}
		%!implementation-cache{$key}
	}

	=begin pod

	Return the concrete implementation for operation C<$type> and C<$format>.

	=end pod
	method make(Str :$type!, Str :$format!) {
		self.instance!implementation($type, $format)
	}
}
