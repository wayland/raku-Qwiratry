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
use Qwiratry::Table;
use Qwiratry::Table::Schema;
use Qwiratry::Query::Selector;

my sub relational() { Qwiratry::Query::Relational.instance }
my constant selector = Qwiratry::Query::Selector.instance;

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
	False
}

sub mold-topic-matches(Mu $query, Mu $node, Mu :$origin --> Bool) {
	match-topic-chain($query, $node, :$origin);
}

sub match-topic-chain(Mu $query, Mu $node, Mu :$origin --> Bool) {
	given $query {
		when NavQueryTopic { True }
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
		when UnionOperator {
			return lazy-union(
				relation-source($query.left, $origin),
				relation-source($query.right, $origin),
			);
		}
		when IntersectionOperator {
			return lazy-intersection(
				relation-source($query.left, $origin),
				relation-source($query.right, $origin),
			);
		}
		when SetDifferenceOperator {
			return lazy-set-difference(
				relation-source($query.left, $origin),
				relation-source($query.right, $origin),
			);
		}
		when SymmetricDifferenceOperator {
			return lazy-symmetric-difference(
				relation-source($query.left, $origin),
				relation-source($query.right, $origin),
			);
		}
		when InnerJoinOperator {
			my &cond = $query.condition.defined ?? $query.condition !! Nil;
			return lazy-natural-join(
				relation-source($query.left, $origin),
				relation-source($query.right, $origin),
				&cond,
			);
		}
		when LeftOuterJoinOperator {
			my &cond = $query.condition.defined ?? $query.condition !! Nil;
			return lazy-left-outer-join(
				relation-source($query.left, $origin),
				relation-source($query.right, $origin),
				&cond,
			);
		}
		when RightOuterJoinOperator {
			my &cond = $query.condition.defined ?? $query.condition !! Nil;
			return lazy-right-outer-join(
				relation-source($query.left, $origin),
				relation-source($query.right, $origin),
				&cond,
			);
		}
		when FullOuterJoinOperator {
			my &cond = $query.condition.defined ?? $query.condition !! Nil;
			my $left = relation-source($query.left, $origin);
			my $right = relation-source($query.right, $origin);
			return lazy-union(
				lazy-natural-join($left, $right, &cond),
				lazy-left-antijoin($left, $right, &cond),
				lazy-left-antijoin($right, $left, &cond),
			);
		}
		when LeftSemijoinOperator {
			my &cond = $query.condition.defined ?? $query.condition !! Nil;
			return lazy-left-semijoin(
				relation-source($query.left, $origin),
				relation-source($query.right, $origin),
				&cond,
			);
		}
		when RightSemijoinOperator {
			my &cond = $query.condition.defined ?? $query.condition !! Nil;
			return lazy-left-semijoin(
				relation-source($query.right, $origin),
				relation-source($query.left, $origin),
				&cond,
			);
		}
		when LeftAntijoinOperator {
			my &cond = $query.condition.defined ?? $query.condition !! Nil;
			return lazy-left-antijoin(
				relation-source($query.left, $origin),
				relation-source($query.right, $origin),
				&cond,
			);
		}
		when RightAntijoinOperator {
			my &cond = $query.condition.defined ?? $query.condition !! Nil;
			return lazy-left-antijoin(
				relation-source($query.right, $origin),
				relation-source($query.left, $origin),
				&cond,
			);
		}
		when CrossJoinOperator {
			return lazy-cross-join(
				relation-source($query.left, $origin),
				relation-source($query.right, $origin),
			);
		}
		when ProjectionOperator {
			return lazy-projection(
				relation-source($query.relation, $origin),
				$query.columns,
			);
		}
		when RenameOperator {
			return lazy-rename(
				relation-source($query.relation, $origin),
				$query.renames,
			);
		}
		when SelectionOperator {
			my $source = selection-relation-source($query, $origin);
			my &pred = $query.predicate;
			return lazy-filter($source, -> $base { selection-predicate-matches(&pred, $base) });
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
		when RootOperator {
			my $base = $query.subject.defined ?? $query.subject !! $origin;
			return ($base,);
		}
		when ChildOperator {
			my @bases = resolve-bases($query, $origin);
			my $catalog = Qwiratry::Table::Schema.instance.discover($origin);
			my @results;
			for @bases -> $base {
				if $catalog.defined {
					@results.append($catalog.child-results($base, $query));
				}
				else {
					for tree-children($base) -> $child {
						selector.matches($query.selector, $child) and @results.push($child);
					}
				}
			}
			return @results;
		}
		when DescendantOperator {
			my @bases = resolve-bases($query, $origin);
			my $catalog = Qwiratry::Table::Schema.instance.discover($origin);
			my @results;
			for @bases -> $base {
				if $catalog.defined {
					@results.append($catalog.descendant-results($base, $query));
				}
				else {
					for tree-descendants($base) -> $desc {
						selector.matches($query.selector, $desc) and @results.push($desc);
					}
				}
			}
			return @results;
		}
		when AttributeOperator {
			my @bases = resolve-bases($query, $origin);
			my @results;
			for @bases -> $base {
				my $value = attribute-value($base, $query.key);
				$value.defined and @results.push($value);
			}
			return @results;
		}
		when ParentOperator {
			my @bases = resolve-bases($query, $origin);
			my $catalog = Qwiratry::Table::Schema.instance.discover($origin);
			my @results;
			for @bases -> $base {
				if $catalog.defined {
					@results.append($catalog.parent-results($base, $query));
				}
				else {
					my $parent = tree-parent($base, :$origin);
					@results.push($parent) if $parent.defined
						&& selector.matches($query.selector, $parent);
				}
			}
			return @results;
		}
		when AncestorOperator {
			my @bases = resolve-bases($query, $origin);
			my $catalog = Qwiratry::Table::Schema.instance.discover($origin);
			my @results;
			for @bases -> $base {
				if $catalog.defined {
					@results.append($catalog.parent-results($base, $query));
				}
				else {
					for tree-ancestors($base, :$origin) -> $anc {
						selector.matches($query.selector, $anc) and @results.push($anc);
					}
				}
			}
			return @results;
		}
		when FollowingSiblingOperator | PrecedingSiblingOperator
				| FollowingOperator | PrecedingOperator {
			my @bases = resolve-bases($query, $origin);
			my $catalog = Qwiratry::Table::Schema.instance.discover($origin);
			my @results;
			for @bases -> $base {
				if $catalog.defined && $catalog.is-table-row($base) {
					@results.append($catalog.sibling-results($base, $query));
					next;
				}
				my @siblings = sibling-context($base, :$origin)<all>;
				my $index = sibling-index(@siblings, $base);
				next unless $index.defined;
				my @candidates = sibling-candidates($query, @siblings, $index);
				for @candidates -> $candidate {
					if selector.matches($query.selector, $candidate) {
						@results.push($candidate);
					}
				}
			}
			return @results;
		}
		when UnionOperator {
			my @left = select-relation($query.left, $origin);
			my @right = select-relation($query.right, $origin);
			return unique-nodes(|@left, |@right);
		}
		when IntersectionOperator {
			my @left = select-relation($query.left, $origin);
			my @right = select-relation($query.right, $origin);
			return @left.grep(-> $node { relational.node-in-list($node, @right) }).List;
		}
		when SetDifferenceOperator {
			my @left = select-relation($query.left, $origin);
			my @right = select-relation($query.right, $origin);
			return @left.grep(-> $node { !relational.node-in-list($node, @right) }).List;
		}
		when SymmetricDifferenceOperator {
			my @left = select-relation($query.left, $origin);
			my @right = select-relation($query.right, $origin);
			return relational.symmetric-difference(@left, @right).List;
		}
		when ElementOfOperator {
			my @collection = select-list($query.collection, $origin);
			my @elements = select-list($query.element, $origin);
			my @results;
			for @elements -> $elem {
				relational.row-in-list($elem, @collection) and @results.push($elem);
			}
			return @results;
		}
		when ContainsOperator {
			my @collection = select-list($query.collection, $origin);
			my @elements = select-list($query.element, $origin);
			return @collection.grep(-> $row {
				@elements.grep(-> $elem { relational.row-equal($elem, $row) }).so
			}).List;
		}
		when SubsetOperator {
			my @left = select-list($query.left, $origin);
			my @right = select-list($query.right, $origin);
			return relational.is-subset-of(@left, @right)
				&& !relational.collections-equal(@left, @right)
				?? @left.List !! ();
		}
		when SubsetOrEqualOperator {
			my @left = select-list($query.left, $origin);
			my @right = select-list($query.right, $origin);
			return relational.is-subset-of(@left, @right) ?? @left.List !! ();
		}
		when IdentityOperator {
			my @left = select-relation($query.left, $origin);
			my @right = select-relation($query.right, $origin);
			return relational.collections-equal(@left, @right) ?? @left.List !! ();
		}
		when ProjectionOperator {
			my @rows = select-list($query.relation, $origin);
			return @rows.map(-> $row {
				$row ~~ Associative ?? relational.project-row($row, $query.columns) !! $row
			}).List;
		}
		when RenameOperator {
			my @rows = select-list($query.relation, $origin);
			return @rows.map(-> $row {
				$row ~~ Associative ?? relational.rename-row($row, $query.renames) !! $row
			}).List;
		}
		when InnerJoinOperator {
			my @left = select-relation($query.left, $origin);
			my @right = select-relation($query.right, $origin);
			my &cond = $query.condition.defined ?? $query.condition !! Nil;
			return join-with-condition(&cond, "natural-join", @left, @right).List;
		}
		when LeftOuterJoinOperator {
			my @left = select-relation($query.left, $origin);
			my @right = select-relation($query.right, $origin);
			my &cond = $query.condition.defined ?? $query.condition !! Nil;
			return join-with-condition(&cond, "left-outer-join", @left, @right).List;
		}
		when RightOuterJoinOperator {
			my @left = select-relation($query.left, $origin);
			my @right = select-relation($query.right, $origin);
			my &cond = $query.condition.defined ?? $query.condition !! Nil;
			return join-with-condition(&cond, "right-outer-join", @left, @right).List;
		}
		when FullOuterJoinOperator {
			my @left = select-relation($query.left, $origin);
			my @right = select-relation($query.right, $origin);
			my &cond = $query.condition.defined ?? $query.condition !! Nil;
			return join-with-condition(&cond, "full-outer-join", @left, @right).List;
		}
		when LeftSemijoinOperator {
			my @left = select-relation($query.left, $origin);
			my @right = select-relation($query.right, $origin);
			my &cond = $query.condition.defined ?? $query.condition !! Nil;
			return join-with-condition(&cond, "left-semijoin", @left, @right).List;
		}
		when RightSemijoinOperator {
			my @left = select-relation($query.left, $origin);
			my @right = select-relation($query.right, $origin);
			my &cond = $query.condition.defined ?? $query.condition !! Nil;
			return join-with-condition(&cond, "right-semijoin", @left, @right).List;
		}
		when LeftAntijoinOperator {
			my @left = select-relation($query.left, $origin);
			my @right = select-relation($query.right, $origin);
			my &cond = $query.condition.defined ?? $query.condition !! Nil;
			return join-with-condition(&cond, "left-antijoin", @left, @right).List;
		}
		when RightAntijoinOperator {
			my @left = select-relation($query.left, $origin);
			my @right = select-relation($query.right, $origin);
			my &cond = $query.condition.defined ?? $query.condition !! Nil;
			return join-with-condition(&cond, "right-antijoin", @left, @right).List;
		}
		when CrossJoinOperator {
			my @left = select-relation($query.left, $origin);
			my @right = select-relation($query.right, $origin);
			return relational.cross-join(@left, @right).List;
		}
		when DivisionOperator {
			my @left = select-relation($query.left, $origin);
			my @right = select-relation($query.right, $origin);
			return relational.relational-division(@left, @right).List;
		}
		when SelectionOperator {
			my @bases;
			if $query.subject ~~ NavigationOperator | RootOperator {
				@bases = select-list($query.subject, $origin);
			}
			elsif $query.subject ~~ AdaptorOperator {
				@bases = $origin ~~ Positional ?? $origin.list !! ($origin,);
			}
			elsif $query.subject ~~ Qwiratry::Table::Catalog {
				@bases = $query.subject.active-rows;
			}
			elsif $query.subject ~~ Positional {
				@bases = $query.subject.list;
			}
			else {
				@bases = ($query.subject,);
			}
			if !@bases && $origin ~~ Qwiratry::Table::Catalog {
				@bases = $origin.active-rows;
			}
			my &pred = $query.predicate;
			return @bases.grep(-> $base { selection-predicate-matches(&pred, $base) }).List;
		}
		when SortOperator {
			my @items = mapreduce-items($query, $origin);
			my &key = $query.key-function;
			return @items.sort(-> $a, $b {
				code-result(&key, $a) cmp code-result(&key, $b)
			}).List;
		}
		when MapOperator {
			my @items = mapreduce-items($query, $origin);
			my &transform = $query.transform;
			return @items.map(-> $item { code-result(&transform, $item) }).List;
		}
		when ReduceOperator {
			my @items = mapreduce-items($query, $origin);
			@items or return ();
			my &op = $query.operation;
			my $acc = @items.shift;
			for @items -> $item {
				$acc = reduce-with(&op, $acc, $item);
			}
			return ($acc,);
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

sub resolve-bases(Mu $op, Mu $origin --> List) {
	if $op.can('subject') && $op.subject.defined {
		if $op.subject ~~ NavigationOperator {
			return select-list($op.subject, $origin);
		}
		return ($op.subject,);
	}
	return ($origin,);
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

sub tree-descendants(Mu $node --> Seq) {
	gather {
		for tree-children($node) -> $child {
			take $child;
			take $_ for tree-descendants($child);
		}
	}
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

sub tree-ancestors(Mu $node, Mu :$origin --> Seq) {
	gather {
		my $current = tree-parent($node, :$origin);
		while $current.defined {
			take $current;
			$current = tree-parent($current, :$origin);
		}
	}
}

sub sibling-context(Mu $node, Mu :$origin --> Associative) {
	my $parent = tree-parent($node, :$origin);
	$parent.defined and return %(all => tree-children($parent));
	%(all => ());
}

sub sibling-index(@siblings, Mu $node) {
	for 0..^@siblings -> $i {
		@siblings[$i] === $node and return $i;
	}
	Nil
}

sub sibling-candidates(Mu $op, @siblings, Int $index --> List) {
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

sub attribute-value(Mu $node, Mu $key --> Mu) {
	my $name = selector.normalize-key($key);
	if $node ~~ Associative && $node{$name}:exists {
		return $node{$name};
	}
	if $node.can($name) {
		return $node.$name;
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

sub mapreduce-items(Mu $query, Mu $origin --> List) {
	if $query.subject.defined {
		if $query.subject ~~ NavigationOperator | RootOperator | SetOperator | MapReduceOperator {
			return select-list($query.subject, $origin);
		}
		if $query.subject ~~ AdaptorOperator {
			return $origin ~~ Positional ?? $origin.list !! ($origin,);
		}
		if $query.subject ~~ Positional {
			return $query.subject.list;
		}
		return ($query.subject,);
	}
	if $origin ~~ Qwiratry::Table::Catalog {
		return $origin.active-rows;
	}
	if $origin ~~ Positional {
		return $origin.list;
	}
	($origin,);
}

sub code-result(&code, Mu $item --> Mu) {
	try {
		if &code.arity == 1 {
			code($item);
		}
		else {
			with $item { code() }
		}
	} orelse $item
}

sub reduce-with(&op, Mu $acc, Mu $item --> Mu) {
	try {
		if &op.arity == 2 {
			op($acc, $item);
		}
		elsif &op.arity == 1 {
			op($item);
		}
		else {
			with $acc { with $item { op() } }
		}
	} orelse $acc
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

sub join-with-condition(&cond, Str $join-method, @left, @right --> List) {
	my $rel = relational;
	if &cond.defined {
		return $rel.$join-method(@left, @right, &cond);
	}
	$rel.$join-method(@left, @right);
}
