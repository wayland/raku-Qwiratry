=begin pod

Template Slang for transformer template syntax

This module provides a Slang that extends Raku grammar to recognize
the `template` declarator syntax within transformer bodies. The slang
parses template declarations and converts them into Template objects
that are collected by the Transformer HOW class.

Template syntax:
  template [name] [signature] [traits] when { ... } do { ... }

Example:
  template TOP do { return Node.new(); }
  template section() when { .name eq 'section' } do { make Node.new(); }
  template :streaming when { $_.is_leaf } do { take $_; }

The grammar and actions roles are exported for use with Slangify.
The transformer HOW class will activate this slang when processing
transformer bodies.

=end pod

unit module Qwiratry::TemplateSlang;

use Qwiratry::Template;

=begin pod

Package-level storage for templates collected during slang parsing.
This is accessed by the Transformer HOW class to retrieve templates
that were parsed from the transformer body.

=end pod
our @TEMPLATES;

=begin pod

Grammar role that extends Raku grammar to recognize template declarations.
Export this role for use with Slangify.
The template declarator can appear in transformer bodies and has the syntax:
  template [name] [signature] [traits] when { ... } do { ... }

=end pod
role TemplateGrammar is export {
    =begin pod

    Token for template declarator.
    Matches: template [name] [signature] [traits] when { ... } do { ... }
    
    Uses Raku's existing grammar rules:
    - <deflongname> for the identifier (like routine-def)
    - <signature> for parameter lists (like routine-def)
    - <trait> for traits (like routine-def)
    - <block> for code blocks (like routine-def)
    
    Unlike routine-def which has one block, template has two:
    - Optional 'when' block (matcher)
    - Required 'do' block (action)

    =end pod
    token declarator:sym<template> {
        'template' <.ws>
        [
            | <deflongname> <signature>? <trait>*
            | <signature>? <trait>*
        ]
        [
            'when' <.ws> <block> <.ws>
        ]?
        'do' <.ws> <block>
    }
}

=begin pod

Actions role that processes template declarations and creates Template objects.
Export this role for use with Slangify.
The actions convert parsed template syntax into Template instances that can be
collected by the Transformer HOW class.

=end pod
role TemplateActions is export {
    =begin pod

    Delegate signature parsing to Raku's actions.
    This ensures Raku's actions process the signature and create a Signature object.

    =end pod
    method signature($/) {
        # Call parent actions to process signature
        # This will create a Signature object and set .made
        callsame;
    }
    
    =begin pod

    Delegate trait parsing to Raku's actions.
    This ensures Raku's actions process the trait.

    =end pod
    method trait($/) {
        # Call parent actions to process trait
        # This will process the trait and set .made
        callsame;
    }
    
    =begin pod

    Action method for template declarator.
    Processes the parsed template declaration and creates a Template object.

    =end pod
    method declarator:sym<template>($/) {
        # Extract template components using Raku's existing grammar rules
        # <deflongname> is used for the identifier (like routine-def)
        my $name = $<deflongname> ?? $<deflongname>.Str !! Nil;
        
        # <signature> is already parsed by Raku's grammar and actions
        # Raku's actions should have already created a Signature object
        # Try to access it via .made, or fall back to parsing
        my $signature = Nil;
        if $<signature> {
            # First try to get the already-parsed Signature object
            # Raku's actions may have set .made on the signature node
            $signature = $<signature>.made;
            
            # If not available, try to parse it ourselves
            if !$signature.defined {
                $signature = self!parse-signature($<signature>);
            }
        }
        
        # <trait> is already parsed by Raku's grammar and actions
        # Raku's actions should have already processed traits
        # We need to extract the trait information from the parsed nodes
        my @traits = [];
        if $<trait> {
            @traits = $<trait>.map({ self!parse-trait($_) }).grep(*.defined);
        }
        
        # Extract blocks - when block is first (if present), do block is last
        # <block> is already parsed by Raku's grammar
        my $when-block = Nil;
        my $do-block = Nil;
        if $<block> {
            my @blocks = $<block>.List;
            if @blocks.elems == 2 {
                # First block is 'when', second is 'do'
                $when-block = self!compile-block(@blocks[0]);
                $do-block = self!compile-block(@blocks[1]);
            } elsif @blocks.elems == 1 {
                # Only 'do' block present
                $do-block = self!compile-block(@blocks[0]);
            }
        }
        
        # Extract trait values
        my $priority = 0;
        my $tie-breaker = 0;
        my $streaming = False;
        my $returns-type = Nil;
        
        for @traits -> $trait {
            if $trait<name> eq 'priority' {
                $priority = $trait<value>.Int;
            } elsif $trait<name> eq 'tie-breaker' {
                $tie-breaker = $trait<value>.Int;
            } elsif $trait<name> eq 'streaming' {
                $streaming = True;
            } elsif $trait<name> eq 'returns' {
                $returns-type = self!resolve-type($trait<value>);
            }
        }
        
        # Create Template object
        my $template = Template.new(
            name => $name,
            signature => $signature,
            when-block => $when-block,
            do-block => $do-block,
            priority => $priority,
            tie-breaker => $tie-breaker,
            streaming => $streaming,
            returns-type => $returns-type
        );
        
        # Store template for collection by HOW class
        # This will be accessed by the Transformer HOW class during compose()
        @TEMPLATES.push($template);
        
        # Make the template declaration compile to a statement that does nothing at runtime
        # The template is already registered in @TEMPLATES during compilation
        # We create a simple statement that evaluates to Nil
        # In Raku actions, we can use make to set what the rule produces
        # For a declarator, we typically don't need to produce anything
        # The template registration happens at compile time via @TEMPLATES
        make Nil;
    }
    
    =begin pod

    Parse signature from AST node.
    Converts signature syntax into a Signature object.
    The signature node from the grammar already contains the parsed signature.

    =end pod
    method !parse-signature($signature-node) {
        # The signature is already parsed by Raku's grammar
        # Raku's actions should have already created a Signature object
        # First check if .made contains the Signature object
        if $signature-node.made.defined && $signature-node.made ~~ Signature {
            return $signature-node.made;
        }
        
        # Fallback: try to create Signature from string representation
        # This works for simple signatures like "()", "($x)", "($x, $y)", etc.
        try {
            my $sig-str = $signature-node.Str;
            if $sig-str.chars > 0 {
                # Use EVAL to create the Signature at compile time
                # This is safe because we're in a slang that runs at compile time
                return EVAL "sub ($sig-str) {}.signature";
            }
        }
        
        # If parsing fails, return Nil
        # Templates without signatures will work fine
        Nil
    }
    
    =begin pod

    Parse trait from AST node.
    Extracts trait name and value.

    =end pod
    method !parse-trait($trait-node) {
        # <trait> is already parsed by Raku's grammar and actions
        # Raku's actions may have already processed the trait
        # First check if .made contains processed trait information
        if $trait-node.made.defined {
            # If Raku's actions set .made, use that
            # The structure depends on how Raku processes traits
            # For now, we'll still extract from the node structure
        }
        
        # Extract trait information from the parsed node structure
        # The trait node structure depends on how Raku's grammar parses traits
        my %trait;
        
        # Try to extract trait name and value from the parsed trait
        try {
            # For colon traits like :streaming, :priority(10)
            if $trait-node<colonpair> {
                my $colonpair = $trait-node<colonpair>;
                # Try different ways to get the identifier
                if $colonpair<identifier> {
                    %trait<name> = $colonpair<identifier>.Str;
                } elsif $colonpair<variable> {
                    %trait<name> = $colonpair<variable>.Str;
                } elsif $colonpair<deflongname> {
                    %trait<name> = $colonpair<deflongname>.Str;
                }
                
                # Get the value (if any)
                if $colonpair<nibble> {
                    %trait<value> = $colonpair<nibble>.Str;
                } elsif $colonpair<circumfix> {
                    %trait<value> = $colonpair<circumfix>.Str;
                } else {
                    %trait<value> = True;  # Boolean trait
                }
            }
            # For returns(Type) trait or other named traits
            elsif $trait-node<longname> {
                my $trait-name = $trait-node<longname>.Str;
                %trait<name> = $trait-name;
                
                # Get the argument (if any)
                if $trait-node<circumfix> {
                    %trait<value> = $trait-node<circumfix>.Str;
                } elsif $trait-node<colonpair> {
                    %trait<value> = $trait-node<colonpair>.Str;
                } else {
                    %trait<value> = True;  # Boolean trait
                }
            }
            # Fallback: try to get trait as string
            else {
                my $trait-str = $trait-node.Str;
                # Try to parse simple colon traits
                if $trait-str.starts-with(':') {
                    my $parts = $trait-str.substr(1).split('(');
                    %trait<name> = $parts[0];
                    if $parts.elems > 1 {
                        %trait<value> = $parts[1].subst(')', '');
                    } else {
                        %trait<value> = True;
                    }
                }
            }
        }
        
        # Return trait hash only if we successfully extracted information
        %trait<name> ?? %trait !! Nil
    }
    
    =begin pod

    Compile block from AST node into executable Block.
    The pblock node from the grammar already contains the parsed block.
    We need to compile it into a Block object that can be executed at runtime.

    =end pod
    method !compile-block($block-node) {
        # <block> is already parsed by Raku's grammar
        # The block node should contain the compiled block or code
        # We need to extract the block content and compile it
        
        my $result = try {
            # The block is already parsed by Raku's grammar
            # We can try to get the block's code content
            # The structure depends on how Raku's grammar parses blocks
            my $code = '';
            
            # Try to extract code from the block node
            # Check various possible structures in Raku's block grammar
            if $block-node<blockoid> {
                # blockoid contains the actual code
                if $block-node<blockoid><statementlist> {
                    $code = $block-node<blockoid><statementlist>.Str;
                } else {
                    $code = $block-node<blockoid>.Str;
                }
            } elsif $block-node<statementlist> {
                $code = $block-node<statementlist>.Str;
            } elsif $block-node<quoted> {
                # Sometimes blocks are stored as quoted strings
                $code = $block-node<quoted>.Str;
            } else {
                # Fallback: try to get the string representation
                # Remove the outer braces if present
                $code = $block-node.Str;
                $code = $code.subst(/^ \s* '{' \s* /, '');
                $code = $code.subst(/ \s* '}' \s* $ /, '');
            }
            
            # Compile the block using EVAL (at compile time)
            # This is safe because we're in a slang that runs at compile time
            # The block will be compiled and stored in the Template object
            # We create a pointy block that accepts $_ as the context
            EVAL "-> \$_ { $code }";
        };
        
        # If compilation fails, return Nil
        # This will be caught during template execution
        return $result // Nil;
    }
    
    =begin pod

    Resolve type name string to a type object.
    Converts type name strings like "Int" or "My::Type" to actual type objects.

    =end pod
    method !resolve-type(Str $type-name) {
        my $result = try {
            # Try to resolve the type using ::($type-name)
            # This works for types in the current scope
            ::($type-name);
        };
        
        # If type resolution fails, return Nil
        # The type check will happen at runtime during template execution
        return $result // Nil;
    }
}


=begin pod

Get templates collected by the slang.
This function is called by the Transformer HOW class to retrieve
templates that were parsed from the transformer body.

=end pod
sub get-collected-templates() is export {
    my @result = @TEMPLATES;
    @TEMPLATES = [];
    return @result;
}

=begin pod

Clear the template collection.
Called by the Transformer HOW class before processing a new transformer body.

=end pod
sub clear-collected-templates() is export {
    @TEMPLATES = [];
}

