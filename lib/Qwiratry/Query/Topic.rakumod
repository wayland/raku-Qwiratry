=begin pod

=head1 Overview

Sentinel values used while extracting topic-rooted query expressions.

=end pod
unit module Qwiratry::Query::Topic;

class NavQueryTopic is export {
	multi method gist(--> Str) { 'NavQueryTopic' }
}
