=begin pod

=head1 Overview

NDJSON (newline-delimited JSON) demo format module.

Defines C<Qwiratry::Format::NDJSONdemo::Parse> and
C<Qwiratry::Format::NDJSONdemo::Render>, loaded through L<Qwiratry::Format.make>.

Each non-empty line is one JSON value. Parsing and rendering reuse the
dependency-free L<Qwiratry::Format::JSONdemo> grammar and renderer for single
values. Both sides also implement the optional streaming capabilities from
L<Qwiratry::Format::Base>, so adaptor pipelines can stay incremental end to end.

=end pod
use Qwiratry::Format::Base;
use Qwiratry::Format::JSONdemo;

class Qwiratry::Format::NDJSONdemo::ChunkParseIterator does Iterator {
	has Iterator $.chunks is required;
	has $.json-parse is required;
	has Str $!buffer = '';

	method pull-one() {
		loop {
			if $!buffer.contains("\n") {
				my $idx = $!buffer.index("\n");
				my $line = $!buffer.substr(0, $idx);
				$!buffer = $!buffer.substr($idx + 1);
				my $trimmed = $line.trim;
				next unless $trimmed.chars;
				return $!json-parse.parse-walkable($trimmed);
			}
			my $chunk := $!chunks.pull-one;
			if $chunk =:= IterationEnd {
				my $trimmed = $!buffer.trim;
				$!buffer = '';
				return $trimmed.chars ?? $!json-parse.parse-walkable($trimmed) !! IterationEnd;
			}
			$!buffer ~= $chunk.Str;
		}
	}
}

class Qwiratry::Format::NDJSONdemo::Parse
	is Qwiratry::Format::Base::ParseWalkable
	does Qwiratry::Format::Base::ParsePull
{
	has $!json-parse = Qwiratry::Format::JSONdemo::Parse.new;

	=begin pod

	=head1 Methods

	=head2 C<parse-walkable(Str $input-string)>

	=begin code
	method parse-walkable(Str $input-string --> Mu)
	=end code

	Parses NDJSON text into an array of Raku values (one per non-empty line).

	=end pod
	method parse-walkable(Str $input-string --> Mu) {
		my @rows;
		for $input-string.lines -> $line {
			my $trimmed = $line.trim;
			next unless $trimmed.chars;
			@rows.push($!json-parse.parse-walkable($trimmed));
		}
		@rows
	}

	=begin pod

	=head2 C<parse-pull(Iterator:D $chunks, *%options)>

	=begin code
	method parse-pull(Iterator:D $chunks, *%options --> Mu)
	=end code

	Parses a pull stream of text chunks into a lazy C<Seq> of top-level values.

	Chunks may split mid-line; incomplete trailing text is buffered until a
	newline arrives. A final non-empty unterminated line is emitted at end of
	stream.

	=end pod
	method parse-pull(Iterator:D $chunks, *%options --> Mu) {
		Seq.new(Qwiratry::Format::NDJSONdemo::ChunkParseIterator.new(
			:chunks($chunks),
			:json-parse($!json-parse),
		))
	}
}

class Qwiratry::Format::NDJSONdemo::Render
	is Qwiratry::Format::Base::RenderWalkable
	does Qwiratry::Format::Base::RenderPull
{
	has $!json-render = Qwiratry::Format::JSONdemo::Render.new;

	=begin pod

	=head2 C<render-walkable(Mu $data, Associative :%options)>

	=begin code
	method render-walkable(Mu $data, Associative :%options --> Str)
	=end code

	Renders a positional collection (or single value) as NDJSON text.

	Each top-level value becomes one JSON line terminated by a newline.

	=end pod
	method render-walkable(Mu $data, Associative :%options --> Str) {
		my @values = $data ~~ Positional | Seq ?? $data.list !! ($data,);
		@values.map({ $!json-render.render-walkable($_, |%options) ~ "\n" }).join
	}

	=begin pod

	=head2 C<render-pull(Mu $data, Associative :%options)>

	=begin code
	method render-pull(Mu $data, Associative :%options --> Iterator:D)
	=end code

	Renders data as a pull iterator of NDJSON line chunks without forcing a lazy
	C<Seq> into a list first.

	=end pod
	method render-pull(Mu $data, Associative :%options --> Iterator:D) {
		my $json-render = $!json-render;
		my $options = %options;
		my $source = do {
			if $data ~~ Iterator {
				$data
			}
			elsif $data ~~ Seq {
				$data.iterator
			}
			elsif $data ~~ Positional {
				$data.iterator
			}
			else {
				($data,).iterator
			}
		};
		Seq.from-loop({
			my $item := $source.pull-one;
			$item =:= IterationEnd
				?? IterationEnd
				!! ($json-render.render-walkable($item, |%$options) ~ "\n")
		}).iterator
	}
}
