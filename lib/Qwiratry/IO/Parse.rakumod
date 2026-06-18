=begin pod

Parse interface — discovers and loads C<Qwiratry::IO::Parse::*> format implementations.

Use L<instance> to obtain the singleton, then call L<parse> with a format name
and external text. Pipeline operators (C<↱ 'JSON'>) and L<Qwiratry::Operator::PipelineStep>
delegate through this interface.

=head2 Writing a parse implementation

Implementations are plain Raku classes discovered at runtime by L<Implementation::Loader>.
To add support for a new on-disk format:

=item Create C<lib/Qwiratry/IO/Parse/MyFormat.rakumod> (filename matches the class name).

=item Declare a class that subclasses L<Qwiratry::IO::Parse::Base>:

  use Qwiratry::IO::Parse::Base;

  class Qwiratry::IO::Parse::MyFormat is Qwiratry::IO::Parse::Base {
      method parse(Str $input-string --> Mu) {
          # return structured data: rows, a tree, a single hash, etc.
      }
  }

=item The trailing component of the class name (C<MyFormat>) is the format label,
    uppercased when referenced (C<'MYFORMAT'> or C<'MyFormat'> both resolve to
    C<Qwiratry::IO::Parse::MYFORMAT>).

=item Implement C<parse> to turn C<$input-string> into in-memory data. Table pipelines
    usually expect a L<Positional> of L<Associative> rows; tree pipelines may
    return nested structures instead.

=item No registration step is required — L<formats> picks up any module matching
    C<Qwiratry::IO::Parse::*> under C<lib/> except L<Qwiratry::IO::Parse::Base>.

=item Call C<Qwiratry::IO::Parse.instance.parse('MYFORMAT', $input-string)> or construct
    C<Qwiratry::IO::Parse::MyFormat.new.parse($input-string)> directly in tests.

See the built-in L<Qwiratry::IO::Parse::JSON>, L<Qwiratry::IO::Parse::CSV>, and
L<Qwiratry::IO::Parse::XML> modules for minimal reference implementations.

=end pod
use Implementation::Loader;
use Qwiratry::Exception::Operator;

class Qwiratry::IO::Parse does Implementation::Loader {

	constant @LIB-PATHS = 'lib';
	constant FORMAT-GLOB = 'Qwiratry::IO::Parse::*';
	constant BASE-CLASS = 'Qwiratry::IO::Parse::Base';

	has %!implementation-cache;
	has @!format-list;

	my $instance;

	=begin pod

	Return the shared Parse interface instance.

	=end pod
	method instance(--> Qwiratry::IO::Parse) {
		$instance //= self.new
	}

	=begin pod

	Normalize a format label to an uppercase name without module suffix.

	Accepts bare names (C<json>), mixed case (C<Json>), or module-style strings
	(C<Qwiratry::IO::Parse::JSON>).

	=end pod
	method normalize-format-name(Str $format --> Str) {
		my $name = $format.subst(/\.rakumod$/, '');
		$name = $name.split('::').[*-1] if $name.contains('::');
		$name.uc
	}

	=begin pod

	Return the fully qualified module name for a format label.

	For example C<'json'> → C<Qwiratry::IO::Parse::JSON>.

	=end pod
	method format-module-name(Str $format --> Str) {
		"Qwiratry::IO::Parse::{self.normalize-format-name($format)}"
	}

	# Derive a format label from a discovered module FQCN.
	method !format-name-from-module(Str $module --> Str) {
		self.normalize-format-name($module.split('::').[*-1])
	}

	=begin pod

	Return sorted format labels for all discovered parse implementations.

	Result is cached after the first scan of C<lib/> for modules matching
	C<Qwiratry::IO::Parse::*> (excluding L<Qwiratry::IO::Parse::Base>).

	=end pod
	method formats(--> List) {
		unless @!format-list {
			@!format-list = self.find-module-pattern(
				:globs([FORMAT-GLOB]),
				:paths(@LIB-PATHS),
			).grep(!*.ends-with('::Base')).map({ self!format-name-from-module($_) }).sort.List;
		}
		@!format-list
	}

	=begin pod

	Verify that a parse implementation exists for C<$format>; throw otherwise.

	Returns the fully qualified module name when the implementation is present.
	Throws L<X::Qwiratry::IO::FormatNotFound> when no matching module is found.

	=end pod
	method ensure-format(Str $format --> Str) {
		my $module = self.format-module-name($format);
		unless self.find-module-pattern(
			:globs([FORMAT-GLOB]),
			:paths(@LIB-PATHS),
		).grep(* eq $module) {
			X::Qwiratry::IO::FormatNotFound.new(
				:message("Parse format module not found for $format"),
				:format(self.normalize-format-name($format)),
				:parse-or-render('Parse'),
				:operator-type('ParseOperator'),
			).throw;
		}
		$module
	}

	# Load (or return cached) implementation instance for $format.
	method !implementation(Str $format) {
		my $name = self.normalize-format-name($format);
		%!implementation-cache{$name} //= self.load-library(
			:module-name(self.format-module-name($name)),
			:does(BASE-CLASS),
		);
	}

	=begin pod

	Parse C<$input-string> using the implementation registered for C<$format>.

	Delegates to the format class's C<parse> method. The return type depends on
	the implementation; table-oriented formats typically yield a L<Positional> of rows.

	=end pod
	method parse(Str $format, Str $input-string --> Mu) {
		self!implementation($format).parse($input-string)
	}
}
