=begin pod

Minimal JSON parse format module (no external dependencies).

=end pod
unit module Qwiratry::IO::Parse::JSON;

our sub parse(Str $text --> Mu) is export {
	my ($value, $pos) = parse-value($text.trim, 0);
	$value
}

sub parse-value(Str $s, Int $pos is copy) {
	$pos = skip-ws($s, $pos);
	my $c = $s.substr($pos, 1);
	given $c {
		when '{' { parse-object($s, $pos) }
		when '[' { parse-array($s, $pos) }
		when '"' { parse-string($s, $pos) }
		when 't' { parse-literal($s, $pos, 'true', True) }
		when 'f' { parse-literal($s, $pos, 'false', False) }
		when 'n' { parse-literal($s, $pos, 'null', Nil) }
		default { parse-number($s, $pos) }
	}
}

sub skip-ws(Str $s, Int $pos is copy) {
	while $pos < $s.chars && $s.substr($pos, 1) ~~ /\s/ { $pos++ }
	$pos
}

sub parse-object(Str $s, Int $pos is copy) {
	$pos++;
	$pos = skip-ws($s, $pos);
	return (%(), $pos + 1) if $s.substr($pos, 1) eq '}';
	my %obj;
	loop {
		my ($key, $p1) = parse-string($s, $pos);
		$pos = skip-ws($s, $p1);
		die "Expected :" unless $s.substr($pos, 1) eq ':';
		$pos = skip-ws($s, $pos + 1);
		my ($value, $p2) = parse-value($s, $pos);
		%obj{$key} = $value;
		$pos = skip-ws($s, $p2);
		last if $s.substr($pos, 1) eq '}';
		die "Expected ," unless $s.substr($pos, 1) eq ',';
		$pos = skip-ws($s, $pos + 1);
	}
	(%obj, $pos + 1)
}

sub parse-array(Str $s, Int $pos is copy) {
	$pos++;
	$pos = skip-ws($s, $pos);
	return (@(), $pos + 1) if $s.substr($pos, 1) eq ']';
	my @arr;
	loop {
		my ($value, $p1) = parse-value($s, $pos);
		@arr.push($value);
		$pos = skip-ws($s, $p1);
		last if $s.substr($pos, 1) eq ']';
		die "Expected ," unless $s.substr($pos, 1) eq ',';
		$pos = skip-ws($s, $pos + 1);
	}
	(@arr, $pos + 1)
}

sub parse-string(Str $s, Int $pos is copy) {
	$pos++;
	my $buf = '';
	while $pos < $s.chars {
		my $c = $s.substr($pos, 1);
		if $c eq '"' {
			return ($buf, $pos + 1);
		}
		if $c eq '\\' {
			$pos++;
			my $esc = $s.substr($pos, 1);
			$buf ~= do given $esc {
				when 'n' { "\n" }
				when 't' { "\t" }
				when 'r' { "\r" }
				when '"' { '"' }
				when '\\' { '\\' }
				default { $esc }
			};
		}
		else {
			$buf ~= $c;
		}
		$pos++;
	}
	die "Unterminated JSON string";
}

sub parse-literal(Str $s, Int $pos, Str $word, Mu $value) {
	die "Invalid JSON literal" unless $s.substr($pos, $word.chars) eq $word;
	($value, $pos + $word.chars)
}

sub parse-number(Str $s, Int $pos is copy) {
	my $start = $pos;
	while $pos < $s.chars && $s.substr($pos, 1) ~~ /<[0..9 . e E + -]>/ { $pos++ }
	my $num-str = $s.substr($start, $pos - $start);
	my $value = $num-str.contains('.') ?? $num-str.Num !! $num-str.Int;
	($value, $pos)
}
