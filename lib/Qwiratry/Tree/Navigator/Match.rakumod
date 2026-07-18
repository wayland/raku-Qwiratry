=begin pod

=head1 Overview

Match tree navigator.

Matches are the result of a grammar, and are suited to be transformed into a
variety of things, possibly into RakuAST nodes, or whatever the next stage in
compilation is. This module adapts Match nodes to Qwiratry's tree navigation
protocol.

A C<Match>'s children are its sub-captures: the positional captures (C<.list>)
and the named captures (C<.hash>). Quantified captures (for example C<< <item>+ >>)
appear as arrays of C<Match> objects and are flattened so each sub-match is an
individual child.

Named captures also act as the node's attributes, so C<< ⪪ <name> >> follows a
named capture and C<σ> predicates can inspect captures by name. Descendant walks
(C<< ⪪⪪ >>) are owned by the query evaluator; this navigator only supplies
one-step shape operations.

Note that C<Match> objects are immutable, so this navigator supports reading and
querying a match tree (typically to transform it into some other structure);
it does not mutate the match in place.

=end pod
use Qwiratry::Query::Selector;
use Qwiratry::Tree::Navigator::Base;

class Qwiratry::Tree::Navigator::Match does Qwiratry::Tree::Navigator::Base {
	=begin pod

	=head2 C<supported-types()>

	=begin code
	method supported-types(--> List)
	=end code

	=end pod
	method supported-types(--> List) {
		(Match,)
	}

	=begin pod

	=head2 C<tree-children>

	=begin code
	multi method tree-children(Match:D $node --> List)
	=end code

	Expose direct sub-captures (positional then named), flattening arrays of
	quantified captures into individual C<Match> children.

	=end pod
	multi method tree-children(Match:D $node --> List) {
		my @children;
		self!collect-matches($node.list, @children);
		self!collect-matches($node.hash.values, @children);
		@children.list
	}

	# Flatten a capture value into Match children. Recurses only into Positional
	# wrappers (quantified captures); never descends into a Match's own captures.
	method !collect-matches($captures, @out --> Nil) {
		for @($captures) -> $capture {
			next without $capture;
			if $capture ~~ Match {
				@out.push($capture);
			}
			elsif $capture ~~ Positional {
				self!collect-matches($capture, @out);
			}
		}
	}

	# Return the sub-matches held by a named capture (empty when absent).
	method !named-capture-children(Match:D $node, Str $selector, Int :$limit --> List) {
		my $key = self!selector.normalize-name($selector);
		return () unless $node.hash{$key}:exists;
		my @named;
		self!collect-matches(($node.hash{$key},), @named);
		self!apply-limit(@named, $limit)
	}

	=begin pod

	=head2 C<tree-child-results>

	=begin code
	multi method tree-child-results(Match:D $node, List $selector, Int :$limit --> List)
	multi method tree-child-results(Match:D $node, Str $selector, Int :$limit --> List)
	multi method tree-child-results(Match:D $node, Mu $selector, Int :$limit --> List)
	=end code

	Return children of C<$node> matching C<$selector>. A non-wildcard string
	selector (for example C<< <greeting> >>) follows the named capture of that
	name; a list selector fans out; wildcards return every child; and block or
	type selectors filter the structural children.

	=end pod
	multi method tree-child-results(Match:D $node, List $selector, Int :$limit --> List) {
		self!fan-out-child-results($node, $selector, |%(:$limit if $limit.defined))
	}

	multi method tree-child-results(
		Match:D $node,
		Str $selector where { !Qwiratry::Query::Selector.instance.is-wildcard($_) },
		Int :$limit --> List
	) {
		self!named-capture-children($node, $selector, |%(:$limit if $limit.defined))
	}

	multi method tree-child-results(
		Match:D $node,
		Mu $selector where { Qwiratry::Query::Selector.instance.is-wildcard($_) },
		Int :$limit --> List
	) {
		self!apply-limit(self.tree-children($node), $limit)
	}

	multi method tree-child-results(Match:D $node, Mu $selector, Int :$limit --> List) {
		self!filter-child-results($node, $selector, |%(:$limit if $limit.defined))
	}

	=begin pod

	=head2 C<tree-attributes>

	=begin code
	multi method tree-attributes(Match:D $node --> Associative)
	=end code

	Expose the named captures as the node's attribute map.

	=end pod
	multi method tree-attributes(Match:D $node --> Associative) {
		$node.hash
	}

	=begin pod

	=head2 C<tree-attribute-value>

	=begin code
	multi method tree-attribute-value(Match:D $node, Mu $key --> Mu)
	=end code

	Return the named capture C<$key> from C<$node>, or C<Nil>.

	=end pod
	multi method tree-attribute-value(Match:D $node, Mu $key --> Mu) {
		my $name = self!selector.normalize-key($key);
		return $node.hash{$name} if $node.hash{$name}:exists;
		Nil
	}
}
