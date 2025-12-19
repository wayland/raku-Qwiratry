# Research: Composite Walker Handovers

**Feature**: Composite Walker Handovers  
**Date**: 2025-01-27  
**Phase**: 0 - Outline & Research

## Research Questions

### RQ1: Raku Trait Implementation and Runtime Access

**Question**: How do we implement `trait_mod:<provides>` and access trait metadata at runtime?

**Findings**:
- Raku traits are implemented via `trait_mod:<trait-name>` subroutines
- Traits are applied at compile-time to declarations (variables, classes, etc.)
- Trait metadata can be stored in the meta-object via `$declarand.set_why()` or custom meta-object attributes
- Runtime access via `.^traits` method or meta-object introspection (`.^meta`)
- The spec mentions `.^traits` as the mechanism for runtime introspection
- Trait metadata should be discoverable by Slangs and Walkers during planning phase

**Decision**: 
- Implement `trait_mod:<provides>` that attaches metadata to the declarand's meta-object
- Store domain names as a list/array in meta-object attributes
- Access metadata at runtime via `.^traits` or `.^meta.custom-properties` (or similar meta-object API)
- Metadata format: Array[Str] of domain names (e.g., `['sql', 'json']` for `provides<sql json>`)

**Rationale**: Uses Raku's native trait system, leverages meta-object protocol for storage, enables runtime discovery without custom registries.

**Alternatives Considered**: 
- Custom registry keyed by object identity - rejected, adds complexity, doesn't leverage Raku's trait system
- Separate metadata storage - rejected, trait metadata should be attached to the object itself

---

### RQ2: Walker Discovery via Introspection

**Question**: How can Master Walkers discover candidate domain-specific walkers via introspection?

**Findings**:
- Raku supports introspection via `.^methods`, `.^roles`, `.^does`, `.^name`
- Can scan loaded modules/classes for those implementing Walker role
- Discovery can be expensive, so should be cached per Master Walker instance
- Explicit registration provides control and performance optimization
- Discovery should check: `$candidate.^does(Walker)` to verify role composition

**Decision**:
- Default discovery: Scan loaded classes/types checking `$type.^does(Walker)` 
- Cache discovered walkers in Master Walker instance attribute
- Discovery happens once per Master Walker instance (lazy initialization)
- Override: Accept `:@candidate-walkers` constructor parameter (Array[Walker])
- When explicit list provided, skip discovery and use provided walkers

**Rationale**: Convenience by default (auto-discovery), explicit control when needed (testing, performance, specific selection). Caching avoids repeated introspection overhead.

**Alternatives Considered**:
- Always require explicit registration - rejected, less convenient, requires manual walker management
- Discovery on every handover - rejected, too expensive, should cache results

---

### RQ3: Composite Plan Structure with Subplans

**Question**: How should composite plans embed subplans from delegated walkers?

**Findings**:
- `Walker::Plan.subplans()` already exists with default implementation returning empty array
- Subplans are `Array[Walker::Plan]` - can contain plans from multiple walkers
- Composite plan's `query()` should return the original query AST (not modified)
- Subplans represent delegated query subtrees, each with its own query AST
- Plan immutability: subplans should not mutate original query ASTs

**Decision**:
- Master Walker creates composite plan class implementing `Walker::Plan`
- Composite plan stores: original query AST, array of subplans, execution metadata
- `subplans()` returns `Array[Walker::Plan]` containing all embedded subplans
- `query()` returns original query AST (composite query, not modified)
- Each subplan has its own query AST (extracted subtree from original)

**Rationale**: Reuses existing `subplans()` mechanism, maintains plan immutability, enables introspection of composite structure.

**Alternatives Considered**:
- Custom composite plan structure - rejected, would duplicate existing subplans mechanism
- Mutating original query AST - rejected, violates immutability contract

---

### RQ4: Handover Detection Priority Implementation

**Question**: How should Master Walker implement the handover detection priority order?

**Findings**:
- Priority order: domain metadata → capability checks → AST pattern → heuristics
- Each step can either accept responsibility or trigger delegation
- Domain metadata check is fast path (compile-time metadata, O(1) lookup)
- Capability checks require calling `supports()` on each candidate (O(n) where n = candidates)
- AST pattern suitability is optimization (optional, not required for correctness)
- Heuristic probing is last resort (expensive, should be avoided)

**Decision**:
- Implement handover detection as sequential checks following priority order
- Step 1: Check `provides` trait metadata on root object (fast path)
- Step 2: Query candidate walkers via `supports($subtree)` (fallback if no metadata)
- Step 3: AST pattern recognition (optional optimization, can be skipped)
- Step 4: Heuristic probing (last resort, can be skipped for MVP)
- Early exit: If step finds suitable walker, stop and delegate
- If all steps fail, reject query with diagnostic error

**Rationale**: Follows spec priority order, enables fast path optimization, maintains predictable behavior.

**Alternatives Considered**:
- Parallel evaluation of all methods - rejected, doesn't follow priority order, less efficient
- Skip domain metadata - rejected, loses fast path optimization

---

### RQ5: Composite Execution Coordination

**Question**: How should Master Walker coordinate execution of composite plans with multiple subplans?

**Findings**:
- Composite execution involves: execution ordering, data flow, join semantics, result materialization
- Subplans are independent Walker::Plan instances, each can produce QueryIterator
- Master Walker orchestrates subplan execution, not individual walkers
- Data flow between domains may require materialization (e.g., SQL results → JSON processing)
- Join semantics depend on query structure (not specified in detail, can be deferred)

**Decision**:
- Master Walker's plan.iterator() creates composite iterator
- Composite iterator coordinates subplan iterators in execution order
- Execution ordering: determined during planning (dependency analysis or explicit order)
- Data flow: materialize results from one subplan before feeding to next (for MVP)
- Join semantics: deferred to future enhancement (not required for initial implementation)
- Result materialization: collect results from subplans, combine as needed

**Rationale**: Focuses on core handover mechanism first, defers complex coordination to later phases. Materialization is simpler than streaming coordination for MVP.

**Alternatives Considered**:
- Streaming coordination between subplans - rejected, too complex for MVP, can be added later
- Full join semantics implementation - rejected, out of scope for initial feature, can be enhancement

---

## Summary of Decisions

1. **Trait Implementation**: `trait_mod:<provides>` stores metadata in meta-object, accessed via `.^traits` or `.^meta`
2. **Walker Discovery**: Default to introspection (cached), override with explicit registration
3. **Composite Plans**: Extend `Walker::Plan.subplans()` to embed subplans from delegated walkers
4. **Handover Detection**: Sequential priority order (domain metadata → capability → pattern → heuristic)
5. **Composite Execution**: Materialize subplan results, coordinate execution order (join semantics deferred)

All research questions resolved. Ready for Phase 1 design.


