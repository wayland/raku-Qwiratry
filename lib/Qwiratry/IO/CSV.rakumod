=begin pod

CSV format module.

Defines C<Qwiratry::IO::CSV::Parse> and C<Qwiratry::IO::CSV::Render>
implementations loaded through L<Qwiratry::IO.make>.

=end pod
use Qwiratry::IO::Base::Parse;
use Qwiratry::IO::Base::Render;

class Qwiratry::IO::CSV::Parse is Qwiratry::IO::Base::Parse {

	method parse(Str $input-string --> Mu) {
		my @lines = $input-string.lines.grep(*.chars);
		return @() unless @lines;
		my @headers = @lines[0].split(',', :trim);
		my @rows;
		for @lines[1..*] -> $line {
			my @values = $line.split(',', :trim);
			my %row;
			for @headers.kv -> $i, $header {
				%row{$header} = @values[$i] // '';
			}
			@rows.push(%row);
		}
		@rows
	}
}

class Qwiratry::IO::CSV::Render is Qwiratry::IO::Base::Render {

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
}
