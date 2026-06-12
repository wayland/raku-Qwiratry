=begin pod

Represents a successful match of a Query AST against a data element.

Passed to L<Qwiratry::Strategy> C<on-match> hooks so strategies can inspect
the query, element, and traversal origin for rewrites or analysis.

=end pod
unit module Qwiratry::QueryMatch;

=begin pod

Match result for a query against a single element during traversal.

=end pod
class QueryMatch is export {
	has Mu $.element is required;
	has Mu $.query is required;
	has Mu $.origin;
	has Mu $.path;

	method gist(--> Str) {
		"QueryMatch(element => {$!element.gist}, query => {$!query.^name})"
	}
}
