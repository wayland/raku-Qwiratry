=begin pod

Test Walker for discovery mechanism testing.

This is a minimal Walker implementation used solely for testing
the Qwiratry::Walker::Factory discovery mechanism.

=end pod

use Qwiratry::Walker;
use Qwiratry::QueryIterator;

unit class Qwiratry::Walker::TestWalker does Qwiratry::Walker;

method plan($query, $root --> Qwiratry::Walker::Plan) {
	die "TestWalker.plan() not implemented for testing";
}

method iterator(Qwiratry::Walker::Plan $plan --> QueryIterator) {
	die "TestWalker.iterator() not implemented for testing";
}
