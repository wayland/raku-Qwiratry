# Activate template slang in the caller (Piersing pattern).
# Grammar/actions must live in a non-unit compunit for Slangify to work.
use v6.e.PREVIEW;
use Qwiratry::Template;
use Qwiratry::Template::Slang;

role TemplateGrammar {
    rule template-def($declarator) {
        :my $*BLOCK;
        <.enter-block-scope('Sub')>
        $<name>=<identifier>?
        'do' <.ws> $<do-block>=<blockoid>
        <.leave-block-scope>
    }

    token routine-declarator:sym<template> {
        'template'
        <.end-keyword>
        <template-def=.key-origin('template-def', 'template')>
    }
}

role TemplateActions {
    method routine-declarator:sym<template>(Mu $/) {
        self.attach: $/, $<template-def>.ast;
    }

    method template-def(Mu $/) {
        my $name = $<name>.defined ?? ~$<name> !! Nil;
        register-template(Template.new(:$name, do-block => { @_[0] }));
        my $routine := $*BLOCK;
        if $name.defined {
            $routine.replace-name(RakuAST::Name.from-identifier("_q_tpl_$name"));
        }
        $routine.replace-body($<do-block>.ast);
        self.attach: $/, $routine;
    }
}

use Slangify TemplateGrammar, TemplateActions;
