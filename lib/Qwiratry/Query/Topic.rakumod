=begin pod

=head1 Overview

Sentinel values used while extracting topic-rooted query expressions.

=end pod
unit module Qwiratry::Query::Topic;

=begin pod

=head2 C<class NavQueryTopic>

=begin code :lang<raku>
class NavQueryTopic is export
=end code

Defines C<NavQueryTopic>.

=end pod
class NavQueryTopic is export {
	=begin pod

	=head2 C<method gist>

	=begin code :lang<raku>
	multi method gist(--> Str)
	=end code

	Documents C<method gist>.

	=end pod
	multi method gist(--> Str) { 'NavQueryTopic' }
}
