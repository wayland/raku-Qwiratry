=begin pod

Evaluate navigation Query AST nodes against tree-shaped Raku data.

Provides lazy C<select> to find matching nodes and C<node-matches> to test
membership. Used by L<Qwiratry::Walker::Implementation::Tree> and mold
C<when-query> matching.

Tree semantics (Operators.md section 7.2.1):

- C<Positional> values expose children via C<.list>
- C<Associative> values expose children via C<.values>
- Selectors match node names (strings, or C<name>/C<tag>/C<type> keys)

=end pod
unit module Qwiratry::Query::Match;

use Qwiratry::Operator::Navigation;
use Qwiratry::Operator::Capability;
use Qwiratry::Operator::Set;
use Qwiratry::Operator::MapReduce;
use Qwiratry::Operator::IO;
use Qwiratry::Query::Relational;
use Qwiratry::Query::Lazy;
use Qwiratry::Query::Evaluator::Union;
use Qwiratry::Query::Evaluator::Set;
use Qwiratry::Query::Evaluator::Join;
use Qwiratry::Query::Evaluator::Row;
use Qwiratry::Query::Evaluator::Filter;
use Qwiratry::Query::Evaluator::Navigation;
use Qwiratry::Query::Evaluator::Relational;
use Qwiratry::Query::Evaluator::MapReduce;
use Qwiratry::Table;
use Qwiratry::Table::Schema;
use Qwiratry::Query::Selector;

my sub relational() { Qwiratry::Query::Relational.instance }
my constant selector = Qwiratry::Query::Selector.instance;

my sub evaluators() {
	state %evaluators = %(
		UnionOperator => UnionEvaluator.new,
		IntersectionOperator => IntersectionEvaluator.new,
		SetDifferenceOperator => SetDifferenceEvaluator.new,
		SymmetricDifferenceOperator => SymmetricDifferenceEvaluator.new,
		InnerJoinOperator => InnerJoinEvaluator.new,
		LeftOuterJoinOperator => LeftOuterJoinEvaluator.new,
		RightOuterJoinOperator => RightOuterJoinEvaluator.new,
		FullOuterJoinOperator => FullOuterJoinEvaluator.new,
		LeftSemijoinOperator => LeftSemijoinEvaluator.new,
		RightSemijoinOperator => RightSemijoinEvaluator.new,
		LeftAntijoinOperator => LeftAntijoinEvaluator.new,
		RightAntijoinOperator => RightAntijoinEvaluator.new,
		CrossJoinOperator => CrossJoinEvaluator.new,
		ProjectionOperator => ProjectionEvaluator.new,
		RenameOperator => RenameEvaluator.new,
		SelectionOperator => SelectionEvaluator.new,
		RootOperator => RootEvaluator.new(:select-list(&select-list)),
		ChildOperator => ChildEvaluator.new(:select-list(&select-list)),
		DescendantOperator => DescendantEvaluator.new(:select-list(&select-list)),
		AttributeOperator => AttributeEvaluator.new(:select-list(&select-list)),
		ParentOperator => ParentEvaluator.new(:select-list(&select-list)),
		AncestorOperator => AncestorEvaluator.new(:select-list(&select-list)),
		FollowingSiblingOperator => FollowingSiblingEvaluator.new(:select-list(&select-list)),
		PrecedingSiblingOperator => PrecedingSiblingEvaluator.new(:select-list(&select-list)),
		FollowingOperator => FollowingEvaluator.new(:select-list(&select-list)),
		PrecedingOperator => PrecedingEvaluator.new(:select-list(&select-list)),
		ElementOfOperator => ElementOfEvaluator.new(
			:select-list(&select-list),
			:select-relation(&select-relation),
		),
		ContainsOperator => ContainsEvaluator.new(
			:select-list(&select-list),
			:select-relation(&select-relation),
		),
		SubsetOperator => SubsetEvaluator.new(
			:select-list(&select-list),
			:select-relation(&select-relation),
		),
		SubsetOrEqualOperator => SubsetOrEqualEvaluator.new(
			:select-list(&select-list),
			:select-relation(&select-relation),
		),
		IdentityOperator => IdentityEvaluator.new(
			:select-list(&select-list),
			:select-relation(&select-relation),
		),
		DivisionOperator => DivisionEvaluator.new(
			:select-list(&select-list),
			:select-relation(&select-relation),
		),
		SortOperator => SortEvaluator.new(:select-list(&select-list)),
		MapOperator => MapEvaluator.new(:select-list(&select-list)),
		ReduceOperator => ReduceEvaluator.new(:select-list(&select-list)),
	);
	%evaluators
}

=begin pod

Sentinel substituted for C<$_> when extracting navigation queries from mold
C<when> blocks. See L<Qwiratry::Query::Extract>.

=end pod
class NavQueryTopic is export {
	multi method gist(--> Str) { 'NavQueryTopic' }
}

=begin pod

Match a node against a mold C<when-query>, including topic-rooted queries
extracted from C<when { $_ ⪪ ... }> blocks.

=end pod
our sub when-query-matches(Mu $query, Mu $node, Mu :$origin --> Bool) is export {
	$query.defined or return False;
	if query-uses-topic($query) {
		return mold-topic-matches($query, $node, :$origin);
	}
	node-matches($query, $node, :$origin);
}

sub query-uses-topic(Mu $query --> Bool) {
	$query ~~ NavQueryTopic and return True;
	if $query.can('subject') && $query.subject.defined {
		$query.subject ~~ NavQueryTopic and return True;
		$query.subject ~~ NavigationOperator and return query-uses-topic($query.subject);
	}
	if $query.can('left') && $query.can('right') {
		return query-uses-topic($query.left) || query-uses-topic($query.right);
	}
	False
}

sub mold-topic-matches(Mu $query, Mu $node, Mu :$origin --> Bool) {
	match-topic-chain($query, $node, :$origin);
}

sub match-topic-chain(Mu $query, Mu $node, Mu :$origin --> Bool) {
	given $query {
		when NavQueryTopic { True }
		when UnionOperator {
			return match-topic-chain(.left, $node, :$origin)
				|| match-topic-chain(.right, $node, :$origin);
		}
		when IntersectionOperator {
			return match-topic-chain(.left, $node, :$origin)
				&& match-topic-chain(.right, $node, :$origin);
		}
		when SetDifferenceOperator {
			return match-topic-chain(.left, $node, :$origin)
				&& !match-topic-chain(.right, $node, :$origin);
		}
		when SymmetricDifferenceOperator {
			my $left = match-topic-chain(.left, $node, :$origin);
			my $right = match-topic-chain(.right, $node, :$origin);
			return ($left && !$right) || (!$left && $right);
		}
		when ChildOperator {
			selector.matches(.selector, $node) or return False;
			.subject ~~ NavQueryTopic and return True;
			my $parent = tree-parent($node, :$origin);
			$parent.defined or return False;
			match-topic-chain(.subject, $parent, :$origin);
		}
		when DescendantOperator {
			selector.matches(.selector, $node) or return False;
			.subject ~~ NavQueryTopic and return True;
			match-topic-chain(.subject, $node, :$origin);
		}
		default {
			my $leaf = navigation-leaf($query);
			$leaf.defined && $leaf.can('selector') or return False;
			selector.matches($leaf.selector, $node);
		}
	}
}

sub navigation-leaf(Mu $query --> Mu) {
	if $query.can('subject') && $query.subject.defined
			&& $query.subject ~~ NavigationOperator {
		return navigation-leaf($query.subject);
	}
	$query
}

=begin pod

Return a lazy sequence of nodes matching C<$query> from C<$origin>.

=end pod
our sub select(Mu $query, Mu $origin --> Seq) is export {
	select-seq($query, $origin);
}

=begin pod

Return True when C<$node> appears in the result of C<select($query, $origin)>.

=end pod
our sub node-matches(Mu $query, Mu $node, Mu :$origin --> Bool) is export {
	my $start = query-origin($query, $origin);
	for select-list($query, $start) -> $candidate {
		$candidate === $node and return True;
	}
	False
}

sub select-list(Mu $query, Mu $origin --> List) {
	$query.defined or return ();
	select-seq($query, $origin).list;
}

sub select-seq(Mu $query, Mu $origin --> Seq) {
	$query.defined or return ().Seq;

	given $query {
		when SelectionOperator {
			my $evaluator = evaluators(){$query.evaluator-key}
				// die "No evaluator registered for {$query.^name}";
			return $evaluator.select-seq(
				$query,
				$origin,
				:&selection-relation-source,
				:&selection-predicate-matches,
			);
		}
		when LazyEvaluatedOperator {
			my $evaluator = evaluators(){$query.evaluator-key}
				// die "No evaluator registered for {$query.^name}";
			return $evaluator.select-seq($query, $origin, :&relation-source);
		}
		default {
			my @items = select-list-eager($query, $origin);
			@items or return ().Seq;
			return lazy-from-list(@items);
		}
	}
}

sub relation-source(Mu $operand, Mu $origin) {
	if $operand ~~ NavigationOperator | SetOperator | MapReduceOperator | AdaptorOperator | RootOperator {
		return select-seq($operand, $origin);
	}
	if $operand ~~ Iterator | Positional {
		return $operand;
	}
	select-seq($operand, $origin);
}

sub select-list-eager(Mu $query, Mu $origin --> List) {
	$query.defined or return ();

	given $query {
		when EagerEvaluatedOperator {
			my $evaluator = evaluators(){$query.evaluator-key}
				// die "No eager evaluator registered for {$query.^name}";
			return $evaluator.eager($query, $origin);
		}
		default {
			if is-union-query-list($query) {
				my @combined;
				for $query.list -> $branch {
					@combined.append(select-list($branch, $origin));
				}
				return unique-nodes(|@combined);
			}
			return ();
		}
	}
}

sub query-origin(Mu $query, Mu $fallback --> Mu) {
	if $query.can('subject') && $query.subject.defined {
		if $query.subject ~~ NavigationOperator {
			return query-origin($query.subject, $fallback);
		}
		return $query.subject;
	}
	$fallback
}

sub tree-children(Mu $node --> List) {
	$node ~~ Positional and return $node.list;
	if $node ~~ Associative {
		if $node<children> ~~ Positional {
			return $node<children>.list;
		}
	}
	();
}

sub tree-parent(Mu $node, Mu :$origin --> Mu) {
	$node.can('parent') and return $node.parent;
	$origin.defined and return find-parent-in-tree($node, $origin);
	Nil
}

our sub find-parent-in-tree(Mu $node, Mu $current --> Mu) is export {
	$current.defined or return Nil;
	for tree-children($current) -> $child {
		$child === $node and return $current;
		my $found = find-parent-in-tree($node, $child);
		$found.defined and return $found;
	}
	Nil
}

sub is-union-query-list(Mu $query --> Bool) {
	$query.WHAT === Array || $query.WHAT === List or return False;
	$query.elems > 0 && $query[0] ~~ NavigationOperator;
}

sub unique-nodes(*@nodes --> List) {
	my @unique;
	for @nodes -> $node {
		next if relational.node-in-list($node, @unique);
		@unique.push($node);
	}
	@unique
}

sub selection-predicate-matches(&pred, Mu $base --> Bool) {
	my $result = try {
		if &pred.arity == 1 {
			pred($base).Bool;
		}
		else {
			(with $base { pred() }).Bool;
		}
	};
	return $result // False;
}

sub relation-row-snapshot(Mu $source) {
	$source ~~ Positional and return Array.new($source.list);
	$source
}

sub selection-relation-source(Mu $query, Mu $origin) {
	if $query.subject ~~ NavigationOperator | RootOperator {
		return select-seq($query.subject, $origin);
	}
	if $query.subject ~~ AdaptorOperator {
		return $origin ~~ Positional ?? $origin !! ($origin,);
	}
	if $query.subject ~~ Qwiratry::Table::Catalog {
		return $query.subject.active-rows;
	}
	if $query.subject ~~ Iterator {
		return $query.subject;
	}
	if $query.subject ~~ Positional {
		return relation-row-snapshot($query.subject);
	}
	if $query.subject.defined {
		return ($query.subject,);
	}
	if $origin ~~ Qwiratry::Table::Catalog {
		return $origin.active-rows;
	}
	if $origin ~~ Positional {
		return relation-row-snapshot($origin);
	}
	($origin,);
}

sub select-relation(Mu $operand, Mu $origin --> List) {
	if $operand ~~ Positional {
		$operand ~~ NavigationOperator or return $operand.list;
	}
	select-list($operand, $origin)
}
