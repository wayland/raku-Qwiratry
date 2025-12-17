# Feature Specification: Walker Core Infrastructure

**Feature Branch**: `002-walker-core-infrastructure`  
**Created**: 2025-12-17  
**Status**: Draft  
**Input**: User description: "Implement the core Walker infrastructure including the `Walker` role, `Walker::Plan` role, `Context` role, and `QueryIterator` role as specified in Specification.md sections 2.1.2, 3.2, 3.2.1-3.2.4, and 4. This includes all required methods (plan, iterator, start), optional hooks (PRE-PASS, POST-PASS), capability introspection methods, and the query execution flow that connects queries to incremental result streams. Query AST types use RakuAST::Node."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Create Execution Plan from Query (Priority: P1)

As a developer implementing a domain-specific walker (e.g., Tree::Walker::DFS), I need to create an execution plan from a Query AST, so I can optimize traversal strategy before executing the query.

**Why this priority**: Planning is the foundation of the Walker architecture. Without planning, walkers cannot optimize queries or support multi-phase execution. This enables all other walker functionality.

**Independent Test**: Can be fully tested by creating a Walker role, implementing the `plan` method to return a Walker::Plan, and verifying the plan contains the query AST. Delivers immediate value by enabling query optimization.

**Acceptance Scenarios**:

1. **Given** a Walker role implementation and a Query AST, **When** I call `walker.plan($query, $root)`, **Then** I receive a Walker::Plan object containing the query
2. **Given** a Walker cannot interpret a Query AST, **When** I call `plan`, **Then** it throws `X::Qwiratry::UnknownQueryElement` exception
3. **Given** a Walker creates a plan, **When** I examine the plan, **Then** I can introspect the query via `plan.query()` method

---

### User Story 2 - Produce Incremental Result Streams (Priority: P1)

As a developer using a Walker, I need to produce multiple independent result streams from the same plan, so I can iterate over query results lazily without re-planning.

**Why this priority**: This is core to the Walker architecture - enabling lazy evaluation and multiple consumers of the same query. Without this, walkers cannot efficiently produce results.

**Independent Test**: Can be fully tested by creating a plan, calling `plan.iterator` multiple times, and verifying each iterator produces independent results. Delivers value by enabling lazy query execution.

**Acceptance Scenarios**:

1. **Given** a Walker::Plan exists, **When** I call `plan.iterator`, **Then** I receive a QueryIterator that implements Iterator
2. **Given** multiple iterators from the same plan, **When** I iterate over them independently, **Then** each produces results without interfering with others
3. **Given** a QueryIterator, **When** I call `next()`, **Then** it returns the next matching result or Nil if exhausted

---

### User Story 3 - Per-Traversal State Management (Priority: P2)

As a Walker implementation, I need a Context object to store mutable state during traversal, so I can coordinate with Strategy hooks and maintain traversal state across multiple passes.

**Why this priority**: Context enables complex traversal behaviors like backtracking, multi-phase execution, and coordination between Walker and Strategy. Lower priority than core planning/iteration but essential for advanced features.

**Independent Test**: Can be fully tested by creating a Context, storing state in it during traversal, and verifying the state persists across hook calls. Delivers value by enabling stateful traversal logic.

**Acceptance Scenarios**:

1. **Given** a traversal begins, **When** a Walker creates a Context, **Then** the Context is shared between Walker and Strategy hooks
2. **Given** a Context exists, **When** Strategy hooks store data in it, **Then** the data persists across all hook calls in the same traversal
3. **Given** multiple traversals, **When** each creates its own Context, **Then** Contexts do not share state between traversals

---

### User Story 4 - Convenience Execution Entrypoint (Priority: P2)

As a developer using a Walker, I need a simple `start` method that combines planning and iteration, so I can execute queries with a single method call for common use cases.

**Why this priority**: Improves developer ergonomics for simple use cases. Lower priority than core functionality but makes the API more usable.

**Independent Test**: Can be fully tested by calling `walker.start($query, $root)` and verifying it returns a QueryIterator equivalent to `walker.plan($query, $root).iterator`. Delivers value by simplifying common usage patterns.

**Acceptance Scenarios**:

1. **Given** a Walker and Query AST, **When** I call `walker.start($query, $root)`, **Then** I receive a QueryIterator ready to produce results
2. **Given** `start` is called, **When** I examine the behavior, **Then** it is equivalent to calling `plan` then `iterator` on the resulting plan

---

### User Story 5 - Walker-Level Hooks (Priority: P3)

As a Walker implementation, I need PRE-PASS and POST-PASS hooks to initialize and finalize traversal state, so I can support multi-phase execution and resource management.

**Why this priority**: Enables advanced features like multi-phase execution and resource cleanup. Lower priority as it's optional functionality.

**Independent Test**: Can be fully tested by implementing PRE-PASS and POST-PASS methods in a Walker and verifying they are called at appropriate times. Delivers value by enabling multi-phase walkers.

**Acceptance Scenarios**:

1. **Given** a Walker implements PRE-PASS, **When** a traversal begins, **Then** PRE-PASS is called with the Context before traversal starts
2. **Given** a Walker implements POST-PASS, **When** a traversal completes, **Then** POST-PASS is called with the Context after traversal ends
3. **Given** hooks are not implemented, **When** traversal occurs, **Then** traversal proceeds normally without errors

---

### Edge Cases

- What happens when `plan` is called with an invalid Query AST? (Should throw `X::Qwiratry::UnknownQueryElement`)
- How does a Walker handle a Query AST it cannot interpret? (Must throw exception, cannot return invalid plan)
- What if `iterator` is called on a plan multiple times? (Each call returns independent QueryIterator)
- How does Context handle concurrent access? (Context is per-traversal, not thread-safe by default)
- What if QueryIterator.next() is called after exhaustion? (Returns Nil consistently)
- How does Walker handle empty Query ASTs? (Should produce empty iterator or throw, depending on Walker implementation)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a `Walker` role that implements `plan`, `iterator`, and `start` methods as specified in Specification.md section 3.2.1
- **FR-015**: Walker.iterator($query) MUST be a convenience method that internally calls plan($query, $root) then plan.iterator(), where $root is provided via Walker instance state
- **FR-002**: System MUST provide a `Walker::Plan` role with `iterator`, `query`, `describe`, `optimise`, `subplans`, and `capabilities` methods as specified in Specification.md section 3.2.2
- **FR-014**: Walker::Plan.optimise callback MUST receive the plan itself and return a modified plan
- **FR-003**: System MUST provide a `Context` role for per-traversal mutable state as specified in Specification.md section 3.2.3
- **FR-004**: System MUST provide a `QueryIterator` role that extends Iterator with `next()` method as specified in Specification.md section 3.2.4
- **FR-005**: Walker role MUST throw `X::Qwiratry::UnknownQueryElement` exception when it cannot interpret a Query AST
- **FR-006**: Walker::Plan MUST support producing multiple independent QueryIterator instances from the same plan
- **FR-007**: Walker::Plan MUST NOT mutate the original Query AST in observable ways
- **FR-008**: Context MUST be created fresh for each traversal and not shared across separate traversals
- **FR-009**: QueryIterator MUST maintain traversal state and support lazy evaluation
- **FR-013**: QueryIterator MUST receive Context via constructor and store it as an attribute
- **FR-010**: Walker role MUST support optional PRE-PASS and POST-PASS hook methods
- **FR-011**: Walker role SHOULD support optional `capabilities()` and `supports()` methods for introspection
- **FR-016**: Walker.capabilities() and Walker::Plan.capabilities() MUST return Associative with structured metadata (e.g., `{ lazy => { enabled => True, type => "incremental" }, ... }`)
- **FR-012**: Query AST type MUST use RakuAST types (not CompUnit::Perl5AST::Node)

### Key Entities *(include if feature involves data)*

- **Walker**: Raku role that encapsulates how a query is executed. Has methods: `plan`, `iterator`, `start`, optional hooks `PRE-PASS`, `POST-PASS`, optional introspection `capabilities`, `supports`. Produces Walker::Plan objects and QueryIterator instances. Walker instance may store root data structure for use by `iterator` method.

- **Walker::Plan**: Raku role representing a precomputed execution strategy. Has methods: `iterator`, `query`, `describe`, `optimise`, `subplans`, `capabilities`. Contains Query AST and execution metadata. Can produce multiple QueryIterator instances.

- **Context**: Raku role providing mutable per-traversal state. Shared between Walker and Strategy. Stores counters, memoisation, queues, intermediate results. Created fresh for each traversal pass.

- **QueryIterator**: Raku role extending Iterator. Has method `next()` returning Mu or Nil. Receives Context via constructor and stores it as an attribute. Maintains traversal state, supports lazy evaluation and backtracking. Coordinates with Walker, Query, and Strategy via shared Context.

- **Query AST**: RakuAST node representing a query expression. Immutable, composable, introspectable. Passed to Walker.plan() and stored in Walker::Plan.query().

## Constitution Alignment *(non-negotiable)*

- **Testing**: Automated tests must verify: (1) Walker role methods work correctly, (2) Walker::Plan produces independent iterators, (3) Context maintains state correctly, (4) QueryIterator.next() works correctly, (5) Exception handling for unknown queries, (6) Hook methods are called at appropriate times. Unit tests for each role, integration tests for query execution flow.

- **Data contracts**: Roles define method signatures with type constraints. Query AST uses RakuAST types. Context is mutable but scoped to traversal. Walker::Plan is immutable with respect to Query AST. No schema migrations needed as these are role definitions.

- **CLI & observability**: No CLI surface for this feature (library roles). Logging should be available for debugging walker execution (via Context or Walker hooks). No metrics required at this level.

- **Security/privacy**: No sensitive data involved. Roles are type-safe interfaces. No secrets or credentials required. Exception handling prevents information leakage.

- **Simplicity & increments**: Smallest testable slices: (1) Basic Walker role with plan method, (2) Walker::Plan role with iterator method, (3) Context role, (4) QueryIterator role, (5) start convenience method, (6) Optional hooks. Each slice independently testable. Rollback: roles can be versioned or deprecated if needed.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developers can create a Walker role implementation that successfully plans queries and produces QueryIterator instances
- **SC-002**: Multiple QueryIterator instances from the same plan produce independent result streams without interference
- **SC-003**: Context correctly maintains state across all hook calls within a single traversal
- **SC-004**: Walker throws `X::Qwiratry::UnknownQueryElement` when given an uninterpretable Query AST
- **SC-005**: Walker::Plan.query() returns the Query AST that was used to create the plan
- **SC-006**: QueryIterator.next() correctly returns results or Nil when exhausted

## Clarifications

### Session 2025-12-17

- Q: Should the Walker roles be implemented as Raku roles or abstract base classes? → A: Raku roles (as shown in spec)
- Q: What type should be used for Query AST? → A: Use RakuAST types (not CompUnit::Perl5AST::Node)
- Q: Should UnknownQueryElementException be a custom exception class? → A: Custom exception class `X::Qwiratry::UnknownQueryElement`
- Q: How does QueryIterator receive and store the Context object? → A: Context passed to QueryIterator constructor and stored as an attribute
- Q: What signature should Walker::Plan.optimise callback have? → A: Callback receives the plan itself and returns modified plan
- Q: Should Walker.iterator take Query AST or Walker::Plan? → A: Keep Walker.iterator($query) as convenience that internally calls plan then plan.iterator()
- Q: Should Walker.iterator require $root parameter? → A: No, keep only Query AST, require root via Walker instance state
- Q: What structure should capabilities() return? → A: Structured metadata with nested hashes (e.g., `{ lazy => { enabled => True, type => "incremental" }, ... }`)

