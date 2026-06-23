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

use Qwiratry::Query::Runtime;

my constant runtime = Qwiratry::Query::Runtime.new;

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
	runtime.when-query-matches($query, $node, :$origin);
}

=begin pod

Return a lazy sequence of nodes matching C<$query> from C<$origin>.

=end pod
our sub select(Mu $query, Mu $origin --> Seq) is export {
	runtime.select($query, $origin);
}

=begin pod

Return True when C<$node> appears in the result of C<select($query, $origin)>.

=end pod
our sub node-matches(Mu $query, Mu $node, Mu :$origin --> Bool) is export {
	runtime.node-matches($query, $node, :$origin);
}

our sub find-parent-in-tree(Mu $node, Mu $current --> Mu) is export {
	runtime.find-parent-in-tree($node, $current);
}
