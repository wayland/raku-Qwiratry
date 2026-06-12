=begin pod

Shared selector normalization and matching for query evaluation.

Centralizes wildcard detection, path normalization, and node/row matching used by
L<Qwiratry::Query::Match>, L<Qwiratry::Query::Specificity>, and
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
		return True if $selector ~~ Whatever;
		return True if $selector ~~ Str && $selector eq any(<* **>);
		False
	}

	=begin pod

	Return True for non-wildcard string or Callable selectors.

	=end pod
	method is-explicit-path(Mu $selector --> Bool) {
		return False unless $selector.defined;
		return False if self.is-wildcard($selector);
		return True if $selector ~~ Str && $selector.chars > 0;
		return True if $selector ~~ Callable;
		False
	}

	=begin pod

	Normalize key, list, or scalar to a string column name.

	=end pod
	method normalize-key(Mu $key --> Str) {
		return $key if $key ~~ Str;
		if $key ~~ List && $key.elems == 1 {
			return self.normalize-key($key[0]);
		}
		~$key
	}

	=begin pod

	Strip angle brackets from selector strings.

	=end pod
	method normalize-name(Str $selector --> Str) {
		return $selector.substr(1, *-2) if $selector.starts-with('<') && $selector.ends-with('>');
		$selector
	}

	=begin pod

	Return True when a table row matches a child/sibling column selector.

	=end pod
	method table-row-matches(Associative $row, Mu $selector --> Bool) {
		return True if self.is-wildcard($selector);
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
		return True if self.is-wildcard($selector);
		if $selector ~~ List {
			return True if $selector.grep({ self.matches($_, $node) }).so;
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
		return $node if $node ~~ Str;
		if $node ~~ Associative {
			for <name tag type> -> $field {
				return ~($node{$field}) if $node{$field}:exists;
			}
		}
		Nil
	}
}
