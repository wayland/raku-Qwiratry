=begin pod

Walker factory for automatic Walker selection based on data type

This module provides a factory/registry pattern for selecting appropriate
Walker instances based on input data type. The factory enables automatic
Walker selection while maintaining flexibility for explicit registration.

=end pod

use Qwiratry::Walker;
use X::Qwiratry;
use Implementation::Loader;

=begin pod

Walker factory class for automatic Walker selection.

Maintains a registry of Walker types keyed by data type/role.
Supports automatic discovery and explicit registration.

=end pod
class Qwiratry::Walker::Factory {
    # Registry of Walker types keyed by data type/role
    has %!walker-registry;
    
    # Cached discovered walkers (lazy initialization)
    has @!discovered-walkers;
    
    # Flag indicating if discovery has been performed
    has Bool $!discovery-performed = False;
    
    # Singleton instance (optional - can also instantiate directly)
    my $instance;
    
    =begin pod

    Get or create singleton instance of Qwiratry::Walker::Factory.

    @returns Qwiratry::Walker::Factory - Singleton instance

    =end pod
    method instance(--> Qwiratry::Walker::Factory) {
        $instance //= Qwiratry::Walker::Factory.new;
    }
    
    =begin pod

    Get appropriate Walker for given data.

    Selection logic:
    1. Check explicit registry entries (by type name or role)
    2. Use type-based heuristics (e.g., Positional for arrays)
    3. Return Nil if no Walker found

    @param $data - Data structure to get Walker for
    @returns Qwiratry::Walker? - Walker instance or Nil if none found

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
    @param $walker-type - Walker type (class that does Qwiratry::Walker role)

    =end pod
    method register-walker($type, $walker-type) {
        # T028: Register Walker for type
        my $type-name = $type ~~ Str ?? $type !! $type.^name;
        %!walker-registry{$type-name} = $walker-type;
    }
    
    =begin pod

    Discover available Walkers via Implementation::Loader.

    Scans for classes matching the Qwiratry::Walker::Implementation::* pattern in the specified
    directories using Implementation::Loader. Results are cached for performance.
    Discovered classes are assumed to implement Qwiratry::Walker role without runtime
    verification.

    @param :@paths - List of directory paths to scan (default: ['lib'])
    @param :$refresh - If True, forces re-discovery and updates cache. If False,
                      returns cached results if available.
    @returns Array[Qwiratry::Walker] - Array of discovered Walker type objects (not instances)

    =end pod
    method discover-walkers(:@paths = ['lib'], Bool :$refresh = False --> Array) {
        # Return cached result if discovery already performed and refresh not requested
        if $!discovery-performed && !$refresh {
            return @!discovered-walkers;
        }
        
        {
            # Use Implementation::Loader to discover classes matching pattern
            # Pattern: Qwiratry::Walker::Implementation::* in specified directories
            my $discoverer = Implementation::Loader.new;
            
            # load-module-pattern accepts :globs and :paths as arrays
            # It will search all paths for classes matching the glob pattern
            # Cache results
            @!discovered-walkers = $discoverer.load-module-pattern(
                :globs(['Qwiratry::Walker::Implementation::*']),
                :paths(@paths)
            );
            $!discovery-performed = True;
            CATCH {
                default {
                    # Implementation::Loader API error or incompatible version
                    X::Qwiratry::Walker.new(
                        message => "Implementation::Loader discovery failed. Version 0.0.7 or higher is required. Error: {.message}",
                        walker-type => 'Qwiratry::Walker::Factory'
                    ).throw;
                }
            }
        }
        
        return @!discovered-walkers;
    }
}
