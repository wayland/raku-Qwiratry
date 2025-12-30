# Data Model: Walker Discovery via Implementation::Loader

**Feature**: Walker Discovery via Implementation::Loader  
**Date**: 2025-01-27

## Entities

### WalkerFactory (Enhanced)

**Description**: Factory class that maintains Walker registry and provides discovery functionality. Enhanced with automatic discovery using Implementation::Loader.

**Attributes**:
- `%!walker-registry` (Hash) - Registry of Walker types keyed by data type/role name
- `@!discovered-walkers` (Array[Walker]) - Cached discovered Walker type objects (private, lazy)
- `$!discovery-performed` (Bool) - Flag indicating if discovery has been performed (private)

**Methods** (existing, unchanged):
- `instance()` → WalkerFactory - Get or create singleton instance
- `get-walker($data)` → Mu - Get appropriate Walker for given data
- `register-walker($type, $walker-type)` - Register a Walker type explicitly

**Methods** (modified):
- `discover-walkers(Bool :$refresh = False)` → Array[Walker] - Discover available Walkers via Implementation::Loader
  - If `$refresh` is True or discovery not performed, run discovery and cache results
  - Otherwise return cached `@!discovered-walkers`
  - Uses Implementation::Loader to scan for `Qwiratry::Walker::*` pattern in `lib` directory
  - Returns Array of Walker type objects (not instances)
  - Throws exception if Implementation::Loader unavailable or incompatible

**State Transitions**:
- Initial: `$!discovery-performed = False`, `@!discovered-walkers = []`
- After first discovery: `$!discovery-performed = True`, `@!discovered-walkers` populated
- After refresh: `@!discovered-walkers` repopulated, `$!discovery-performed` remains True

**Validation Rules**:
- Discovered classes are assumed to implement Walker (no runtime verification)
- Empty array returned if no matching classes found
- Exception thrown if Implementation::Loader unavailable or version < 0.0.7

## Relationships

- **WalkerFactory** uses **Implementation::Loader** for discovery (external dependency)
- **WalkerFactory** discovers **Walker** type objects (assumed to implement Walker role)
- **WalkerFactory** maintains registry of **Walker** types (existing functionality)

## Data Flow

1. **Discovery Flow**:
   - User calls `discover-walkers(:refresh)` or first call
   - Implementation::Loader scans `lib` for `Qwiratry::Walker::*` pattern
   - Matching classes loaded and type objects collected
   - Results cached in `@!discovered-walkers`
   - Cached results returned on subsequent calls (unless refresh requested)

2. **Error Flow**:
   - If Implementation::Loader unavailable → throw exception
   - If version incompatible → throw exception
   - If no matches found → return empty array (not an error)

