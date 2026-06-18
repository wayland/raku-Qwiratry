=begin pod

Render abstract base and factory for format-specific render implementations.

Use L<make> to obtain the implementation for a format, then call L<render> on
the returned object. Pipeline operators (C<↴ 'JSON'>) and
L<Qwiratry::Operator::PipelineStep> delegate through this factory.

=head2 Writing a render implementation

Implementations are plain Raku classes in format modules discovered at runtime
by L<Implementation::Loader>.
To add support for a new output format:

=item Create a format module file under lib/Qwiratry/IO/ whose name matches the format.

=item Declare a class that subclasses L<Qwiratry::IO::Render>:

  use Qwiratry::IO::Render;

  class Qwiratry::IO::MyFormat::Render is Qwiratry::IO::Render {
      method render(Mu $data, Associative :%options --> Str) {
          # serialize $data to external text
      }
  }

=item The trailing component of the class name is the format label, uppercased
    when referenced. For example, C<json> resolves to the JSON format module
    and its C<Render> implementation class.

=item Implement C<render> to serialize C<$data> to a C<Str>. The C<:%options>
    hash carries render hints from L<RenderOperator> (for example C<< :pretty >> on
    JSON). Implementations may ignore unknown options.

=item No registration step is required; L<formats> scans format modules and
    keeps those that define a C<Render> class.

=item Call L<make> with the desired C<:format> and then call C<render> on the
    returned object. Concrete implementation constructors are an implementation
    detail of the factory.

See the built-in L<Qwiratry::IO::JSON>, L<Qwiratry::IO::CSV>, and
L<Qwiratry::IO::XML> modules for minimal reference implementations.

=end pod
use Implementation::Loader;
use Qwiratry::Exception::Operator;

class Qwiratry::IO::Render does Implementation::Loader {

	constant @LIB-PATHS = 'lib';
	constant FORMAT-GLOB = 'Qwiratry::IO::*';

	has %!implementation-cache;
	has @!format-list;

	my $instance;

	=begin pod

	Return the shared Render factory instance.

	=end pod
	method instance() {
		$instance //= self.new
	}

	=begin pod

	Normalize a format label to an uppercase name without module suffix.

	Accepts bare names (C<json>), mixed case (C<Json>), or module-style strings
	(C<Qwiratry::IO::JSON::Render>).

	=end pod
	method normalize-format-name(Str $format --> Str) {
		my $name = $format.subst(/\.rakumod$/, '');
		$name = $name.split('::').[*-1] if $name.contains('::');
		$name.uc
	}

	=begin pod

	Return the fully qualified format module name for a format label.

	For example C<'json'> → C<Qwiratry::IO::JSON>.

	=end pod
	method format-module-name(Str $format --> Str) {
		'Qwiratry::IO::' ~ self.normalize-format-name($format)
	}

	=begin pod

	Return the fully qualified render implementation class for a format label.

	For example C<'json'> → C<Qwiratry::IO::JSON::Render>.

	=end pod
	method format-class-name(Str $format --> Str) {
		self.format-module-name($format) ~ '::Render'
	}

	# Derive a format label from a discovered format module FQCN.
	method !format-name-from-module(Str $module --> Str) {
		self.normalize-format-name($module.split('::')[2])
	}

	# Load a format module, resolve its ::Render class, and verify inheritance.
	method !implementation-type(Str $format --> Mu) {
		my $module = self.format-module-name($format);
		my $class-name = self.format-class-name($format);
		my $type = try {
			self.load-library(
				:module-name($module),
				:type($class-name),
				:return-type(True),
			);
		};
		return $type if $type ~~ self.WHAT;
		Nil
	}

	=begin pod

	Return sorted format labels for all discovered render implementations.

	Result is cached after the first scan of C<lib/> for format modules defining
	a C<Render> implementation class.

	=end pod
	method formats(--> List) {
		return self.instance.formats unless self.DEFINITE;
		unless @!format-list {
			@!format-list = self.find-module-pattern(
				:globs([FORMAT-GLOB]),
				:paths(@LIB-PATHS),
			).map({ self!format-name-from-module($_) })
				.grep({ self!implementation-type($_) ~~ self.WHAT })
				.sort.List;
		}
		@!format-list
	}

	=begin pod

	Verify that a render implementation exists for C<$format>; throw otherwise.

	Returns the fully qualified implementation class name when the implementation is present.
	Throws L<X::Qwiratry::IO::FormatNotFound> when no matching module is found.

	=end pod
	method ensure-format(Str $format --> Str) {
		return self.instance.ensure-format($format) unless self.DEFINITE;
		my $class = self.format-class-name($format);
		unless self!implementation-type($format) ~~ self.WHAT {
			io-format-not-found(
				:message("Render format module not found for $format"),
				:format(self.normalize-format-name($format)),
				:parse-or-render('Render'),
				:operator-type('RenderOperator'),
			).throw;
		}
		$class
	}

	# Load (or return cached) implementation instance for $format.
	method !implementation(Str $format) {
		my $name = self.normalize-format-name($format);
		%!implementation-cache{$name} //= self!implementation-type($name).new;
	}

	=begin pod

	Return the concrete render implementation for C<$format>.

	For example, C<Qwiratry::IO::Render.make(:format<JSON>)> returns a
	L<Qwiratry::IO::JSON::Render> object. The implementation is cached by normalized
	format name.

	=end pod
	method make(Str :$format!) {
		self.instance!implementation($format)
	}

	=begin pod

	Render structured data to external text; implementations must override.

	=end pod
	method render(Mu $data, Associative :%options --> Str) {
		die "render not implemented by {self.^name}";
	}
}
