=begin pod

Minimal JSON format module (no external dependencies).

Defines C<Qwiratry::Format::JSON::Parse> and C<Qwiratry::Format::JSON::Render>
implementations loaded through L<Qwiratry::Format.make>.

=end pod
use Qwiratry::Format::Base;

class Qwiratry::Format::JSON::Parse is Qwiratry::Format::Base::Parse {

	method parse(Str $input-string --> Mu) {
		my ($value, $pos) = self.parse-value($input-string.trim, 0);
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

class Qwiratry::Format::JSON::Render is Qwiratry::Format::Base::Render {

	method render(Mu $data, Associative :%options --> Str) {
		my $pretty = %options<pretty> // False;
		self.to-json-text($data, $pretty, 0)
	}

	method to-json-text($value, Bool $pretty, Int $indent --> Str) {
		return 'null' unless $value.defined;
		if $value ~~ Str {
			my $escaped = $value;
			$escaped = $escaped.subst(/[\x22]/, '\\"', :g);
			$escaped = $escaped.subst(/\\/, '\\\\', :g);
			$escaped = $escaped.subst(/\n/, '\\n', :g);
			$escaped = $escaped.subst(/\t/, '\\t', :g);
			return q["] ~ $escaped ~ q["];
		}
		return $value.raku if $value ~~ Bool || $value ~~ Int || $value ~~ Num;

		if $value ~~ Associative {
			my @pairs = $value.pairs.sort(*.key);
			return '{}' unless @pairs;
			my $pad = $pretty ?? ' ' x ($indent + 2) !! '';
			my $sep = $pretty ?? (",\n") !! ',';
			my $inner = @pairs.map(-> $p {
				($pretty ?? $pad !! '') ~ self.to-json-text(~$p.key, False, 0) ~ ': '
					~ self.to-json-text($p.value, $pretty, $indent + 2)
			}).join($sep);
			return $pretty ?? ('{' ~ "\n" ~ $inner ~ "\n" ~ (' ' x $indent) ~ '}')
				!! ('{' ~ $inner ~ '}');
		}

		if $value ~~ Positional {
			return '[]' unless $value.elems;
			my $pad = $pretty ?? ' ' x ($indent + 2) !! '';
			my $sep = $pretty ?? (",\n") !! ',';
			my $inner = $value.map({
				($pretty ?? $pad !! '') ~ self.to-json-text($_, $pretty, $indent + 2)
			}).join($sep);
			return $pretty ?? ('[' ~ "\n" ~ $inner ~ "\n" ~ (' ' x $indent) ~ ']')
				!! ('[' ~ $inner ~ ']');
		}

		$value.raku
	}
}
