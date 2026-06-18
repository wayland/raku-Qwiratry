=begin pod

Minimal XML format module (string wrapper for round-trip tests).

Defines C<Qwiratry::Format::XML::Parse> and C<Qwiratry::Format::XML::Render>
implementations loaded through L<Qwiratry::Format.make>.

=end pod
use Qwiratry::Format::Base;

class Qwiratry::Format::XML::Parse is Qwiratry::Format::Base::Parse {

	method parse(Str $input-string --> Mu) {
		%(xml => $input-string)
	}
}

class Qwiratry::Format::XML::Render is Qwiratry::Format::Base::Render {

	method render(Mu $data, Associative :%options --> Str) {
		if $data ~~ Associative && $data<xml>:exists {
			return ~$data<xml>;
		}
		"<data>{$data.raku}</data>"
	}
}
