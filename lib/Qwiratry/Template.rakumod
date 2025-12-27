=begin pod

Template class for pattern-matching transformation rules

This module provides the Template class that represents individual
transformation rules within a Transformer. Templates consist of
a `when` block (matcher) and a `do` block (action), along with
metadata for ordering (priority, specificity, tie-breaker).

=end pod
unit module Qwiratry::Template;

=begin pod

Template class representing a match-and-action rule within a Transformer.

Templates define how nodes are selected (via `when` block) and transformed
(via `do` block). Templates are ordered by priority → specificity → tie-breaker
to determine which template applies when multiple could match.

Example:
  template section() when { $_.name eq 'section' } do {
      make Node.new(name => $_.name);
  }

=end pod
class Template {
    #| Optional template name (makes template callable as method on transformer)
    has Str $.name;
    
    #| Optional template signature (for parameters)
    has Signature $.signature;
    
    #| Code block for matching nodes (template matcher)
    #| Evaluated against each node during transformation
    #| Returns True if template should apply to this node
    has Block $.when-block;
    
    #| Code block for producing output (template action)
    #| Executed when template matches a node
    #| Produces output via `make` or return value
    has Block $.do-block;
    
    #| Template priority (from `:priority` trait, default 0)
    #| Higher priority templates are tried first
    has Int $.priority = 0;
    
    #| Calculated specificity score (cached after calculation)
    #| Higher specificity templates are tried first when priority is equal
    has Int $.specificity;
    
    #| Tie-breaker value (from `:tie-breaker` trait, default 0)
    #| Used to break ties when priority and specificity are equal
    has Int $.tie-breaker = 0;
    
    #| Whether template has `:streaming` trait
    #| Streaming templates can produce lazy iterators
    has Bool $.streaming = False;
    
    #| Output type constraint (from `returns(Type)` trait)
    #| Enforces the type of output returned by template
    has Mu $.returns-type;
    
    #| Constructor
    submethod BUILD(
        :$!name,
        :$!signature,
        :$!when-block!,
        :$!do-block!,
        :$!priority = 0,
        :$!specificity,
        :$!tie-breaker = 0,
        :$!streaming = False,
        :$!returns-type
    ) {
        # All attributes set via BUILD parameters
    }
    
    =begin pod

    Evaluates `when` block against node, returns True if matches.

    This method will be implemented in WP05 (template execution).
    For WP03, this is a stub that returns False.

    @param $node - Node to match against
    @returns Bool - True if template matches node

    =end pod
    method matches($node --> Bool) {
        # Stub for WP03 - will be implemented in WP05
        # Will evaluate $.when-block with $node as $_
        False
    }
    
    =begin pod

    Executes `do` block with magic variables set, returns result.

    This method will be implemented in WP05 (template execution).
    For WP03, this is a stub that returns Nil.

    @param $node - Node to transform
    @param :$context - Optional context (defaults to $*CONTEXT)
    @returns Iterator|Mu|List|Nil - Transformation result

    =end pod
    method execute($node, :$context --> Mu) {
        # Stub for WP03 - will be implemented in WP05
        # Will execute $.do-block with $*CONTEXT set to $node
        Nil
    }
}
