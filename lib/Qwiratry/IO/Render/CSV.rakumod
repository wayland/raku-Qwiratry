=begin pod

CSV render format module.

=end pod
unit module Qwiratry::IO::Render::CSV;

our sub render(Mu $data, Associative :%options --> Str) is export {
    my @rows = $data ~~ Positional ?? $data.list !! ($data,);
    return '' unless @rows;
    my @headers = @rows[0].keys.sort;
    my @lines = (@headers.join(','));
    for @rows -> $row {
        @lines.push((@headers.map({ ~($row{$_} // '') })).join(','));
    }
    @lines.join("\n")
}
