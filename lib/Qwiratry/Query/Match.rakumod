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
    gather {
        take $_ for select-list($query, $origin);
    }
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

    given $query {
        when RootOperator {
            my $base = $query.subject.defined ?? $query.subject !! $origin;
            return ($base,);
        }
        when ChildOperator {
            my @bases = resolve-bases($query, $origin);
            my @results;
            for @bases -> $base {
                for tree-children($base) -> $child {
                    @results.push($child) if selector-matches($query.selector, $child);
                }
            }
            return @results;
        }
        when DescendantOperator {
            my @bases = resolve-bases($query, $origin);
            my @results;
            for @bases -> $base {
                for tree-descendants($base) -> $desc {
                    @results.push($desc) if selector-matches($query.selector, $desc);
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
            my @results;
            for @bases -> $base {
                my $parent = tree-parent($base, :$origin);
                @results.push($parent) if $parent.defined
                    && selector-matches($query.selector, $parent);
            }
            return @results;
        }
        when AncestorOperator {
            my @bases = resolve-bases($query, $origin);
            my @results;
            for @bases -> $base {
                for tree-ancestors($base, :$origin) -> $anc {
                    @results.push($anc) if selector-matches($query.selector, $anc);
                }
            }
            return @results;
        }
        when FollowingSiblingOperator | PrecedingSiblingOperator
                | FollowingOperator | PrecedingOperator {
            my @bases = resolve-bases($query, $origin);
            my @results;
            for @bases -> $base {
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
            my @left = select-list($query.left, $origin);
            my @right = select-list($query.right, $origin);
            return unique-nodes(|@left, |@right);
        }
        when IntersectionOperator {
            my @left = select-list($query.left, $origin);
            my @right = select-list($query.right, $origin);
            return @left.grep(-> $node { node-in-list($node, @right) }).List;
        }
        when SetDifferenceOperator {
            my @left = select-list($query.left, $origin);
            my @right = select-list($query.right, $origin);
            return @left.grep(-> $node { !node-in-list($node, @right) }).List;
        }
        when SelectionOperator {
            my @bases;
            if $query.subject ~~ NavigationOperator | RootOperator {
                @bases = select-list($query.subject, $origin);
            }
            elsif $query.subject ~~ Positional {
                @bases = $query.subject.list;
            }
            else {
                @bases = ($query.subject,);
            }
            my &pred = $query.predicate;
            return @bases.grep(-> $base { selection-predicate-matches(&pred, $base) }).List;
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
        next if node-in-list($node, @unique);
        @unique.push($node);
    }
    @unique
}

sub node-in-list(Mu $node, @list --> Bool) {
    for @list -> $candidate {
        return True if $candidate === $node;
    }
    False
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
