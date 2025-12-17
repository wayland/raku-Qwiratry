# Research: Walker Core Infrastructure

**Feature**: Walker Core Infrastructure  
**Date**: 2025-12-17  
**Phase**: 0 - Outline & Research

## Research Questions

### RQ1: RakuAST::Node Structure and Introspection

**Question**: What is the structure of RakuAST::Node and how can we introspect Query AST nodes?

**Findings**:
- RakuAST::Node is the base class for all RakuAST nodes in Raku 6.e
- Nodes are immutable and composable
- Introspection available via `.^methods`, `.^attributes`, and node-specific methods
- Query AST nodes will be descendants of RakuAST::Node

**Decision**: Use RakuAST::Node as the type constraint for Query AST parameters. Concrete walkers will need to pattern-match or introspect specific node types.

**Rationale**: RakuAST::Node is the standard type for AST nodes in Raku 6.e, ensuring compatibility with the language's AST infrastructure.

**Alternatives Considered**: 
- Custom Query AST base class - rejected, would require separate AST system
- Generic Mu type - rejected, loses type safety

---

### RQ2: Raku Role Default Method Implementations

**Question**: How should we provide default implementations in Raku roles?

**Findings**:
- Raku roles can have default method implementations (not just stubs)
- Default implementations can call other role methods
- Optional methods can have empty bodies `{ }` or provide sensible defaults
- Roles can be composed and methods can be overridden by classes

**Decision**: Provide default implementations for:
- `start` method: `self.plan($query, $root).iterator`
- `PRE-PASS` and `POST-PASS`: Empty bodies `{ }` (no-op by default)
- `capabilities()`: Return empty hash `{}` (concrete walkers override)
- `supports()`: Return `False` (concrete walkers override)

**Rationale**: Default implementations reduce boilerplate for concrete walkers while allowing full customization when needed.

**Alternatives Considered**:
- Stub methods only (`{ ... }`) - rejected, increases boilerplate
- Abstract base classes - rejected, Raku roles are preferred for composability

---

### RQ3: Raku Exception Hierarchy Patterns

**Question**: What is the standard pattern for exception hierarchies in Raku?

**Findings**:
- Raku exceptions use `X::` namespace prefix
- Base exceptions typically named `X::Module::BaseName`
- Specific exceptions extend base: `X::Module::SpecificError`
- Exception classes can have attributes for context (query AST, walker type, message)
- Exceptions inherit from `Exception` role

**Decision**: Create exception hierarchy:
- Base: `X::Qwiratry::Walker` (extends Exception)
- Specific: `X::Qwiratry::UnknownQueryElement` (extends X::Qwiratry::Walker)
- Attributes: `$.query-ast` (RakuAST::Node), `$.walker-type` (Str), `$.message` (Str)

**Rationale**: Follows Raku conventions, provides extensibility for future walker-specific exceptions, includes diagnostic context.

**Alternatives Considered**:
- Single exception class - rejected, limits extensibility
- No base exception - rejected, makes future exception additions harder

---

### RQ4: Raku Iterator Role Contract and Lazy Evaluation

**Question**: What is the Iterator role contract and how does lazy evaluation work?

**Findings**:
- Raku Iterator role requires `pull-one()` method (or `next()` as alias)
- Iterator.pull-one() returns `IterationEnd` when exhausted, or the next value
- Lazy evaluation achieved by returning values on-demand
- QueryIterator extends Iterator, so must implement `pull-one()` or `next()`

**Decision**: 
- QueryIterator implements `next()` method returning `Mu` or `Nil` (Nil for exhaustion)
- QueryIterator maintains internal state (Context, traversal position)
- Lazy evaluation handled by concrete walker implementations

**Rationale**: Follows Raku Iterator contract, enables lazy query execution, maintains compatibility with Raku iteration protocols.

**Alternatives Considered**:
- Eager evaluation - rejected, conflicts with spec requirement for lazy evaluation
- Custom iteration protocol - rejected, breaks compatibility with Raku ecosystem

---

### RQ5: Module Organization Patterns for Raku Libraries

**Question**: How should we organize modules for a Raku library with multiple roles?

**Findings**:
- Raku modules typically use `lib/Module/Name.rakumod` structure
- Related roles can be grouped in single module or separated
- Separation improves discoverability and reduces compilation overhead
- Logical grouping balances cohesion with modularity

**Decision**: Logical grouping:
- `lib/Qwiratry/Walker.rakumod` - Walker + Walker::Plan (closely related)
- `lib/Qwiratry/Context.rakumod` - Context (independent)
- `lib/Qwiratry/QueryIterator.rakumod` - QueryIterator (independent)
- `lib/Qwiratry/X.rakumod` - Exception hierarchy (grouped)

**Rationale**: Groups related roles (Walker/Plan) while keeping independent roles separate. Exception hierarchy grouped for discoverability.

**Alternatives Considered**:
- Single module - rejected, too large and reduces modularity
- One module per role - rejected, too granular, Walker and Plan are tightly coupled

---

## Summary of Decisions

1. **Query AST Type**: RakuAST::Node (standard Raku AST type)
2. **Role Implementation**: Default implementations for common patterns, empty hooks
3. **Exception Hierarchy**: X::Qwiratry::Walker base with X::Qwiratry::UnknownQueryElement subclass
4. **Iterator Contract**: Implement next() returning Mu or Nil, maintain lazy evaluation
5. **Module Structure**: Logical grouping (Walker+Plan together, others separate)

All research questions resolved. Ready for Phase 1 design.

