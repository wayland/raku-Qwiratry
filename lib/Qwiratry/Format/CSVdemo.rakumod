=begin pod

CSV demo format module.

Defines C<Qwiratry::Format::CSVdemo::Parse> and C<Qwiratry::Format::CSVdemo::Render>
implementations loaded through L<Qwiratry::Format.make>.

=end pod
use Qwiratry::Format::Base;

grammar Qwiratry::Format::CSVdemo::LineGrammar {
	token TOP { ^ <field>* % ',' $ }
	token field { <quoted> | <bare> }
	token quoted { '"' <quoted-char>* '"' }
	token quoted-char { '""' | <-["]> }
	token bare { <-[,"]>* }
}

class Qwiratry::Format::CSVdemo::LineActions {
	method TOP($/) {
		make $<field>.map(*.made).Array
	}

	method field($/) {
		make $<quoted> ?? $<quoted>.made !! $<bare>.made
	}

	method quoted($/) {
		make $<quoted-char>.map(*.made).join
	}

	method quoted-char($/) {
		make ~$/ eq '""' ?? '"' !! ~$/
	}

	method bare($/) {
		make (~$/).trim
	}
}

class Qwiratry::Format::CSVdemo::Parse is Qwiratry::Format::Base::Parse {

	method parse(Str $input-string --> Mu) {
		my @lines = $input-string.lines.grep(*.chars);
		return @() unless @lines;
		my @records = @lines.map({ self!parse-line($_) });
		my @headers = @records[0].Slip;
		my @rows;
		for @records[1..*] -> @values {
			my %row;
			for @headers.kv -> $i, $header {
				%row{$header} = @values[$i] // '';
			}
			@rows.push(%row);
		}
		@rows
	}

	method !parse-line(Str $line --> Array) {
		my $match = Qwiratry::Format::CSVdemo::LineGrammar.parse(
			$line,
			:actions(Qwiratry::Format::CSVdemo::LineActions.new),
		);
		die "Invalid CSVdemo line: $line" unless $match;
		$match.made
	}
}

class Qwiratry::Format::CSVdemo::Render is Qwiratry::Format::Base::Render {

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
