=begin pod

Capability roles for operator-walker compatibility checking.

Operators implement capability roles to declare navigation, map-reduce, set, or I/O
support. Walkers use C<capabilities()> metadata during C<supports()> checks.

=end pod
unit module Qwiratry::Operator::Capability;

role OperatorBase is export {
	method describe(--> Str) {
		self.^name
	}
}

role NavigationOperator is export {
	method capabilities(--> Associative) {
		{
			navigation => True,
			domains => ['tree', 'table', 'graph'],
			lazy => True,
		}
	}
}

role MapReduceOperator is export {
	method capabilities(--> Associative) {
		{
			'map-reduce' => True,
			lazy => True,
		}
	}
}

role SetOperator is export {
	method capabilities(--> Associative) {
		{
			'set-operation' => True,
			relational => True,
			lazy => True,
		}
	}
}

role IOOperator is export {
	method capabilities(--> Associative) {
		{
			io => True,
			formats => ['json', 'xml', 'csv'],
			lazy => False,
		}
	}
}
