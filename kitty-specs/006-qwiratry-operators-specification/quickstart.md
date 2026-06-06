# Quickstart: Qwiratry Operators

**Feature**: 006-qwiratry-operators-specification  
**Date**: 2025-01-27

## Overview

Qwiratry operators are RakuAST::Node descendants that represent declarative query intent. They work in both Query Slang expressions and regular Raku code, enabling flexible query composition across different data domains.

## Key Concepts

### Operator Categories

1. **Navigation Operators** - Traverse hierarchical structures (trees, tables, graphs)
2. **Map-Reduce Operators** - Filter, sort, transform, and aggregate collections
3. **Set Operators** - Combine collections using set theory and relational algebra
4. **I/O Operators** - Read, parse, render, and write data

### Core Principles

- **Immutability**: Operators are immutable and safely shareable
- **Composability**: Operators can be chained and combined
- **Domain Flexibility**: Same operator may have different semantics per domain
- **Capability System**: Operators declare capabilities; Walkers check compatibility

## Basic Usage

### Creating Operators

```raku
use Qwiratry::Operator::Navigation;
use Qwiratry::Operator::MapReduce;

# Navigation operator
my $child-op = ChildOperator.new(selector => '*');

# Selection operator
my $select-op = SelectionOperator.new(
    predicate => { $_.age > 18 }
);
```

### Operator Composition

```raku
use Qwiratry::Operator::Set;

# Union of two queries
my $union-op = UnionOperator.new(
    left => $query1,
    right => $query2
);

# Chained navigation
my $nested = ChildOperator.new(
    selector => ChildOperator.new(selector => '*')
);
```

### Checking Capabilities

```raku
my $caps = $operator.capabilities;
if $caps<navigation> && 'tree' ∈ $caps<domains> {
    say "Operator supports tree navigation";
}
```

## Integration with Walkers

### Walker Compatibility

Walkers check operator compatibility during planning:

```raku
class TreeWalker does Walker {
    method plan(RakuAST::Node $query, Mu:D $root --> Walker::Plan) {
        # Check if operator is supported
        unless self.supports($query) {
            die X::Qwiratry::UnknownQueryElement.new(
                query-ast => $query,
                walker-type => self.^name
            );
        }
        # Create execution plan...
    }
    
    method supports(RakuAST::Node $query --> Bool) {
        my $caps = $query.capabilities;
        return $caps<navigation> && 'tree' ∈ $caps<domains>;
    }
}
```

## Common Patterns

### Navigation Pattern

```raku
# Navigate tree structure
my $children = ChildOperator.new(selector => 'item');
my $descendants = DescendantOperator.new(selector => '*');

# Navigate table foreign keys
my $fk-navigation = ChildOperator.new(
    selector => 'customer_id'  # Foreign key column
);
```

### Filtering Pattern

```raku
# Selection with predicate
my $filtered = SelectionOperator.new(
    predicate => { $_.price > 100 && $_.active }
);

# Sort by key
my $sorted = SortOperator.new(
    key-function => { $_.name }
);
```

### Set Operations Pattern

```raku
# Union
my $combined = UnionOperator.new(
    left => $query1,
    right => $query2
);

# Intersection
my $common = IntersectionOperator.new(
    left => $query1,
    right => $query2
);
```

### I/O Pattern

```raku
# Read and parse
my $source = SourceOperator.new(location => 'data.json');
my $parsed = ParseOperator.new(format => 'JSON');

# Render and write
my $rendered = RenderOperator.new(
    format => 'JSON',
    options => { pretty => True }
);
my $dest = DestinationOperator.new(location => 'output.json');
```

## Error Handling

### Compile-Time Errors

Invalid operator syntax is caught by Raku compiler:

```raku
# This will fail at compile-time
my $bad = ChildOperator.new();  # Missing required selector
```

### Planning-Time Errors

Unsupported operators throw during planning:

```raku
try {
    my $plan = $walker.plan($unsupported-operator, $root);
} catch X::Qwiratry::UnknownQueryElement {
    say "Operator not supported by this walker";
}
```

### Runtime Errors

Data validation errors occur during execution:

```raku
# Invalid foreign key navigation
try {
    my $iter = $walker.start($query, $root);
    $iter.pull-one;
} catch X::Qwiratry::Navigation::InvalidForeignKey {
    say "Foreign key not found";
}
```

## Next Steps

1. **Implement Core Operators**: Start with navigation operators (P1)
2. **Add Map-Reduce**: Implement selection, sort, map, reduce (P1)
3. **Set Operations**: Implement union, intersection, joins (P2)
4. **I/O Operations**: Implement source, parse, render, destination (P2)
5. **Query Slang Integration**: Integrate operators into Query Slang (separate feature)

## References

- **Specification**: [spec.md](spec.md)
- **Data Model**: [data-model.md](data-model.md)
- **API Contract**: [contracts/operator-api.md](contracts/operator-api.md)
- **Operators Reference**: `../../Operators.md`

