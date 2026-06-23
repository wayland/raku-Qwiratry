=begin pod

=head1 Overview

Eager evaluators for navigation query operators.

=end pod
unit module Qwiratry::Query::Evaluator::Navigation;

use Qwiratry::Operator::Navigation;
use Qwiratry::Operator::Capability;
use Qwiratry::Query::Evaluator::Eager;
use Qwiratry::Query::Selector;
use Qwiratry::Table::Schema;

role NavigationEagerEvaluator does EagerEvaluator {
	has &.select-list is required;

	method selector() {
		Qwiratry::Query::Selector.instance
	}

	method select-list-for(Mu $query, Mu $origin --> List) {
		&!select-list($query, $origin)
	}

	method resolve-bases(Mu $op, Mu $origin --> List) {
		if $op.can('subject') && $op.subject.defined {
			if $op.subject ~~ NavigationOperator {
				return self.select-list-for($op.subject, $origin);
			}
			return ($op.subject,);
		}
		($origin,)
	}

	method catalog(Mu $origin) {
		Qwiratry::Table::Schema.instance.discover($origin)
	}

	method tree-children(Mu $node --> List) {
		$node ~~ Positional and return $node.list;
		if $node ~~ Associative {
			if $node<children> ~~ Positional {
				return $node<children>.list;
			}
		}
		()
	}

	method tree-descendants(Mu $node --> Seq) {
		gather {
			for self.tree-children($node) -> $child {
				take $child;
				take $_ for self.tree-descendants($child);
			}
		}
	}

	method tree-parent(Mu $node, Mu :$origin --> Mu) {
		$node.can('parent') and return $node.parent;
		$origin.defined and return self.find-parent-in-tree($node, $origin);
		Nil
	}

	method find-parent-in-tree(Mu $node, Mu $current --> Mu) {
		$current.defined or return Nil;
		for self.tree-children($current) -> $child {
			$child === $node and return $current;
			my $found = self.find-parent-in-tree($node, $child);
			$found.defined and return $found;
		}
		Nil
	}

	method tree-ancestors(Mu $node, Mu :$origin --> Seq) {
		gather {
			my $current = self.tree-parent($node, :$origin);
			while $current.defined {
				take $current;
				$current = self.tree-parent($current, :$origin);
			}
		}
	}

	method sibling-context(Mu $node, Mu :$origin --> Associative) {
		my $parent = self.tree-parent($node, :$origin);
		$parent.defined and return %(all => self.tree-children($parent));
		%(all => ())
	}

	method sibling-index(@siblings, Mu $node) {
		for 0..^@siblings -> $i {
			@siblings[$i] === $node and return $i;
		}
		Nil
	}

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

	method attribute-value(Mu $node, Mu $key --> Mu) {
		my $name = self.selector.normalize-key($key);
		if $node ~~ Associative && $node{$name}:exists {
			return $node{$name};
		}
		if $node.can($name) {
			return $node.$name;
		}
		Nil
	}
}

class RootEvaluator does NavigationEagerEvaluator is export {
	method eager(RootOperator $query, Mu $origin --> List) {
		my $base = $query.subject.defined ?? $query.subject !! $origin;
		($base,)
	}
}

class ChildEvaluator does NavigationEagerEvaluator is export {
	method eager(ChildOperator $query, Mu $origin --> List) {
		my @bases = self.resolve-bases($query, $origin);
		my $catalog = self.catalog($origin);
		my @results;
		for @bases -> $base {
			if $catalog.defined {
				@results.append($catalog.child-results($base, $query));
			}
			else {
				for self.tree-children($base) -> $child {
					self.selector.matches($query.selector, $child) and @results.push($child);
				}
			}
		}
		@results
	}
}

class DescendantEvaluator does NavigationEagerEvaluator is export {
	method eager(DescendantOperator $query, Mu $origin --> List) {
		my @bases = self.resolve-bases($query, $origin);
		my $catalog = self.catalog($origin);
		my @results;
		for @bases -> $base {
			if $catalog.defined {
				@results.append($catalog.descendant-results($base, $query));
			}
			else {
				for self.tree-descendants($base) -> $desc {
					self.selector.matches($query.selector, $desc) and @results.push($desc);
				}
			}
		}
		@results
	}
}

class AttributeEvaluator does NavigationEagerEvaluator is export {
	method eager(AttributeOperator $query, Mu $origin --> List) {
		my @bases = self.resolve-bases($query, $origin);
		my @results;
		for @bases -> $base {
			my $value = self.attribute-value($base, $query.key);
			$value.defined and @results.push($value);
		}
		@results
	}
}

class ParentEvaluator does NavigationEagerEvaluator is export {
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

class AncestorEvaluator does NavigationEagerEvaluator is export {
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

role SiblingNavigationEvaluator does NavigationEagerEvaluator {
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

class FollowingSiblingEvaluator does SiblingNavigationEvaluator is export {
	method eager(FollowingSiblingOperator $query, Mu $origin --> List) {
		self.sibling-eager($query, $origin)
	}
}

class PrecedingSiblingEvaluator does SiblingNavigationEvaluator is export {
	method eager(PrecedingSiblingOperator $query, Mu $origin --> List) {
		self.sibling-eager($query, $origin)
	}
}

class FollowingEvaluator does SiblingNavigationEvaluator is export {
	method eager(FollowingOperator $query, Mu $origin --> List) {
		self.sibling-eager($query, $origin)
	}
}

class PrecedingEvaluator does SiblingNavigationEvaluator is export {
	method eager(PrecedingOperator $query, Mu $origin --> List) {
		self.sibling-eager($query, $origin)
	}
}
