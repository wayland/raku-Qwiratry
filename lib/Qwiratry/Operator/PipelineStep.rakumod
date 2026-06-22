=begin pod

Pipeline evaluation for operator AST nodes.

L<PipelineStep> provides the default C<evaluate> path (resolve root, C<select>,
materialize). Capability roles compose it; I/O operator classes override C<evaluate>.
C<execute> is the recursive entry point that dispatches to C<evaluate>.

=end pod
unit module Qwiratry::Operator::PipelineStep;

use X::Qwiratry;

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
	$op.can('evaluate') and return $op.evaluate(:$origin, :&execute);
	$op
}

=begin pod

Resolve the data root for a query operator by walking C<subject> links leftward.

=end pod
our sub pipeline-root(Mu $op, Mu $origin, :&execute --> Mu) is export {
	if $op.can('subject') && $op.subject.defined {
		is-adaptor-operator($op.subject) and return execute($op.subject, :$origin);
		$op.subject.can('subject') and return pipeline-root($op.subject, $origin, :&execute);
		return $op.subject;
	}
	$origin // $op
}

sub is-adaptor-operator(Mu $subject --> Bool) {
	so $subject.^roles.map(*.^name).grep({ .contains(any('AdaptorOperator', 'FormatOperator', 'LocationOperator')) })
}

=begin pod

Materialize a C<Seq> from C<select>: empty, singleton, or list (never a bare Seq).

=end pod
our sub seq-to-pipeline-value(Seq $seq --> Mu) is export {
	my $iter = $seq.iterator;
	my $first = $iter.pull-one;
	$first ~~ IterationEnd and return ();
	my $second = $iter.pull-one;
	$second ~~ IterationEnd and return $first;
	gather {
		take $first;
		take $second;
		while (my $value = $iter.pull-one) !~~ IterationEnd {
			take $value;
		}
	}.List
}
