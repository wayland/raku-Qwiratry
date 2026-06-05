=begin pod

Template class for pattern-matching transformation rules

This module provides the Template class that represents individual
transformation rules within a Transformer. Templates consist of
a `when` block (matcher) and a `do` block (action), along with
metadata for ordering (priority, specificity, tie-breaker).

=end pod
unit module Qwiratry::Template;

use X::Qwiratry;  # For X::Qwiratry::TypeCheck

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
class Template is export {
    # Optional template name (makes template callable as method on transformer)
    has Str $.name;
    
    # Optional template signature (for parameters)
    has Signature $.signature;
    
    =begin pod
    
    Code block for matching nodes (template matcher).
    Evaluated against each node during transformation.
    Returns True if template should apply to this node.
    
    =end pod
    has Block $.when-block;
    
    =begin pod
    
    Code block for producing output (template action).
    Executed when template matches a node.
    Produces output via `make` or return value.
    
    =end pod
    has Block $.do-block;
    
    =begin pod
    
    Template priority (from `:priority` trait, default 0).
    Higher priority templates are tried first.
    
    =end pod
    has Int $.priority = 0;
    
    =begin pod
    
    Calculated specificity score (cached after calculation).
    Higher specificity templates are tried first when priority is equal.
    
    =end pod
    has Int $.specificity;
    
    =begin pod
    
    Tie-breaker value (from `:tie-breaker` trait, default 0).
    Used to break ties when priority and specificity are equal.
    
    =end pod
    has Int $.tie-breaker = 0;
    
    =begin pod
    
    Whether template has `:streaming` trait.
    Streaming templates can produce lazy iterators.
    
    =end pod
    has Bool $.streaming = False;
    
    =begin pod
    
    Output type constraint (from `returns(Type)` trait).
    Enforces the type of output returned by template.
    
    =end pod
    has Mu $.returns-type;
    
    # Constructor
    submethod BUILD(
        :$name,
        :$signature,
        :$when-block,
        :$!do-block!,
        :$!priority = 0,
        :$specificity,
        :$!tie-breaker = 0,
        :$!streaming = False,
        :$returns-type
    ) {
        $!name = $name if $name.defined;
        $!signature = $signature if $signature.defined;
        $!when-block = $when-block if $when-block.defined;
        $!specificity = $specificity if $specificity.defined;
        $!returns-type = $returns-type if $returns-type.defined;
    }
    
    =begin pod

    Evaluates `when` block against node, returns True if matches.

    Sets magic variables ($*CONTEXT, $_) before evaluating the when block.
    Handles errors gracefully by returning False if evaluation fails.

    @param $node - Node to match against
    @returns Bool - True if template matches node

    =end pod
    method matches($node --> Bool) {
        # T021/T024: Set magic variables and evaluate when block
        # If no when block, template always matches (default behavior)
        if !$!when-block.defined {
            return True;
        }
        
        # Set magic variables for when block evaluation
        # T021: Set $*CONTEXT and $_ to current node
        # Note: $_ is the topic variable and cannot be declared with 'my'
        # We'll set it by calling the block with $node as the topic
        my $*CONTEXT = $node;
        
        # Execute when block with magic variables set
        # Pass $node as topic ($_) to the block
        # Coerce result to Bool and handle errors
        {
            my $result = self!invoke-block($!when-block, $node);
            return ?$result;
            CATCH {
                return False;
            }
        }
    }

    method !invoke-block($block, $node) {
        return $block($node) if $block.arity == 1;
        return do with $node { $block() };
    }
    
    =begin pod

    Executes `do` block with magic variables set, returns result.

    Sets all magic variables ($*CONTEXT, $_, $*CAPTURE, $/, self) before
    executing the do block. Handles both `make` calls and return values.

    @param $node - Node to transform
    @param :$transformer - Transformer instance (for self reference)
    @param :$context - Optional context (defaults to $node)
    @returns Iterator|Mu|List|Nil - Transformation result

    =end pod
    method execute($node, :$transformer, :$context --> Mu) {
        # T021: Set $*CONTEXT and $_ to current node
        # Note: $_ is the topic variable and will be set by passing $node to the block
        my $*CONTEXT = $context // $node;
        
        # T022: Set $*CAPTURE and $/ if template has signature
        # For now, we'll set them to Nil if no signature
        # Full signature matching will be implemented when query operators are available
        # Note: $/ is a special variable and cannot be declared with 'my'
        my $*CAPTURE = Nil;
        $/ = $*CAPTURE;
        
        if $!signature.defined {
            # TODO: Match node against signature to capture parameters
            # This will require coordination with query system
            # For MVP, we'll leave $*CAPTURE as Nil
            # Future: $*CAPTURE = $node ~~ $!signature;
        }
        
        # T023: self is automatically available in Raku blocks
        # However, we need to ensure the block executes in the transformer's context
        # We'll call the block with the transformer bound to self via closure
        # Actually, in Raku, blocks capture their lexical scope, so self from
        # the transformer's method context should be available
        
        # Execute do block with magic variables set
        if !$!do-block.defined {
            return Nil;
        }
        
        # T025: Execute do block and handle results
        # Pass $node as topic ($_) to the block
        # Support both make and return value patterns
        my $result = self!invoke-block($!do-block, $node);
        
        # T050: Execute WRAP_TEMPLATE_ACTION wrapper around template action execution
        # The wrapper receives node and action result, can modify action result or perform side effects
        # Wrappers are called as submethods on the transformer, which automatically traverse the hierarchy via MRO
        if $transformer.defined {
            try {
                $result = $transformer.WRAP_TEMPLATE_ACTION($node, $result);
                CATCH {
                    when X::Method::NotFound { }
                }
            }
        }
        
        # T053: Check returns(Type) trait if present on template
        if $!returns-type.WHICH ne Mu.WHICH {
            unless $result ~~ $!returns-type {
                X::Qwiratry::TypeCheck.new(
                    expected => $!returns-type,
                    got => $result.WHAT,
                    message => "Template result does not match returns type constraint"
                ).throw;
            }
        }
        
        # If result is Nil, return Nil
        # Otherwise return the result (could be Iterator, List, single value)
        return $result;
    }
}
