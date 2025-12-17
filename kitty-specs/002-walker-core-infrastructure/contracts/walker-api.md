# API Contracts: Walker Core Infrastructure

**Feature**: Walker Core Infrastructure  
**Date**: 2025-12-17  
**Phase**: 1 - Design & Contracts

## Walker Role API

### `method plan`

```raku
method plan(
    RakuAST::Node $query,
    Mu $root
    --> Walker::Plan
)
```

**Contract**:
- **Input**: Query AST (`RakuAST::Node`) and root data (`Mu`)
- **Output**: `Walker::Plan` object
- **Errors**: Throws `X::Qwiratry::UnknownQueryElement` if Query AST cannot be interpreted
- **Side Effects**: None (must not mutate Query AST)

**Preconditions**:
- `$query` is a valid `RakuAST::Node`
- `$root` is the root data structure to query

**Postconditions**:
- Returns a `Walker::Plan` containing the query
- Plan can produce multiple iterators

---

### `method iterator`

```raku
method iterator(
    RakuAST::Node $q
    --> QueryIterator
)
```

**Contract**:
- **Input**: Query AST (`RakuAST::Node`)
- **Output**: `QueryIterator` instance
- **Errors**: Throws `X::Qwiratry::UnknownQueryElement` if Query AST cannot be interpreted
- **Side Effects**: Creates plan internally (convenience method)

**Preconditions**:
- `$q` is a valid `RakuAST::Node`
- Walker instance has root data available (via instance state)

**Postconditions**:
- Returns a `QueryIterator` ready to produce results
- Equivalent to `self.plan($q, $root).iterator`

---

### `method start`

```raku
method start(
    RakuAST::Node $query,
    Mu:D $root
    --> QueryIterator
)
```

**Contract**:
- **Input**: Query AST (`RakuAST::Node`) and root data (`Mu:D`)
- **Output**: `QueryIterator` instance
- **Errors**: Throws `X::Qwiratry::UnknownQueryElement` if Query AST cannot be interpreted
- **Side Effects**: Creates plan and iterator internally

**Preconditions**:
- `$query` is a valid `RakuAST::Node`
- `$root` is defined (not Nil)

**Postconditions**:
- Returns a `QueryIterator` ready to produce results
- Equivalent to `self.plan($query, $root).iterator`

**Default Implementation**:
```raku
method start(RakuAST::Node $query, Mu:D $root --> QueryIterator) {
    self.plan($query, $root).iterator
}
```

---

### `method PRE-PASS`

```raku
method PRE-PASS(Context $ctx) { }
```

**Contract**:
- **Input**: `Context` object
- **Output**: None (void)
- **Errors**: None (optional hook)
- **Side Effects**: Implementation-specific (may initialize Context state)

**Preconditions**:
- `$ctx` is a valid `Context` instance
- Called before traversal begins

**Postconditions**:
- Context may be modified (implementation-specific)

**Default Implementation**: Empty (no-op)

---

### `method POST-PASS`

```raku
method POST-PASS(Context $ctx) { }
```

**Contract**:
- **Input**: `Context` object
- **Output**: None (void)
- **Errors**: None (optional hook)
- **Side Effects**: Implementation-specific (may finalize Context state)

**Preconditions**:
- `$ctx` is a valid `Context` instance
- Called after traversal completes

**Postconditions**:
- Context may be modified (implementation-specific)

**Default Implementation**: Empty (no-op)

---

### `method capabilities`

```raku
method capabilities(--> Associative) { }
```

**Contract**:
- **Input**: None
- **Output**: `Associative` (Hash) with structured metadata
- **Errors**: None (optional introspection)
- **Side Effects**: None

**Preconditions**: None

**Postconditions**:
- Returns hash with capability metadata
- Format: `{ lazy => { enabled => True, type => "incremental" }, ... }`

**Default Implementation**: Returns empty hash `{}`

---

### `method supports`

```raku
method supports(RakuAST::Node $query --> Bool) { }
```

**Contract**:
- **Input**: Query AST (`RakuAST::Node`)
- **Output**: `Bool` (True if can interpret, False otherwise)
- **Errors**: None (optional introspection)
- **Side Effects**: None

**Preconditions**:
- `$query` is a valid `RakuAST::Node`

**Postconditions**:
- Returns `True` if Walker can interpret query, `False` otherwise

**Default Implementation**: Returns `False`

---

## Walker::Plan Role API

### `method iterator`

```raku
method iterator(--> QueryIterator) { ... }
```

**Contract**:
- **Input**: None
- **Output**: `QueryIterator` instance
- **Errors**: None (plan already validated)
- **Side Effects**: Creates fresh Context and initializes traversal state

**Preconditions**:
- Plan is valid (created by `Walker.plan()`)

**Postconditions**:
- Returns independent `QueryIterator` instance
- Multiple calls return independent iterators

---

### `method query`

```raku
method query(--> RakuAST::Node) { ... }
```

**Contract**:
- **Input**: None
- **Output**: `RakuAST::Node` (the Query AST used to create plan)
- **Errors**: None
- **Side Effects**: None

**Preconditions**: None

**Postconditions**:
- Returns the Query AST that was used to create the plan
- Query AST is immutable

---

### `method describe`

```raku
method describe(--> Str) { ... }
```

**Contract**:
- **Input**: None
- **Output**: `Str` (human-readable description of execution strategy)
- **Errors**: None
- **Side Effects**: None

**Preconditions**: None

**Postconditions**:
- Returns descriptive string for debugging/profiling

---

### `method optimise`

```raku
method optimise(&modification --> Walker::Plan) { ... }
```

**Contract**:
- **Input**: Callable `&modification` that receives plan and returns modified plan
- **Output**: `Walker::Plan` (new or modified plan)
- **Errors**: None (optional method)
- **Side Effects**: May create new plan (immutability discipline)

**Preconditions**:
- `&modification` is a callable: `-> Walker::Plan $plan { ... } --> Walker::Plan`

**Postconditions**:
- Returns modified plan (new instance unless in-place modification is safe)

**Default Implementation**: May return `self` if not implemented

---

### `method subplans`

```raku
method subplans(--> @Walker::Plan) { ... }
```

**Contract**:
- **Input**: None
- **Output**: Array of `Walker::Plan` objects (empty if not composite)
- **Errors**: None (optional method)
- **Side Effects**: None

**Preconditions**: None

**Postconditions**:
- Returns array of subplans (empty array if not composite plan)

**Default Implementation**: Returns empty array `[]`

---

### `method capabilities`

```raku
method capabilities(--> Associative) { ... }
```

**Contract**:
- **Input**: None
- **Output**: `Associative` (Hash) with structured metadata
- **Errors**: None (optional method)
- **Side Effects**: None

**Preconditions**: None

**Postconditions**:
- Returns hash with capability metadata
- Format: `{ lazy => { enabled => True, type => "incremental" }, ... }`

**Default Implementation**: Returns empty hash `{}`

---

## Context Role API

**Contract**:
- Marker role (no required methods)
- Concrete classes define attributes and methods
- Mutable per-traversal state
- Shared between Walker and Strategy

---

## QueryIterator Role API

### `method next`

```raku
method next(--> Mu) { ... }
```

**Contract**:
- **Input**: None
- **Output**: `Mu` (next result) or `Nil` (exhausted)
- **Errors**: None (returns Nil when exhausted)
- **Side Effects**: Advances traversal state, may modify Context

**Preconditions**:
- Iterator is valid (created by `Walker::Plan.iterator()` or `Walker.iterator()`)

**Postconditions**:
- Returns next matching result or `Nil` if exhausted
- Consistent behavior: always returns `Nil` after exhaustion

**Note**: Extends `Iterator` role contract (`pull-one()` method)

---

## Exception API

### `X::Qwiratry::Walker` (Base)

```raku
class X::Qwiratry::Walker is Exception {
    has Str $.message;
    has Str $.walker-type;
}
```

**Contract**:
- Base exception for Walker-related errors
- Attributes: `$.message`, `$.walker-type`

---

### `X::Qwiratry::UnknownQueryElement`

```raku
class X::Qwiratry::UnknownQueryElement is X::Qwiratry::Walker {
    has RakuAST::Node $.query-ast;
    has Str $.message;
    has Str $.walker-type;
}
```

**Contract**:
- Thrown when Walker cannot interpret Query AST
- Attributes: `$.query-ast` (problematic query), `$.message`, `$.walker-type`
- Extends `X::Qwiratry::Walker`

---

## Type Constraints Summary

- **Query AST**: `RakuAST::Node` (immutable)
- **Root Data**: `Mu` (any type)
- **Plan**: `Walker::Plan` (immutable with respect to Query AST)
- **Context**: `Context` (mutable, per-traversal)
- **Iterator**: `QueryIterator` (extends `Iterator`)
- **Result**: `Mu` (any type) or `Nil`
- **Capabilities**: `Associative` (Hash with structured metadata)


