=begin pod

=head1 Overview

Minimal JSON demo format module (no external dependencies).

Defines C<Qwiratry::Format::JSONdemo::Parse> and C<Qwiratry::Format::JSONdemo::Render>
implementations loaded through L<Qwiratry::Format.make>.

This backend exists so source/parse/render/destination pipelines can run in a
fresh checkout without pulling in a JSON library. The parser lowers JSON objects
to hashes, arrays to arrays, strings to C<Str>, numbers to C<Int> or C<Num>, and
JSON literals to Raku booleans or C<Nil>.

The renderer performs the inverse for ordinary Raku scalar, positional, and
associative values. It supports a C<:pretty> option for multi-line output.

=end pod
use Qwiratry::Format::Base;

grammar Qwiratry::Format::JSONdemo::Grammar {
	token TOP { ^ \s* <value> \s* $ }
	token value { <object> | <array> | <string> | <number> | <literal> }
	token object { '{' \s* [ <pair>* % [ \s* ',' \s* ] ]? \s* '}' }
	token pair { <string> \s* ':' \s* <value> }
	token array { '[' \s* [ <value>* % [ \s* ',' \s* ] ]? \s* ']' }
	token string { '"' <string-char>* '"' }
	token string-char { '\\' <escape> | <-["\\]> }
	token escape { '"' | '\\' | '/' | 'b' | 'f' | 'n' | 'r' | 't' }
	token number { '-'? [ '0' | <[1..9]> <[0..9]>* ] [ '.' <[0..9]>+ ]? [ <[eE]> <[+\-]>? <[0..9]>+ ]? }
	token literal { 'true' | 'false' | 'null' }
}

class Qwiratry::Format::JSONdemo::Actions {
	method TOP($/) {
		make $<value>.made
	}

	method value($/) {
		make ($<object> // $<array> // $<string> // $<number> // $<literal>).made
	}

	method object($/) {
		my %object;
		for $<pair> -> $pair {
			my ($key, $value) = $pair.made;
			%object{$key} = $value;
		}
		make %object
	}

	method pair($/) {
		make ($<string>.made, $<value>.made)
	}

	method array($/) {
		make $<value>.map(*.made).Array
	}

	method string($/) {
		make $<string-char>.map(*.made).join
	}

	method string-char($/) {
		if $<escape> {
			make do given ~$<escape> {
				when 'n' { "\n" }
				when 't' { "\t" }
				when 'r' { "\r" }
				when 'b' { "\b" }
				when 'f' { "\f" }
				when '"' { '"' }
				when '\\' { '\\' }
				when '/' { '/' }
				default { ~$<escape> }
			}
		}
		else {
			make ~$/
		}
	}

	method number($/) {
		my $text = ~$/.Str;
		make $text ~~ /<[.eE]>/ ?? $text.Num !! $text.Int
	}

	method literal($/) {
		make do given ~$/ {
			when 'true' { True }
			when 'false' { False }
			default { Nil }
		}
	}
}

class Qwiratry::Format::JSONdemo::Parse is Qwiratry::Format::Base::Parse {

	=begin pod

	=head1 Methods

	=head2 C<parse(Str $input-string)>

	=begin code
	method parse(Str $input-string --> Mu)
	=end code

	=head3 Parameters

	=item C<$input-string>

	 The external text to parse into Qwiratry data.


	Parses JSONdemo text into Raku data.

	Invalid input dies with a concise demo-format error. The caller is typically
	an adaptor pipeline, so higher layers decide whether to wrap that exception in
	a user-facing diagnostic.

	=end pod
	method parse(Str $input-string --> Mu) {
		my $match = Qwiratry::Format::JSONdemo::Grammar.parse(
			$input-string,
			:actions(Qwiratry::Format::JSONdemo::Actions.new),
		);
		die "Invalid JSONdemo input" unless $match;
		$match.made
	}
}

class Qwiratry::Format::JSONdemo::Render is Qwiratry::Format::Base::Render {

	=begin pod

	=head2 C<render(Mu $data, Associative :%options)>

	=begin code
	method render(Mu $data, Associative :%options --> Str)
	=end code

	=head3 Parameters

	=item C<$data>

	 The input data, root value, or rendered value handled by this operation.

	=item C<%options>

	 Named format options, such as rendering preferences.


	Renders Raku data to JSONdemo text.

	C<%options<pretty>> enables indentation. Other options are ignored, keeping
	the demo renderer small while preserving the common format-backend signature.

	=end pod
	method render(Mu $data, Associative :%options --> Str) {
		my $pretty = %options<pretty> // False;
		self.to-json-text($data, $pretty, 0)
	}

	method to-json-text($value, Bool $pretty, Int $indent --> Str) {
		$value.defined or return 'null';
		if $value ~~ Str {
			my $escaped = $value;
			$escaped = $escaped.subst(/[\x22]/, '\\"', :g);
			$escaped = $escaped.subst(/\\/, '\\\\', :g);
			$escaped = $escaped.subst(/\n/, '\\n', :g);
			$escaped = $escaped.subst(/\t/, '\\t', :g);
			return q["] ~ $escaped ~ q["];
		}
		$value ~~ Bool || $value ~~ Int || $value ~~ Num and return $value.raku;

		if $value ~~ Associative {
			my @pairs = $value.pairs.sort(*.key);
			@pairs or return '{}';
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
			$value.elems or return '[]';
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
