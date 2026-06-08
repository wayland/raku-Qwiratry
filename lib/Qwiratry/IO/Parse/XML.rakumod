=begin pod

Minimal XML parse format module (string wrapper for round-trip tests).

=end pod
unit module Qwiratry::IO::Parse::XML;

our sub parse(Str $text --> Mu) is export {
    %(xml => $text)
}
