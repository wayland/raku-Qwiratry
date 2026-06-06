# API Contract: Qwiratry Operators

**Version**: 1.0.0  
**Feature**: 006-qwiratry-operators-specification

## Overview

This contract defines the API for Qwiratry query operators. All operators are RakuAST::Node descendants that work in both Query Slang expressions and regular Raku code.

## Operator Base Contract

### Type Constraint

All operators MUST extend `RakuAST::Node`:

```raku
class MyOperator is RakuAST::Node {
    # Operator implementation
}
```

### Required Methods

#### `capabilities(--> Associative)`

Returns capability metadata describing operator capabilities and domain support.

**Returns**: `Associative` (Hash) with structure:
```raku
{
    navigation => Bool,      # True if navigation operator
    map-reduce => Bool,      # True if map-reduce operator
    set-operation => Bool,   # True if set operation
    io => Bool,              # True if I/O operation
    domains => Array[Str],   # Supported domains: ['tree', 'table', 'graph']
    lazy => Bool,            # Supports lazy evaluation
    formats => Array[Str]    # Supported formats (for I/O operators)
}
```

**Example**:
```raku
method capabilities(--> Associative) {
    {
        navigation => True,
        domains => ['tree', 'table'],
        lazy => True
    }
}
```

#### `describe(--> Str)`

Returns human-readable description for debugging and introspection.

**Returns**: `Str` - Description string

**Example**:
```raku
method describe(--> Str) {
    "ChildOperator(selector: {$!selector.gist})"
}
```

### Immutability Contract

- Operators MUST be immutable (no observable mutations after creation)
- Attributes MUST be read-only (`has $.attr` not `has $!attr` with mutators)
- Methods MUST NOT modify operator state

### Composition Contract

- Operators MUST support nesting (operators can contain other operators)
- Composition MUST maintain immutability
- Operators MUST be safely shareable across multiple queries

## Navigation Operators

### ChildOperator (`⪪`)

**Type**: `class ChildOperator is RakuAST::Node does NavigationOperator`

**Attributes**:
- `$.selector` (Mu) - Right operand (wildcard `*`, label, or selector)
- `$.adverbs` (Associative?) - Optional adverbs

**Constructor**:
```raku
ChildOperator.new(
    selector => Mu,
    adverbs => Associative? = Nil
) --> ChildOperator
```

**Capabilities**:
```raku
{
    navigation => True,
    domains => ['tree', 'table', 'graph'],
    lazy => True
}
```

### ParentOperator (`⪫`)

**Type**: `class ParentOperator is RakuAST::Node does NavigationOperator`

**Attributes**:
- `$.selector` (Mu) - Right operand (typically `*`)
- `$.adverbs` (Associative?) - Optional adverbs (e.g., `:reference`)

**Constructor**:
```raku
ParentOperator.new(
    selector => Mu,
    adverbs => Associative? = Nil
) --> ParentOperator
```

**Special Adverbs**:
- `:reference` - Navigate backwards through foreign key relationships (for tables)

### RootOperator (`⇤`)

**Type**: `class RootOperator is RakuAST::Node does NavigationOperator`

**Attributes**: None (unary postfix operator)

**Constructor**:
```raku
RootOperator.new() --> RootOperator
```

**Note**: This is a unary postfix operator, unlike other navigation operators which are binary.

## Map-Reduce Operators

### SelectionOperator (`σ`)

**Type**: `class SelectionOperator is RakuAST::Node does MapReduceOperator`

**Attributes**:
- `$.predicate` (Code) - Predicate block for filtering

**Constructor**:
```raku
SelectionOperator.new(
    predicate => Code
) --> SelectionOperator
```

**Capabilities**:
```raku
{
    map-reduce => True,
    lazy => True
}
```

### SortOperator (`⇅`)

**Type**: `class SortOperator is RakuAST::Node does MapReduceOperator`

**Attributes**:
- `$.key-function` (Code) - Key function for sorting

**Constructor**:
```raku
SortOperator.new(
    key-function => Code
) --> SortOperator
```

## Set Operators

### UnionOperator (`∪`)

**Type**: `class UnionOperator is RakuAST::Node does SetOperator`

**Attributes**:
- `$.left` (RakuAST::Node) - Left operand (query/collection)
- `$.right` (RakuAST::Node) - Right operand (query/collection)

**Constructor**:
```raku
UnionOperator.new(
    left => RakuAST::Node,
    right => RakuAST::Node
) --> UnionOperator
```

**Capabilities**:
```raku
{
    set-operation => True,
    lazy => True
}
```

### InnerJoinOperator (`⨝`)

**Type**: `class InnerJoinOperator is RakuAST::Node does SetOperator`

**Attributes**:
- `$.left` (RakuAST::Node) - Left relation
- `$.right` (RakuAST::Node) - Right relation
- `$.condition` (Code?) - Optional join condition

**Constructor**:
```raku
InnerJoinOperator.new(
    left => RakuAST::Node,
    right => RakuAST::Node,
    condition => Code? = Nil
) --> InnerJoinOperator
```

## I/O Operators

### SourceOperator (`⮳`)

**Type**: `class SourceOperator is RakuAST::Node does IOOperator`

**Attributes**:
- `$.location` (Str) - File path, URL, or location identifier

**Constructor**:
```raku
SourceOperator.new(
    location => Str
) --> SourceOperator
```

**Location Formats**:
- File path: `"data.json"` or `"/absolute/path/data.json"`
- URL: `"https://example.com/data.json"` or `"http://localhost:8080/api/data"`
- Protocol: `"file:///path/to/file"`

### ParseOperator (`↱`, `⮣`)

**Type**: `class ParseOperator is RakuAST::Node does IOOperator`

**Attributes**:
- `$.format` (Str) - Format identifier (JSON, XML, CSV, etc.)

**Constructor**:
```raku
ParseOperator.new(
    format => Str
) --> ParseOperator
```

**Format Detection**: Format modules must exist as `Qwiratry::IO::Parse::{format}`

### RenderOperator (`↴`, `⮧`)

**Type**: `class RenderOperator is RakuAST::Node does IOOperator`

**Attributes**:
- `$.format` (Str) - Format identifier
- `$.options` (Associative?) - Format-specific options (e.g., `:pretty`)

**Constructor**:
```raku
RenderOperator.new(
    format => Str,
    options => Associative? = Nil
) --> RenderOperator
```

## Capability System Contract

### Capability Roles

Operators implement capability roles to declare their semantics:

```raku
role NavigationOperator {
    method capabilities(--> Associative) { ... }
}

role MapReduceOperator {
    method capabilities(--> Associative) { ... }
}

role SetOperator {
    method capabilities(--> Associative) { ... }
}

role IOOperator {
    method capabilities(--> Associative) { ... }
}
```

### Walker Compatibility Check

Walkers check operator compatibility via `supports()` method:

```raku
method supports(RakuAST::Node $query --> Bool) {
    # Check if operator capabilities match walker's domain
    my $caps = $query.capabilities;
    return $caps<navigation> && 'tree' ∈ $caps<domains>;
}
```

## Error Handling

### Compile-Time Errors

- Invalid operator syntax → Raku compiler error
- Missing required attributes → Type error

### Planning-Time Errors

- Unsupported operator → `X::Qwiratry::UnknownQueryElement`
- Incompatible capabilities → `X::Qwiratry::UnknownQueryElement`

### Runtime Errors

- Invalid data → Domain-specific exceptions
- Missing format modules → `X::Qwiratry::IO::FormatNotFound`
- Invalid location → `X::Qwiratry::IO::LocationError`

## Examples

### Creating Operators

```raku
# Navigation operator
my $child-op = ChildOperator.new(selector => '*');

# Selection operator
my $select-op = SelectionOperator.new(
    predicate => { $_.age > 18 }
);

# Union operator
my $union-op = UnionOperator.new(
    left => $query1,
    right => $query2
);
```

### Checking Capabilities

```raku
my $caps = $operator.capabilities;
if $caps<navigation> && 'tree' ∈ $caps<domains> {
    # Operator supports tree navigation
}
```

### Walker Integration

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
}
```

