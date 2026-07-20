=begin pod

=head1 Overview

Eager evaluators for navigation query operators.

=end pod
unit module Qwiratry::Query::Evaluator::Navigation;

use Qwiratry::Operator::Navigation;
use Qwiratry::Operator::Capability;
use Qwiratry::Tree::Navigator;
use Qwiratry::Query::Evaluator::Eager;
use Qwiratry::Query::Selector;
use Qwiratry::Table::Schema;

=begin pod

=head2 C<role NavigationEagerEvaluator>

Shared behavior for navigation eager evaluators.

=end pod
role NavigationEagerEvaluator does EagerEvaluator {
	has &.select-list is required;

	=begin pod

	=head2 C<method selector>

	=begin code :lang<raku>
	method selector()
	=end code

	Documents C<method selector>.

	=end pod
	method selector() {
		Qwiratry::Query::Selector.instance
	}

	=begin pod

	=head2 C<method select-list-for>

	=begin code :lang<raku>
	method select-list-for(Mu $query, Mu $origin --> List)
	=end code

	Documents C<method select-list-for>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method select-list-for(Mu $query, Mu $origin --> List) {
		&!select-list($query, $origin)
	}

	=begin pod

	=head2 C<method resolve-bases>

	=begin code :lang<raku>
	method resolve-bases(Mu $op, Mu $origin --> List)
	=end code

	Documents C<method resolve-bases>.

	=item C<$op>

	The C<$op> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method resolve-bases(Mu $op, Mu $origin --> List) {
		if $op.can('subject') && $op.subject.defined {
			if $op.subject ~~ NavigationOperator {
				return self.select-list-for($op.subject, $origin);
			}
			# Evaluate adaptor subjects (Source/Parse/...) to concrete data before
			# navigation axes walk them (chained slang like source then descendant).
			if $op.subject ~~ AdaptorOperator {
				return (execute($op.subject, :$origin),);
			}
			if $op.subject ~~ Seq {
				return $op.subject.list;
			}
			if $op.subject ~~ Iterator {
				return Seq.new($op.subject).list;
			}
			return ($op.subject,);
		}
		($origin,)
	}

	=begin pod

	=head2 C<method catalog>

	=begin code :lang<raku>
	method catalog(Mu $origin)
	=end code

	Documents C<method catalog>.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method catalog(Mu $origin) {
		Qwiratry::Table::Schema.instance.discover($origin)
	}

	=begin pod

	=head2 C<method tree-children>

	=begin code :lang<raku>
	method tree-children(Mu $node, Mu :$origin --> List)
	=end code

	Return direct children of C<$node> through the active tree navigator.

	=item C<$node>

	The node whose children are requested.

	=item C<$origin>

	Optional traversal root used for navigator selection and parent fallback.

	=end pod
	method tree-children(Mu $node, Mu :$origin --> List) {
		Qwiratry::Tree::Navigator.tree-navigator-for($node, :$origin).tree-children($node)
	}

	=begin pod

	=head2 C<method tree-child-results>

	=begin code :lang<raku>
	method tree-child-results(Mu $node, Mu $selector, Mu :$origin, Int :$limit --> List)
	=end code

	Return children of C<$node> matching C<$selector>, optionally capped by
	C<$limit>, through the active tree navigator.

	=item C<$node>

	The node whose matching children are requested.

	=item C<$selector>

	Child selector passed to the navigator.

	=item C<$origin>

	Optional traversal root used for navigator selection.

	=item C<$limit>

	Optional maximum number of results.

	=end pod
	method tree-child-results(Mu $node, Mu $selector, Mu :$origin, Int :$limit --> List) {
		Qwiratry::Tree::Navigator.tree-navigator-for($node, :$origin)
			.tree-child-results($node, $selector, |%(:$limit if $limit.defined))
	}

	=begin pod

	=head2 C<method tree-descendant-results>

	=begin code :lang<raku>
	multi method tree-descendant-results(Mu $node, List $selector, Mu :$origin, Int :$limit --> List)
	multi method tree-descendant-results(Mu $node, Mu $selector, Mu :$origin, Int :$limit --> List)
	=end code

	Return matching descendants of C<$node>, optionally capped by C<$limit>.

	Traversal belongs here (not on the tree navigator): a pre-order depth-first
	walk expands each node via the navigator's one-step C<tree-children> /
	C<tree-child-results>. That keeps model-specific shape ops (JSON keys, Match
	named captures) on the navigator while the evaluator owns the walk. List
	selectors fan out (slang C<< <name> >> is often a one-element List).

	=item C<$node>

	The node whose matching descendants are requested.

	=item C<$selector>

	Descendant selector.

	=item C<$origin>

	Optional traversal root used for navigator selection.

	=item C<$limit>

	Optional maximum number of results.

	=end pod
	multi method tree-descendant-results(Mu $node, List $selector, Mu :$origin, Int :$limit --> List) {
		my @out;
		for $selector.list -> $one {
			@out.append(self.tree-descendant-results(
				$node, $one, :$origin, |%(:$limit if $limit.defined),
			));
			last if $limit.defined && @out.elems >= $limit;
		}
		$limit.defined ?? @out.head($limit).list !! @out.list
	}

	multi method tree-descendant-results(Mu $node, Mu $selector, Mu :$origin, Int :$limit --> List) {
		my $sel = self.selector;
		# One-step hits at this node (JSON key / Match named capture / name filter).
		my @hits = self.tree-child-results(
			$node, $selector, :$origin, |%(:$limit if $limit.defined),
		).list;
		my @children = self.tree-children($node, :$origin);
		my @out;

		for @children -> $child {
			my $is-hit = $sel.is-wildcard($selector)
				|| @hits.first({ self!same-tree-node($_, $child) }).defined
				|| $sel.matches($selector, $child);
			if $is-hit {
				@out.push($child);
				return @out.list if $limit.defined && @out.elems >= $limit;
			}
			my $remaining = $limit.defined ?? $limit - @out.elems !! Int;
			@out.append(self.tree-descendant-results(
				$child, $selector, :$origin,
				|%(:limit($remaining) if $remaining.defined),
			));
			return @out.list if $limit.defined && @out.elems >= $limit;
		}

		# Scalar / non-structural hits from one-step lookup (e.g. JSON C<login>
		# values) are not in C<tree-children>; emit them after the structural walk.
		# Wildcards stay structural-only, matching the previous Base behaviour.
		# IO::Path children from separate C<.dir> calls are distinct objects, so
		# also dedupe by absolute path when structural matching already pushed them.
		unless $sel.is-wildcard($selector) {
			for @hits -> $hit {
				next if @children.first({ self!same-tree-node($_, $hit) }).defined;
				next if @out.first({ self!same-tree-node($_, $hit) }).defined;
				@out.push($hit);
				return @out.list if $limit.defined && @out.elems >= $limit;
			}
		}
		$limit.defined ?? @out.head($limit).list !! @out.list
	}

	# Identity for ordinary nodes; absolute path equality for filesystem nodes.
	method !same-tree-node(Mu $a, Mu $b --> Bool) {
		return True if $a === $b;
		return True if $a ~~ IO::Path && $b ~~ IO::Path && $a.absolute eq $b.absolute;
		False
	}

	=begin pod

	=head2 C<method tree-attribute-value>

	=begin code :lang<raku>
	method tree-attribute-value(Mu $node, Mu $key, Mu :$origin --> Mu)
	=end code

	Return one attribute or key value from C<$node> through the active tree
	navigator.

	=item C<$node>

	The node to read from.

	=item C<$key>

	Attribute or key selector.

	=item C<$origin>

	Optional traversal root used for navigator selection.

	=end pod
	method tree-attribute-value(Mu $node, Mu $key, Mu :$origin --> Mu) {
		Qwiratry::Tree::Navigator.tree-navigator-for($node, :$origin)
			.tree-attribute-value($node, $key)
	}

	=begin pod

	=head2 C<method tree-descendants>

	=begin code :lang<raku>
	method tree-descendants(Mu $node, Mu :$origin --> Seq)
	=end code

	Documents C<method tree-descendants>.

	=item C<$node>

	The C<$node> parameter.

	=item C<$origin>

	Optional traversal root used for navigator selection.

	=end pod
	method tree-descendants(Mu $node, Mu :$origin --> Seq) {
		gather {
			for self.tree-children($node, :$origin) -> $child {
				take $child;
				take $_ for self.tree-descendants($child, :$origin);
			}
		}
	}

	=begin pod

	=head2 C<method tree-parent>

	=begin code :lang<raku>
	method tree-parent(Mu $node, Mu :$origin --> Mu)
	=end code

	Documents C<method tree-parent>.

	=item C<$node>

	The C<$node> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method tree-parent(Mu $node, Mu :$origin --> Mu) {
		my $navigator = Qwiratry::Tree::Navigator.tree-navigator-for($node, :$origin);
		$navigator.tree-parent($node, :$origin)
	}

	=begin pod

	=head2 C<method tree-ancestors>

	=begin code :lang<raku>
	method tree-ancestors(Mu $node, Mu :$origin --> Seq)
	=end code

	Documents C<method tree-ancestors>.

	=item C<$node>

	The C<$node> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method tree-ancestors(Mu $node, Mu :$origin --> Seq) {
		gather {
			my $current = self.tree-parent($node, :$origin);
			while $current.defined {
				take $current;
				$current = self.tree-parent($current, :$origin);
			}
		}
	}

	=begin pod

	=head2 C<method sibling-context>

	=begin code :lang<raku>
	method sibling-context(Mu $node, Mu :$origin --> Associative)
	=end code

	Documents C<method sibling-context>.

	=item C<$node>

	The C<$node> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method sibling-context(Mu $node, Mu :$origin --> Associative) {
		my $parent = self.tree-parent($node, :$origin);
		$parent.defined and return %(all => self.tree-children($parent, :$origin));
		%(all => ())
	}

	=begin pod

	=head2 C<method sibling-index>

	=begin code :lang<raku>
	method sibling-index(@siblings, Mu $node)
	=end code

	Documents C<method sibling-index>.

	=item C<@siblings>

	The C<@siblings> parameter.

	=item C<$node>

	The C<$node> parameter.

	=end pod
	method sibling-index(@siblings, Mu $node) {
		for 0..^@siblings -> $i {
			@siblings[$i] === $node and return $i;
		}
		Nil
	}

	=begin pod

	=head2 C<method sibling-candidates>

	=begin code :lang<raku>
	method sibling-candidates(Mu $op, @siblings, Int $index --> List)
	=end code

	Documents C<method sibling-candidates>.

	=item C<$op>

	The C<$op> parameter.

	=item C<@siblings>

	The C<@siblings> parameter.

	=item C<$index>

	The C<$index> parameter.

	=end pod
	method sibling-candidates(Mu $op, @siblings, Int $index --> List) {
		given $op {
			when FollowingSiblingOperator {
				return @siblings[$index+1 .. *];
			}
			when PrecedingSiblingOperator {
				return @siblings[0 ..^ $index];
			}
			when FollowingOperator {
				return @siblings[$index+1 .. *];
			}
			when PrecedingOperator {
				return @siblings[0 ..^ $index];
			}
			default {
				return ();
			}
		}
	}

	=begin pod

	=head2 C<method attribute-value>

	=begin code :lang<raku>
	method attribute-value(Mu $node, Mu $key, Mu :$origin --> Mu)
	=end code

	Return one attribute or key value from C<$node> through the active tree
	navigator.

	=item C<$node>

	The node to read from.

	=item C<$key>

	Attribute or key selector.

	=item C<$origin>

	Optional traversal root used for navigator selection.

	=end pod
	method attribute-value(Mu $node, Mu $key, Mu :$origin --> Mu) {
		self.tree-attribute-value($node, $key, :$origin)
	}

	=begin pod

	=head2 C<method navigation-leaf>

	=begin code :lang<raku>
	method navigation-leaf(Mu $query --> Mu)
	=end code

	Documents C<method navigation-leaf>.

	=item C<$query>

	The C<$query> parameter.

	=end pod
	method navigation-leaf(Mu $query --> Mu) {
		if $query.can('subject') && $query.subject.defined
				&& $query.subject ~~ NavigationOperator {
			return self.navigation-leaf($query.subject);
		}
		$query
	}

	=begin pod

	=head2 C<method topic-matches>

	=begin code :lang<raku>
	method topic-matches(Mu $query, Mu $node, Mu :$origin, :&topic-matches! --> Bool)
	=end code

	Documents C<method topic-matches>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$node>

	The C<$node> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=item C<&topic-matches>

	The C<&topic-matches> parameter.

	=end pod
	method topic-matches(Mu $query, Mu $node, Mu :$origin, :&topic-matches! --> Bool) {
		my $leaf = self.navigation-leaf($query);
		$leaf.defined && $leaf.can('selector') or return False;
		self.selector.matches($leaf.selector, $node);
	}
}

=begin pod

=head2 C<class RootEvaluator>

=begin code :lang<raku>
class RootEvaluator does NavigationEagerEvaluator is export
=end code

Defines C<RootEvaluator>.

=end pod
class RootEvaluator does NavigationEagerEvaluator is export {
	=begin pod

	=head2 C<method eager>

	=begin code :lang<raku>
	method eager(RootOperator $query, Mu $origin --> List)
	=end code

	Documents C<method eager>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method eager(RootOperator $query, Mu $origin --> List) {
		# Operators.md §5.2.7: walk up from the current node to the data root.
		my $node = $query.subject.defined ?? $query.subject !! $origin;
		$node.defined or return ($origin,);

		my $search-root = $origin.defined ?? $origin !! $node;
		my $current = $node;
		my $parent = self.tree-parent($current, :origin($search-root));
		while $parent.defined {
			$current = $parent;
			$parent = self.tree-parent($current, :origin($search-root));
		}
		($current,)
	}
}

=begin pod

=head2 C<class ChildEvaluator>

=begin code :lang<raku>
class ChildEvaluator does NavigationEagerEvaluator is export
=end code

Defines C<ChildEvaluator>.

=end pod
class ChildEvaluator does NavigationEagerEvaluator is export {
	=begin pod

	=head2 C<method eager>

	=begin code :lang<raku>
	method eager(ChildOperator $query, Mu $origin --> List)
	=end code

	Documents C<method eager>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method eager(ChildOperator $query, Mu $origin --> List) {
		my @bases = self.resolve-bases($query, $origin);
		my $catalog = self.catalog($origin);
		my @results;
		my $limit = ($query.adverbs // %())<limit>;
		for @bases -> $base {
			if $catalog.defined {
				@results.append($catalog.child-results($base, $query));
			}
			else {
				@results.append(self.tree-child-results(
					$base,
					$query.selector,
					:$origin,
					|%(:limit($limit) if $limit.defined),
				));
			}
		}
		@results
	}

	=begin pod

	=head2 C<method topic-matches>

	=begin code :lang<raku>
	method topic-matches(ChildOperator $query, Mu $node, Mu :$origin, :&topic-matches! --> Bool)
	=end code

	Documents C<method topic-matches>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$node>

	The C<$node> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=item C<&topic-matches>

	The C<&topic-matches> parameter.

	=end pod
	method topic-matches(ChildOperator $query, Mu $node, Mu :$origin, :&topic-matches! --> Bool) {
		self.selector.matches($query.selector, $node) or return False;
		my $parent = self.tree-parent($node, :$origin);
		$parent.defined or return False;
		topic-matches($query.subject, $parent, :$origin);
	}
}

=begin pod

=head2 C<class DescendantEvaluator>

=begin code :lang<raku>
class DescendantEvaluator does NavigationEagerEvaluator is export
=end code

Defines C<DescendantEvaluator>.

=end pod
class DescendantEvaluator does NavigationEagerEvaluator is export {
	=begin pod

	=head2 C<method eager>

	=begin code :lang<raku>
	method eager(DescendantOperator $query, Mu $origin --> List)
	=end code

	Documents C<method eager>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method eager(DescendantOperator $query, Mu $origin --> List) {
		my @bases = self.resolve-bases($query, $origin);
		my $catalog = self.catalog($origin);
		my @results;
		my $limit = ($query.adverbs // %())<limit>;
		for @bases -> $base {
			if $catalog.defined {
				@results.append($catalog.descendant-results($base, $query));
			}
			else {
				@results.append(self.tree-descendant-results(
					$base,
					$query.selector,
					:$origin,
					|%(:limit($limit) if $limit.defined),
				));
			}
		}
		@results
	}

	=begin pod

	=head2 C<method topic-matches>

	=begin code :lang<raku>
	method topic-matches(DescendantOperator $query, Mu $node, Mu :$origin, :&topic-matches! --> Bool)
	=end code

	Documents C<method topic-matches>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$node>

	The C<$node> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=item C<&topic-matches>

	The C<&topic-matches> parameter.

	=end pod
	method topic-matches(DescendantOperator $query, Mu $node, Mu :$origin, :&topic-matches! --> Bool) {
		self.selector.matches($query.selector, $node) or return False;
		topic-matches($query.subject, $node, :$origin);
	}
}

=begin pod

=head2 C<class AttributeEvaluator>

=begin code :lang<raku>
class AttributeEvaluator does NavigationEagerEvaluator is export
=end code

Defines C<AttributeEvaluator>.

=end pod
class AttributeEvaluator does NavigationEagerEvaluator is export {
	=begin pod

	=head2 C<method eager>

	=begin code :lang<raku>
	method eager(AttributeOperator $query, Mu $origin --> List)
	=end code

	Documents C<method eager>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method eager(AttributeOperator $query, Mu $origin --> List) {
		my @bases = self.resolve-bases($query, $origin);
		my @results;
		for @bases -> $base {
			my $value = self.attribute-value($base, $query.key, :$origin);
			$value.defined and @results.push($value);
		}
		@results
	}
}

=begin pod

=head2 C<class ParentEvaluator>

=begin code :lang<raku>
class ParentEvaluator does NavigationEagerEvaluator is export
=end code

Defines C<ParentEvaluator>.

=end pod
class ParentEvaluator does NavigationEagerEvaluator is export {
	=begin pod

	=head2 C<method eager>

	=begin code :lang<raku>
	method eager(ParentOperator $query, Mu $origin --> List)
	=end code

	Documents C<method eager>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method eager(ParentOperator $query, Mu $origin --> List) {
		my @bases = self.resolve-bases($query, $origin);
		my $catalog = self.catalog($origin);
		my @results;
		for @bases -> $base {
			if $catalog.defined {
				@results.append($catalog.parent-results($base, $query));
			}
			else {
				my $parent = self.tree-parent($base, :$origin);
				@results.push($parent) if $parent.defined
					&& self.selector.matches($query.selector, $parent);
			}
		}
		@results
	}
}

=begin pod

=head2 C<class AncestorEvaluator>

=begin code :lang<raku>
class AncestorEvaluator does NavigationEagerEvaluator is export
=end code

Defines C<AncestorEvaluator>.

=end pod
class AncestorEvaluator does NavigationEagerEvaluator is export {
	=begin pod

	=head2 C<method eager>

	=begin code :lang<raku>
	method eager(AncestorOperator $query, Mu $origin --> List)
	=end code

	Documents C<method eager>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method eager(AncestorOperator $query, Mu $origin --> List) {
		my @bases = self.resolve-bases($query, $origin);
		my $catalog = self.catalog($origin);
		my @results;
		for @bases -> $base {
			if $catalog.defined {
				@results.append($catalog.parent-results($base, $query));
			}
			else {
				for self.tree-ancestors($base, :$origin) -> $anc {
					self.selector.matches($query.selector, $anc) and @results.push($anc);
				}
			}
		}
		@results
	}
}

=begin pod

=head2 C<role SiblingNavigationEvaluator>

=begin code :lang<raku>
role SiblingNavigationEvaluator does NavigationEagerEvaluator
=end code

Defines C<SiblingNavigationEvaluator>.

=end pod
role SiblingNavigationEvaluator does NavigationEagerEvaluator {
	=begin pod

	=head2 C<method sibling-eager>

	=begin code :lang<raku>
	method sibling-eager(Mu $query, Mu $origin --> List)
	=end code

	Documents C<method sibling-eager>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method sibling-eager(Mu $query, Mu $origin --> List) {
		my @bases = self.resolve-bases($query, $origin);
		my $catalog = self.catalog($origin);
		my @results;
		for @bases -> $base {
			if $catalog.defined && $catalog.is-table-row($base) {
				@results.append($catalog.sibling-results($base, $query));
				next;
			}
			my @siblings = self.sibling-context($base, :$origin)<all>;
			my $index = self.sibling-index(@siblings, $base);
			next unless $index.defined;
			my @candidates = self.sibling-candidates($query, @siblings, $index);
			for @candidates -> $candidate {
				if self.selector.matches($query.selector, $candidate) {
					@results.push($candidate);
				}
			}
		}
		@results
	}
}

=begin pod

=head2 C<class FollowingSiblingEvaluator>

=begin code :lang<raku>
class FollowingSiblingEvaluator does SiblingNavigationEvaluator is export
=end code

Defines C<FollowingSiblingEvaluator>.

=end pod
class FollowingSiblingEvaluator does SiblingNavigationEvaluator is export {
	=begin pod

	=head2 C<method eager>

	=begin code :lang<raku>
	method eager(FollowingSiblingOperator $query, Mu $origin --> List)
	=end code

	Documents C<method eager>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method eager(FollowingSiblingOperator $query, Mu $origin --> List) {
		self.sibling-eager($query, $origin)
	}
}

=begin pod

=head2 C<class PrecedingSiblingEvaluator>

=begin code :lang<raku>
class PrecedingSiblingEvaluator does SiblingNavigationEvaluator is export
=end code

Defines C<PrecedingSiblingEvaluator>.

=end pod
class PrecedingSiblingEvaluator does SiblingNavigationEvaluator is export {
	=begin pod

	=head2 C<method eager>

	=begin code :lang<raku>
	method eager(PrecedingSiblingOperator $query, Mu $origin --> List)
	=end code

	Documents C<method eager>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method eager(PrecedingSiblingOperator $query, Mu $origin --> List) {
		self.sibling-eager($query, $origin)
	}
}

=begin pod

=head2 C<class FollowingEvaluator>

=begin code :lang<raku>
class FollowingEvaluator does SiblingNavigationEvaluator is export
=end code

Defines C<FollowingEvaluator>.

=end pod
class FollowingEvaluator does SiblingNavigationEvaluator is export {
	=begin pod

	=head2 C<method eager>

	=begin code :lang<raku>
	method eager(FollowingOperator $query, Mu $origin --> List)
	=end code

	Documents C<method eager>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method eager(FollowingOperator $query, Mu $origin --> List) {
		self.sibling-eager($query, $origin)
	}
}

=begin pod

=head2 C<class PrecedingEvaluator>

=begin code :lang<raku>
class PrecedingEvaluator does SiblingNavigationEvaluator is export
=end code

Defines C<PrecedingEvaluator>.

=end pod
class PrecedingEvaluator does SiblingNavigationEvaluator is export {
	=begin pod

	=head2 C<method eager>

	=begin code :lang<raku>
	method eager(PrecedingOperator $query, Mu $origin --> List)
	=end code

	Documents C<method eager>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=end pod
	method eager(PrecedingOperator $query, Mu $origin --> List) {
		self.sibling-eager($query, $origin)
	}
}
