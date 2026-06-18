=begin pod

Minimal XML format module (string wrapper for round-trip tests).

Defines C<Qwiratry::IO::XML::Parse> and C<Qwiratry::IO::XML::Render>
implementations loaded through L<Qwiratry::IO.make>.

=end pod
use Qwiratry::IO::Base::Parse;
use Qwiratry::IO::Base::Render;

class Qwiratry::IO::XML::Parse is Qwiratry::IO::Base::Parse {

	method parse(Str $input-string --> Mu) {
		%(xml => $input-string)
	}
}

class Qwiratry::IO::XML::Render is Qwiratry::IO::Base::Render {

	method render(Mu $data, Associative :%options --> Str) {
		if $data ~~ Associative && $data<xml>:exists {
			return ~$data<xml>;
		}
		"<data>{$data.raku}</data>"
	}
}
