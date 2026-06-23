=begin pod

Shared selector normalization and matching for query evaluation.

Centralizes wildcard detection, path normalization, and node/row matching used by
L<Qwiratry::Query::Runtime>, L<Qwiratry::Query::Specificity>, and
L<Qwiratry::Table::Catalog> navigation.

=end pod
class Qwiratry::Query::Selector {

	my $instance;

	=begin pod

	Return the shared Selector service instance.

	=end pod
	method instance(--> Qwiratry::Query::Selector) {
		$instance //= self.new
	}

	=begin pod

	Return True for wildcard selectors (C<*>, C<**>, C<Whatever>).

	=end pod
	method is-wildcard(Mu $selector --> Bool) {
		$selector ~~ Whatever and return True;
		$selector ~~ Str && $selector eq any(<* **>) and return True;
		False
	}

	=begin pod

	Return True for non-wildcard string or Callable selectors.

	=end pod
	method is-explicit-path(Mu $selector --> Bool) {
		$selector.defined or return False;
		self.is-wildcard($selector) and return False;
		$selector ~~ Str && $selector.chars > 0 and return True;
		$selector ~~ Callable and return True;
		False
	}

	=begin pod

	Normalize key, list, or scalar to a string column name.

	=end pod
	method normalize-key(Mu $key --> Str) {
		$key ~~ Str and return $key;
		if $key ~~ List && $key.elems == 1 {
			return self.normalize-key($key[0]);
		}
		~$key
	}

	=begin pod

	Strip angle brackets from selector strings.

	=end pod
	method normalize-name(Str $selector --> Str) {
		# Strip one enclosing pair of angle brackets, if present.
		$selector ~~ S/^ '<' (.*) '>' $/$0/
	}

	=begin pod

	Return True when a table row matches a child/sibling column selector.

	=end pod
	method table-row-matches(Associative $row, Mu $selector --> Bool) {
		self.is-wildcard($selector) and return True;
		if $selector ~~ Str {
			my $col = self.normalize-name($selector);
			return $row{$col}:exists;
		}
		False
	}

	=begin pod

	Return True when C<$node> matches a navigation selector.

	=end pod
	method matches(Mu $selector, Mu $node --> Bool) {
		self.is-wildcard($selector) and return True;
		if $selector ~~ List {
			$selector.grep({ self.matches($_, $node) }).so and return True;
			return False;
		}
		if $selector ~~ Str {
			my $name = self.node-name($node);
			return $name.defined && $name eq self.normalize-name($selector);
		}
		False
	}

	=begin pod

	Resolve a display name from a tree or table node.

	=end pod
	method node-name(Mu $node --> Mu) {
		$node ~~ Str and return $node;
		if $node ~~ Associative {
			for <name tag type> -> $field {
				$node{$field}:exists and return ~($node{$field});
			}
		}
		Nil
	}
}
