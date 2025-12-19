---
work_package_id: "WP07"
subtasks:
  - "T047"
  - "T048"
  - "T049"
  - "T050"
  - "T051"
  - "T052"
  - "T053"
  - "T054"
title: "Handover Detection Priority Order & Edge Cases"
phase: "Phase 3 - Polish"
lane: "planned"
assignee: ""
agent: ""
shell_pid: ""
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2025-01-27T00:00:00Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
---

# Work Package Prompt: WP07 – Handover Detection Priority Order & Edge Cases

## Objectives & Success Criteria

- Complete handover detection priority order implementation (AST pattern, heuristics)
- Handle edge cases: no walker found, multiple walkers support subtree, walker declines responsibility
- Master Walker follows priority order correctly, handles edge cases gracefully

**Success**: Master Walker follows priority order correctly (domain metadata → capability → pattern → heuristic). Edge cases handled gracefully with diagnostic errors.

## Context & Constraints

- **Prerequisites**: WP04 (handover detection)
- **Related Documents**:
  - `kitty-specs/004-composite-walker-handovers/spec.md` - User Story 2, FR-004 to FR-007
  - `kitty-specs/004-composite-walker-handovers/plan.md` - Handover detection priority order
  - `kitty-specs/004-composite-walker-handovers/research.md` - RQ4: Handover detection priority implementation
  - `kitty-specs/004-composite-walker-handovers/data-model.md` - Handover Detection Process entity

- **Architecture Decisions**:
  - Priority order: domain metadata → capability → pattern → heuristic
  - AST pattern suitability is optional optimization (not required for correctness)
  - Heuristic probing is last resort (optional, can be skipped for MVP)
  - Edge cases handled with diagnostic errors

## Subtasks & Detailed Guidance

### Subtask T047 – Implement AST pattern suitability check

- **Purpose**: Recognize AST patterns, delegate if pattern matches (optional optimization)
- **Steps**:
  1. Implement `method check-ast-pattern(RakuAST::Node $subtree --> Walker?)`
  2. Recognize common AST patterns (e.g., SQL SELECT, JSON path expressions)
  3. Match patterns to walker capabilities
  4. Return walker if pattern matches, Nil otherwise
  5. This is optional optimization - can be skipped for MVP
- **Files**: `lib/Qwiratry/MasterWalker.rakumod`
- **Parallel?**: No
- **Notes**: AST pattern recognition is optional. Can be enhanced later based on usage patterns.

### Subtask T048 – Implement heuristic probing

- **Purpose**: Use heuristics to select walker (optional, last resort)
- **Steps**:
  1. Implement `method check-heuristic(RakuAST::Node $subtree --> Walker?)`
  2. Use heuristics (e.g., node type, structure, keywords) to guess walker
  3. Return walker if heuristic matches, Nil otherwise
  4. This is last resort - only used if all other checks fail
- **Files**: `lib/Qwiratry/MasterWalker.rakumod`
- **Parallel?**: No (depends on T047)
- **Notes**: Heuristic probing is optional. Can be skipped for MVP if not needed.

### Subtask T049 – Ensure priority order

- **Purpose**: Ensure strict priority order: domain metadata → capability → pattern → heuristic
- **Steps**:
  1. Update `detect-handover()` method to follow full priority order
  2. Try domain metadata first (fast path)
  3. If domain metadata fails, try capability checks
  4. If capability checks fail, try AST pattern (if implemented)
  5. If AST pattern fails, try heuristic (if implemented)
  6. Return Nil if all checks fail
- **Files**: `lib/Qwiratry/MasterWalker.rakumod`
- **Parallel?**: No (depends on T047, T048)
- **Notes**: Priority order must be strict - don't skip steps.

### Subtask T050 – Handle edge case: no walker found

- **Purpose**: Fail with diagnostic error when no walker supports required subtree
- **Steps**:
  1. After all priority checks fail, throw exception
  2. Exception should include: which subtree was checked, which walkers were tried, why each failed
  3. Exception type: X::Qwiratry::UnknownQueryElement or similar
  4. Diagnostic message should help user understand why handover failed
- **Files**: `lib/Qwiratry/MasterWalker.rakumod`
- **Parallel?**: No (depends on T049)
- **Notes**: Early failure with clear diagnostics prevents wasted effort.

### Subtask T051 – Handle edge case: multiple walkers

- **Purpose**: Select walker when multiple walkers support subtree
- **Steps**:
  1. When multiple walkers return True for `supports()` or match pattern
  2. Select first walker found (or based on priority/specificity if implemented)
  3. Log warning if multiple walkers match (optional, for debugging)
  4. Return selected walker
- **Files**: `lib/Qwiratry/MasterWalker.rakumod`
- **Parallel?**: No (depends on T049)
- **Notes**: For MVP, select first. Priority/specificity can be enhanced later.

### Subtask T052 – Handle edge case: walker declines

- **Purpose**: Handle case where walker accepts via `supports()` but declines during planning
- **Steps**:
  1. When walker's `plan()` method throws exception after accepting via `supports()`
  2. Catch exception and try next walker in priority order
  3. If all walkers decline, throw diagnostic error
  4. Error should explain that walkers accepted but declined during planning
- **Files**: `lib/Qwiratry/MasterWalker.rakumod`
- **Parallel?**: No (depends on T049)
- **Notes**: Walker may accept via `supports()` but fail during planning. Handle gracefully.

### Subtask T053 – Integration tests: priority order

- **Purpose**: Verify priority order is followed correctly
- **Steps**:
  1. Create test scenarios where multiple detection methods could match
  2. Verify domain metadata is checked first
  3. Verify capability checks are used if domain metadata fails
  4. Verify AST pattern is used if capability checks fail (if implemented)
  5. Verify heuristic is used if AST pattern fails (if implemented)
- **Files**: `tests/integration/composite-handover.rakutest`
- **Parallel?**: Yes (can be written once T049-T052 are complete)
- **Notes**: Test that priority order is strictly followed.

### Subtask T054 – Integration tests: edge cases

- **Purpose**: Verify edge cases handled correctly
- **Steps**:
  1. Test no walker found: verify diagnostic error is thrown
  2. Test multiple walkers: verify first one is selected (or priority logic)
  3. Test walker declines: verify next walker is tried, or error is thrown
  4. Verify all edge cases produce clear diagnostic messages
- **Files**: `tests/integration/composite-handover.rakutest`
- **Parallel?**: Yes
- **Notes**: Test all edge cases produce helpful diagnostics.

## Test Strategy

- All tests in `tests/integration/composite-handover.rakutest`
- Use Raku Test module
- Create test scenarios for priority order and edge cases
- Test that priority order is strictly followed and edge cases are handled gracefully

## Risks & Mitigations

- **AST pattern recognition complexity**: Make optional, can be enhanced later based on usage patterns
- **Heuristic accuracy**: Make last resort, can be improved based on usage patterns
- **Multiple walkers ambiguity**: For MVP, select first. Priority/specificity can be enhanced later

## Definition of Done Checklist

- [ ] AST pattern suitability check implemented (optional)
- [ ] Heuristic probing implemented (optional, last resort)
- [ ] Priority order strictly followed (domain metadata → capability → pattern → heuristic)
- [ ] Edge case: no walker found handled with diagnostic error
- [ ] Edge case: multiple walkers handled (select first or priority)
- [ ] Edge case: walker declines handled gracefully
- [ ] All integration tests pass
- [ ] Documentation (Rakudoc) added to methods
- [ ] `tasks.md` updated with status change

## Review Guidance

- Verify priority order is strictly followed
- Verify edge cases are handled gracefully with diagnostic errors
- Verify AST pattern and heuristic are optional (can be skipped for MVP)
- Check code follows Raku style guidelines

## Activity Log

- 2025-01-27T00:00:00Z – system – lane=planned – Prompt created.

