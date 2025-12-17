---
work_package_id: "WP05"
subtasks:
  - "T023"
  - "T024"
  - "T025"
  - "T026"
  - "T027"
  - "T028"
  - "T029"
  - "T030"
  - "T031"
  - "T032"
  - "T033"
title: "Walker::Plan Role"
phase: "Phase 2 - Core Infrastructure"
lane: "for_review"
assignee: "claude"
agent: "claude"
shell_pid: "72117"
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2025-12-17T11:41:34Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
---

# Work Package Prompt: WP05 – Walker::Plan Role

## Objectives & Success Criteria

- Implement Walker::Plan role with all required and optional methods
- Methods: iterator(), query(), describe(), optimise(), subplans(), capabilities()
- Verify multiple iterators from same plan are independent
- Verify plan does not mutate original Query AST
- Write comprehensive unit tests

**Success**: Walker::Plan role complete, all methods work, immutability verified, tests pass.

## Context & Constraints

- **Prerequisites**: WP01 (module structure), WP03 (Context), WP04 (QueryIterator)
- **Related Documents**:
  - `kitty-specs/002-walker-core-infrastructure/contracts/walker-api.md` - Walker::Plan API
  - `kitty-specs/002-walker-core-infrastructure/data-model.md` - Walker::Plan entity model
  - `kitty-specs/002-walker-core-infrastructure/spec.md` - FR-002, FR-006, FR-007, FR-014, FR-016

- **Architecture Decisions**:
  - Required: iterator(), query(), describe()
  - Optional with defaults: optimise(), subplans(), capabilities()
  - Query AST immutability: plan must not mutate original Query AST
  - Multiple iterators: each iterator() call creates independent QueryIterator

## Subtasks & Detailed Guidance

### Subtask T023 – Implement Walker::Plan role

- **Purpose**: Create Walker::Plan role structure
- **Steps**:
  1. Open `lib/Qwiratry/Walker.rakumod`
  2. Add `role Walker::Plan { }` after Walker role
  3. Add documentation comment explaining purpose
  4. Note that concrete classes implement methods
- **Files**: `lib/Qwiratry/Walker.rakumod`
- **Parallel?**: No
- **Notes**: Walker::Plan is in same module as Walker per plan.md

### Subtask T024 – Implement iterator() method

- **Purpose**: Implement iterator() returning QueryIterator
- **Steps**:
  1. Add `method iterator(--> QueryIterator) { ... }` stub
  2. Document that it creates fresh Context and QueryIterator
  3. Document that multiple calls return independent iterators
- **Files**: `lib/Qwiratry/Walker.rakumod`
- **Parallel?**: No (depends on T023)
- **Notes**: Stub method (concrete classes implement)

### Subtask T025 – Implement query() method

- **Purpose**: Implement query() returning Query AST
- **Steps**:
  1. Add `method query(--> RakuAST::Node) { ... }` stub
  2. Document that it returns immutable Query AST used to create plan
- **Files**: `lib/Qwiratry/Walker.rakumod`
- **Parallel?**: No (depends on T023)
- **Notes**: Returns RakuAST::Node

### Subtask T026 – Implement describe() method

- **Purpose**: Implement describe() returning human-readable string
- **Steps**:
  1. Add `method describe(--> Str) { ... }` stub
  2. Document that it returns description for debugging/profiling
- **Files**: `lib/Qwiratry/Walker.rakumod`
- **Parallel?**: No (depends on T023)
- **Notes**: Returns descriptive string

### Subtask T027 – Implement optimise() method

- **Purpose**: Implement optimise() with callback signature
- **Steps**:
  1. Add `method optimise(&modification --> Walker::Plan) { ... }` stub
  2. Document callback signature: `-> Walker::Plan $plan { ... } --> Walker::Plan`
  3. Document that it returns modified plan (new instance unless safe in-place)
- **Files**: `lib/Qwiratry/Walker.rakumod`
- **Parallel?**: No (depends on T023)
- **Notes**: Optional method, callback receives plan itself

### Subtask T028 – Implement subplans() method

- **Purpose**: Implement subplans() returning array of plans
- **Steps**:
  1. Add `method subplans(--> @Walker::Plan) { ... }` stub
  2. Document default returns empty array (for non-composite plans)
- **Files**: `lib/Qwiratry/Walker.rakumod`
- **Parallel?**: No (depends on T023)
- **Notes**: Optional method, default empty array

### Subtask T029 – Implement capabilities() method

- **Purpose**: Implement capabilities() returning structured metadata
- **Steps**:
  1. Add `method capabilities(--> Associative) { ... }` stub
  2. Document default returns empty hash
  3. Document format: `{ lazy => { enabled => True, type => "incremental" }, ... }`
- **Files**: `lib/Qwiratry/Walker.rakumod`
- **Parallel?**: No (depends on T023)
- **Notes**: Optional method, structured metadata format

### Subtask T030 – Write unit tests for Walker::Plan role

- **Purpose**: Comprehensive tests for Walker::Plan
- **Steps**:
  1. Open `tests/unit/walker-plan.rakutest`
  2. Create example concrete class implementing Walker::Plan
  3. Test all methods exist and have correct signatures
  4. Test query() returns Query AST
  5. Test describe() returns string
  6. Test optimise() callback signature
  7. Test subplans() default returns empty array
  8. Test capabilities() default returns empty hash
- **Files**: `tests/unit/walker-plan.rakutest`
- **Parallel?**: Yes (can be written alongside implementation)
- **Notes**: Create example implementation for testing

### Subtask T031 – Test multiple iterators from same plan are independent

- **Purpose**: Verify iterator independence
- **Steps**:
  1. Create plan instance
  2. Call iterator() multiple times
  3. Verify each iterator is independent
  4. Verify iterators do not share state
- **Files**: `tests/unit/walker-plan.rakutest`
- **Parallel?**: No (depends on T030)
- **Notes**: Critical requirement (FR-006)

### Subtask T032 – Test plan does not mutate original Query AST

- **Purpose**: Verify Query AST immutability
- **Steps**:
  1. Create Query AST
  2. Create plan with Query AST
  3. Perform operations on plan
  4. Verify original Query AST unchanged
- **Files**: `tests/unit/walker-plan.rakutest`
- **Parallel?**: No (depends on T030)
- **Notes**: Critical requirement (FR-007)

### Subtask T033 – Test optimise callback signature and behavior

- **Purpose**: Verify optimise() callback works correctly
- **Steps**:
  1. Create plan instance
  2. Call optimise() with callback
  3. Verify callback receives plan
  4. Verify callback returns modified plan
  5. Test callback signature matches contract
- **Files**: `tests/unit/walker-plan.rakutest`
- **Parallel?**: No (depends on T030)
- **Notes**: Verify callback contract (FR-014)

## Test Strategy

- **Framework**: Raku Test module
- **Coverage**: All methods, iterator independence, Query AST immutability, optimise callback
- **Commands**: `raku -Ilib tests/unit/walker-plan.rakutest`

## Risks & Mitigations

- **Query AST immutability**: Ensure plan does not mutate original Query AST (copy if needed)
- **Iterator independence**: Verify each iterator() call creates fresh Context
- **Optimise callback**: Ensure proper signature and return type

## Definition of Done Checklist

- [ ] Walker::Plan role implemented with all methods
- [ ] Required methods (iterator, query, describe) implemented
- [ ] Optional methods (optimise, subplans, capabilities) implemented with defaults
- [ ] Unit tests written and passing
- [ ] Iterator independence verified
- [ ] Query AST immutability verified
- [ ] Optimise callback verified

## Review Guidance

- Verify all methods have correct signatures
- Verify iterator independence (critical)
- Verify Query AST immutability (critical)
- Verify optimise callback contract

## Activity Log

- 2025-12-17T11:41:34Z – system – lane=planned – Prompt created.
- 2025-12-17T23:00:00Z – claude – shell_pid=72117 – lane=doing – Started implementation
- 2025-12-17T23:05:00Z – claude – shell_pid=72117 – lane=doing – Completed: Walker::Plan role with iterator(), query(), describe() (required), optimise(), subplans(), capabilities() (optional with defaults). Comprehensive unit tests (14 test groups) covering method signatures, iterator independence, Query AST immutability.
- 2025-12-17T23:05:00Z – claude – shell_pid=72117 – lane=for_review – Ready for review. Note: Walker role (WP06) also implemented in same file.


