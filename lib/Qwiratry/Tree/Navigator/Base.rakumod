=begin pod

=head1 Overview

Base role and default implementation for tree navigators.

Tree navigators adapt concrete tree-shaped values to Qwiratry's generic tree
navigation protocol. Custom navigators do C<Qwiratry::Tree::Navigator::Base>.

Prefer typed multi candidates so multiple dispatch selects the relevant
implementation. Broad C<Mu> candidates are only fallbacks that return empty
results. Selector-shaped dispatch follows the same rule: C<List> and non-wildcard
C<Str> are typed candidates; wildcards and other selector forms fall through to
C<Mu> (with a C<where> constraint for wildcards, since C<*> / C<**> are still
C<Str>). Descendant walks live on the query evaluator, not here.

Associative nodes with a positional C<children> key keep the existing nested
tree-demo shape. Other associative nodes are treated as JSON-like maps whose
keys are followable with C<tree-child-results>.

=end pod
use Qwiratry::Query::Selector;

role Qwiratry::Tree::Navigator::Base {
	=begin pod

	=head2 C<supported-types()>

	=begin code
	method supported-types(--> List)
	=end code

	Returns the types or roles this navigator handles. The base navigator
	handles ordinary Raku containers.

	=end pod
	method supported-types(--> List) {
		(Positional, Associative)
	}

	=begin pod

	=head2 C<supports(Mu $node)>

	=begin code
	method supports(Mu $node --> Bool)
	=end code

	Returns whether C<$node> matches one of C<supported-types>.

	=end pod
	method supports(Mu $node --> Bool) {
		for self.supported-types -> $type {
			$node ~~ $type and return True;
		}
		False
	}

	=begin pod

	=head2 C<!selector>

	=begin code
	method !selector()
	=end code

	Return the shared L<Qwiratry::Query::Selector> instance used for name
	normalization and matching.

	=end pod
	method !selector() {
		Qwiratry::Query::Selector.instance
	}

	=begin pod

	=head2 C<!apply-limit>

	=begin code
	method !apply-limit(@items, Int $limit --> List)
	=end code

	Return C<@items> unchanged when C<$limit> is undefined, otherwise the first
	C<$limit> elements as a C<List>.

	=end pod
	method !apply-limit(@items, Int $limit --> List) {
		$limit.defined ?? @items.head($limit).list !! @items.list
	}

	# Fan a List selector out across C<tree-child-results>, honouring C<$limit>.
	method !fan-out-child-results(Mu $node, List $selector, Int :$limit --> List) {
		my @out;
		for $selector.list -> $one {
			@out.append(self.tree-child-results(
				$node, $one, |%(:$limit if $limit.defined),
			));
			last if $limit.defined && @out.elems >= $limit;
		}
		self!apply-limit(@out, $limit)
	}

	# Filter C<tree-children> of C<$node> with the shared selector matcher.
	method !filter-child-results(Mu $node, Mu $selector, Int :$limit --> List) {
		my $sel = self!selector;
		my @out;
		for self.tree-children($node) -> $child {
			next unless $sel.matches($selector, $child);
			@out.push($child);
			last if $limit.defined && @out.elems >= $limit;
		}
		@out.list
	}

	=begin pod

	=head2 C<tree-children>

	=begin code
	multi method tree-children(Positional $node --> List)
	multi method tree-children(Associative $node --> List)
	multi method tree-children(Mu $node --> List)
	=end code

	Returns direct children for ordinary Raku tree-shaped values.

	C<Positional> nodes expose their elements. C<Associative> nodes with a
	positional C<children> key expose that list. Other associative nodes expose
	nested container values so JSON-like maps remain traversable without treating
	scalar fields as child nodes.

	=end pod
	multi method tree-children(Positional $node --> List) {
		$node.list
	}
	multi method tree-children(Associative $node --> List) {
		if $node<children> ~~ Positional {
			return $node<children>.list;
		}
		$node.values.grep({ $_ ~~ Positional|Associative }).list
	}
	multi method tree-children(Mu $node --> List) {
		()
	}

	=begin pod

	=head2 C<tree-child-results>

	=begin code
	multi method tree-child-results(Positional $node, Mu $selector, Int :$limit --> List)
	multi method tree-child-results(Associative $node, List $selector, Int :$limit --> List)
	multi method tree-child-results(Associative $node, Str $selector, Int :$limit --> List)
	multi method tree-child-results(Associative $node, Mu $selector, Int :$limit --> List)
	multi method tree-child-results(Mu $node, Mu $selector, Int :$limit --> List)
	=end code

	Return children of C<$node> that match C<$selector>, optionally capped by
	C<$limit>.

	For associative maps, a non-wildcard string selector first tries hash-key
	lookup so C<⪪ <owner>> follows JSON keys. If that key is absent, structural
	children are filtered with the shared selector matcher so nested demo trees
	that use a C<children> array and C<name>/C<tag>/C<type> labels still work.
	List selectors fan out; wildcards expose every value (or the C<children>
	array for demo trees).

	=end pod
	# Positional: filter elements via the shared matcher (List selectors OR via
	# Selector.matches; wildcards match every element).
	multi method tree-child-results(Positional $node, Mu $selector, Int :$limit --> List) {
		my $sel = self!selector;
		my @out;
		for $node.list -> $child {
			next unless $sel.matches($selector, $child);
			@out.push($child);
			last if $limit.defined && @out.elems >= $limit;
		}
		@out.list
	}

	# Associative + List: fan each element out and concatenate.
	multi method tree-child-results(Associative $node, List $selector, Int :$limit --> List) {
		self!fan-out-child-results($node, $selector, |%(:$limit if $limit.defined))
	}

	# Associative + non-wildcard Str: prefer hash-key lookup, else name-match children.
	# The where clause keeps "*" / "**" out of this candidate (they are still Str).
	multi method tree-child-results(
		Associative $node,
		Str $selector where { !Qwiratry::Query::Selector.instance.is-wildcard($_) },
		Int :$limit --> List
	) {
		my $sel = self!selector;
		my $key = $sel.normalize-name($selector);
		if $node{$key}:exists {
			return self!apply-limit(($node{$key},), $limit);
		}
		self!filter-child-results($node, $selector, |%(:$limit if $limit.defined))
	}

	# Associative + wildcard: every value (JSON maps) or the children array (demo trees).
	multi method tree-child-results(
		Associative $node,
		Mu $selector where { Qwiratry::Query::Selector.instance.is-wildcard($_) },
		Int :$limit --> List
	) {
		my @kids = $node<children> ~~ Positional
			?? $node<children>.list
			!! $node.values.list;
		self!apply-limit(@kids, $limit)
	}

	# Associative + Callable / type object / other: filter structural children.
	multi method tree-child-results(Associative $node, Mu $selector, Int :$limit --> List) {
		self!filter-child-results($node, $selector, |%(:$limit if $limit.defined))
	}

	multi method tree-child-results(Mu $node, Mu $selector, Int :$limit --> List) {
		()
	}

	=begin pod

	=head2 C<tree-parent(Mu $node, Mu :$origin)>

	=begin code
	method tree-parent(Mu $node, Mu :$origin --> Mu)
	=end code

	Returns a direct parent when the node model exposes one. Callers should fall
	back to context caches when this returns C<Nil>. When C<origin> is supplied,
	the default implementation walks from that root using this navigator's
	C<tree-children> method.

	=end pod
	method tree-parent(Mu $node, Mu :$origin --> Mu) {
		if $node.can('parent') {
			my $parent = $node.parent;
			return $parent if $parent.defined;
		}
		$origin.defined and return self.find-parent-in-tree($node, $origin);
		Nil
	}

	=begin pod

	=head2 C<find-parent-in-tree(Mu $node, Mu $current)>

	=begin code
	method find-parent-in-tree(Mu $node, Mu $current --> Mu)
	=end code

	Finds C<$node>'s direct parent by identity while walking from C<$current>.

	=end pod
	method find-parent-in-tree(Mu $node, Mu $current --> Mu) {
		$current.defined or return Nil;
		for self.tree-children($current) -> $child {
			$child === $node and return $current;
			my $found = self.find-parent-in-tree($node, $child);
			$found.defined and return $found;
		}
		Nil
	}

	=begin pod

	=head2 C<tree-attributes>

	=begin code
	multi method tree-attributes(Associative $node --> Associative)
	multi method tree-attributes(Mu $node --> Associative)
	=end code

	Returns attribute-like values when the node naturally exposes them.

	=end pod
	multi method tree-attributes(Associative $node --> Associative) {
		$node
	}
	multi method tree-attributes(Mu $node --> Associative) {
		%()
	}

	=begin pod

	=head2 C<tree-attribute-value>

	=begin code
	multi method tree-attribute-value(Associative $node, Mu $key --> Mu)
	multi method tree-attribute-value(Mu $node, Mu $key --> Mu)
	=end code

	Return one attribute/key value from C<$node>.

	=end pod
	multi method tree-attribute-value(Associative $node, Mu $key --> Mu) {
		my $name = self!selector.normalize-key($key);
		return $node{$name} if $node{$name}:exists;
		Nil
	}
	multi method tree-attribute-value(Mu $node, Mu $key --> Mu) {
		my $name = self!selector.normalize-key($key);
		if $node.can($name) {
			return $node."$name"();
		}
		Nil
	}
}
