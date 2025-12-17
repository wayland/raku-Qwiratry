# Data Model: Walker Core Infrastructure

**Feature**: Walker Core Infrastructure  
**Date**: 2025-12-17  
**Phase**: 1 - Design & Contracts

## Entities

### Walker Role

**Purpose**: Encapsulates how a query is executed over a data structure.

**Attributes**:
- None (role, not a class)

**Methods**:
- `plan(RakuAST::Node $query, Mu $root --> Walker::Plan)` - Required
- `iterator(RakuAST::Node $q --> QueryIterator)` - Required (convenience method)
- `start(RakuAST::Node $query, Mu:D $root --> QueryIterator)` - Required (default implementation provided)
- `PRE-PASS(Context $ctx)` - Optional hook (default: empty)
- `POST-PASS(Context $ctx)` - Optional hook (default: empty)
- `capabilities(--> Associative)` - Optional introspection (default: empty hash)
- `supports(RakuAST::Node $query --> Bool)` - Optional introspection (default: False)

**Lifecycle**:
- Created once per walker instance
- Reusable across multiple queries
- Immutable (role, not stateful)

**Relationships**:
- Produces `Walker::Plan` objects
- Produces `QueryIterator` instances
- May store root data structure in instance state (for `iterator` convenience method)

**Constraints**:
- Must throw `X::Qwiratry::UnknownQueryElement` if cannot interpret Query AST
- Must not mutate Query AST in observable ways

---

### Walker::Plan Role

**Purpose**: Represents a precomputed execution strategy for a specific query and root.

**Attributes**:
- Query AST (via `query()` method)
- Execution metadata (internal, implementation-specific)

**Methods**:
- `iterator(--> QueryIterator)` - Required
- `query(--> RakuAST::Node)` - Required
- `describe(--> Str)` - Required
- `optimise(&modification --> Walker::Plan)` - Optional
- `subplans(--> @Walker::Plan)` - Optional
- `capabilities(--> Associative)` - Optional

**Lifecycle**:
- Created by `Walker.plan()`
- Reusable (can produce multiple iterators)
- Immutable with respect to Query AST (must not mutate original Query AST)

**Relationships**:
- Created by `Walker`
- Contains `RakuAST::Node` (Query AST)
- Produces `QueryIterator` instances
- May contain subplans (for composite walkers)

**Constraints**:
- Must not mutate original Query AST in observable ways
- Must support producing multiple independent QueryIterator instances
- `optimise` callback receives plan itself and returns modified plan

---

### Context Role

**Purpose**: Provides mutable per-traversal state shared between Walker and Strategy.

**Attributes**:
- Mutable state (counters, memoisation, queues, intermediate results)
- Implementation-specific (role is marker, concrete classes define attributes)

**Methods**:
- None required (marker role)

**Lifecycle**:
- Created fresh for each traversal pass
- Shared between Walker and Strategy hooks
- Not shared across separate traversals or iterators
- May be reused for multi-phase walkers (if design requires)

**Relationships**:
- Created by `Walker` or `Walker::Plan.iterator()`
- Shared with `Strategy` hooks
- Passed to `QueryIterator` constructor
- Used by `PRE-PASS` and `POST-PASS` hooks

**Constraints**:
- Must be created fresh for each traversal
- Must not be shared across separate traversals (unless explicitly designed)
- Mutable (unlike Query AST and Walker)

---

### QueryIterator Role

**Purpose**: Exposes pull-based stream of results from a traversal.

**Attributes**:
- `$.context` (Context) - Required, passed via constructor
- Traversal state (stacks, queues, cursor positions) - Implementation-specific

**Methods**:
- `next(--> Mu)` - Required (extends Iterator contract)
- Inherits from `Iterator` role

**Lifecycle**:
- Created by `Walker::Plan.iterator()` or `Walker.iterator()`
- One per traversal/result stream
- Independent instances from same plan do not share mutable state
- Exhausted when `next()` returns `Nil`

**Relationships**:
- Created by `Walker::Plan` or `Walker`
- Contains `Context` (via constructor)
- Coordinates with `Walker`, `Query`, and `Strategy` via shared `Context`

**Constraints**:
- Must receive Context via constructor and store as attribute
- Must maintain traversal state
- Must support lazy evaluation
- Must return `Nil` when exhausted (consistent behavior)

---

### X::Qwiratry::Walker Exception (Base)

**Purpose**: Base exception for Walker-related errors.

**Attributes**:
- `$.message` (Str) - Error message
- `$.walker-type` (Str) - Type of walker that threw exception

**Lifecycle**:
- Created when Walker encounters error
- Thrown immediately

**Relationships**:
- Base class for `X::Qwiratry::UnknownQueryElement`

---

### X::Qwiratry::UnknownQueryElement Exception

**Purpose**: Thrown when Walker cannot interpret a Query AST.

**Attributes**:
- Inherits from `X::Qwiratry::Walker`
- `$.query-ast` (RakuAST::Node) - The Query AST that could not be interpreted
- `$.message` (Str) - Diagnostic message
- `$.walker-type` (Str) - Type of walker that threw exception

**Lifecycle**:
- Created when `Walker.plan()` or `Walker.iterator()` cannot interpret Query AST
- Thrown immediately

**Relationships**:
- Extends `X::Qwiratry::Walker`
- Contains `RakuAST::Node` (the problematic query)

---

## Relationships Summary

```
Walker
  ├── produces → Walker::Plan
  ├── produces → QueryIterator (via convenience method)
  └── creates → Context (for traversal)

Walker::Plan
  ├── contains → RakuAST::Node (Query AST)
  ├── produces → QueryIterator (multiple instances)
  └── may contain → @Walker::Plan (subplans)

QueryIterator
  ├── contains → Context (via constructor)
  └── coordinates → Walker, Query, Strategy (via Context)

Context
  ├── created by → Walker or Walker::Plan.iterator()
  └── shared with → Strategy hooks, PRE-PASS, POST-PASS

X::Qwiratry::UnknownQueryElement
  ├── extends → X::Qwiratry::Walker
  └── contains → RakuAST::Node (problematic query)
```

---

## State Transitions

### Query Execution Flow

1. **Planning Phase**:
   - `Walker.plan($query, $root)` → `Walker::Plan`
   - If Query AST uninterpretable → `X::Qwiratry::UnknownQueryElement`

2. **Iterator Creation**:
   - `Walker::Plan.iterator()` → `QueryIterator`
   - Creates fresh `Context`
   - Initializes traversal state

3. **Result Production**:
   - `QueryIterator.next()` → `Mu` (result) or `Nil` (exhausted)
   - Uses shared `Context` for state
   - Lazy evaluation (on-demand)

4. **Traversal Hooks**:
   - `PRE-PASS($ctx)` called before traversal
   - Traversal executes (Strategy hooks called)
   - `POST-PASS($ctx)` called after traversal

---

## Validation Rules

1. **Query AST**: Must be `RakuAST::Node` (type constraint)
2. **Walker::Plan**: Must not mutate original Query AST
3. **Context**: Must be created fresh per traversal
4. **QueryIterator**: Must receive Context via constructor
5. **Exception**: Must be thrown when Query AST uninterpretable (cannot return invalid plan)

---

## Notes

- All roles are composable (Raku roles)
- Query AST is immutable
- Context is mutable but scoped to traversal
- Walker and Walker::Plan are reusable
- QueryIterator instances are independent

