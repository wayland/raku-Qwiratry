# Activate template slang in the caller (Piersing pattern).
# Grammar/actions must live in a non-unit compunit for Slangify to work.
use v6.e.PREVIEW;
use Qwiratry::Template;
use Qwiratry::Template::Slang;

sub compile-invokable(Mu $cap) {
    return { @_[0] } unless $cap.defined;
    my $block = RakuAST::Block.new(body => $cap.ast);
    try {
        $block.to-begin-time($*R, $*CU.context);
        my $code = $block.meta-object;
        return $code if $code.defined;
    }
    { @_[0] }
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

role TemplateGrammar {
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

role TemplateActions {
    method routine-declarator:sym<template>(Mu $/) {
        self.attach: $/, $<template-def>.ast;
    }

    method template-def(Mu $/) {
        my $name = $<name>.defined ?? ~$<name> !! Nil;
        my $signature = $<signature>.defined ?? $<signature>.ast !! Nil;

        my $routine := $*BLOCK;
        if $name.defined {
            $routine.replace-name(RakuAST::Name.from-identifier("_q_tpl_$name"));
        }
        unless $<signature>.defined {
            $routine.replace-signature(implicit-template-signature());
        }
        $routine.replace-body($<do-block>.ast);
        self.attach: $/, $routine;

        my $do-block = try $routine.meta-object // compile-invokable($<do-block>);
        my $when-block;
        if $<when-block>.defined {
            my $when-routine := RakuAST::Sub.new(
                :signature(implicit-template-signature()),
                body => RakuAST::Blockoid.new($<when-block>.ast),
            );
            $when-block = try $when-routine.compile-time-value // compile-invokable($<when-block>);
        }
        else {
            $when-block = Nil;
        }

        my $template = Template.new(:$name, :$signature, :$when-block, :$do-block);
        apply-template-traits($template, $routine);
        register-template($template);
    }

    method routine-declarator:sym<wrapper>(Mu $/) {
        self.attach: $/, $<wrapper-def>.ast;
    }

    method wrapper-def(Mu $/) {
        my $type = ~$<wrapper-type>;
        my $routine := $*BLOCK;
        $routine.replace-name(RakuAST::Name.from-identifier("_q_wrap_$type"));
        $routine.replace-body($<wrap-block>.ast);
        self.attach: $/, $routine;
        my $block = try $routine.meta-object // compile-invokable($<wrap-block>);
        register-wrapper($type, $block);
    }
}

use Slangify TemplateGrammar, TemplateActions;
