=begin pod

Main Qwiratry module - provides unified entry point for all Qwiratry functionality

This module exports the core Qwiratry transformer symbols. Mold slang currently
needs direct activation in the caller with C<use Qwiratry::Mold::Slang>.

Example:
  use Qwiratry::Mold::Slang;  # required for mold/wrapper syntax
  use Qwiratry;
  
  transformer MyTransform {
      mold TOP do {
          return Node.new();
      }
  }

=end pod

use Qwiratry::Mold::Slang;
use Qwiratry::Mold;
use Qwiratry::Transformer;

sub EXPORT(|) {
	Map.new(
		'Transformer' => Transformer,
		'Mold' => Mold,
		'NextMold' => NextMold,
		'&make' => &make,
	);
}

=begin pod

Run when a compunit C<use Qwiratry>s this module. Exports the core transformer
symbols; slang activation remains direct via C<use Qwiratry::Mold::Slang>.

=end pod
my package EXPORTHOW {
	package DECLARE {
		constant transformer = MetamodelX::TransformerHOW;
	}
}

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

