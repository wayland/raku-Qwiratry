=begin pod

Minimal CSV parse/render format modules.

=end pod
unit module Qwiratry::IO::Parse::CSV;

our sub parse(Str $text --> Mu) is export {
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
