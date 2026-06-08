# Feature Specification: Strategy and ControlSignal

**Feature Branch**: `003-strategy-and-controlsignal`  
**Created**: 2024-12-19  
**Status**: Complete  
**Specification Reference**: Specification.md sections 2.1.3, 3.2.5, 3.2.6

## Overview

The Strategy role provides element-level behaviour during data traversal. It defines hooks that are called at key points when visiting elements (nodes, rows, etc.), allowing pluggable, reusable processing logic. Strategies are walker-agnostic - the same strategy can work across trees, tables, graphs, and other data models.

The ControlSignal enumeration provides a vocabulary for Strategies to communicate decisions back to the Walker - whether to continue, skip elements, stop traversal, or schedule rewrites.

## User Scenarios & Testing

### User Story 1 - Basic Traversal Control (Priority: P1)

A developer implementing a tree search wants to stop traversal early when a target is found, without processing remaining elements.

**Why this priority**: Early termination is fundamental to efficient traversal. Without it, every search must visit all elements even after finding the target.

**Independent Test**: Can be tested by creating a Strategy that returns STOP_TRAVERSAL from on-match, verifying traversal halts immediately.

**Acceptance Scenarios**:

1. **Given** a Walker traversing a tree with a Strategy, **When** the Strategy returns STOP_TRAVERSAL from any hook, **Then** the Walker immediately stops visiting further elements
2. **Given** a Walker with a Strategy that returns NO_REWRITE, **When** elements are visited, **Then** traversal continues normally to all reachable elements

---

### User Story 2 - Element Skipping and Pruning (Priority: P1)

A developer wants to skip certain branches of a tree (e.g., ignore all "metadata" subtrees) to improve performance and focus results.

**Why this priority**: Pruning is essential for efficient traversal of large data structures. It allows developers to avoid visiting irrelevant subtrees.

**Independent Test**: Can be tested by creating a Strategy with should-follow returning False for certain relations, verifying those branches are not visited.

**Acceptance Scenarios**:

1. **Given** a Walker traversing a tree, **When** should-follow returns False for a relation, **Then** the target element and its descendants are not visited
2. **Given** a Strategy returning SKIP_ELEMENT from before hook, **When** that element is encountered, **Then** the element and its relations are skipped entirely

---

### User Story 3 - Match Processing (Priority: P1)

A developer wants to perform custom actions when query patterns match elements - collecting matches, transforming data, or building result sets.

**Why this priority**: The on-match hook is the primary integration point between query results and application logic.

**Independent Test**: Can be tested by creating a Strategy with on-match that collects matches into Context, verifying all matching elements are captured.

**Acceptance Scenarios**:

1. **Given** a Walker executing a query with a Strategy, **When** an element matches the query, **Then** the on-match hook is called with the element and match information
2. **Given** on-match returns a ControlSignal, **When** processing continues, **Then** the Walker respects that signal (skip, stop, continue)

---

### User Story 4 - Pre/Post Visit Processing (Priority: P2)

A developer wants to perform setup before visiting an element (e.g., push to a path stack) and cleanup after (e.g., pop from stack).

**Why this priority**: Stateful traversal patterns like path tracking, depth counting, or scope management require paired before/after hooks.

**Independent Test**: Can be tested by creating a Strategy that increments a depth counter in before and decrements in after, verifying correct depth at each element.

**Acceptance Scenarios**:

1. **Given** a Walker with a Strategy, **When** an element is about to be visited, **Then** the before hook is called before any relations are followed
2. **Given** a Walker with a Strategy, **When** all relations of an element have been visited, **Then** the after hook is called

---

### User Story 5 - Traversal Completion (Priority: P2)

A developer wants to perform final processing after a complete traversal - computing aggregates, finalizing results, or cleaning up resources.

**Why this priority**: Many use cases require post-traversal processing that cannot be done incrementally.

**Independent Test**: Can be tested by creating a Strategy with finish that returns a computed result, verifying the result reflects all visited elements.

**Acceptance Scenarios**:

1. **Given** a Walker that has completed traversing all elements, **When** traversal ends, **Then** the finish hook is called with the root element and Context
2. **Given** finish returns a FinishResult, **When** the traversal completes, **Then** the result is available to the caller

---

### User Story 6 - Fixed-Point Iteration (Priority: P3)

A developer implementing dataflow analysis wants the Walker to perform multiple passes until no more changes occur (fixed-point computation).

**Why this priority**: Fixed-point iteration is an advanced pattern needed for specific algorithms like type inference or constant propagation.

**Independent Test**: Can be tested by creating a Strategy with should-continue that returns True while changes occur, verifying multiple passes execute.

**Acceptance Scenarios**:

1. **Given** a Walker supporting multi-pass execution, **When** should-continue returns True after a pass, **Then** another traversal pass begins
2. **Given** should-continue returns False, **When** a pass completes, **Then** traversal terminates

---

### Edge Cases

- What happens when a hook returns Nil? (Treated as default behaviour - continue normally)
- What happens when before returns SKIP_ELEMENT but on-match would have matched? (Element is skipped, on-match not called)
- What happens when multiple ControlSignals could apply? (Most restrictive wins: STOP_TRAVERSAL > SKIP_ELEMENT > others)
- What happens when should-follow is not implemented? (Default: follow all relations)
- What happens when finish is called but traversal was stopped early? (finish still called with whatever state exists)

## Requirements

### Functional Requirements

#### ControlSignal Enum

- **FR-001**: System MUST provide a ControlSignal enumeration with values: NO_REWRITE, REWRITE_IMMEDIATE, REWRITE_DEFERRED, SKIP_ELEMENT, STOP_TRAVERSAL, FINAL_RESULT
- **FR-002**: ControlSignal values MUST be usable as return values from Strategy hooks
- **FR-003**: Each ControlSignal MUST have clear, documented semantics for Walker behaviour

#### Strategy Role

- **FR-004**: System MUST provide a Strategy role that can be composed into classes
- **FR-005**: Strategy MUST define a before hook called before visiting an element, accepting element and Context, returning ControlSignal or Nil
- **FR-006**: Strategy MUST define an on-match hook called when a query matches, accepting element, Match, and Context, returning ControlSignal, RewriteSpec, or Nil
- **FR-007**: Strategy MUST define a should-follow hook for relation pruning, accepting origin, Relation, target element, and Context, returning Bool
- **FR-008**: Strategy MUST define an after hook called after visiting element relations, accepting element and Context, returning ControlSignal, RewriteSpec, or Nil
- **FR-009**: Strategy MUST define a finish hook called after traversal completes, accepting root element and Context, returning FinishResult
- **FR-010**: Strategy MUST define a should-continue hook for fixed-point iteration, accepting root element and Context, returning Bool
- **FR-011**: All Strategy hooks MUST be optional - undefined hooks treated as default behaviour

#### Supporting Types

- **FR-012**: System MUST provide a RewriteSpec role as a stub type for rewrite specifications
- **FR-013**: System MUST provide a FinishResult class with at minimum a type field and value field
- **FR-014**: FinishResult MUST support construction with type and value parameters

#### Walker Integration

- **FR-015**: Walker MUST call Strategy before hook before visiting each element
- **FR-016**: Walker MUST call Strategy on-match hook when a query matches an element
- **FR-017**: Walker MUST call Strategy should-follow hook before following each relation
- **FR-018**: Walker MUST call Strategy after hook after visiting all relations of an element
- **FR-019**: Walker MUST call Strategy finish hook when traversal completes
- **FR-020**: Walker MUST respect ControlSignal returns: STOP_TRAVERSAL halts immediately, SKIP_ELEMENT skips element and relations
- **FR-021**: Walker MUST share the same Context instance with Strategy across all hook calls in a traversal

### Key Entities

- **Strategy**: Role defining element-level traversal behaviour through hooks. Walker-agnostic and reusable.
- **ControlSignal**: Enumeration of signals communicating Strategy decisions to Walker.
- **RewriteSpec**: Specification for how to rewrite/transform an element (stub in this feature).
- **FinishResult**: Result object returned from finish hook containing traversal outcome.
- **Context**: Mutable per-traversal state shared between Walker and Strategy (already implemented).

## Success Criteria

### Measurable Outcomes

- **SC-001**: All six Strategy hooks can be implemented in a concrete class and are called at the correct traversal points
- **SC-002**: A Strategy returning STOP_TRAVERSAL causes traversal to halt within one element visit
- **SC-003**: A Strategy returning SKIP_ELEMENT causes that element's relations to not be visited
- **SC-004**: should-follow returning False prevents visitation of the target element
- **SC-005**: The same Strategy instance can be used with different Walker implementations without modification
- **SC-006**: All ControlSignal values are recognized and produce documented behaviour
- **SC-007**: Context state is preserved and accessible across all hook calls within a single traversal

## Assumptions

- The existing Walker role from feature 002 provides the infrastructure for calling hooks
- The existing Context role from feature 002 provides adequate state management
- Relation and Element are generic type placeholders that concrete implementations will specialize
- Match refers to the standard Raku Match type or a compatible query match object
- RewriteSpec and FinishResult will be expanded in future features when rewrite functionality is fully implemented

## Dependencies

- Feature 002: Walker Core Infrastructure (Context, QueryIterator, Walker, Walker::Plan)
- Specification.md sections 2.1.3, 3.2.5, 3.2.6

## Out of Scope

- Full rewrite/transformation implementation (RewriteSpec is a stub)
- Transformer integration (separate feature per Specification.md section 3.3)
- Query AST and matching logic (separate Query Group feature)
- Specific Walker implementations (DFS, BFS, table scan, etc.)

