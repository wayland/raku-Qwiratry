=begin pod

Template class for pattern-matching transformation rules

This module provides the Template class that represents individual
transformation rules within a Transformer. Templates consist of
a `when` block (matcher) and a `do` block (action), along with
metadata for ordering (priority, specificity, tie-breaker).

=end pod
unit module Qwiratry::Template;

use X::Qwiratry;  # For X::Qwiratry::TypeCheck
use Qwiratry::Query::Match;

=begin pod

Collector for C<make> calls during template execution. When defined, C<make>
pushes values here instead of using the block's return value.

=end pod
our $*MAKE-OUTPUT is export;

=begin pod

Add a value to the current template's output stream.

=end pod
sub make(Mu $value) is export {
    unless $*MAKE-OUTPUT.defined {
        X::Qwiratry::Walker.new(
            message => 'make() called outside template execution',
            walker-type => 'Template',
        ).throw;
    }
    $*MAKE-OUTPUT.push($value);
    $value;
}

=begin pod

Skip the current template action and continue with the next matching template.

=end pod
class NextTemplate is export {
    method throw(NextTemplate:U: ) {
        X::Qwiratry::NextTemplate.new(
            message => 'Continue to next matching template',
            walker-type => 'Template',
        ).throw;
    }
}

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

    =begin pod

    Optional Query AST extracted from the C<when> clause for specificity calculation.

    =end pod
    has Mu $.when-query is rw;
    
    # Constructor
    submethod BUILD(
        :$name,
        :$signature,
        :$when-block,
        :$when-query,
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
        $!when-query = $when-query if $when-query.defined;
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
        if $!when-query.defined && !$!when-block.defined {
            return when-query-matches($!when-query, $node, :origin($node));
        }

        if !$!when-block.defined {
            return True;
        }

        my $*MAKE-OUTPUT := Nil;
        try {
            return self!run-with-magic-variables(
                $node,
                { ?self!invoke-block($!when-block, $node) },
                :setup-capture($!signature.defined),
            );
        }
        False;
    }

    method !run-with-magic-variables($node, &code, :$context, :$setup-capture = False, :$make-output) {
        my $*CONTEXT = $context // $node;
        my $*MAKE-OUTPUT := $make-output if $make-output.defined;
        my $capture = self!capture-signature($node) if $setup-capture;
        my $*CAPTURE = $capture if $capture.defined;
        $/ = $capture if $capture.defined;
        code();
    }

    method !param-field-name($param --> Str) {
        my $name = $param.name;
        $name.=subst(/^\$/, '');
        $name.=subst(/^\@/, '');
        $name.=subst(/^\%/, '');
        $name eq '_' ?? 'topic' !! $name;
    }

    method !capture-signature($node) {
        return %() unless $!signature.defined;

        my @params = $!signature.params;
        if !@params || (@params == 1 && self!param-field-name(@params[0]) eq 'topic') {
            return %(topic => $node);
        }

        my @pos;
        my %named;
        for @params -> $param {
            next if $param.slurpy;
            my $field = self!param-field-name($param);
            if $param.named {
                my $val = self!extract-field($node, $field);
                next unless $val.defined;
                %named{$field} = $val;
            }
            elsif $field eq 'topic' {
                @pos.push($node);
            }
            else {
                my $val = self!extract-field($node, $field);
                next unless $val.defined;
                %named{$field} = $val;
                @pos.push($val);
            }
        }

        return %named if @pos == 0;
        return %(|%named, pos => @pos) if @pos;
        %named;
    }

    method !extract-field($node, $field) {
        return $node if $field eq 'topic';
        if $node ~~ Associative {
            return $node{$field} if $node{$field}:exists;
        }
        try {
            return $node."$field"();
        }
        Nil;
    }

    method !invoke-arity0($node, &code) {
        if $node.defined {
            with $node { code() }
        }
        else {
            $node.&({ code() })
        }
    }

    method !invoke-block($block, $node) {
        if $block.arity == 0 && $block.count == 0 {
            return self!invoke-arity0($node, { $block() });
        }
        return $block($node) if $block.arity == 1;
        $block($node);
    }

    method !invoke-do-block($block, $node, $transformer, :$context, :$make-output) {
        my $template = self;
        $template!run-with-magic-variables(
            $node,
            {
                if $block ~~ Method && $transformer.defined {
                    if $block.arity == 0 && $block.count == 0 {
                        $template!invoke-arity0($node, { $block($transformer) });
                    }
                    elsif $block.arity >= 1 {
                        $block($transformer, $node);
                    }
                    else {
                        $block($transformer);
                    }
                }
                elsif $block.arity == 0 && $block.count == 0 {
                    $template!invoke-arity0($node, { $block() });
                }
                elsif $block.arity == 1 {
                    $block($node);
                }
                else {
                    $block($node);
                }
            },
            :$context,
            :setup-capture(True),
            :$make-output,
        );
    }

    method !finalize-result($block-result, @make-output) {
        if @make-output {
            return @make-output.elems == 1 ?? @make-output[0] !! @make-output.List;
        }
        $block-result;
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
        if !$!do-block.defined {
            return Nil;
        }

        my @make-output;
        my $result = self!invoke-do-block(
            $!do-block,
            $node,
            $transformer,
            :$context,
            :make-output(@make-output),
        );
        $result = self!finalize-result($result, @make-output);

        if $transformer.defined {
            try {
                $result = $transformer.WRAP_TEMPLATE_ACTION($node, $result);
                CATCH {
                    when X::Method::NotFound { }
                }
            }
        }

        if $!returns-type.WHICH ne Mu.WHICH {
            unless $result ~~ $!returns-type {
                X::Qwiratry::TypeCheck.new(
                    expected => $!returns-type,
                    got => $result.WHAT,
                    message => "Template result does not match returns type constraint"
                ).throw;
            }
        }

        return $result;
    }
}
