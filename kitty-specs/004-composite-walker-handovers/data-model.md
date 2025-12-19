# Data Model: Composite Walker Handovers

**Feature**: Composite Walker Handovers  
**Date**: 2025-01-27  
**Phase**: 1 - Design & Contracts

## Entities

### provides Trait

**Purpose**: Compile-time trait that attaches advisory domain metadata to root objects, containers, or declarations.

**Attributes**:
- Domain names (Array[Str]) - Stored in meta-object, e.g., `['sql', 'json']` for `provides<sql json>`
- Applied at compile-time via `trait_mod:<provides>`

**Methods**:
- `trait_mod:<provides>` - Compile-time subroutine that attaches metadata to declarand

**Lifecycle**:
- Applied at compile-time during code compilation
- Metadata persists in object's meta-object for runtime discovery
- Does not alter runtime semantics, method dispatch, or type identity

**Relationships**:
- Attached to root objects (variables, containers, declarations)
- Discovered by Master Walkers during planning phase
- Discovered by Slangs during query parsing

**Constraints**:
- Must be discoverable by Slangs and Walkers during planning phase
- Must not affect runtime behavior (advisory only)
- Must support multiple domains per object (e.g., `provides<sql json>`)
- Domain names are strings (e.g., `'sql'`, `'json'`, `'tree'`)

---

### Master Walker Class

**Purpose**: Walker implementation responsible for detecting handovers and delegating to domain-specific walkers.

**Attributes**:
- `@.candidate-walkers` (Array[Walker]) - Optional, explicitly registered walkers (overrides discovery)
- `@.discovered-walkers` (Array[Walker]) - Cached discovered walkers (lazy initialization)
- `$.discovery-cache` (Bool) - Flag indicating if discovery has been performed

**Methods**:
- `plan(RakuAST::Node $query, Mu $root --> Walker::Plan)` - Required (implements Walker role)
- `iterator(Walker::Plan $plan --> QueryIterator)` - Required (implements Walker role)
- `start(RakuAST::Node $query, Mu:D $root --> QueryIterator)` - Required (default from Walker role)
- `discover-walkers(--> Array[Walker])` - Discovers candidate walkers via introspection
- `detect-handover(RakuAST::Node $subtree, Mu $root --> Walker?)` - Detects if handover needed, returns Walker or Nil
- `supports(RakuAST::Node $query --> Bool)` - Optional (implements Walker role, may return True for composite queries)

**Lifecycle**:
- Created once per Master Walker instance
- Discovery performed lazily on first use (cached)
- Reusable across multiple queries
- Can be constructed with explicit candidate walkers (overrides discovery)

**Relationships**:
- Implements `Walker` role
- Discovers or receives `Array[Walker]` (candidate domain-specific walkers)
- Produces `CompositePlan` (Walker::Plan with embedded subplans)
- Delegates to domain-specific `Walker` instances

**Constraints**:
- Must implement all required Walker role methods
- Must follow handover detection priority order
- Must fail planning early with diagnostic error if no suitable walker found
- Must ensure all handovers occur during planning phase (not execution time)

---

### Composite Plan Class

**Purpose**: Walker::Plan implementation that contains embedded subplans from multiple domain-specific walkers.

**Attributes**:
- `$.query-ast` (RakuAST::Node) - Original composite query AST
- `@.subplans` (Array[Walker::Plan]) - Embedded subplans from delegated walkers
- `$.execution-order` (Array[Int]) - Optional, execution ordering for subplans
- Execution metadata (internal, implementation-specific)

**Methods**:
- `iterator(--> QueryIterator)` - Required (implements Walker::Plan role)
- `query(--> RakuAST::Node)` - Required (returns original query AST)
- `describe(--> Str)` - Required (describes composite plan structure)
- `subplans(--> Array[Walker::Plan])` - Required (returns embedded subplans)
- `optimise(&modification --> Walker::Plan)` - Optional (implements Walker::Plan role)
- `capabilities(--> Associative)` - Optional (implements Walker::Plan role)

**Lifecycle**:
- Created by `MasterWalker.plan()`
- Contains immutable query AST and subplans
- Reusable (can produce multiple iterators)
- Immutable with respect to Query AST (must not mutate original)

**Relationships**:
- Created by `MasterWalker`
- Contains `RakuAST::Node` (original composite query)
- Contains `Array[Walker::Plan]` (subplans from delegated walkers)
- Produces `QueryIterator` instances (composite iterators)

**Constraints**:
- Must not mutate original Query AST
- Must support producing multiple independent QueryIterator instances
- Subplans must be valid Walker::Plan instances
- `query()` must return original query AST (not modified subtrees)

---

### Handover Detection Process

**Purpose**: Process by which Master Walker determines if responsibility for a query subtree should be delegated.

**Attributes**:
- Detection method (domain metadata, capability check, AST pattern, heuristic)
- Candidate walkers (Array[Walker])
- Query subtree (RakuAST::Node)
- Root object (Mu)

**Methods**:
- `check-domain-metadata(Mu $root --> Array[Str]?)` - Checks `provides` trait, returns domain names or Nil
- `check-capability(RakuAST::Node $subtree, Walker $walker --> Bool)` - Calls `$walker.supports($subtree)`
- `check-ast-pattern(RakuAST::Node $subtree --> Walker?)` - Optional, AST pattern recognition
- `check-heuristic(RakuAST::Node $subtree --> Walker?)` - Optional, last resort heuristic

**Lifecycle**:
- Executed during `MasterWalker.plan()` phase
- Sequential evaluation following priority order
- Early exit when suitable walker found
- Fails with diagnostic error if all methods fail

**Relationships**:
- Part of `MasterWalker.plan()` process
- Uses `provides` trait metadata (if available)
- Queries candidate `Walker` instances via `supports()`
- Produces `Walker` instance for delegation or Nil

**Constraints**:
- Must follow priority order: domain metadata → capability → pattern → heuristic
- Must fail early if domain metadata declares domains but no suitable walker exists
- Must respect walker autonomy (walkers can decline responsibility)
- Domain metadata must not override capability checks

---

### Domain-Specific Walker

**Purpose**: Walker implementation specialized for a particular domain (e.g., SQL, JSON, in-memory objects).

**Attributes**:
- None (inherits from Walker role)

**Methods**:
- All Walker role methods (required and optional)
- `supports(RakuAST::Node $query --> Bool)` - Required for handover detection, indicates capability

**Lifecycle**:
- Created once per walker instance
- Reusable across multiple queries
- Independent of other domain-specific walkers

**Relationships**:
- Implements `Walker` role
- Discovered or registered with `MasterWalker`
- Delegated to by `MasterWalker` for domain-specific subtrees
- Produces `Walker::Plan` instances (may be embedded as subplans)

**Constraints**:
- Must implement `supports()` method for capability checks
- Must remain independent (no knowledge of other domains)
- Can decline responsibility even when domain metadata suggests it should handle query
- Must throw `X::Qwiratry::UnknownQueryElement` if cannot interpret Query AST

---

## Relationships Summary

```
provides Trait
  ├── attached to → Root objects (variables, containers)
  └── discovered by → Master Walker, Slangs

Master Walker
  ├── implements → Walker role
  ├── discovers/registers → Array[Walker] (candidate walkers)
  ├── detects → Handover requirements
  ├── delegates to → Domain-specific Walkers
  └── produces → Composite Plan

Composite Plan
  ├── implements → Walker::Plan role
  ├── contains → RakuAST::Node (original query)
  ├── contains → Array[Walker::Plan] (subplans)
  └── produces → QueryIterator (composite iterator)

Handover Detection
  ├── part of → MasterWalker.plan() process
  ├── uses → provides trait metadata
  ├── queries → Walker.supports()
  └── produces → Walker (for delegation) or Nil

Domain-Specific Walker
  ├── implements → Walker role
  ├── provides → supports() method
  └── produces → Walker::Plan (may be embedded as subplan)
```

---

## State Transitions

### Handover Detection Flow

1. **Domain Metadata Check (Fast Path)**:
   - Master Walker checks `provides` trait on root object
   - If domains declared, find walker supporting at least one domain
   - If found → delegate to that walker
   - If not found → fail with diagnostic error
   - If no metadata → proceed to capability checks

2. **Capability Checks**:
   - Master Walker queries candidate walkers via `supports($subtree)`
   - First walker returning True → delegate to that walker
   - If all return False → proceed to AST pattern (or fail)

3. **AST Pattern Suitability (Optional)**:
   - Master Walker recognizes AST patterns
   - If pattern matches known efficient backend → delegate
   - If not → proceed to heuristic (or fail)

4. **Heuristic Probing (Last Resort, Optional)**:
   - Master Walker uses heuristics to select walker
   - If successful → delegate
   - If not → fail with diagnostic error

### Composite Planning Flow

1. **Planning Phase**:
   - `MasterWalker.plan($query, $root)` → `CompositePlan`
   - Master Walker detects handovers via detection process
   - For each handover: delegate to domain-specific walker, receive `Walker::Plan`
   - Embed subplans in `CompositePlan`
   - Return `CompositePlan` with embedded subplans

2. **Iterator Creation**:
   - `CompositePlan.iterator()` → `QueryIterator` (composite iterator)
   - Creates iterators for each subplan
   - Coordinates execution ordering

3. **Composite Execution**:
   - Composite iterator coordinates subplan iterators
   - Materializes results from subplans as needed
   - Combines results according to query structure

---

## Validation Rules

1. **provides Trait**: Must be discoverable via `.^traits` or `.^meta` introspection
2. **Master Walker**: Must implement all required Walker role methods
3. **Composite Plan**: Must not mutate original Query AST, must contain valid subplans
4. **Handover Detection**: Must follow priority order, must fail early with diagnostic error
5. **Domain-Specific Walker**: Must implement `supports()` method, must remain independent

---

## Notes

- `provides` trait is advisory only, does not force walker acceptance
- Master Walker discovery is cached per instance (lazy initialization)
- All handover decisions made during planning phase (not execution time)
- Composite plans enable introspection of multi-domain query structure
- Domain-specific walkers remain independent (no coupling between domains)


