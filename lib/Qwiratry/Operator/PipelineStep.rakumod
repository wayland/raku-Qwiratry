=begin pod

Pipeline evaluation for operator AST nodes.

L<PipelineStep> provides the default C<evaluate> path (resolve root, C<select>,
materialize). Capability roles compose it; I/O operator classes override C<evaluate>.
C<execute> is the recursive entry point that dispatches to C<evaluate>.

=end pod
unit module Qwiratry::Operator::PipelineStep;

use Qwiratry::IO::Parse;
use Qwiratry::IO::Render;
use Qwiratry::Exception::Operator;

=begin pod

Default pipeline step for query operators: resolve data root, run C<select>, materialize.

=end pod
role PipelineStep is export {
	=begin pod

	Evaluate this operator node in a pipeline context.

	=end pod
	method evaluate(Mu :$origin, :&execute) {
		my $root = pipeline-root(self, $origin, :&execute);
		require Qwiratry::Query::Match;
		seq-to-pipeline-value(Qwiratry::Query::Match::select(self, $root))
	}
}

=begin pod

Recursively evaluate an operator AST node and return the pipeline result.

Delegates to each operator's C<evaluate> method.

=end pod
our sub execute(Mu $op, Mu :$origin) is export {
	return $op.evaluate(:$origin, :&execute) if $op.can('evaluate');
	$op
}

=begin pod

Resolve the data root for a query operator by walking C<subject> links leftward.

=end pod
our sub pipeline-root(Mu $op, Mu $origin, :&execute --> Mu) is export {
	if $op.can('subject') && $op.subject.defined {
		return execute($op.subject, :$origin) if is-io-operator($op.subject);
		return pipeline-root($op.subject, $origin, :&execute) if $op.subject.can('subject');
		return $op.subject;
	}
	$origin // $op
}

sub is-io-operator(Mu $subject --> Bool) {
	so $subject.^roles.map(*.^name).grep(*.ends-with('IOOperator'))
}

=begin pod

Read text from a file location. Throws L<X::Qwiratry::IO::LocationError> for
network URLs or missing files.

=end pod
our sub read-location(Str $location --> Str) is export {
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
our sub write-location(Str $location, Mu $content) is export {
	my $text = $content ~~ Str ?? $content !! ~$content;
	my $path = $location;
	$path.IO.parent.mkdir unless $path.IO.parent.d;
	spurt $path, $text
}

=begin pod

Parse external text via L<Qwiratry::IO::Parse>.

=end pod
our sub parse-data(Str $format, Str $text) is export {
	Qwiratry::IO::Parse.instance.parse($format, $text)
}

=begin pod

Render in-memory data via L<Qwiratry::IO::Render>.

=end pod
our sub render-data(Str $format, Mu $data, Associative $options) is export {
	Qwiratry::IO::Render.instance.render($format, pipeline-render-payload($data), |%($options // %()))
}

=begin pod

Normalize lazy C<Seq> results from C<select> into a plain list for rendering.

=end pod
our sub pipeline-render-payload(Mu $data --> Mu) is export {
	return $data.list if $data ~~ Seq;
	$data
}

=begin pod

Materialize a C<Seq> from C<select>: empty, singleton, or list (never a bare Seq).

=end pod
our sub seq-to-pipeline-value(Seq $seq --> Mu) is export {
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
