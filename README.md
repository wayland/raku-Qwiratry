# Qwiratry

A Raku architecture for declarative queries and flexible data walking, suitable for trees, tables, relational structures, logic-programming environments, and anything reasonably structured and traversable.

## Overview

Qwiratry provides a general-purpose query execution pipeline that separates **what** to query from **how** to walk the data. This design enables the same query to work across different data models without forcing a single semantic interpretation.

The framework is built around five core architectural groups:

- **Query Group**: Declarative, immutable query specifications (what to find)
- **Walker Group**: Traversal strategies and execution plans (how to walk)
- **Strategy Group**: Element-level behavior and reusable processing logic
- **Transformer Group**: Declarative data transformations using molds
- **Per-Traversal Group**: Mutable state management (`Context`) and incremental result streaming (`QueryIterator`)

## Key Features

- **Separation of Concerns**: Queries describe intent; Walkers interpret and execute; QueryIterators yield results
- **Reusability**: Walkers can produce multiple iterators; queries can be reused and optimized
- **Composability**: Supports composite walker handovers for multi-domain queries
- **Declarative Transformations**: XSLT-like mold system for structured data manipulation
- **Flexible Execution**: Supports backtracking, multi-phase execution, and optimization planning
- **Domain Flexibility**: Works with trees (ASTs, XML, JSON), tables, logic programming, and hybrid systems

## Installation

```bash
zef install Qwiratry
```

Or install from source:

```bash
git clone <repository-url>
cd raku-Qwiratry
zef install .
```

Either way, you'll need to set RAKUDO_RAKUAST=1 to run it

## Quick Start

```raku
use Qwiratry;

# Declare a transformer with molds
transformer MyTransform {
    mold TOP do {
        # Transform the root node
        return $*NODE.deepcopy;
    }
    
    mold /type eq 'element'/ do {
        # Match and transform specific elements
        return $*NODE.clone;
    }
}

# Use the transformer
my $result = MyTransform.transform($data-structure);
```

## Architecture

Qwiratry's architecture enables:

- **Multiple traversal strategies** for the same query
- **Query optimization** before execution
- **Streaming results** via lazy iterators
- **Composite execution** across multiple domains
- **Pluggable strategies** for element processing

## Documentation

- [Specification.md](Specification.md) - Complete architecture specification
- [Operators.md](Operators.md) - Query operator reference
- `kitty-specs/` - Detailed feature specifications and design documents
- `t/examples/` - Example code and usage patterns

## Requirements

- Raku 6.e or later
- `Slangify` module
- `Implementation::Loader` v0.0.7 or later

## Testing

Run the test suite.  zef seems to be broken with RAKUDO_RAKUAST=1 so you'll need to do:

```bash
./project test
```

## License

See the repository for license information.

## Author

Tim Nelson (wayland at wayland dot id dot au)

