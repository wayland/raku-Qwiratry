=begin pod

Copy service class for shallow and deep copying of transformable nodes

This module provides `copy()` and `deepcopy()` multi subs as service functions
for copying transformable nodes. Transformable nodes are those that have a Walker
with the `supports-rewrite` capability.

Follows spec section 3.3.6 exactly.

=end pod
unit module Qwiratry::Copy;

# T033: Create Copy module structure

=begin pod

Shallow copy - creates a new instance sharing children with original.

Default identity case - returns value as-is for immutable primitives
and objects with identity.

@param $x - Value to copy
@returns Mu - Copy of value (or original if identity)

=end pod
# T034: copy(Mu) multi sub - default identity
# Use proto to declare multi subs (avoid conflict with built-in copy)
proto sub copy(|) is export {*}

multi sub copy(Mu $x --> Mu) {
    # T042: Check for custom .copy() method first (for all types)
    if $x.^find_method('copy', :no_fallback) -> $method {
        # Custom method exists - call it
        # Note: Custom method should still be O(1) per spec
        return $x.copy();
    }
    
    # Default: identity (for immutable primitives and objects with identity)
    $x
}

=begin pod

Shallow copy for Positional types (arrays, lists).

First checks if node has custom `.copy()` method, calls it if available.
Otherwise uses `clone` for shallow copy (O(1) operation).

@param $p - Positional value to copy
@returns Positional - Shallow copy (children shared with original)

=end pod
# T035: copy(Positional) multi sub - shallow copy via clone
multi sub copy(Positional $p --> Positional) {
    # T042: Check for custom .copy() method first
    if $p.^find_method('copy', :no_fallback) -> $method {
        # Custom method exists - call it
        # Note: Custom method should still be O(1) per spec
        return $p.copy();
    }
    
    # Default: use clone for shallow copy (O(1))
    $p.clone
}

=begin pod

Shallow copy for Associative types (hashes, maps).

First checks if node has custom `.copy()` method, calls it if available.
Otherwise uses `clone` for shallow copy (O(1) operation).

@param $a - Associative value to copy
@returns Associative - Shallow copy (children shared with original)

=end pod
# T036: copy(Associative) multi sub - shallow copy via clone
multi sub copy(Associative $a --> Associative) {
    # T042: Check for custom .copy() method first
    if $a.^find_method('copy', :no_fallback) -> $method {
        # Custom method exists - call it
        # Note: Custom method should still be O(1) per spec
        return $a.copy();
    }
    
    # Default: use clone for shallow copy (O(1))
    $a.clone
}

=begin pod

Deep copy - recursively clones node and all descendants.

Default identity case - returns value as-is for immutable primitives
(Str, Numeric, Bool) and objects with identity.

@param $x - Value to deep copy
@param :%visited - Internal visited hash for cycle detection (optional)
@returns Mu - Deep copy of value (or original if identity)

=end pod
# T037: deepcopy(Mu) multi sub - default identity
# Use proto to declare multi subs
proto sub deepcopy(|) is export {*}

multi sub deepcopy(Mu $x, :%visited = %() --> Mu) {
    $x  # atoms, objects with identity
}

=begin pod

Recursive deep copy for Positional types.

Recursively calls deepcopy on each element. Uses visited hash
for cycle detection and DAG preservation.

@param $p - Positional value to deep copy
@param :%visited - Internal visited hash for cycle detection
@returns Positional - Deep copy with all descendants cloned

=end pod
# T038: deepcopy(Positional) multi sub - recursive deep copy
multi sub deepcopy(Positional $p, :%visited = %() --> Positional) {
    # T040/T041: Check visited hash for cycle detection and DAG preservation
    my $identity = $p.WHICH;
    if %visited{$identity}:exists {
        # Already visited - return existing clone (cycle detection / DAG preservation)
        return %visited{$identity};
    }
    
    # T040/T041: Create placeholder and store in visited hash BEFORE recursing
    # This prevents infinite recursion when encountering cycles
    my $cloned = Array.new;
    %visited{$identity} = $cloned;
    
    # Now recursively deep-copy elements into the cloned array
    for $p -> $elem {
        $cloned.push(deepcopy($elem, :%visited));
    }
    
    return $cloned;
}

=begin pod

Recursive deep copy for Associative types.

Recursively calls deepcopy on each value. Uses visited hash
for cycle detection and DAG preservation.

@param $a - Associative value to deep copy
@param :%visited - Internal visited hash for cycle detection
@returns Associative - Deep copy with all descendants cloned

=end pod
# T039: deepcopy(Associative) multi sub - recursive deep copy with cycle detection
multi sub deepcopy(Associative $a, :%visited = %() --> Associative) {
    # T040/T041: Check visited hash for cycle detection and DAG preservation
    my $identity = $a.WHICH;
    if %visited{$identity}:exists {
        # Already visited - return existing clone (cycle detection / DAG preservation)
        return %visited{$identity};
    }
    
    # T040/T041: Create placeholder and store in visited hash BEFORE recursing
    # This prevents infinite recursion when encountering cycles
    my $cloned = Hash.new;
    %visited{$identity} = $cloned;
    
    # Now recursively deep-copy values into the cloned hash
    for $a.kv -> $key, $value {
        $cloned{$key} = deepcopy($value, :%visited);
    }
    
    return $cloned;
}
