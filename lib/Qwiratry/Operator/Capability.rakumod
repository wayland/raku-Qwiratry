=begin pod

Capability roles for operator-walker compatibility checking.

Operators implement capability roles to declare navigation, map-reduce, set, or I/O
support. Walkers use C<capabilities()> metadata during C<supports()> checks.

=end pod
unit module Qwiratry::Operator::Capability;

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

Marks an operator as a navigation query (tree, table, or graph axes).

=end pod
role NavigationOperator is export {
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
role MapReduceOperator is export {
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
role SetOperator is export {
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

Marks an operator as part of an I/O pipeline (source, parse, render, destination).

=end pod
role IOOperator is export {
	=begin pod

	Declare I/O support and the set of data formats available for parse/render.

	=end pod
	method capabilities(--> Associative) {
		{
			io => True,
			formats => ['json', 'xml', 'csv'],
			lazy => False,
		}
	}
}
