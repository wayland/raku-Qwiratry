---
work_package_id: WP04
title: QueryIterator Role
lane: done
history:
- timestamp: '2025-12-17T11:41:34Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
agent: claude-reviewer
assignee: claude
phase: Phase 1 - Foundational
review_status: ''
reviewed_by: ''
shell_pid: '89292'
subtasks:
- T017
- T018
- T019
- T020
- T021
- T022
---

# Work Package Prompt: WP04 – QueryIterator Role

## Objectives & Success Criteria

- Implement QueryIterator role extending Iterator
- Implement next() method returning Mu or Nil
- QueryIterator receives Context via constructor and stores as attribute
- Verify QueryIterator extends Iterator role correctly
- Write comprehensive unit tests

**Success**: QueryIterator implements Iterator contract, next() works correctly, Context integration verified, tests pass.

## Context & Constraints

- **Prerequisites**: WP01 (module structure), WP03 (Context role)
- **Related Documents**:
  - `kitty-specs/002-walker-core-infrastructure/data-model.md` - QueryIterator entity model
  - `kitty-specs/002-walker-core-infrastructure/contracts/walker-api.md` - QueryIterator API contract
  - `kitty-specs/002-walker-core-infrastructure/spec.md` - FR-004, FR-009, FR-013 QueryIterator requirements

- **Architecture Decisions**:
  - QueryIterator does Iterator role
  - next() returns Mu (result) or Nil (exhausted)
  - Constructor receives Context, stores as $.context attribute
  - Supports lazy evaluation (implementation-specific)

## Subtasks & Detailed Guidance

### Subtask T017 – Implement QueryIterator role

- **Purpose**: Create QueryIterator role extending Iterator
- **Steps**:
  1. Open `lib/Qwiratry/QueryIterator.rakumod`
  2. Add `use Qwiratry::Context;` for Context dependency
  3. Define `role QueryIterator does Iterator`
  4. Add `has Context $.context` attribute (required, set via constructor)
  5. Add documentation comment explaining Iterator contract
- **Files**: `lib/Qwiratry/QueryIterator.rakumod`
- **Parallel?**: No
- **Notes**: Must extend Iterator role, Context attribute required

### Subtask T018 – Implement next() method contract

- **Purpose**: Implement next() method returning Mu or Nil
- **Steps**:
  1. In QueryIterator role, add `method next(--> Mu) { ... }` stub
  2. Document that next() returns Mu (result) or Nil (exhausted)
  3. Document lazy evaluation support
  4. Note that concrete implementations provide actual logic
- **Files**: `lib/Qwiratry/QueryIterator.rakumod`
- **Parallel?**: No (depends on T017)
- **Notes**: Stub method is sufficient (concrete classes implement)

### Subtask T019 – Write unit tests for QueryIterator role

- **Purpose**: Verify QueryIterator role contract and behavior
- **Steps**:
  1. Open `tests/unit/query-iterator.rakutest`
  2. Add `use Qwiratry::QueryIterator;` and `use Test;`
  3. Create example concrete class implementing QueryIterator
  4. Test QueryIterator extends Iterator correctly
  5. Test QueryIterator receives Context via constructor
  6. Test next() method signature
  7. Test next() returns Nil when exhausted
- **Files**: `tests/unit/query-iterator.rakutest`
- **Parallel?**: Yes (can be written alongside implementation)
- **Notes**: Create example implementation for testing

### Subtask T020 – Test QueryIterator receives Context via constructor

- **Purpose**: Verify Context integration
- **Steps**:
  1. Create test Context instance
  2. Create QueryIterator instance passing Context to constructor
  3. Verify $.context attribute is set
  4. Verify Context is accessible
- **Files**: `tests/unit/query-iterator.rakutest`
- **Parallel?**: No (depends on T019)
- **Notes**: Verify constructor pattern works

### Subtask T021 – Test QueryIterator.next() returns Nil when exhausted

- **Purpose**: Verify exhaustion behavior
- **Steps**:
  1. Create QueryIterator with finite results
  2. Call next() until exhausted
  3. Verify next() returns Nil consistently after exhaustion
  4. Test multiple calls after exhaustion all return Nil
- **Files**: `tests/unit/query-iterator.rakutest`
- **Parallel?**: No (depends on T019)
- **Notes**: Consistent Nil return is important

### Subtask T022 – Verify QueryIterator extends Iterator role correctly

- **Purpose**: Ensure Iterator contract compliance
- **Steps**:
  1. Test QueryIterator does Iterator role
  2. Verify Iterator methods are available
  3. Test QueryIterator can be used where Iterator expected
- **Files**: `tests/unit/query-iterator.rakutest`
- **Parallel?**: No (depends on T019)
- **Notes**: Verify role composition works

## Test Strategy

- **Framework**: Raku Test module
- **Coverage**: Iterator contract, next() behavior, Context integration, exhaustion
- **Commands**: `raku -Ilib tests/unit/query-iterator.rakutest`

## Risks & Mitigations

- **Iterator contract compliance**: Verify QueryIterator properly extends Iterator
- **Context integration**: Ensure Context is properly stored and accessible
- **Exhaustion behavior**: Ensure consistent Nil return

## Definition of Done Checklist

- [ ] QueryIterator role implemented (extends Iterator)
- [ ] next() method contract defined
- [ ] Context integration verified
- [ ] Unit tests written and passing
- [ ] Iterator contract compliance verified

## Review Guidance

- Verify QueryIterator extends Iterator correctly
- Verify Context integration works
- Verify next() contract is correct
- Verify tests are comprehensive

## Activity Log

- 2025-12-17T11:41:34Z – system – lane=planned – Prompt created.
- 2025-12-17T22:55:00Z – claude – shell_pid=72117 – lane=doing – Started implementation
- 2025-12-17T22:58:00Z – claude – shell_pid=72117 – lane=doing – Completed: QueryIterator role with $.context attribute, pull-one() method contract, comprehensive documentation. Unit tests (12 test groups) covering Iterator extension, Context integration, exhaustion behavior.
- 2025-12-17T22:58:00Z – claude – shell_pid=72117 – lane=for_review – Ready for review
- 2025-12-18T20:29:03Z – claude-reviewer – shell_pid=89292 – lane=done – Code review approved
