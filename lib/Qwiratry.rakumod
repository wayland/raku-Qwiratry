=begin pod

Main Qwiratry module - provides unified entry point for all Qwiratry functionality

This module activates the template slang and exports all core Qwiratry modules.
Users can simply `use Qwiratry` to get access to transformers, templates, walkers,
and all other Qwiratry features.

Example:
  use Qwiratry;
  
  transformer MyTransform {
      template TOP do {
          return Node.new();
      }
  }

=end pod

#unit module Qwiratry;

# Activate template slang FIRST so it's available when other modules load
# This must be done at the module level so it's active when users
# declare transformers in their code
use Qwiratry::Template::Slang;
#use Slangify Qwiratry::Template::Slang::TemplateGrammar, Qwiratry::Template::Slang::TemplateActions;

#-----
# This next was borrowed from Slangify, because Slangify wasn't working
#BEGIN {
say "pre-load";
my $LANG := $*LANG;

my $grammar = Qwiratry::Template::Slang::TemplateGrammar;
my $actions = Qwiratry::Template::Slang::TemplateActions;

$LANG.define_slang('MAIN',
          $grammar<> =:= Mu
            ?? $LANG.slang_grammar('MAIN')
            !! $LANG.slang_grammar('MAIN').^mixin($grammar<>),
            $LANG.slang_actions('MAIN')
#          $actions<> =:= Mu
#            ?? $LANG.slang_actions('MAIN')
#            !! $LANG.slang_actions('MAIN').^mixin($actions<>)
        );
say "post-load";
#}
#-----

# Import transformer-related modules - these are the essential ones for transformers
use Qwiratry::Template;
use Qwiratry::Transformer;

# Import other core modules as needed
# Users can import additional modules individually if needed
# use Qwiratry::Context;
# use Qwiratry::QueryIterator;
# use Qwiratry::Walker;
# use Qwiratry::Strategy;
# use Qwiratry::Strategy::ControlSignal;
# use Qwiratry::Walker::Provides;
# use Qwiratry::Strategy::FinishResult;
# use Qwiratry::Transformer::Copy;
# use X::Qwiratry;

