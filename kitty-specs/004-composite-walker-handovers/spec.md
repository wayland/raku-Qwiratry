# Feature Specification: Composite Walker Handovers
*Path: [templates/spec-template.md](templates/spec-template.md)*

**Feature Branch**: `004-composite-walker-handovers`  
**Created**: 2025-01-27  
**Status**: Draft  
**Input**: User description: "-- we want to do the ticket at docs/tickets/composite-handover-shell.md"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Declare Domain Metadata with provides Trait (Priority: P1)

As a developer working with multi-domain data (e.g., SQL tables, JSON documents, in-memory objects), I need to declare domain metadata on root objects using the `provides<domain-name>` compile-time trait, so that Master Walkers can automatically detect which domain-specific walkers should handle different parts of a query.

**Why this priority**: Domain metadata is the fast path for handover detection. Without it, the system must rely on slower capability checks and heuristics. This enables efficient multi-domain query planning.

**Independent Test**: Can be fully tested by applying the `provides<sql>` trait to a variable declaration, verifying the trait is attached at compile time, and confirming the metadata is discoverable during planning. Delivers immediate value by enabling automatic walker selection.

**Acceptance Scenarios**:

1. **Given** a root object with `my $table provides<sql> = ...`, **When** a Master Walker examines the root during planning, **Then** it can discover the `sql` domain metadata
2. **Given** a root object with `my $hybrid provides<sql json> = ...`, **When** planning occurs, **Then** the Master Walker recognizes both domains and expects hybrid execution
3. **Given** the `provides` trait is applied, **When** the code is compiled, **Then** the trait metadata is attached without altering runtime semantics or method dispatch

---

### User Story 2 - Master Walker Detects Handovers via Capability Checks (Priority: P1)

As a Master Walker implementation, I need to query candidate walkers about their capabilities using the `supports()` method, so I can determine which walker should handle each part of a multi-domain query.

**Why this priority**: Capability checks are the primary mechanism for handover detection when domain metadata is absent. This enables the system to work with existing code that doesn't use the `provides` trait.

**Independent Test**: Can be fully tested by implementing a Master Walker that queries multiple domain-specific walkers via `supports()`, detects when the current walker cannot handle a subtree, and delegates to an appropriate walker. Delivers value by enabling automatic walker selection based on query structure.

**Acceptance Scenarios**:

1. **Given** a Master Walker encounters a query subtree it cannot handle, **When** it queries candidate walkers via `supports($subtree)`, **Then** it receives boolean responses indicating capability
2. **Given** no walker supports a required subtree, **When** planning occurs, **Then** the Master Walker rejects the query with a diagnostic error
3. **Given** multiple walkers support a subtree, **When** handover occurs, **Then** the Master Walker selects an appropriate walker (e.g., based on priority or specificity)

---

### User Story 3 - Plan-Level Handover with Embedded Subplans (Priority: P1)

As a Master Walker, I need to delegate planning of query subtrees to domain-specific walkers and embed their resulting plans as subplans in my own plan, so I can coordinate execution of multi-domain queries without runtime handover decisions.

**Why this priority**: Plan-level handover is the core mechanism for composite execution. All handover decisions must be made during planning, not execution, to ensure predictable and efficient query execution.

**Independent Test**: Can be fully tested by creating a Master Walker that detects a handover, delegates planning to a domain-specific walker, receives a Walker::Plan, and embeds it as a subplan. Delivers value by enabling composite query execution with predictable performance.

**Acceptance Scenarios**:

1. **Given** a Master Walker detects a handover is needed, **When** it delegates planning to a domain-specific walker, **Then** it receives a Walker::Plan for that subtree
2. **Given** a Master Walker creates a composite plan, **When** I examine the plan via `subplans()`, **Then** I can see all embedded subplans from different walkers
3. **Given** a composite plan with subplans, **When** execution occurs, **Then** the Master Walker orchestrates subplan execution without re-evaluating domain suitability

---

### User Story 4 - Composite Execution Coordination (Priority: P2)

As a Master Walker executing a multi-domain query, I need to coordinate execution ordering, data flow between subplans, join semantics, and result materialization, so that queries spanning multiple domains execute correctly and efficiently.

**Why this priority**: Composite execution coordination enables the system to handle real-world multi-domain queries. Lower priority than handover detection because it builds on the foundation of plan-level handovers.

**Independent Test**: Can be fully tested by executing a composite plan with multiple subplans, verifying results are correctly combined, and confirming data flows between domains as expected. Delivers value by enabling end-to-end multi-domain query execution.

**Acceptance Scenarios**:

1. **Given** a composite plan with subplans from SQL and JSON walkers, **When** execution occurs, **Then** the Master Walker coordinates execution ordering and data flow
2. **Given** a query requires joining results from multiple domains, **When** execution occurs, **Then** the Master Walker handles join semantics correctly
3. **Given** subplans produce streaming results, **When** execution occurs, **Then** the Master Walker coordinates result materialization or streaming as appropriate

---

### User Story 5 - Handover Detection Priority Order (Priority: P2)

As a Master Walker, I need to follow a predictable priority order when detecting handovers (domain metadata → capability checks → AST pattern suitability → heuristic probing), so that handover decisions are consistent and efficient.

**Why this priority**: Priority order ensures predictable behavior and enables optimizations. Lower priority than core handover mechanisms but important for system reliability.

**Independent Test**: Can be fully tested by creating scenarios where multiple detection methods could apply, verifying the Master Walker follows the priority order, and confirming faster methods (domain metadata) are tried before slower ones (heuristics). Delivers value by ensuring consistent and efficient handover detection.

**Acceptance Scenarios**:

1. **Given** a root object has domain metadata via `provides`, **When** handover detection occurs, **Then** the Master Walker uses domain metadata first (fast path) before falling back to capability checks
2. **Given** no domain metadata exists, **When** handover detection occurs, **Then** the Master Walker falls back to capability checks via `supports()`
3. **Given** capability checks are inconclusive, **When** handover detection occurs, **Then** the Master Walker may use AST pattern suitability or heuristic probing as last resort

---

### Edge Cases

- What happens when a root object declares domain metadata via `provides<sql>` but no SQL-capable walker is registered?
- How does the system handle a query where multiple walkers claim to support the same subtree?
- What happens when a walker's `supports()` method returns True but the walker cannot actually execute the query?
- How does the system handle handover detection when domain metadata conflicts with capability checks?
- What happens when a composite query requires data flow between domains but one domain walker produces results in an incompatible format?
- How does the system handle execution-time errors in a subplan when the Master Walker is coordinating composite execution?
- What happens when a walker declines responsibility after initially accepting via `supports()`?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST implement the `provides<domain-name>` compile-time trait via `trait_mod:<provides>` that attaches advisory domain metadata to objects, containers, or declarations
- **FR-002**: System MUST make `provides` trait metadata discoverable by Slangs and Walkers during the planning phase
- **FR-003**: System MUST ensure `provides` trait does not alter runtime semantics, method dispatch, or type identity
- **FR-004**: System MUST implement Master Walker detection logic that follows handover detection priority: domain metadata → capability checks → AST pattern suitability → heuristic probing
- **FR-005**: System MUST require each Walker to provide a `supports(RakuAST::Node $node --> Bool)` capability predicate method
- **FR-006**: System MUST enable Master Walkers to query candidate walkers about their capabilities via `supports()` during planning
- **FR-007**: System MUST fail planning early with a diagnostic error when a root object declares domains via `provides` but no suitable Walker exists
- **FR-008**: System MUST enable Master Walkers to extract relevant AST subtrees and delegate planning to domain-specific walkers
- **FR-009**: System MUST enable Master Walkers to embed Walker::Plan objects from delegated walkers as subplans in composite plans
- **FR-010**: System MUST ensure all Walker handovers occur during the planning phase, not at execution time
- **FR-011**: System MUST enable Master Walkers to coordinate composite execution including execution ordering, data flow between subplans, join semantics, and result materialization or streaming
- **FR-012**: System MUST ensure domain-specific Walkers remain independent and do not require knowledge of other domains
- **FR-013**: System MUST ensure domain metadata is advisory only and MUST NOT force a Walker to accept responsibility
- **FR-014**: System MUST ensure Walkers remain free to decline responsibility even when domain metadata suggests they should handle a query
- **FR-015**: System MUST ensure domain metadata does not override Walker capability checks
- **FR-016**: System MUST make hybrid execution explicit in the resulting plan structure when multiple domains are involved
- **FR-017**: System MUST support AST pattern suitability recognition as an optimization mechanism (optional, not required for correctness)

### Key Entities

- **provides Trait**: A compile-time trait that attaches advisory domain metadata to root objects. Applied via `trait_mod:<provides>`, discoverable during planning, does not alter runtime behavior.

- **Master Walker**: A Walker implementation responsible for detecting when handovers are required and delegating planning and execution to appropriate domain-specific Walkers. Coordinates composite execution for multi-domain queries.

- **Domain-Specific Walker**: A Walker implementation specialized for a particular domain (e.g., SQL, JSON, in-memory objects). Provides `supports()` method to indicate capability, remains independent of other domains.

- **Composite Plan**: A Walker::Plan that contains embedded subplans from multiple domain-specific walkers. Produced by Master Walkers during plan-level handover, enables coordinated execution of multi-domain queries.

- **Handover Detection**: The process by which a Master Walker determines that responsibility for a query subtree should be delegated to another Walker. Follows priority order: domain metadata → capability checks → AST pattern suitability → heuristic probing.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developers can declare domain metadata on root objects using `provides<domain-name>` trait, and the metadata is discoverable during planning phase
- **SC-002**: Master Walkers can detect handover requirements and delegate to appropriate domain-specific walkers for 100% of multi-domain queries
- **SC-003**: All handover decisions are made during planning phase (0% of handovers occur at execution time)
- **SC-004**: Composite plans with embedded subplans execute correctly, coordinating data flow and join semantics across multiple domains
- **SC-005**: System provides diagnostic errors when domain metadata declares domains but no suitable walker exists, enabling early failure detection
- **SC-006**: Domain-specific walkers remain independent (0% coupling between walkers of different domains)
- **SC-007**: Walkers can decline responsibility even when domain metadata suggests they should handle a query, maintaining walker autonomy

## Assumptions

- Walker core infrastructure (Walker role, Walker::Plan role, Context role, QueryIterator role) is already implemented (feature 002)
- Query AST structure exists and uses RakuAST::Node (from walker-core feature)
- Multiple domain-specific walker implementations will exist or be created separately (e.g., SQL walker, JSON walker)
- The `supports()` method signature is already defined in the Walker role (from walker-core feature), though implementation may be optional
- Composite execution coordination may require additional infrastructure (e.g., result materialization, streaming coordination) that will be implemented as part of this feature

