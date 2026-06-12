=begin pod

Parse interface — discovers and loads C<Qwiratry::IO::Parse::*> format implementations.

=end pod
use Implementation::Loader;
use Qwiratry::Exception::Operator;

unit class Qwiratry::IO::Parse does Implementation::Loader;

constant @LIB-PATHS = 'lib';
constant FORMAT-GLOB = 'Qwiratry::IO::Parse::*';
constant BASE-CLASS = 'Qwiratry::IO::Parse::Base';

has %!implementation-cache;
has @!format-list;

my $instance;

method instance(--> Qwiratry::IO::Parse) {
	$instance //= self.new
}

method normalize-format-name(Str $format --> Str) {
	my $name = $format.subst(/\.rakumod$/, '');
	$name = $name.split('::').[*-1] if $name.contains('::');
	$name.uc
}

method format-module-name(Str $format --> Str) {
	"Qwiratry::IO::Parse::{self.normalize-format-name($format)}"
}

method !format-name-from-module(Str $module --> Str) {
	self.normalize-format-name($module.split('::').[*-1])
}

method formats(--> List) {
	unless @!format-list {
		@!format-list = self.find-module-pattern(
			:globs([FORMAT-GLOB]),
			:paths(@LIB-PATHS),
		).grep(!*.ends-with('::Base')).map({ self!format-name-from-module($_) }).sort.List;
	}
	@!format-list
}

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

method !implementation(Str $format) {
	my $name = self.normalize-format-name($format);
	%!implementation-cache{$name} //= self.load-library(
		:module-name(self.format-module-name($name)),
		:does(BASE-CLASS),
	);
}

method parse(Str $format, Str $text --> Mu) {
	self!implementation($format).parse($text)
}
