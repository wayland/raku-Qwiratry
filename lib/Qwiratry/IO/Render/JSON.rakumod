=begin pod

Minimal JSON render format module (no external dependencies).

=end pod
use Qwiratry::IO::Render::Base;

class Qwiratry::IO::Render::JSON is Qwiratry::IO::Render::Base {

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
