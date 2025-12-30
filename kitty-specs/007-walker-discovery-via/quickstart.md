# Quickstart: Walker Discovery via Implementation::Loader

**Feature**: Walker Discovery via Implementation::Loader  
**Date**: 2025-01-27

## Overview

The `WalkerFactory.discover-walkers()` method automatically discovers Walker classes using Implementation::Loader. This eliminates the need to manually register each Walker implementation.

## Prerequisites

1. **Add Implementation::Loader dependency** to `META6.json`:
   ```json
   {
     "depends": [
       "Slangify",
       "Implementation::Loader:ver<0.0.7+>"
     ]
   }
   ```

2. **Install dependency**:
   ```bash
   zef install --deps-only .
   ```

## Basic Usage

### Automatic Discovery

```raku
use Qwiratry::WalkerFactory;

my $factory = WalkerFactory.instance;

# Discover all Walker classes matching Qwiratry::Walker::* pattern
my @walkers = $factory.discover-walkers();

say "Found {@walkers.elems} Walker classes";
for @walkers -> $walker-type {
    say "  - {$walker-type.^name}";
}
```

### Caching

Discovery results are automatically cached for performance:

```raku
# First call - performs discovery
my @first = $factory.discover-walkers();

# Second call - returns cached results (fast)
my @cached = $factory.discover-walkers();
```

### Force Refresh

If you dynamically load new Walker classes, force a refresh:

```raku
# Load a new Walker class at runtime
require Qwiratry::Walker::MyNewWalker;

# Force re-discovery to include the new class
my @refreshed = $factory.discover-walkers(:refresh);
```

## Creating Discoverable Walker Classes

To make your Walker class discoverable, place it in the `Qwiratry::Walker::*` namespace:

```raku
# File: lib/Qwiratry/Walker/MyWalker.rakumod
unit module Qwiratry::Walker::MyWalker;

use Qwiratry::Walker;

class MyWalker does Walker {
    method plan($query, $root) { ... }
    method iterator($plan) { ... }
}
```

The discovery mechanism will automatically find this class.

## Error Handling

If Implementation::Loader is unavailable or incompatible:

```raku
try {
    my @walkers = $factory.discover-walkers();
    CATCH {
        when X::Qwiratry {
            note "Discovery failed: {.message}";
            note "Ensure Implementation::Loader v0.0.7+ is installed";
        }
    }
}
```

## Integration with Existing Code

The discovery mechanism works alongside explicit registration:

```raku
# Explicit registration (still works)
$factory.register-walker(MyType, MyWalker);

# Automatic discovery (new)
my @discovered = $factory.discover-walkers();

# get-walker() checks registry first, then can use discovered walkers
my $walker = $factory.get-walker($data);
```

## Performance Considerations

- **First call**: Performs discovery (may load modules)
- **Subsequent calls**: Returns cached results (fast)
- **Refresh**: Re-performs discovery (use only when needed)

Discovery only loads modules matching the `Qwiratry::Walker::*` pattern, avoiding unnecessary module loading.

## Troubleshooting

**Problem**: `discover-walkers()` throws exception  
**Solution**: Ensure Implementation::Loader v0.0.7+ is installed and listed in `META6.json`

**Problem**: No Walker classes discovered  
**Solution**: Verify classes are in `Qwiratry::Walker::*` namespace and located in `lib` directory

**Problem**: New Walker class not discovered  
**Solution**: Call `discover-walkers(:refresh)` to force re-discovery

