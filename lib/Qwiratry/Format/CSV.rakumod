=begin pod

CSV format module.

Defines C<Qwiratry::Format::CSV::Parse> and C<Qwiratry::Format::CSV::Render>
implementations loaded through L<Qwiratry::Format.make>.

=end pod
use Qwiratry::Format::Base;

class Qwiratry::Format::CSV::Parse is Qwiratry::Format::Base::Parse {

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

class Qwiratry::Format::CSV::Render is Qwiratry::Format::Base::Render {

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
