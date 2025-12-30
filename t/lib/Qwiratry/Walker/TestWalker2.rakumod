=begin pod

Second test Walker for discovery mechanism testing.

This is a minimal Walker implementation used solely for testing
the WalkerFactory discovery mechanism with multiple walkers.

=end pod
unit class Qwiratry::Walker::TestWalker2;

use Qwiratry::Walker;
use Qwiratry::QueryIterator;
use Qwiratry::Walker::Plan;

does Walker;

method plan($query, $root --> Walker::Plan) {
    die "TestWalker2.plan() not implemented for testing";
}

method iterator(Walker::Plan $plan --> QueryIterator) {
    die "TestWalker2.iterator() not implemented for testing";
}

