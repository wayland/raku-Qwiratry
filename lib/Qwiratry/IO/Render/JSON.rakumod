=begin pod

Minimal JSON render format module (no external dependencies).

=end pod
unit module Qwiratry::IO::Render::JSON;

our sub render(Mu $data, Associative :%options --> Str) is export {
	my $pretty = %options<pretty> // False;
	to-json-text($data, $pretty, 0)
}

sub to-json-text($value, Bool $pretty, Int $indent --> Str) {
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
			($pretty ?? $pad !! '') ~ to-json-text(~$p.key, False, 0) ~ ': '
				~ to-json-text($p.value, $pretty, $indent + 2)
		}).join($sep);
		return $pretty ?? ('{' ~ "\n" ~ $inner ~ "\n" ~ (' ' x $indent) ~ '}')
			!! ('{' ~ $inner ~ '}');
	}

	if $value ~~ Positional {
		return '[]' unless $value.elems;
		my $pad = $pretty ?? ' ' x ($indent + 2) !! '';
		my $sep = $pretty ?? (",\n") !! ',';
		my $inner = $value.map({
			($pretty ?? $pad !! '') ~ to-json-text($_, $pretty, $indent + 2)
		}).join($sep);
		return $pretty ?? ('[' ~ "\n" ~ $inner ~ "\n" ~ (' ' x $indent) ~ ']')
			!! ('[' ~ $inner ~ ']');
	}

	$value.raku
}
