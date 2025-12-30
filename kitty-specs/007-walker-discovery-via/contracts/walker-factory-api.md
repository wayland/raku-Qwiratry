# WalkerFactory API Contract

**Feature**: Walker Discovery via Implementation::Loader  
**Date**: 2025-01-27

## Method: discover-walkers

### Signature

```raku
method discover-walkers(Bool :$refresh = False --> Array[Walker])
```

### Description

Discovers available Walker classes using Implementation::Loader. Scans for classes matching the `Qwiratry::Walker::*` pattern in the `lib` directory. Results are cached for performance, with optional refresh capability.

### Parameters

- `:$refresh` (Bool, optional, default: False) - If True, forces re-discovery and updates cache. If False, returns cached results if available.

### Returns

- `Array[Walker]` - Array of Walker type objects (not instances). Empty array if no matching classes found.

### Preconditions

- Implementation::Loader (v0.0.7+) must be available as a dependency
- `lib` directory must exist and follow standard Raku module structure

### Postconditions

- If discovery succeeds: `@!discovered-walkers` is populated and `$!discovery-performed` is True
- Returned array contains type objects (not instances) of discovered classes
- Discovered classes are assumed to implement Walker role (no verification performed)

### Exceptions

- Throws exception if Implementation::Loader is unavailable
- Throws exception if Implementation::Loader version is below 0.0.7
- Throws exception if Implementation::Loader fails during discovery (e.g., invalid pattern)

### Side Effects

- First call or refresh: loads matching Walker classes into memory
- Updates internal cache state (`@!discovered-walkers`, `$!discovery-performed`)
- Does not load non-matching modules

### Examples

```raku
# First call - performs discovery and caches results
my @walkers = $factory.discover-walkers();
say @walkers.elems;  # Number of discovered Walker classes

# Subsequent call - returns cached results
my @cached = $factory.discover-walkers();  # Fast, no discovery

# Force refresh - re-discovers and updates cache
my @refreshed = $factory.discover-walkers(:refresh);

# Empty result when no matching classes
# Returns empty array, does not throw
```

### Testing Requirements

- Test discovery with matching classes
- Test empty result when no matches
- Test caching behavior (second call returns cached)
- Test refresh parameter forces re-discovery
- Test exception when Implementation::Loader unavailable
- Test exception when version incompatible

