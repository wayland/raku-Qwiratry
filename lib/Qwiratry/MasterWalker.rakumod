#| Master Walker for composite walker handovers
#|
#| This module implements the Master Walker class that detects when handovers
#| are required between domain-specific walkers and delegates planning and
#| execution to appropriate walkers. The Master Walker coordinates composite
#| execution for multi-domain queries.
#|
#| The Master Walker:
#| - Discovers candidate walkers via introspection (default) or accepts explicit registration
#| - Detects handover requirements using domain metadata and capability checks
#| - Delegates planning to domain-specific walkers and embeds resulting plans as subplans
#| - Coordinates composite execution of multi-domain queries
unit module Qwiratry::MasterWalker;

use Qwiratry::Walker;
use Qwiratry::Provides;

#| Master Walker class that implements Walker role for composite handovers.
#|
#| Responsible for detecting when handovers are required and delegating
#| planning and execution to appropriate domain-specific Walkers.
#|
#| Constructor parameters:
#|   :@candidate-walkers - Optional array of Walker instances (overrides discovery)
#|
#| Example:
#|   my $master = MasterWalker.new;
#|   my $master-with-walkers = MasterWalker.new(:candidate-walkers[@sql-walker, @json-walker]);
class MasterWalker does Walker {
    # TODO: Implement Master Walker class
    # This will be implemented in WP03-WP05
    
    #| Discover candidate walkers via introspection.
    #| Cached per instance to avoid repeated introspection.
    method discover-walkers(--> Array[Walker]) {
        # TODO: Implement discovery mechanism
        # This will be implemented in WP03
        Array[Walker].new
    }
    
    #| Required: Create execution plan from query and root.
    method plan(RakuAST::Node $query, Mu $root --> Walker::Plan) {
        # TODO: Implement plan method with handover detection
        # This will be implemented in WP04-WP05
        die "Not yet implemented"
    }
    
    #| Required: Produce QueryIterator from plan.
    method iterator(Walker::Plan $plan --> QueryIterator) {
        # TODO: Implement iterator method
        # This will be implemented in WP05-WP06
        die "Not yet implemented"
    }
}

