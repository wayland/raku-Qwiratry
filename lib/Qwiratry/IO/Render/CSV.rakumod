=begin pod

CSV render format module.

=end pod
use Qwiratry::IO::Render::Base;

unit class Qwiratry::IO::Render::CSV is Qwiratry::IO::Render::Base;

method render(Mu $data, Associative :%options --> Str) {
	my @rows = $data ~~ Positional ?? $data.list !! ($data,);
	return '' unless @rows;
	my @headers = @rows[0].keys.sort;
	my @lines = (@headers.join(','));
	for @rows -> $row {
		@lines.push((@headers.map({ ~($row{$_} // '') })).join(','));
	}
	@lines.join("\n")
}

our sub render(Mu $data, Associative :%options --> Str) is export {
	Qwiratry::IO::Render::CSV.new.render($data, :%options)
}
