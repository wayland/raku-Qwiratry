=begin pod

Parse abstract base and factory for format-specific parse implementations.

Use L<make> to obtain the implementation for a format, then call L<parse> on
the returned object. Pipeline operators (C<↱ 'JSON'>) and
L<Qwiratry::Operator::PipelineStep> delegate through this factory.

=head2 Writing a parse implementation

Implementations are plain Raku classes in format modules discovered at runtime
by L<Implementation::Loader>.
To add support for a new on-disk format:

=item Create a format module file under lib/Qwiratry/IO/ whose name matches the format.

=item Declare a class that subclasses L<Qwiratry::IO::Parse>:

  use Qwiratry::IO::Parse;

  class Qwiratry::IO::MyFormat::Parse is Qwiratry::IO::Parse {
      method parse(Str $input-string --> Mu) {
          # return structured data: rows, a tree, a single hash, etc.
      }
  }

=item The trailing component of the class name is the format label, uppercased
    when referenced. For example, C<json> resolves to the JSON format module
    and its C<Parse> implementation class.

=item Implement C<parse> to turn C<$input-string> into in-memory data. Table pipelines
    usually expect a L<Positional> of L<Associative> rows; tree pipelines may
    return nested structures instead.

=item No registration step is required; L<formats> scans format modules and
    keeps those that define a C<Parse> class.

=item Call L<make> with the desired C<:format> and then call C<parse> on the
    returned object. Concrete implementation constructors are an implementation
    detail of the factory.

See the built-in L<Qwiratry::IO::JSON>, L<Qwiratry::IO::CSV>, and
L<Qwiratry::IO::XML> modules for minimal reference implementations.

=end pod
use Implementation::Loader;
use Qwiratry::Exception::Operator;

class Qwiratry::IO::Parse does Implementation::Loader {

	constant @LIB-PATHS = 'lib';
	constant FORMAT-GLOB = 'Qwiratry::IO::*';

	has %!implementation-cache;
	has @!format-list;

	my $instance;

	=begin pod

	Return the shared Parse factory instance.

	=end pod
	method instance() {
		$instance //= self.new
	}

	=begin pod

	Normalize a format label to an uppercase name without module suffix.

	Accepts bare names (C<json>), mixed case (C<Json>), or module-style strings
	(C<Qwiratry::IO::JSON::Parse>).

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

	Return the fully qualified parse implementation class for a format label.

	For example C<'json'> → C<Qwiratry::IO::JSON::Parse>.

	=end pod
	method format-class-name(Str $format --> Str) {
		self.format-module-name($format) ~ '::Parse'
	}

	# Derive a format label from a discovered format module FQCN.
	method !format-name-from-module(Str $module --> Str) {
		self.normalize-format-name($module.split('::')[2])
	}

	# Load a format module, resolve its ::Parse class, and verify inheritance.
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

	Return sorted format labels for all discovered parse implementations.

	Result is cached after the first scan of C<lib/> for format modules defining
	a C<Parse> implementation class.

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

	Verify that a parse implementation exists for C<$format>; throw otherwise.

	Returns the fully qualified implementation class name when the implementation is present.
	Throws L<X::Qwiratry::IO::FormatNotFound> when no matching module is found.

	=end pod
	method ensure-format(Str $format --> Str) {
		return self.instance.ensure-format($format) unless self.DEFINITE;
		my $class = self.format-class-name($format);
		unless self!implementation-type($format) ~~ self.WHAT {
			io-format-not-found(
				:message("Parse format module not found for $format"),
				:format(self.normalize-format-name($format)),
				:parse-or-render('Parse'),
				:operator-type('ParseOperator'),
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

	Return the concrete parse implementation for C<$format>.

	For example, C<Qwiratry::IO::Parse.make(:format<JSON>)> returns a
	L<Qwiratry::IO::JSON::Parse> object. The implementation is cached by normalized
	format name.

	=end pod
	method make(Str :$format!) {
		self.instance!implementation($format)
	}

	=begin pod

	Parse external text into structured data; implementations must override.

	=end pod
	method parse(Str $input-string --> Mu) {
		die "parse not implemented by {self.^name}";
	}
}
