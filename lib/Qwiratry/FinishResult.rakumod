=begin pod

FinishResult class for Strategy.finish() hook results

This module provides the FinishResult class that contains
traversal outcomes with a type identifier and optional value.

Usage:
  my $result = FinishResult.new(type => 'final-result', value => $data);
  say $result.gist;  # Human-readable representation

=end pod
unit module Qwiratry::FinishResult;

=begin pod

Result object returned from Strategy.finish() hook.
Contains the traversal outcome with a type identifier and optional value.

=end pod
class FinishResult is export {
    # Result type identifier (e.g., 'final-result', 'aggregated', 'error')
    # This is a required parameter when constructing a FinishResult.
    has Str $.type is required;
    
    # The result value (can be any type including Nil)
    # Optional - defaults to Nil if not provided.
    has $.value;
    
    # Human-readable representation of the result.
    # Format: FinishResult(type: <type>, value: <value.gist>)
    method gist(--> Str) {
        "FinishResult(type: $.type, value: {$.value.gist})"
    }
}
