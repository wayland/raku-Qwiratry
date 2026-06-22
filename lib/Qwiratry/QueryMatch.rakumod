=begin pod

=head1 Overview

Represents a successful match of a Query AST against a data element.

Passed to L<Qwiratry::Strategy> C<on-match> hooks so strategies can inspect
the query, element, and traversal origin for rewrites or analysis.

The object is intentionally small: it is a snapshot of "what matched" rather
than a mutable traversal controller. Strategies that need counters, accumulators,
or rewrite queues should store those in the active L<Qwiratry::Context>.

=end pod
unit module Qwiratry::QueryMatch;

=begin pod

=head1 Class

C<QueryMatch> records a matched element, the query AST fragment that matched it,
the traversal origin, and an optional path when a walker can provide one.

=end pod
class QueryMatch is export {
	has Mu $.element is required;
	has Mu $.query is required;
	has Mu $.origin;
	has Mu $.path;

	=begin pod

	=head1 Methods

	=head2 C<gist()>

	=begin code
	method gist(--> Str)
	=end code

	Returns a compact label for diagnostics and strategy debugging.

	=end pod
	method gist(--> Str) {
		"QueryMatch(element => {$!element.gist}, query => {$!query.^name})"
	}
}
