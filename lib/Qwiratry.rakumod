=begin pod

=head1 Overview

Main Qwiratry entry point.

Importing C<Qwiratry> exports the core transformer-facing symbols:
C<Transformer>, C<Mold>, C<NextMold>, C<make>, and the C<transformer>
declarator HOW. Mold syntax itself still depends on the slang module being
loaded in the caller's compunit, so user code that declares molds should also
load L<Qwiratry::Mold::Slang>.

=head1 Example

=begin code
use Qwiratry::Mold::Slang;  # required for mold/wrapper syntax
use Qwiratry;

transformer MyTransform {
    mold TOP do {
        return Node.new();
    }
}
=end code

=end pod

no precompilation;

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

=head1 Export HOW

The C<EXPORTHOW> package exposes the C<transformer> declarator to importing
compunits. Runtime symbols are exported from C<EXPORT>; declarator syntax is
exported through this HOW hook.

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

