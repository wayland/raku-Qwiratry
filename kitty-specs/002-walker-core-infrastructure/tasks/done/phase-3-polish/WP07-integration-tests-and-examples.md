---
work_package_id: "WP07"
subtasks:
  - "T051"
  - "T052"
  - "T053"
  - "T054"
  - "T055"
  - "T056"
  - "T057"
title: "Integration Tests & Example Walker"
phase: "Phase 3 - Polish"
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

# Work Package Prompt: WP07 – Integration Tests & Example Walker

## Objectives & Success Criteria

- Create integration tests for plan → iterator → results flow
- Create SimpleWalker example class implementing all roles
- Write example walker tests verifying end-to-end behavior
- Validate quickstart.md scenarios work correctly
- Verify all roles work together correctly

**Success**: Integration tests pass, example walker demonstrates all features, quickstart scenarios validated, end-to-end flow works.

## Context & Constraints

- **Prerequisites**: WP01-WP06 (all roles implemented)
- **Related Documents**:
  - `kitty-specs/002-walker-core-infrastructure/quickstart.md` - Usage examples
  - `kitty-specs/002-walker-core-infrastructure/spec.md` - Integration test requirements
  - `kitty-specs/002-walker-core-infrastructure/plan.md` - Example walker specification

- **Architecture Decisions**:
  - SimpleWalker: minimal concrete implementation demonstrating all roles
  - Integration tests: verify plan → iterator → results flow
  - Example tests: verify concrete walker works end-to-end

## Subtasks & Detailed Guidance

### Subtask T051 – Write integration test for plan → iterator → results flow

- **Purpose**: Verify end-to-end query execution flow
- **Steps**:
  1. Open `tests/integration/walker-flow.rakutest`
  2. Add `use Test;` and necessary module imports
  3. Create test that:
     - Creates Walker instance
     - Calls plan() with query
     - Calls iterator() on plan
     - Calls next() on iterator
     - Verifies results
  4. Test multiple iterators from same plan
  5. Test Context state management
- **Files**: `tests/integration/walker-flow.rakutest`
- **Parallel?**: No
- **Notes**: End-to-end flow verification

### Subtask T052 – Create SimpleWalker example class implementing all roles

- **Purpose**: Create minimal concrete walker demonstrating all features
- **Steps**:
  1. Create SimpleWalker class in test file or separate module
  2. Implement Walker role with:
     - plan() method creating SimplePlan
     - iterator() convenience method
     - start() uses default
     - PRE-PASS and POST-PASS hooks (optional)
     - capabilities() and supports() (optional)
  3. Create SimplePlan class implementing Walker::Plan
  4. Create SimpleContext class implementing Context
  5. Create SimpleIterator class implementing QueryIterator
  6. Ensure all roles work together
- **Files**: `tests/examples/simple-walker.rakutest` or separate module
- **Parallel?**: No (needed for T053)
- **Notes**: Minimal but complete implementation

### Subtask T053 – Write example walker tests

- **Purpose**: Verify example walker works end-to-end
- **Steps**:
  1. Open `tests/examples/simple-walker.rakutest`
  2. Test SimpleWalker can plan queries
  3. Test SimpleWalker can produce iterators
  4. Test SimpleWalker start() method works
  5. Test SimpleWalker exception handling
  6. Test SimpleWalker hooks (if implemented)
  7. Test SimpleWalker capabilities and supports
- **Files**: `tests/examples/simple-walker.rakutest`
- **Parallel?**: No (depends on T052)
- **Notes**: Verify example demonstrates all features

### Subtask T054 – Test multiple iterators from same plan produce independent results

- **Purpose**: Verify iterator independence in integration context
- **Steps**:
  1. Create plan from SimpleWalker
  2. Create multiple iterators from same plan
  3. Iterate over each independently
  4. Verify results are independent
  5. Verify no interference between iterators
- **Files**: `tests/integration/walker-flow.rakutest` or `tests/examples/simple-walker.rakutest`
- **Parallel?**: No (depends on T051 or T053)
- **Notes**: Critical requirement verification

### Subtask T055 – Test Context state persists across hook calls

- **Purpose**: Verify Context state management
- **Steps**:
  1. Create Context instance
  2. Store data in Context
  3. Call hooks (PRE-PASS, POST-PASS)
  4. Verify data persists
  5. Test across multiple operations
- **Files**: `tests/integration/walker-flow.rakutest` or `tests/examples/simple-walker.rakutest`
- **Parallel?**: No (depends on T051 or T053)
- **Notes**: Context lifecycle verification

### Subtask T056 – Validate quickstart.md scenarios work correctly

- **Purpose**: Ensure quickstart examples are valid
- **Steps**:
  1. Review `quickstart.md` scenarios
  2. Implement scenarios using SimpleWalker
  3. Verify each scenario works
  4. Update quickstart.md if needed (fix any errors)
  5. Document any differences between quickstart and actual implementation
- **Files**: `tests/examples/simple-walker.rakutest`, `quickstart.md` (if updates needed)
- **Parallel?**: No (depends on T052)
- **Notes**: Quickstart validation

### Subtask T057 – Test end-to-end query execution with example walker

- **Purpose**: Comprehensive end-to-end test
- **Steps**:
  1. Create complete query execution scenario
  2. Use SimpleWalker to execute query
  3. Verify all steps work:
     - Planning
     - Iterator creation
     - Result production
     - Context management
     - Hook execution (if applicable)
  4. Verify error handling
  5. Verify all roles integrate correctly
- **Files**: `tests/integration/walker-flow.rakutest` or `tests/examples/simple-walker.rakutest`
- **Parallel?**: No (depends on T052)
- **Notes**: Final integration verification

## Test Strategy

- **Framework**: Raku Test module
- **Coverage**: End-to-end flow, example walker, quickstart scenarios, integration points
- **Commands**: 
  - `raku -Ilib tests/integration/walker-flow.rakutest`
  - `raku -Ilib tests/examples/simple-walker.rakutest`

## Risks & Mitigations

- **Integration complexity**: Ensure all roles work together correctly
- **Example walker completeness**: Verify example demonstrates all features
- **Quickstart accuracy**: Ensure quickstart examples match actual implementation

## Definition of Done Checklist

- [ ] Integration tests written and passing
- [ ] SimpleWalker example class created
- [ ] Example walker tests written and passing
- [ ] Multiple iterators independence verified
- [ ] Context state persistence verified
- [ ] Quickstart scenarios validated
- [ ] End-to-end query execution verified

## Review Guidance

- Verify integration tests cover all critical flows
- Verify example walker demonstrates all features
- Verify quickstart scenarios are accurate
- Verify all roles integrate correctly

## Activity Log

- 2025-12-17T11:41:34Z – system – lane=planned – Prompt created.
- 2025-12-17T23:12:00Z – claude – shell_pid=72117 – lane=doing – Started implementation
- 2025-12-17T23:18:00Z – claude – shell_pid=72117 – lane=doing – Completed: Integration tests (10 test groups) covering plan→iterator→results flow, Context management, exception handling. SimpleWalker example tests (12 test groups) demonstrating all roles working together.
- 2025-12-17T23:18:00Z – claude – shell_pid=72117 – lane=for_review – Ready for review
- 2025-12-18T20:29:03Z – claude-reviewer – shell_pid=89292 – lane=done – Code review approved
