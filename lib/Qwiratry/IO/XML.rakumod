=begin pod

Minimal XML format module (string wrapper for round-trip tests).

Defines C<Qwiratry::IO::XML::Parse> and C<Qwiratry::IO::XML::Render>
implementations loaded through L<Qwiratry::IO::Parse.make> and
L<Qwiratry::IO::Render.make>.

=end pod
use Qwiratry::IO::Parse;
use Qwiratry::IO::Render;

class Qwiratry::IO::XML::Parse is Qwiratry::IO::Parse {

	method parse(Str $input-string --> Mu) {
		%(xml => $input-string)
	}
}

class Qwiratry::IO::XML::Render is Qwiratry::IO::Render {

	method render(Mu $data, Associative :%options --> Str) {
		if $data ~~ Associative && $data<xml>:exists {
			return ~$data<xml>;
		}
		"<data>{$data.raku}</data>"
	}
}
