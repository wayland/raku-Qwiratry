=begin pod

Main Qwiratry module - provides unified entry point for all Qwiratry functionality

This module activates the mold slang and exports all core Qwiratry modules.
Users can simply `use Qwiratry` to get access to transformers, molds, walkers,
and all other Qwiratry features.

Example:
  use Qwiratry::Mold::Slang;  # required for mold/wrapper syntax
  use Qwiratry;
  
  transformer MyTransform {
      mold TOP do {
          return Node.new();
      }
  }

=end pod

unit module Qwiratry;

=begin pod

Run when a compunit C<use Qwiratry>s this module. Loads mold slang and core
transformer modules into the I<importer's> compilation unit (Piersing pattern).

=end pod
sub IMPORT(::(?Mu) $, |) {
	# Slangify must be loaded in the importer's compunit (Piersing pattern).
	use Qwiratry::Mold::Slang;
	use Qwiratry::Transformer;
	use Qwiratry::Mold;
}

use Qwiratry::Mold::Slang;
use Qwiratry::Mold;
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

