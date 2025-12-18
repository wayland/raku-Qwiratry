---
work_package_id: "WP06"
subtasks:
  - "T034"
  - "T035"
  - "T036"
  - "T037"
  - "T038"
  - "T039"
  - "T040"
  - "T041"
  - "T042"
  - "T043"
  - "T044"
  - "T045"
  - "T046"
  - "T047"
  - "T048"
  - "T049"
  - "T050"
title: "Walker Role"
phase: "Phase 2 - Core Infrastructure"
lane: "done"
assignee: "claude"
agent: "claude-reviewer"
shell_pid: "89292"
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2025-12-17T11:41:34Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
---

# Work Package Prompt: WP06 – Walker Role

## Objectives & Success Criteria

- Implement Walker role with plan(), iterator(), start() methods
- Implement optional hooks: PRE-PASS(), POST-PASS()
- Implement optional introspection: capabilities(), supports()
- Throw X::Qwiratry::UnknownQueryElement for uninterpretable queries
- Provide default implementations where appropriate
- Write comprehensive unit tests

**Success**: Walker role complete, all methods work, exceptions thrown correctly, hooks work, tests pass.

## Context & Constraints

- **Prerequisites**: WP01 (module structure), WP02 (exceptions), WP05 (Walker::Plan)
- **Related Documents**:
  - `kitty-specs/002-walker-core-infrastructure/contracts/walker-api.md` - Walker API
  - `kitty-specs/002-walker-core-infrastructure/data-model.md` - Walker entity model
  - `kitty-specs/002-walker-core-infrastructure/spec.md` - FR-001, FR-005, FR-010, FR-011, FR-015, FR-016

- **Architecture Decisions**:
  - plan() is required, throws exception if query uninterpretable
  - iterator() convenience method uses stored root (instance state)
  - start() default implementation: self.plan($query, $root).iterator
  - PRE-PASS and POST-PASS hooks default to empty bodies
  - capabilities() returns structured metadata (default empty hash)
  - supports() returns Bool (default False)

## Subtasks & Detailed Guidance

### Subtask T034 – Implement Walker role

- **Purpose**: Create Walker role structure
- **Steps**:
  1. Open `lib/Qwiratry/Walker.rakumod`
  2. Define `role Walker does Iterable`
  3. Add documentation comment explaining purpose
  4. Note that concrete classes implement methods
- **Files**: `lib/Qwiratry/Walker.rakumod`
- **Parallel?**: No
- **Notes**: Walker does Iterable per spec

### Subtask T035 – Implement plan() method

- **Purpose**: Implement plan() method creating Walker::Plan
- **Steps**:
  1. Add `method plan(RakuAST::Node $query, Mu $root --> Walker::Plan) { ... }` stub
  2. Document that it throws X::Qwiratry::UnknownQueryElement if query uninterpretable
  3. Document that it returns reusable Walker::Plan
- **Files**: `lib/Qwiratry/Walker.rakumod`
- **Parallel?**: No (depends on T034)
- **Notes**: Required method, must throw exception for uninterpretable queries

### Subtask T036 – Implement iterator() convenience method

- **Purpose**: Implement iterator() convenience method using stored root
- **Steps**:
  1. Add `method iterator(RakuAST::Node $q --> QueryIterator) { ... }` stub
  2. Document that it internally calls plan($q, $root) then plan.iterator()
  3. Document that $root comes from Walker instance state
- **Files**: `lib/Qwiratry/Walker.rakumod`
- **Parallel?**: No (depends on T034)
- **Notes**: Convenience method, uses stored root

### Subtask T037 – Implement start() default method

- **Purpose**: Implement start() default convenience method
- **Steps**:
  1. Add `method start(RakuAST::Node $query, Mu:D $root --> QueryIterator) { self.plan($query, $root).iterator }`
  2. Document that it's equivalent to plan().iterator()
  3. Provide default implementation (not stub)
- **Files**: `lib/Qwiratry/Walker.rakumod`
- **Parallel?**: No (depends on T034)
- **Notes**: Default implementation provided (not stub)

### Subtask T038 – Implement PRE-PASS() hook

- **Purpose**: Implement PRE-PASS() optional hook
- **Steps**:
  1. Add `method PRE-PASS(Context $ctx) { }` with empty body
  2. Document that it's called before traversal begins
  3. Document typical uses (initialize state, prepare caches)
- **Files**: `lib/Qwiratry/Walker.rakumod`
- **Parallel?**: No (depends on T034)
- **Notes**: Optional hook, default empty body

### Subtask T039 – Implement POST-PASS() hook

- **Purpose**: Implement POST-PASS() optional hook
- **Steps**:
  1. Add `method POST-PASS(Context $ctx) { }` with empty body
  2. Document that it's called after traversal completes
  3. Document typical uses (collect diagnostics, finalize results)
- **Files**: `lib/Qwiratry/Walker.rakumod`
- **Parallel?**: No (depends on T034)
- **Notes**: Optional hook, default empty body

### Subtask T040 – Implement capabilities() method

- **Purpose**: Implement capabilities() returning structured metadata
- **Steps**:
  1. Add `method capabilities(--> Associative) { {} }` with default empty hash
  2. Document format: `{ lazy => { enabled => True, type => "incremental" }, ... }`
  3. Document that concrete walkers override with actual capabilities
- **Files**: `lib/Qwiratry/Walker.rakumod`
- **Parallel?**: No (depends on T034)
- **Notes**: Optional method, structured metadata format (FR-016)

### Subtask T041 – Implement supports() method

- **Purpose**: Implement supports() returning Bool
- **Steps**:
  1. Add `method supports(RakuAST::Node $query --> Bool) { False }` with default False
  2. Document that it returns True if Walker can interpret query
  3. Document that concrete walkers override with actual logic
- **Files**: `lib/Qwiratry/Walker.rakumod`
- **Parallel?**: No (depends on T034)
- **Notes**: Optional method, default False

### Subtask T042 – Throw X::Qwiratry::UnknownQueryElement when query uninterpretable

- **Purpose**: Ensure plan() throws exception for uninterpretable queries
- **Steps**:
  1. Add `use Qwiratry::X;` to Walker.rakumod
  2. Document that plan() must throw X::Qwiratry::UnknownQueryElement
  3. Note that concrete implementations provide actual logic
- **Files**: `lib/Qwiratry/Walker.rakumod`
- **Parallel?**: No (depends on T035)
- **Notes**: Critical requirement (FR-005)

### Subtask T043 – Write unit tests for Walker role

- **Purpose**: Comprehensive tests for Walker role
- **Steps**:
  1. Open `tests/unit/walker.rakutest`
  2. Create example concrete class implementing Walker
  3. Test all methods exist and have correct signatures
  4. Test plan() creates Walker::Plan
  5. Test iterator() convenience method
  6. Test start() default implementation
  7. Test hooks (PRE-PASS, POST-PASS)
  8. Test capabilities() and supports()
  9. Test exception throwing
- **Files**: `tests/unit/walker.rakutest`
- **Parallel?**: Yes (can be written alongside implementation)
- **Notes**: Create example implementation for testing

### Subtask T044 – Test plan() creates Walker::Plan

- **Purpose**: Verify plan() method works
- **Steps**:
  1. Create Walker instance
  2. Call plan() with valid query
  3. Verify returns Walker::Plan
  4. Verify plan contains query
- **Files**: `tests/unit/walker.rakutest`
- **Parallel?**: No (depends on T043)
- **Notes**: Core functionality

### Subtask T045 – Test iterator() convenience method

- **Purpose**: Verify iterator() convenience method
- **Steps**:
  1. Create Walker instance with stored root
  2. Call iterator() with query
  3. Verify returns QueryIterator
  4. Verify internally calls plan then iterator
- **Files**: `tests/unit/walker.rakutest`
- **Parallel?**: No (depends on T043)
- **Notes**: Convenience method behavior

### Subtask T046 – Test start() equivalent to plan().iterator()

- **Purpose**: Verify start() default implementation
- **Steps**:
  1. Create Walker instance
  2. Call start() with query and root
  3. Call plan().iterator() with same query and root
  4. Verify both return QueryIterator
  5. Verify behavior is equivalent
- **Files**: `tests/unit/walker.rakutest`
- **Parallel?**: No (depends on T043)
- **Notes**: Default implementation verification

### Subtask T047 – Test exception for uninterpretable queries

- **Purpose**: Verify exception throwing
- **Steps**:
  1. Create Walker instance
  2. Call plan() with uninterpretable query
  3. Verify throws X::Qwiratry::UnknownQueryElement
  4. Verify exception contains query AST and walker type
- **Files**: `tests/unit/walker.rakutest`
- **Parallel?**: No (depends on T043)
- **Notes**: Critical requirement (FR-005)

### Subtask T048 – Test hooks called at appropriate times

- **Purpose**: Verify hook timing (if applicable)
- **Steps**:
  1. Create Walker with PRE-PASS and POST-PASS implementations
  2. Execute traversal
  3. Verify PRE-PASS called before traversal
  4. Verify POST-PASS called after traversal
- **Files**: `tests/unit/walker.rakutest`
- **Parallel?**: No (depends on T043)
- **Notes**: Hook timing is implementation-specific

### Subtask T049 – Test capabilities() structured metadata

- **Purpose**: Verify capabilities() format
- **Steps**:
  1. Create Walker instance
  2. Call capabilities()
  3. Verify returns Associative
  4. Verify format matches specification (nested hash structure)
- **Files**: `tests/unit/walker.rakutest`
- **Parallel?**: No (depends on T043)
- **Notes**: Structured metadata format (FR-016)

### Subtask T050 – Test supports() returns Bool

- **Purpose**: Verify supports() method
- **Steps**:
  1. Create Walker instance
  2. Call supports() with query
  3. Verify returns Bool
  4. Test with interpretable and uninterpretable queries
- **Files**: `tests/unit/walker.rakutest`
- **Parallel?**: No (depends on T043)
- **Notes**: Introspection method

## Test Strategy

- **Framework**: Raku Test module
- **Coverage**: All methods, exception throwing, hooks, introspection, convenience methods
- **Commands**: `raku -Ilib tests/unit/walker.rakutest`

## Risks & Mitigations

- **Query AST interpretation**: Ensure proper exception throwing for uninterpretable queries
- **Root storage**: Verify iterator() convenience method correctly uses stored root
- **Hook timing**: Ensure hooks are called at appropriate times (implementation-specific)

## Definition of Done Checklist

- [ ] Walker role implemented with all methods
- [ ] Required methods (plan, iterator, start) implemented
- [ ] Optional hooks (PRE-PASS, POST-PASS) implemented with defaults
- [ ] Optional introspection (capabilities, supports) implemented with defaults
- [ ] Exception throwing verified
- [ ] Unit tests written and passing
- [ ] All method behaviors verified

## Review Guidance

- Verify all methods have correct signatures
- Verify exception throwing works correctly (critical)
- Verify default implementations are correct
- Verify hooks and introspection methods work

## Activity Log

- 2025-12-17T11:41:34Z – system – lane=planned – Prompt created.
- 2025-12-17T23:07:00Z – claude – shell_pid=72117 – lane=doing – Started implementation (Walker role already in Walker.rakumod from WP05)
- 2025-12-17T23:10:00Z – claude – shell_pid=72117 – lane=doing – Completed: Walker role with plan(), iterator(), start(), PRE-PASS(), POST-PASS(), capabilities(), supports(). Comprehensive unit tests (15 test groups) covering all methods, exception handling, hooks, introspection.
- 2025-12-17T23:10:00Z – claude – shell_pid=72117 – lane=for_review – Ready for review
- 2025-12-18T20:29:03Z – claude-reviewer – shell_pid=89292 – lane=done – Code review approved
