=begin pod

=head1 Overview

CSV demo format module.

Defines C<Qwiratry::Format::CSVdemo::Parse> and C<Qwiratry::Format::CSVdemo::Render>
implementations loaded through L<Qwiratry::Format.make>.

This is a small built-in format for exercising adaptor pipelines without
external dependencies. It treats the first non-empty line as headers, parses
following lines into hashes keyed by those headers, and renders a positional
collection of associative rows back to comma-separated text.

The implementation intentionally covers a modest CSV subset: quoted fields,
escaped double quotes, bare fields, and blank-line skipping. It is a demo backend
rather than a complete RFC 4180 implementation.

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

	=begin pod

	=head1 Methods

	=head2 C<parse(Str $input-string)>

	=begin code
	method parse(Str $input-string --> Mu)
	=end code

	=head3 Parameters

	=item C<$input-string>

	 The external text to parse into Qwiratry data.


	Parses CSVdemo text into an array of row hashes.

	The first parsed record supplies column names. Each following record becomes
	an C<Associative> row; missing values are filled with empty strings so callers
	can rely on every header key existing.

	=end pod
	method parse(Str $input-string --> Mu) {
		my @lines = $input-string.lines.grep(*.chars);
		@lines or return @();
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

	# Parses one CSVdemo record into a list of field values.
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


	Renders row data to CSVdemo text.

	A single row is accepted, but positional data is the normal case. Headers are
	derived from the first row's keys and sorted for stable output.

	=end pod
	method render(Mu $data, Associative :%options --> Str) {
		my @rows = $data ~~ Positional ?? $data.list !! ($data,);
		@rows or return '';
		my @headers = @rows[0].keys.sort;
		my @lines = (@headers.join(','));
		for @rows -> $row {
			@lines.push((@headers.map({ ~($row{$_} // '') })).join(','));
		}
		@lines.join("\n")
	}
}
