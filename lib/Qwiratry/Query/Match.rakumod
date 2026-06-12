=begin pod

Evaluate navigation Query AST nodes against tree-shaped Raku data.

Provides lazy C<select> to find matching nodes and C<node-matches> to test
membership. Used by L<Qwiratry::Walker::Implementation::Tree> and template
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
use Qwiratry::Query::TableNav;
use Qwiratry::Query::Lazy;
use Qwiratry::Table;

my sub relational() { Qwiratry::Query::Relational.instance }

=begin pod

Sentinel substituted for C<$_> when extracting navigation queries from template
C<when> blocks. See L<Qwiratry::Query::Extract>.

=end pod
class NavQueryTopic is export {
	multi method gist(--> Str) { 'NavQueryTopic' }
}

=begin pod

Match a node against a template C<when-query>, including topic-rooted queries
extracted from C<when { $_ ⪪ ... }> blocks.

=end pod
our sub when-query-matches(Mu $query, Mu $node, Mu :$origin --> Bool) is export {
	return False unless $query.defined;
	if query-uses-topic($query) {
		return template-topic-matches($query, $node, :$origin);
	}
	node-matches($query, $node, :$origin);
}

sub query-uses-topic(Mu $query --> Bool) {
	return True if $query ~~ NavQueryTopic;
	if $query.can('subject') && $query.subject.defined {
		return True if $query.subject ~~ NavQueryTopic;
		return query-uses-topic($query.subject) if $query.subject ~~ NavigationOperator;
	}
	False
}

sub template-topic-matches(Mu $query, Mu $node, Mu :$origin --> Bool) {
	match-topic-chain($query, $node, :$origin);
}

sub match-topic-chain(Mu $query, Mu $node, Mu :$origin --> Bool) {
	given $query {
		when NavQueryTopic { True }
		when ChildOperator {
			return False unless selector-matches(.selector, $node);
			return True if .subject ~~ NavQueryTopic;
			my $parent = tree-parent($node, :$origin);
			return False unless $parent.defined;
			match-topic-chain(.subject, $parent, :$origin);
		}
		when DescendantOperator {
			return False unless selector-matches(.selector, $node);
			return True if .subject ~~ NavQueryTopic;
			match-topic-chain(.subject, $node, :$origin);
		}
		default {
			my $leaf = navigation-leaf($query);
			return False unless $leaf.defined && $leaf.can('selector');
			selector-matches($leaf.selector, $node);
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
		return True if $candidate === $node;
	}
	False
}

sub select-list(Mu $query, Mu $origin --> List) {
	return () unless $query.defined;
	select-seq($query, $origin).list;
}

sub select-seq(Mu $query, Mu $origin --> Seq) {
	return ().Seq unless $query.defined;

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
			return ().Seq unless @items;
			return lazy-from-list(@items);
		}
	}
}

sub relation-source(Mu $operand, Mu $origin) {
	if $operand ~~ NavigationOperator | SetOperator | MapReduceOperator | IOOperator | RootOperator {
		return select-seq($operand, $origin);
	}
	if $operand ~~ Iterator | Positional {
		return $operand;
	}
	select-seq($operand, $origin);
}

sub select-list-eager(Mu $query, Mu $origin --> List) {
	return () unless $query.defined;

	given $query {
		when RootOperator {
			my $base = $query.subject.defined ?? $query.subject !! $origin;
			return ($base,);
		}
		when ChildOperator {
			my @bases = resolve-bases($query, $origin);
			my $catalog = table-catalog($origin);
			my @results;
			for @bases -> $base {
				if $catalog.defined {
					@results.append(table-child-results($base, $query, $catalog));
				}
				else {
					for tree-children($base) -> $child {
						@results.push($child) if selector-matches($query.selector, $child);
					}
				}
			}
			return @results;
		}
		when DescendantOperator {
			my @bases = resolve-bases($query, $origin);
			my $catalog = table-catalog($origin);
			my @results;
			for @bases -> $base {
				if $catalog.defined {
					@results.append(table-descendant-results($base, $query, $catalog));
				}
				else {
					for tree-descendants($base) -> $desc {
						@results.push($desc) if selector-matches($query.selector, $desc);
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
				@results.push($value) if $value.defined;
			}
			return @results;
		}
		when ParentOperator {
			my @bases = resolve-bases($query, $origin);
			my $catalog = table-catalog($origin);
			my @results;
			for @bases -> $base {
				if $catalog.defined {
					@results.append(table-parent-results($base, $query, $catalog));
				}
				else {
					my $parent = tree-parent($base, :$origin);
					@results.push($parent) if $parent.defined
						&& selector-matches($query.selector, $parent);
				}
			}
			return @results;
		}
		when AncestorOperator {
			my @bases = resolve-bases($query, $origin);
			my $catalog = table-catalog($origin);
			my @results;
			for @bases -> $base {
				if $catalog.defined {
					@results.append(table-parent-results($base, $query, $catalog));
				}
				else {
					for tree-ancestors($base, :$origin) -> $anc {
						@results.push($anc) if selector-matches($query.selector, $anc);
					}
				}
			}
			return @results;
		}
		when FollowingSiblingOperator | PrecedingSiblingOperator
				| FollowingOperator | PrecedingOperator {
			my @bases = resolve-bases($query, $origin);
			my $catalog = table-catalog($origin);
			my @results;
			for @bases -> $base {
				if $catalog.defined && table-row-base($base) {
					@results.append(table-sibling-results($base, $query, $catalog));
					next;
				}
				my @siblings = sibling-context($base, :$origin)<all>;
				my $index = sibling-index(@siblings, $base);
				next unless $index.defined;
				my @candidates = sibling-candidates($query, @siblings, $index);
				for @candidates -> $candidate {
					@results.push($candidate)
						if selector-matches($query.selector, $candidate);
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
				@results.push($elem) if relational.row-in-list($elem, @collection);
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
			elsif $query.subject ~~ IOOperator {
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
			return () unless @items;
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
	return $node.list if $node ~~ Positional;
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
	return $node.parent if $node.can('parent');
	return find-parent-in-tree($node, $origin) if $origin.defined;
	Nil
}

our sub find-parent-in-tree(Mu $node, Mu $current --> Mu) is export {
	return Nil unless $current.defined;
	for tree-children($current) -> $child {
		return $current if $child === $node;
		my $found = find-parent-in-tree($node, $child);
		return $found if $found.defined;
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
	return %(all => tree-children($parent)) if $parent.defined;
	%(all => ());
}

sub sibling-index(@siblings, Mu $node) {
	for 0..^@siblings -> $i {
		return $i if @siblings[$i] === $node;
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
	my $name = normalize-key($key);
	if $node ~~ Associative && $node{$name}:exists {
		return $node{$name};
	}
	if $node.can($name) {
		return $node.$name;
	}
	Nil
}

sub normalize-key(Mu $key --> Str) {
	return $key if $key ~~ Str;
	if $key ~~ List && $key.elems == 1 {
		return normalize-key($key[0]);
	}
	~$key
}

sub selector-matches(Mu $selector, Mu $node --> Bool) {
	return True if is-wildcard-selector($selector);
	if $selector ~~ List {
		return True if $selector.grep({ selector-matches($_, $node) }).so;
		return False;
	}
	if $selector ~~ Str {
		my $name = node-name($node);
		return $name.defined && $name eq normalize-selector-name($selector);
	}
	False
}

sub normalize-selector-name(Str $selector --> Str) {
	return $selector.substr(1, *-2) if $selector.starts-with('<') && $selector.ends-with('>');
	$selector
}

sub is-wildcard-selector(Mu $selector --> Bool) {
	return True if $selector ~~ Whatever;
	return True if $selector ~~ Str && $selector eq any(<* **>);
	False
}

sub node-name(Mu $node --> Mu) {
	return $node if $node ~~ Str;
	if $node ~~ Associative {
		for <name tag type> -> $field {
			return ~($node{$field}) if $node{$field}:exists;
		}
	}
	Nil
}

sub is-union-query-list(Mu $query --> Bool) {
	return False unless $query.WHAT === Array || $query.WHAT === List;
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
		if $query.subject ~~ IOOperator {
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
	return Array.new($source.list) if $source ~~ Positional;
	$source
}

sub selection-relation-source(Mu $query, Mu $origin) {
	if $query.subject ~~ NavigationOperator | RootOperator {
		return select-seq($query.subject, $origin);
	}
	if $query.subject ~~ IOOperator {
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
		return $operand.list unless $operand ~~ NavigationOperator;
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
