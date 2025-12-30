=begin pod

Test Walker for discovery mechanism testing.

This is a minimal Walker implementation used solely for testing
the WalkerFactory discovery mechanism.

=end pod
unit class Qwiratry::Walker::TestWalker;

use Qwiratry::Walker;
use Qwiratry::QueryIterator;
use Qwiratry::Walker::Plan;

does Walker;

method plan($query, $root --> Walker::Plan) {
    die "TestWalker.plan() not implemented for testing";
}

method iterator(Walker::Plan $plan --> QueryIterator) {
    die "TestWalker.iterator() not implemented for testing";
}

