=begin pod

Second test Walker for discovery mechanism testing.

This is a minimal Walker implementation used solely for testing
the Qwiratry::Walker::Factory discovery mechanism with multiple walkers.

=end pod
unit class Qwiratry::Walker::TestWalker2;

use Qwiratry::Walker;
use Qwiratry::QueryIterator;

does Qwiratry::Walker;

method plan($query, $root --> Qwiratry::Walker::Plan) {
    die "TestWalker2.plan() not implemented for testing";
}

method iterator(Qwiratry::Walker::Plan $plan --> QueryIterator) {
    die "TestWalker2.iterator() not implemented for testing";
}

