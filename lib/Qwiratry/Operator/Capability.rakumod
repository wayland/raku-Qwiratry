=begin pod

Capability roles for operator-walker compatibility checking, and default pipeline evaluation for query operators.

Operators implement capability roles to declare navigation, map-reduce, set, or adaptor
support. Walkers use C<capabilities()> metadata during C<supports()> checks.
C<execute> is the recursive entry point that dispatches to each operator's
C<evaluate> method.

=end pod
unit module Qwiratry::Operator::Capability;

use Qwiratry::Format;
use Qwiratry::Location;

=begin pod

Base capability role mixed into all operator AST nodes.

=end pod
role OperatorBase is export {
	=begin pod

	Return a short human-readable label for this operator (defaults to the class name).

	=end pod
	method describe(--> Str) {
		self.^name
	}
}

=begin pod

Marks an operator node as chaining from an optional upstream subject.

=end pod
role ChainedOperator is export {
	has Mu $.subject is built;

	=begin pod

	Return the standard subject fragment used in operator debug labels.

	=end pod
	method subject-description(--> Str) {
		$.subject.defined ?? " subject={$.subject.^name}" !! ''
	}
}

=begin pod

Marks an operator that has a lazy evaluator registered in C<Qwiratry::Query::Match>.

=end pod
role LazyEvaluatedOperator is export {
	method evaluation-mode(--> Str) { 'lazy' }
	method evaluator-key(--> Str) { self.^shortname }
}

=begin pod

Marks an operator intentionally handled by eager query matching.

=end pod
role EagerEvaluatedOperator is export {
	method evaluation-mode(--> Str) { 'eager' }
	method evaluator-key(--> Str) { self.^shortname }
}

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

Marks an operator as a navigation query (tree, table, or graph axes).

=end pod
role NavigationOperator does PipelineStep is export {
	=begin pod

	Declare navigation support and supported domains for walker matching.

	=end pod
	method capabilities(--> Associative) {
		{
			navigation => True,
			domains => ['tree', 'table', 'graph'],
			lazy => True,
		}
	}
}

=begin pod

Marks an operator as map, reduce, sort, or selection (relational algebra on streams).

=end pod
role MapReduceOperator does PipelineStep is export {
	=begin pod

	Declare map-reduce and lazy-evaluation support.

	=end pod
	method capabilities(--> Associative) {
		{
			'map-reduce' => True,
			lazy => True,
		}
	}
}

=begin pod

Marks an operator as a set or join operation over relations.

=end pod
role SetOperator does PipelineStep is export {
	=begin pod

	Declare set-operation and relational-algebra support.

	=end pod
	method capabilities(--> Associative) {
		{
			'set-operation' => True,
			relational => True,
			lazy => True,
		}
	}
}

=begin pod

Marks an operator as part of an adaptor pipeline (source, parse, render, destination).

=end pod
role AdaptorOperator does PipelineStep is export {
	=begin pod

	Declare adaptor support shared by format and location operators.

	=end pod
	method adaptor-capabilities(--> Associative) {
		{
			adaptor => True,
			lazy => False,
		}
	}

	method capabilities(--> Associative) {
		self.adaptor-capabilities
	}
}

=begin pod

Marks an operator as a parse/render adaptor backed by format implementations.

=end pod
role FormatOperator does AdaptorOperator is export {
	=begin pod

	Declare format adaptor support and discoverable parse/render formats.

	=end pod
	method capabilities(--> Associative) {
		%(
			|self.adaptor-capabilities,
			format => True,
			formats => (
				|Qwiratry::Format.formats(:type<Parse>),
				|Qwiratry::Format.formats(:type<Render>),
			).unique.sort.map(*.lc).Array,
		)
	}
}

=begin pod

Marks an operator as a source/destination adaptor backed by location implementations.

=end pod
role LocationOperator does AdaptorOperator is export {
	=begin pod

	Declare location adaptor support and discoverable source/destination backends.

	=end pod
	method capabilities(--> Associative) {
		%(
			|self.adaptor-capabilities,
			location => True,
			'source-backends' => Qwiratry::Location.backends(:type<Source>).map(*.lc).Array,
			'destination-backends' => Qwiratry::Location.backends(:type<Destination>).map(*.lc).Array,
		)
	}
}

# A few subs that help PipelineStep evaluate operators.

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
sub pipeline-root(Mu $op, Mu $origin, :&execute --> Mu) {
	if $op.can('subject') && $op.subject.defined {
		$op.subject ~~ AdaptorOperator and return execute($op.subject, :$origin);
		$op.subject.can('subject') and return pipeline-root($op.subject, $origin, :&execute);
		return $op.subject;
	}
	$origin // $op
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