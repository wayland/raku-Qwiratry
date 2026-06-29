=begin pod

Shared selector normalization and matching for query evaluation.

Centralizes wildcard detection, path normalization, and node/row matching used by
L<Qwiratry::Query::Runtime>, L<Qwiratry::Query::Specificity>, and
L<Qwiratry::Table::Catalog> navigation.

=end pod
=begin pod

=head2 C<class Qwiratry::Query::Selector>

=begin code :lang<raku>
class Qwiratry::Query::Selector
=end code

Defines C<Qwiratry::Query::Selector>.

=end pod
class Qwiratry::Query::Selector {

	my $instance;

	=begin pod

	Return the shared Selector service instance.

	=end pod
	=begin pod

	=head2 C<method instance>

	=begin code :lang<raku>
	method instance(--> Qwiratry::Query::Selector)
	=end code

	Documents C<method instance>.

	=end pod
	method instance(--> Qwiratry::Query::Selector) {
		$instance //= self.new
	}

	=begin pod

	Return True for wildcard selectors (C<*>, C<**>, C<Whatever>).

	=end pod
	=begin pod

	=head2 C<method is-wildcard>

	=begin code :lang<raku>
	method is-wildcard(Mu $selector --> Bool)
	=end code

	Documents C<method is-wildcard>.

	=item C<$selector>

	The C<$selector> parameter.

	=end pod
	method is-wildcard(Mu $selector --> Bool) {
		$selector ~~ Whatever and return True;
		$selector ~~ Str && $selector eq any(<* **>) and return True;
		False
	}

	=begin pod

	=head2 C<method is-explicit-path>

	=begin code :lang<raku>
	method is-explicit-path(Mu $selector --> Bool)
	=end code

	Documents C<method is-explicit-path>.

	=item C<$selector>

	The C<$selector> parameter.

	=end pod
	method is-explicit-path(Mu $selector --> Bool) {
		self.is-type-object($selector) and return True;
		$selector.defined or return False;
		self.is-wildcard($selector) and return False;
		$selector ~~ Str && $selector.chars > 0 and return True;
		$selector ~~ Callable and return True;
		False
	}

	=begin pod

	Return True when C<$selector> is a type object usable as a type selector.

	=end pod
	method is-type-object(Mu $selector --> Bool) {
		$selector ~~ Mu:U && $selector.^name ne 'Nil'
	}

	=begin pod

	Normalize key, list, or scalar to a string column name.

	=end pod
	=begin pod

	=head2 C<method normalize-key>

	=begin code :lang<raku>
	method normalize-key(Mu $key --> Str)
	=end code

	Documents C<method normalize-key>.

	=item C<$key>

	The C<$key> parameter.

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
	=begin pod

	=head2 C<method normalize-name>

	=begin code :lang<raku>
	method normalize-name(Str $selector --> Str)
	=end code

	Documents C<method normalize-name>.

	=item C<$selector>

	The C<$selector> parameter.

	=end pod
	method normalize-name(Str $selector --> Str) {
		# Strip one enclosing pair of angle brackets, if present.
		$selector ~~ S/^ '<' (.*) '>' $/$0/
	}

	=begin pod

	Return True when a table row matches a child/sibling column selector.

	=end pod
	=begin pod

	=head2 C<method table-row-matches>

	=begin code :lang<raku>
	method table-row-matches(Associative $row, Mu $selector --> Bool)
	=end code

	Documents C<method table-row-matches>.

	=item C<$row>

	The C<$row> parameter.

	=item C<$selector>

	The C<$selector> parameter.

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
	=begin pod

	=head2 C<method matches>

	=begin code :lang<raku>
	method matches(Mu $selector, Mu $node --> Bool)
	=end code

	Documents C<method matches>.

	=item C<$selector>

	The C<$selector> parameter.

	=item C<$node>

	The C<$node> parameter.

	=end pod
	method matches(Mu $selector, Mu $node --> Bool) {
		self.is-wildcard($selector) and return True;
		if self.is-type-object($selector) {
			return $node ~~ $selector;
		}
		if $selector ~~ List {
			$selector.grep({ self.matches($_, $node) }).so and return True;
			return False;
		}
		if $selector ~~ Str {
			my $name = self.node-name($node);
			return $name.defined && $name eq self.normalize-name($selector);
		}
		if $selector ~~ Callable {
			return ?$selector($node);
		}
		False
	}

	=begin pod

	Resolve a display name from a tree or table node.

	=end pod
	=begin pod

	=head2 C<method node-name>

	=begin code :lang<raku>
	method node-name(Mu $node --> Mu)
	=end code

	Documents C<method node-name>.

	=item C<$node>

	The C<$node> parameter.

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
