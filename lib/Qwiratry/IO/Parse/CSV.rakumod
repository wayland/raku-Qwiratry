=begin pod

Minimal CSV parse format module.

=end pod
use Qwiratry::IO::Parse::Base;

unit class Qwiratry::IO::Parse::CSV is Qwiratry::IO::Parse::Base;

method parse(Str $text --> Mu) {
	my @lines = $text.lines.grep(*.chars);
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

our sub parse(Str $text --> Mu) is export {
	Qwiratry::IO::Parse::CSV.new.parse($text)
}
