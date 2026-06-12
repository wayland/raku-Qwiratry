=begin pod

Main Qwiratry module - provides unified entry point for all Qwiratry functionality

This module activates the template slang and exports all core Qwiratry modules.
Users can simply `use Qwiratry` to get access to transformers, templates, walkers,
and all other Qwiratry features.

Example:
  use Qwiratry::Template::Slang;  # required for template/wrapper syntax
  use Qwiratry;
  
  transformer MyTransform {
      template TOP do {
          return Node.new();
      }
  }

=end pod

unit module Qwiratry;

=begin pod

Run when a compunit C<use Qwiratry>s this module. Loads template slang and core
transformer modules into the I<importer's> compilation unit (Piersing pattern).

=end pod
sub IMPORT(::(?Mu) $, |) {
	# Slangify must be loaded in the importer's compunit (Piersing pattern).
	use Qwiratry::Template::Slang;
	use Qwiratry::Transformer;
	use Qwiratry::Template;
}

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

