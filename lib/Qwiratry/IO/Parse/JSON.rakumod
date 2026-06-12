=begin pod

Minimal JSON parse format module (no external dependencies).

=end pod
use Qwiratry::IO::Parse::Base;

class Qwiratry::IO::Parse::JSON is Qwiratry::IO::Parse::Base {

	method parse(Str $text --> Mu) {
		my ($value, $pos) = self.parse-value($text.trim, 0);
		$value
	}

	method parse-value(Str $s, Int $pos is copy) {
		$pos = self.skip-ws($s, $pos);
		my $c = $s.substr($pos, 1);
		given $c {
			when '{' { self.parse-object($s, $pos) }
			when '[' { self.parse-array($s, $pos) }
			when '"' { self.parse-string($s, $pos) }
			when 't' { self.parse-literal($s, $pos, 'true', True) }
			when 'f' { self.parse-literal($s, $pos, 'false', False) }
			when 'n' { self.parse-literal($s, $pos, 'null', Nil) }
			default { self.parse-number($s, $pos) }
		}
	}

	method skip-ws(Str $s, Int $pos is copy) {
		while $pos < $s.chars && $s.substr($pos, 1) ~~ /\s/ { $pos++ }
		$pos
	}

	method parse-object(Str $s, Int $pos is copy) {
		$pos++;
		$pos = self.skip-ws($s, $pos);
		return (%(), $pos + 1) if $s.substr($pos, 1) eq '}';
		my %obj;
		loop {
			my ($key, $p1) = self.parse-string($s, $pos);
			$pos = self.skip-ws($s, $p1);
			die "Expected :" unless $s.substr($pos, 1) eq ':';
			$pos = self.skip-ws($s, $pos + 1);
			my ($value, $p2) = self.parse-value($s, $pos);
			%obj{$key} = $value;
			$pos = self.skip-ws($s, $p2);
			last if $s.substr($pos, 1) eq '}';
			die "Expected ," unless $s.substr($pos, 1) eq ',';
			$pos = self.skip-ws($s, $pos + 1);
		}
		(%obj, $pos + 1)
	}

	method parse-array(Str $s, Int $pos is copy) {
		$pos++;
		$pos = self.skip-ws($s, $pos);
		return (@(), $pos + 1) if $s.substr($pos, 1) eq ']';
		my @arr;
		loop {
			my ($value, $p1) = self.parse-value($s, $pos);
			@arr.push($value);
			$pos = self.skip-ws($s, $p1);
			last if $s.substr($pos, 1) eq ']';
			die "Expected ," unless $s.substr($pos, 1) eq ',';
			$pos = self.skip-ws($s, $pos + 1);
		}
		(@arr, $pos + 1)
	}

	method parse-string(Str $s, Int $pos is copy) {
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

	method parse-literal(Str $s, Int $pos, Str $word, Mu $value) {
		die "Invalid JSON literal" unless $s.substr($pos, $word.chars) eq $word;
		($value, $pos + $word.chars)
	}

	method parse-number(Str $s, Int $pos is copy) {
		my $start = $pos;
		while $pos < $s.chars && $s.substr($pos, 1) ~~ /<[0..9 . e E + -]>/ { $pos++ }
		my $num-str = $s.substr($start, $pos - $start);
		my $value = $num-str.contains('.') ?? $num-str.Num !! $num-str.Int;
		($value, $pos)
	}
}
