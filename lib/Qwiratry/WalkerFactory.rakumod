=begin pod

Walker factory for automatic Walker selection based on data type

This module provides a factory/registry pattern for selecting appropriate
Walker instances based on input data type. The factory enables automatic
Walker selection while maintaining flexibility for explicit registration.

=end pod
unit module Qwiratry::WalkerFactory;

use Qwiratry::Walker;

=begin pod

Walker factory class for automatic Walker selection.

Maintains a registry of Walker types keyed by data type/role.
Supports automatic discovery and explicit registration.

=end pod
class WalkerFactory is export {
    # Registry of Walker types keyed by data type/role
    has %!walker-registry;
    
    # Singleton instance (optional - can also instantiate directly)
    my $instance;
    
    =begin pod

    Get or create singleton instance of WalkerFactory.

    @returns WalkerFactory - Singleton instance

    =end pod
    method instance(--> WalkerFactory) {
        $instance //= WalkerFactory.new;
    }
    
    =begin pod

    Get appropriate Walker for given data.

    Selection logic:
    1. Check explicit registry entries (by type name or role)
    2. Use type-based heuristics (e.g., Positional for arrays)
    3. Return Nil if no Walker found

    @param $data - Data structure to get Walker for
    @returns Walker? - Walker instance or Nil if none found

    =end pod
    method get-walker($data --> Mu) {
        # T028: Get Walker for data type
        # Check explicit registry first
        my $type = $data.WHAT;
        my $type-name = $type.^name;
        
        # Check registry by type name
        if %!walker-registry{$type-name}:exists {
            my $walker-type = %!walker-registry{$type-name};
            return $walker-type.new;
        }
        
        # Check registry by role composition
        # Iterate through roles that $data does
        for $type.^roles -> $role {
            my $role-name = $role.^name;
            if %!walker-registry{$role-name}:exists {
                my $walker-type = %!walker-registry{$role-name};
                return $walker-type.new;
            }
        }
        
        # Use heuristics for common types
        # Positional (arrays, lists) - could use a default array walker
        if $data ~~ Positional {
            # For MVP, return Nil - specific walkers can be registered
            # Future: return default Positional walker if available
        }
        
        # Associative (hashes, maps) - could use a default hash walker
        if $data ~~ Associative {
            # For MVP, return Nil - specific walkers can be registered
            # Future: return default Associative walker if available
        }
        
        # No Walker found
        # Explicitly return Nil to avoid returning Any (type object)
        return Nil;
    }
    
    =begin pod

    Register a Walker type for a specific data type or role.

    @param $type - Type or role to register Walker for (can be type object or string name)
    @param $walker-type - Walker type (class that does Walker role)

    =end pod
    method register-walker($type, $walker-type) {
        # T028: Register Walker for type
        my $type-name = $type ~~ Str ?? $type !! $type.^name;
        %!walker-registry{$type-name} = $walker-type;
    }
    
    =begin pod

    Discover available Walkers via introspection (optional).

    Scans loaded classes/types for those implementing Walker role.
    Similar to MasterWalker discovery mechanism.

    @returns Array[Walker] - Array of discovered Walker types

    =end pod
    method discover-walkers(--> Array) {
        # T028: Discover Walkers via introspection
        # For MVP, return empty array - discovery can be enhanced later
        # Similar to MasterWalker.discover-walkers() implementation
        my @found = Array.new;
        
        # TODO: Implement discovery mechanism
        # - Scan loaded modules/classes
        # - Check if type does Walker role
        # - Collect into array
        
        return @found;
    }
}

# Export convenience function for getting singleton instance
sub get-walker-factory(--> WalkerFactory) is export {
    WalkerFactory.instance;
}

