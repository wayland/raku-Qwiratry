=begin pod

Render interface — discovers and loads C<Qwiratry::IO::Render::*> format implementations.

Use L<instance> to obtain the singleton, then call L<render> with a format name
and in-memory data. Pipeline operators (C<↴ 'JSON'>) and
L<Qwiratry::Operator::PipelineStep> delegate through this interface.

=head2 Writing a render implementation

Implementations are plain Raku classes discovered at runtime by L<Implementation::Loader>.
To add support for a new output format:

=item Create C<lib/Qwiratry/IO/Render/MyFormat.rakumod> (filename matches the class name).

=item Declare a class that subclasses L<Qwiratry::IO::Render::Base>:

  use Qwiratry::IO::Render::Base;

  class Qwiratry::IO::Render::MyFormat is Qwiratry::IO::Render::Base {
      method render(Mu $data, Associative :%options --> Str) {
          # serialize $data to external text
      }
  }

=item The trailing component of the class name (C<MyFormat>) is the format label,
    uppercased when referenced (C<'MYFORMAT'> or C<'MyFormat'> both resolve to
    C<Qwiratry::IO::Render::MYFORMAT>).

=item Implement C<render> to serialize C<$data> to a C<Str>. The C<:%options>
    hash carries render hints from L<RenderOperator> (for example C<< :pretty >> on
    JSON). Implementations may ignore unknown options.

=item No registration step is required — L<formats> picks up any module matching
    C<Qwiratry::IO::Render::*> under C<lib/> except L<Qwiratry::IO::Render::Base>.

=item Call C<Qwiratry::IO::Render.instance.render('MYFORMAT', $data)> or construct
    C<Qwiratry::IO::Render::MyFormat.new.render($data)> directly in tests.

See the built-in L<Qwiratry::IO::Render::JSON>, L<Qwiratry::IO::Render::CSV>, and
L<Qwiratry::IO::Render::XML> modules for minimal reference implementations.

=end pod
use Implementation::Loader;
use Qwiratry::Exception::Operator;

class Qwiratry::IO::Render does Implementation::Loader {

	constant @LIB-PATHS = 'lib';
	constant FORMAT-GLOB = 'Qwiratry::IO::Render::*';
	constant BASE-CLASS = 'Qwiratry::IO::Render::Base';

	has %!implementation-cache;
	has @!format-list;

	my $instance;

	=begin pod

	Return the shared Render interface instance.

	=end pod
	method instance(--> Qwiratry::IO::Render) {
		$instance //= self.new
	}

	=begin pod

	Normalize a format label to an uppercase name without module suffix.

	Accepts bare names (C<json>), mixed case (C<Json>), or module-style strings
	(C<Qwiratry::IO::Render::JSON>).

	=end pod
	method normalize-format-name(Str $format --> Str) {
		my $name = $format.subst(/\.rakumod$/, '');
		$name = $name.split('::').[*-1] if $name.contains('::');
		$name.uc
	}

	=begin pod

	Return the fully qualified module name for a format label.

	For example C<'json'> → C<Qwiratry::IO::Render::JSON>.

	=end pod
	method format-module-name(Str $format --> Str) {
		"Qwiratry::IO::Render::{self.normalize-format-name($format)}"
	}

	# Derive a format label from a discovered module FQCN.
	method !format-name-from-module(Str $module --> Str) {
		self.normalize-format-name($module.split('::').[*-1])
	}

	=begin pod

	Return sorted format labels for all discovered render implementations.

	Result is cached after the first scan of C<lib/> for modules matching
	C<Qwiratry::IO::Render::*> (excluding L<Qwiratry::IO::Render::Base>).

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

	Verify that a render implementation exists for C<$format>; throw otherwise.

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
				:message("Render format module not found for $format"),
				:format(self.normalize-format-name($format)),
				:parse-or-render('Render'),
				:operator-type('RenderOperator'),
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

	Render C<$data> to text using the implementation registered for C<$format>.

	Delegates to the format class's C<render> method. Pass C<:%options> through
	to the implementation (for example C<< :pretty >> for JSON output).

	=end pod
	method render(Str $format, Mu $data, Associative :%options --> Str) {
		self!implementation($format).render($data, :%options)
	}
}
