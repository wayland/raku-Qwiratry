=begin pod

Execute I/O operator pipelines (source, parse, query, render, destination).

Walks a chain of L<Qwiratry::Operator::IO> AST nodes: reads files, parses and
renders via L<Qwiratry::IO::Parse> / L<Qwiratry::IO::Render>, runs query operators
through L<select|Qwiratry::Query::Match>, and writes results to disk.

=end pod
unit module Qwiratry::IO::Pipeline;

use Qwiratry::IO::Parse;
use Qwiratry::IO::Render;
use Qwiratry::Operator::IO;
use Qwiratry::Operator::Capability;
use Qwiratry::Operator::MapReduce;
use Qwiratry::Query::Match;
use Qwiratry::Exception::Operator;

=begin pod

Recursively evaluate an operator AST node and return the pipeline result.

I/O operators delegate to helpers; query operators call C<select> on the resolved root.

=end pod
our sub execute(Mu $op, Mu :$origin) is export {
	given $op {
		when DestinationOperator {
			my $content = execute($op.subject // $origin, :$origin);
			write-location($op.location, $content);
			$content
		}
		when RenderOperator {
			my $data = execute($op.subject // $origin, :$origin);
			render-data($op.format, $data, $op.options)
		}
		when ParseOperator {
			my $text = execute($op.subject // $origin, :$origin);
			parse-data($op.format, $text)
		}
		when SourceOperator {
			read-location($op.location)
		}
		when IOOperator | NavigationOperator | SetOperator | MapReduceOperator {
			my $root = pipeline-root($op, $origin);
			seq-to-pipeline-value(select($op, $root))
		}
		default {
			$op
		}
	}
}

=begin pod

Resolve the data root for a query operator by walking C<subject> links leftward.

=end pod
sub pipeline-root(Mu $op, Mu $origin --> Mu) {
	if $op.can('subject') && $op.subject.defined {
		return execute($op.subject, :$origin) if $op.subject ~~ IOOperator;
		return pipeline-root($op.subject, $origin) if $op.subject.can('subject');
		return $op.subject;
	}
	$origin // $op
}

=begin pod

Read text from a file location. Throws L<X::Qwiratry::IO::LocationError> for
network URLs or missing files.

=end pod
sub read-location(Str $location --> Str) {
	if $location.starts-with(any('http://', 'https://')) {
		X::Qwiratry::IO::LocationError.new(
			:message("Cannot fetch network location: $location"),
			:location($location),
			:reason('Network fetch not available in test environment'),
			:operator-type('SourceOperator'),
		).throw;
	}
	unless $location.IO.e {
		X::Qwiratry::IO::LocationError.new(
			:message("I/O location not found: $location"),
			:location($location),
			:reason('File not found'),
			:operator-type('SourceOperator'),
		).throw;
	}
	$location.IO.slurp
}

=begin pod

Write pipeline output to a file, creating parent directories when needed.

=end pod
sub write-location(Str $location, Mu $content) {
	my $text = $content ~~ Str ?? $content !! ~$content;
	my $path = $location;
	$path.IO.parent.mkdir unless $path.IO.parent.d;
	spurt $path, $text
}

=begin pod

Parse external text via L<Qwiratry::IO::Parse>.

=end pod
sub parse-data(Str $format, Str $text) {
	Qwiratry::IO::Parse.instance.parse($format, $text)
}

=begin pod

Render in-memory data via L<Qwiratry::IO::Render>.

=end pod
sub render-data(Str $format, Mu $data, Associative $options) {
	Qwiratry::IO::Render.instance.render($format, pipeline-render-payload($data), |%($options // %()))
}

=begin pod

Normalize lazy C<Seq> results from C<select> into a plain list for rendering.

=end pod
sub pipeline-render-payload(Mu $data --> Mu) {
	return $data.list if $data ~~ Seq;
	$data
}

=begin pod

Materialize a C<Seq> from C<select>: empty, singleton, or list (never a bare Seq).

=end pod
sub seq-to-pipeline-value(Seq $seq --> Mu) {
	my $iter = $seq.iterator;
	my $first = $iter.pull-one;
	return () if $first ~~ IterationEnd;
	my $second = $iter.pull-one;
	return $first if $second ~~ IterationEnd;
	gather {
		take $first;
		take $second;
		while (my $value = $iter.pull-one) !~~ IterationEnd {
			take $value;
		}
	}.List
}
