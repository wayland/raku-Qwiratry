=begin pod

Minimal XML render format module.

=end pod
use Qwiratry::IO::Render::Base;

class Qwiratry::IO::Render::XML is Qwiratry::IO::Render::Base {

	method render(Mu $data, Associative :%options --> Str) {
		if $data ~~ Associative && $data<xml>:exists {
			return ~$data<xml>;
		}
		"<data>{$data.raku}</data>"
	}
}
