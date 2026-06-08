=begin pod

Minimal XML render format module.

=end pod
unit module Qwiratry::IO::Render::XML;

our sub render(Mu $data, Associative :%options --> Str) is export {
    if $data ~~ Associative && $data<xml>:exists {
        return ~$data<xml>;
    }
    "<data>{$data.raku}</data>"
}
