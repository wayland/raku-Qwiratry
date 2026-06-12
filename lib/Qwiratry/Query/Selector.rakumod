=begin pod

Shared selector normalization and matching for query evaluation.

=end pod
unit class Qwiratry::Query::Selector;

my $instance;

method instance(--> Qwiratry::Query::Selector) {
	$instance //= self.new
}

method is-wildcard(Mu $selector --> Bool) {
	return True if $selector ~~ Whatever;
	return True if $selector ~~ Str && $selector eq any(<* **>);
	False
}

method is-explicit-path(Mu $selector --> Bool) {
	return False unless $selector.defined;
	return False if self.is-wildcard($selector);
	return True if $selector ~~ Str && $selector.chars > 0;
	return True if $selector ~~ Callable;
	False
}

method normalize-key(Mu $key --> Str) {
	return $key if $key ~~ Str;
	if $key ~~ List && $key.elems == 1 {
		return self.normalize-key($key[0]);
	}
	~$key
}

method normalize-name(Str $selector --> Str) {
	return $selector.substr(1, *-2) if $selector.starts-with('<') && $selector.ends-with('>');
	$selector
}

method table-row-matches(Associative $row, Mu $selector --> Bool) {
	return True if self.is-wildcard($selector);
	if $selector ~~ Str {
		my $col = self.normalize-name($selector);
		return $row{$col}:exists;
	}
	False
}

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

method node-name(Mu $node --> Mu) {
	return $node if $node ~~ Str;
	if $node ~~ Associative {
		for <name tag type> -> $field {
			return ~($node{$field}) if $node{$field}:exists;
		}
	}
	Nil
}
