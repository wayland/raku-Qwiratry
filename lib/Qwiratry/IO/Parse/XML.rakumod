=begin pod

Minimal XML parse format module (string wrapper for round-trip tests).

=end pod
use Qwiratry::IO::Parse::Base;

class Qwiratry::IO::Parse::XML is Qwiratry::IO::Parse::Base {

	method parse(Str $text --> Mu) {
		%(xml => $text)
	}
}
