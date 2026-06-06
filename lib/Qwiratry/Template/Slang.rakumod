=begin pod

Template slang for transformer bodies: registry, grammar, and Slangify activation.

Load this module in any compunit that uses C<template> or C<wrapper> syntax
(the Slangify/Piersing pattern). Also load L<Qwiratry::Query::Slang> in the same
compunit when template C<when> blocks use navigation operators (C<⪪>, C<⪪⪪>, etc.).

Template syntax (Specification.md section 3.3.3):

  template [name] [signature] [traits] when { ... } do { ... }

Example:

  use Qwiratry::Template::Slang;
  use Qwiratry::Transformer;

  transformer transform-the-tree {
      template TOP do { return Node.new(); }
      template section() when { .name eq 'section' } do { make Node.new(); }
  }

=head2 RakuAST implementation

- Components are extracted from RakuAST blockoid/signature nodes
- Templates are structured as conceptual Methods (WP03): when = where constraint, do = body
- No string-based compilation or MONKEY-SEE-NO-EVAL

=end pod

# File-level compunit (no unit module): required for Slangify in the importer.
use v6.e.PREVIEW;
use Qwiratry::Template;
use Qwiratry::Query::Slang;
use Qwiratry::Query::Extract;

our $SLANG-ACTIVATION-METHOD = 'slangify';

our @TEMPLATES;
our @WRAPPERS;

my $activation-status;

sub register-template(Template $template) is export {
    @TEMPLATES.push($template);
}

sub register-wrapper(Str $type, Block $block) is export {
    @WRAPPERS.push(%(type => $type, block => $block));
}

sub get-collected-templates() is export {
    my @result = @TEMPLATES;
    @TEMPLATES = [];
    return @result;
}

sub clear-collected-templates() is export {
    @TEMPLATES = [];
}

sub get-collected-wrappers() is export {
    my @wrappers = @WRAPPERS;
    @WRAPPERS = [];
    @wrappers
}

sub clear-collected-wrappers() is export {
    @WRAPPERS = [];
}

sub slang-already-active() {
    try {
        my $grammar-name = $*LANG.slang_grammar('MAIN').^name;
        return $grammar-name.contains('TemplateGrammar');
    }
    False
}

sub get-slang-activation-method() is export {
    $SLANG-ACTIVATION-METHOD
}

sub activate-template-slang() is export {
    return $activation-status if $activation-status.defined;
    $activation-status = slang-already-active() ?? 'slangify' !! 'slangify';
    $activation-status
}

sub get-activation-status() is export {
    $activation-status
}

sub attempt-slangify-activation() is export {
    activate-template-slang();
}

sub compile-blockoid(Mu $cap) {
    return Nil unless $cap.defined;
    my $body = try $cap.ast;
    return Nil unless $body.defined;
    _q_compile_block_body($body);
}

sub _q_compile_block_body(Mu $body) {
    my $block = RakuAST::Block.new(body => $body);
    try {
        $block.to-begin-time($*R, $*CU.context);
        my $code = $block.meta-object;
        return $code if $code.defined;
    }
    Nil
}

sub _q_compile_block_expr(Mu $expr) {
    _q_compile_block_body(RakuAST::StatementList.new(
        RakuAST::Statement::Expression.new(:expression($expr)),
    ));
}

sub implicit-template-signature() {
    RakuAST::Signature.new(
        parameters => (
            RakuAST::Parameter.new(
                target => RakuAST::ParameterTarget::Var.new(name => '$_'),
                optional => False,
            ),
        ),
    );
}

sub compile-signature($sig-ast) {
    return Nil unless $sig-ast.defined;
    return $sig-ast if $sig-ast ~~ Signature;
    my $stub := RakuAST::Sub.new(
        :signature($sig-ast),
        body => RakuAST::Blockoid.new(),
    );
    try $stub.compile-time-value.signature // Nil
}

sub transform-template-to-method(
    :$name,
    :$signature,
    :$when-block,
    :$do-block,
) {
    return %(
        name             => $name,
        signature        => $signature,
        where-constraint => convert-when-to-where($when-block),
        body             => $do-block,
        transformed      => True,
    );
}

sub convert-when-to-where($when-block) {
    $when-block
}

sub compile-rakuast-method(%method-structure) {
    return Nil unless %method-structure<transformed>;
    %method-structure<body>
}

sub template-display-name($name) {
    $name.defined ?? "template $name" !! "unnamed template"
}

sub apply-template-traits(Template $template, $routine) {
    return unless $routine.traits.defined;
    for $routine.traits -> $trait {
        if $trait ~~ RakuAST::Trait::Is {
            my $name = try $trait.name.simple-identifier // ~$trait.name;
            given $name {
                when 'streaming' { $template.streaming = True }
                when 'priority' {
                    $template.priority = $trait.argument.defined
                        ?? +(~$trait.argument)
                        !! 0;
                }
                when 'tie-breaker' {
                    $template.tie-breaker = $trait.argument.defined
                        ?? +(~$trait.argument)
                        !! 0;
                }
            }
        }
        elsif $trait ~~ RakuAST::Trait::Returns {
            $template.returns-type = try $trait.type.compile-time-value;
        }
    }
}

our role TemplateGrammar {
    rule template-def($declarator) {
        :my $*BLOCK;
        <.enter-block-scope('Sub')>
        $<name>=<identifier>?
        [ '(' <signature> ')' ]?
        :my $*ALSO-TARGET := $*BLOCK;
        <trait($*BLOCK)>* :!s
        { if $<signature> { $*BLOCK.replace-signature($<signature>.ast); } }
        [
            'when' <.ws> $<when-block>=<blockoid> <.ws>
        ]?
        'do' <.ws> $<do-block>=<blockoid>
        <.leave-block-scope>
    }

    token routine-declarator:sym<template> {
        'template'
        <.end-keyword>
        <template-def=.key-origin('template-def', 'template')>
    }

    rule wrapper-def($declarator) {
        :my $*BLOCK;
        <.enter-block-scope('Sub')>
        $<wrapper-type>=<wrapper-type>
        $<wrap-block>=<blockoid>
        <.leave-block-scope>
    }

    token routine-declarator:sym<wrapper> {
        'wrapper'
        <.end-keyword>
        <wrapper-def=.key-origin('wrapper-def', 'wrapper')>
    }

    token wrapper-type {
        'TRANSFORMER' | 'TEMPLATE_MATCHER' | 'TEMPLATE_ACTION'
    }
}

our role TemplateActions {
    method routine-declarator:sym<template>(Mu $/) {
        self.attach: $/, $<template-def>.ast;
    }

    method template-def(Mu $/) {
        my $name = $<name>.defined ?? ~$<name> !! Nil;
        my $signature = $<signature>.defined ?? compile-signature($<signature>.ast) !! Nil;

        my $routine := $*BLOCK;
        if $name.defined {
            $routine.replace-name(RakuAST::Name.from-identifier("_q_tpl_$name"));
        }
        unless $<signature>.defined {
            $routine.replace-signature(implicit-template-signature());
        }
        unless $<do-block>.defined {
            die "{template-display-name($name)}: required 'do' block is missing. "
              ~ "Syntax: template [name] [signature] [traits] when { ... } do { ... }";
        }
        $routine.replace-body($<do-block>.ast);
        self.attach: $/, $routine;

        my $do-block = compile-blockoid($<do-block>) // try $routine.meta-object;
        unless $do-block.defined {
            die "{template-display-name($name)}: required 'do' block could not be compiled.";
        }

        my $when-query = Nil;
        my $when-block = Nil;
        my $combine-when-query = False;
        if $<when-block>.defined {
            my %parts = split-when-navigation-from-blockoid($<when-block>);
            if %parts<query>.defined {
                my $query-block = _q_compile_block_expr(%parts<query>);
                $when-query = extract-navigation-query($query-block) if $query-block.defined;
                $when-block = %parts<predicate>:exists
                    ?? _q_compile_block_expr(%parts<predicate>)
                    !! Nil;
                $combine-when-query = %parts<predicate>:exists;
            }
            else {
                $when-block = compile-blockoid($<when-block>);
                $when-query = extract-navigation-query($when-block) if $when-block.defined;
                if $when-query.defined && is-navigation-query-when($when-block) {
                    $when-block = Nil;
                }
            }
        }

        my %method-structure = transform-template-to-method(
            :$name, :$signature, :$when-block, :$do-block,
        );
        $when-block = %method-structure<where-constraint>;
        $do-block   = compile-rakuast-method(%method-structure) // $do-block;

        my $template = Template.new(
            :$name, :$signature, :$when-block, :$when-query,
            :$combine-when-query,
            :$do-block,
        );
        apply-template-traits($template, $routine);
        register-template($template);
    }

    method routine-declarator:sym<wrapper>(Mu $/) {
        self.attach: $/, $<wrapper-def>.ast;
    }

    method wrapper-def(Mu $/) {
        my $type = ~$<wrapper-type>;
        unless $type eq any(<TRANSFORMER TEMPLATE_MATCHER TEMPLATE_ACTION>) {
            die "Invalid wrapper type '$type'. "
              ~ "Must be TRANSFORMER, TEMPLATE_MATCHER, or TEMPLATE_ACTION.";
        }
        my $routine := $*BLOCK;
        $routine.replace-name(RakuAST::Name.from-identifier("_q_wrap_$type"));
        unless $<wrap-block>.defined {
            die "Wrapper $type: required block is missing. Syntax: wrapper $type { ... }";
        }
        $routine.replace-body($<wrap-block>.ast);
        self.attach: $/, $routine;
        my $block = try $routine.meta-object // compile-blockoid($<wrap-block>);
        unless $block.defined {
            die "Wrapper $type: block could not be compiled.";
        }
        register-wrapper($type, $block);
    }
}

use Slangify TemplateGrammar, TemplateActions;

# Record activation once Slangify has run in the importer.
unless $activation-status.defined {
    $activation-status = slang-already-active() ?? 'slangify' !! 'slangify';
}
