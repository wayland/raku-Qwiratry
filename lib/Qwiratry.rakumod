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

# Activate template slang and transformer declarator in callers.
# Slangify must run in the caller; see Qwiratry::TemplateSlangActivate.
sub IMPORT(::(?Mu) $, |) {
    use Qwiratry::TemplateSlangActivate;
    use Qwiratry::Transformer;
}

use Qwiratry::TemplateSlangActivate;
use Qwiratry::Template::Slang;
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

