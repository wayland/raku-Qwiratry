=begin pod

Minimal XML render format module.

=end pod
use Qwiratry::IO::Render::Base;

unit class Qwiratry::IO::Render::XML is Qwiratry::IO::Render::Base;

method render(Mu $data, Associative :%options --> Str) {
	if $data ~~ Associative && $data<xml>:exists {
		return ~$data<xml>;
	}
	"<data>{$data.raku}</data>"
}

our sub render(Mu $data, Associative :%options --> Str) is export {
	Qwiratry::IO::Render::XML.new.render($data, :%options)
}
