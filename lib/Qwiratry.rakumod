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

unit module Qwiratry;

# Activate template slang FIRST so it's available when other modules load
# This must be done at the module level so it's active when users
# declare transformers in their code
use Qwiratry::TemplateSlang;
use Slangify Qwiratry::TemplateSlang::TemplateGrammar, Qwiratry::TemplateSlang::TemplateActions;

# Import transformer-related modules - these are the essential ones for transformers
use Qwiratry::Template;
use Qwiratry::Transformer;

# Import other core modules as needed
# Users can import additional modules individually if needed
# use Qwiratry::Context;
# use Qwiratry::QueryIterator;
# use Qwiratry::Walker;
# use Qwiratry::Strategy;
# use Qwiratry::ControlSignal;
# use Qwiratry::Provides;
# use Qwiratry::FinishResult;
# use Qwiratry::Copy;
# use Qwiratry::X;

