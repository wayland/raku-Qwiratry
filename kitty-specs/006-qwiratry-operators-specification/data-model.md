# Data Model: Qwiratry Operators Specification

**Feature**: Qwiratry Operators Specification  
**Date**: 2025-01-27  
**Phase**: 1 - Design & Contracts

## Entities

### Operator Base (RakuAST::Node descendant)

**Purpose**: Base class/role for all Qwiratry query operators. All operators extend RakuAST::Node and implement operator-specific behavior.

**Attributes**:
- Inherits from `RakuAST::Node` (immutable AST node structure)
- Operator-specific attributes (varies by operator type)
- Capability metadata (via `capabilities()` method)

**Methods**:
- `capabilities(--> Associative)` - Returns capability metadata hash
- `describe(--> Str)` - Human-readable description for debugging
- Operator-specific methods (varies by operator type)

**Lifecycle**:
- Created during Query Slang parsing or direct instantiation
- Immutable (cannot be modified after creation)
- Composable (can be nested in other operators)
- Reusable (can be shared across multiple queries)

**Relationships**:
- Extends `RakuAST::Node`
- May contain child operators (for composition)
- Declares capabilities via roles
- Processed by `Walker.plan()` method

**Constraints**:
- Must be immutable (no observable mutations)
- Must implement `capabilities()` method
- Must be introspectable by Walkers
- Must work in both Query Slang and regular Raku code

---

### Navigation Operator

**Purpose**: Operators for traversing hierarchical structures (trees, tables, graphs).

**Types**:
- `ChildOperator` (`⪪`) - Direct children
- `ParentOperator` (`⪫`) - Direct parent
- `DescendantOperator` (`⪪⪪`) - All descendants
- `AncestorOperator` (`⪫⪫`) - All ancestors
- `FollowingSiblingOperator` (`⪨`) - Next siblings
- `PrecedingSiblingOperator` (`⪩`) - Previous siblings
- `FollowingOperator` (`⪨⪨`) - All following nodes
- `PrecedingOperator` (`⪩⪩`) - All preceding nodes
- `RootOperator` (`⇤`) - Root node (unary postfix)
- `AttributeOperator` (`⥷`) - Attributes/key-value pairs

**Attributes**:
- `$.selector` (Mu) - Right operand (wildcard `*`, label, or selector)
- `$.adverbs` (Associative) - Optional adverbs (e.g., `:reference` for parent)
- Operator-specific attributes

**Methods**:
- `capabilities(--> Associative)` - Returns `{ navigation => True, domains => [...] }`
- `selector()` - Returns selector value
- Domain-specific methods (e.g., `follows-foreign-key()` for table navigation)

**Capabilities**:
- Declares `does NavigationOperator` role
- Capability metadata: `{ navigation => True, domains => ['tree', 'table', 'graph'] }`

**Domain-Specific Semantics**:
- **Tree**: Navigates child/parent relationships in hierarchical structures
- **Table**: Child follows foreign keys; parent navigates backwards through FKs
- **Graph**: Follows edges between nodes

---

### Map-Reduce Operator

**Purpose**: Operators for filtering, sorting, transforming, and aggregating collections.

**Types**:
- `SelectionOperator` (`σ`) - Filter tuples/items
- `SortOperator` (`⇅`) - Sort tuples/items
- `MapOperator` (`».`) - Transform values (uses Raku hyper operator)
- `ReduceOperator` (`⌿`) - Aggregate to single value

**Attributes**:
- `$.predicate` (Code) - Block/predicate for selection/sorting
- `$.key-function` (Code) - Key function for sorting
- `$.operation` (Code) - Operation for reduce
- Operator-specific attributes

**Methods**:
- `capabilities(--> Associative)` - Returns `{ map-reduce => True, lazy => True }`
- `predicate()` - Returns predicate block
- `key-function()` - Returns key function (for sort)

**Capabilities**:
- Declares `does MapReduceOperator` role
- Capability metadata: `{ map-reduce => True, lazy => True }`

---

### Set Operator

**Purpose**: Operators for combining collections using set theory and relational algebra.

**Types**:
- **Membership**: `ElementOfOperator` (`∈`), `ContainsOperator` (`∋`)
- **Subset**: `SubsetOperator` (`⊂`), `SubsetOrEqualOperator` (`⊆`)
- **Set Operations**: `UnionOperator` (`∪`), `IntersectionOperator` (`∩`), `SymmetricDifferenceOperator` (`⊖`), `SetDifferenceOperator` (`∖`)
- **Relational**: `ProjectionOperator` (`Π`), `RenameOperator` (`ρ`), `InnerJoinOperator` (`⨝`), `LeftOuterJoinOperator` (`⟕`), `RightOuterJoinOperator` (`⟖`), `FullOuterJoinOperator` (`⟗`), `SemijoinOperator` (`⋉`, `⋊`), `AntijoinOperator` (`▷`, `◁`), `DivisionOperator` (`÷`), `CrossJoinOperator` (`X`)

**Attributes**:
- `$.left` (RakuAST::Node) - Left operand (query/collection)
- `$.right` (RakuAST::Node) - Right operand (query/collection)
- `$.condition` (Code?) - Optional join condition
- Operator-specific attributes

**Methods**:
- `capabilities(--> Associative)` - Returns `{ set-operation => True, relational => True/False }`
- `left()` - Returns left operand
- `right()` - Returns right operand

**Capabilities**:
- Declares `does SetOperator` role
- Capability metadata: `{ set-operation => True, relational => True/False }`

---

### I/O Operator

**Purpose**: Operators for reading, parsing, rendering, and writing data.

**Types**:
- `SourceOperator` (`⮳`) - Read from external source
- `ParseOperator` (`↱`, `⮣`) - Parse input format
- `RenderOperator` (`↴`, `⮧`) - Render output format
- `DestinationOperator` (`⮷`) - Write to external destination

**Attributes**:
- `$.location` (Str) - File path, URL, or location identifier
- `$.format` (Str) - Format identifier (JSON, XML, CSV, etc.)
- `$.options` (Associative) - Format-specific options (e.g., `:pretty`)

**Methods**:
- `capabilities(--> Associative)` - Returns `{ io => True, formats => [...] }`
- `location()` - Returns location string
- `format()` - Returns format identifier
- `options()` - Returns format options

**Capabilities**:
- Declares `does IOOperator` role
- Capability metadata: `{ io => True, formats => ['json', 'xml', 'csv', ...] }`

---

### Capability Role

**Purpose**: Roles that operators implement to declare their capabilities and domain support.

**Types**:
- `NavigationOperator` - Navigation capabilities
- `MapReduceOperator` - Map-reduce capabilities
- `SetOperator` - Set operation capabilities
- `IOOperator` - I/O operation capabilities

**Methods**:
- `capabilities(--> Associative)` - Returns capability metadata hash

**Capability Metadata Structure**:
```raku
{
    navigation => Bool,      # Navigation operator
    map-reduce => Bool,      # Map-reduce operator
    set-operation => Bool,   # Set operation
    io => Bool,              # I/O operation
    domains => Array[Str],   # Supported domains: ['tree', 'table', 'graph']
    lazy => Bool,            # Supports lazy evaluation
    formats => Array[Str]     # Supported formats (for I/O)
}
```

**Lifecycle**:
- Applied at compile-time via role composition
- Discovered at runtime via `capabilities()` method
- Used by Walkers to check compatibility

**Relationships**:
- Implemented by operator classes
- Checked by Walkers via `supports()` method

---

### X::Qwiratry::UnknownQueryElement Exception

**Purpose**: Exception thrown when Walker cannot interpret an operator.

**Attributes**:
- `$.query-ast` (RakuAST::Node) - The operator that couldn't be interpreted
- `$.walker-type` (Str) - Type of walker that threw exception
- `$.message` (Str) - Error message

**Lifecycle**:
- Created when `Walker.plan()` encounters unsupported operator
- Thrown immediately
- Caught by calling code

**Relationships**:
- Extends `X::Qwiratry::Walker` (base exception)
- Contains operator AST node for diagnostics

---

## Relationships

| Source | Relation | Target | Cardinality | Notes |
|--------|----------|--------|-------------|-------|
| Operator | extends | RakuAST::Node | 1:1 | All operators are AST nodes |
| Operator | implements | Capability Role | M:N | Operators can implement multiple capability roles |
| Operator | composes | Operator | M:N | Operators can be nested/composed |
| NavigationOperator | declares | NavigationOperator role | 1:1 | Navigation capability |
| MapReduceOperator | declares | MapReduceOperator role | 1:1 | Map-reduce capability |
| SetOperator | declares | SetOperator role | 1:1 | Set operation capability |
| IOOperator | declares | IOOperator role | 1:1 | I/O capability |
| Walker | processes | Operator | 1:M | Walkers process operator ASTs |
| Walker | checks | Capability Role | 1:M | Walkers check operator capabilities |
| X::Qwiratry::UnknownQueryElement | contains | Operator | 1:1 | Exception references operator |

## Validation & Governance

### Data Quality Requirements

- **Immutability**: Operators must be immutable (no observable mutations after creation)
- **Type Safety**: Operators must be valid RakuAST::Node descendants
- **Capability Declaration**: All operators must implement at least one capability role
- **Selector Validation**: Navigation operators must validate selector types (wildcard, label, etc.)
- **Format Validation**: I/O operators must validate format identifiers against available modules

### Compliance Considerations

- **Backward Compatibility**: Operators must not break existing Walker interface
- **Error Handling**: Invalid operators must fail gracefully with actionable error messages
- **Domain Compatibility**: Operators must declare domain support via capabilities

### Source of Truth

- **Operator Definitions**: `lib/Qwiratry/Operator/*.rakumod` modules
- **Capability System**: `lib/Qwiratry/Operator/Capability.rakumod`
- **Specification**: `Operators.md` (defines operator semantics and precedence)
- **Walker Integration**: Existing `lib/Qwiratry/Walker.rakumod` interface

## State Transitions

Operators are immutable and have no state transitions. They are created once and remain unchanged throughout their lifecycle.

**Creation**:
- During Query Slang parsing → Operator AST node created
- Direct instantiation in code → Operator AST node created

**Usage**:
- Passed to `Walker.plan()` → Walker introspects and creates execution plan
- Executed via `QueryIterator` → Results produced incrementally

**No State Changes**: Operators remain immutable throughout their lifecycle.

