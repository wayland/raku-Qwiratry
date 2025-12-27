---
work_package_id: WP04
title: Handover Detection - Domain Metadata & Capability Checks
lane: done
history:
- timestamp: '2025-01-27T00:00:00Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
agent: claude-reviewer
assignee: claude-reviewer
phase: Phase 2 - Core
review_status: approved without changes
reviewed_by: claude-reviewer
shell_pid: '37215'
subtasks:
- T018
- T019
- T020
- T021
- T022
- T023
- T024
- T025
- T026
- T027
---

# Work Package Prompt: WP04 – Handover Detection - Domain Metadata & Capability Checks

## Review Feedback

**Status**: ✅ **Approved Without Changes**

**Key Findings**:
- `check-domain-metadata()` method correctly implemented using `provides-domains()` from Qwiratry::Provides
- Domain metadata fast path implemented via `find-walker-by-domain()` method with heuristic matching (supports `supports-domain()` method or name-based matching)
- Early failure correctly implemented: throws `X::Qwiratry::UnknownQueryElement` with diagnostic message when domains declared but no suitable walker found
- `check-capability()` method correctly implemented: calls `walker.supports($subtree)` with proper error handling
- Capability check fallback correctly implemented in `detect-handover()` method
- `detect-handover()` method properly combines both checks following strict priority order: domain metadata → capability checks → AST pattern (placeholder) → heuristic (placeholder)
- Comprehensive unit tests cover all requirements: domain metadata check, early failure, capability check, and capability delegation
- Excellent Rakudoc documentation for all methods
- Code follows Raku style guidelines

**What Was Done Well**:
- Clean implementation of priority-ordered handover detection
- Proper early failure with diagnostic error messages (includes domain names and available walkers)
- Smart heuristic for domain matching (checks `supports-domain()` method first, falls back to name matching)
- Well-structured tests with mock walkers
- Proper error handling in capability checks (handles walkers without `supports()` method)
- Future-proof design: placeholders for AST pattern and heuristic checks (WP07)

**Action Items**: None - implementation is complete and correct.

**Note**: The implementation correctly follows the priority order and includes placeholders for future enhancements (AST pattern and heuristic checks) that will be implemented in WP07.

---

## Objectives & Success Criteria

- Implement handover detection using domain metadata (fast path) and capability checks (fallback)
- Master Walker can detect when handover is needed via domain metadata or capability checks
- Master Walker delegates planning to appropriate domain-specific walker
- Early failure when domain metadata declares domains but no suitable walker exists

**Success**: Master Walker detects handover requirements via domain metadata or capability checks, delegates planning to appropriate walker. Fails early with diagnostic error when no suitable walker found.

## Context & Constraints

- **Prerequisites**: WP02 (provides trait), WP03 (Master Walker structure)
- **Related Documents**:
  - `kitty-specs/004-composite-walker-handovers/spec.md` - User Story 2, FR-004 to FR-007
  - `kitty-specs/004-composite-walker-handovers/plan.md` - Handover detection priority order
  - `kitty-specs/004-composite-walker-handovers/research.md` - RQ4: Handover detection priority implementation
  - `kitty-specs/004-composite-walker-handovers/data-model.md` - Handover Detection Process entity

- **Architecture Decisions**:
  - Priority order: domain metadata (fast path) → capability checks (fallback)
  - Domain metadata check uses `provides-domains()` from WP02
  - Capability check queries walkers via `supports($subtree)`
  - Early failure with diagnostic error when domain metadata declares domains but no walker exists

## Subtasks & Detailed Guidance

### Subtask T018 – Implement check-domain-metadata() method

- **Purpose**: Check `provides` trait on root object, return domain names or Nil
- **Steps**:
  1. Implement `method check-domain-metadata(Mu $root --> Array[Str]?)`
  2. Use `provides-domains($root)` from Qwiratry::Provides
  3. Return Array[Str] of domain names if metadata exists, Nil otherwise
- **Files**: `lib/Qwiratry/MasterWalker.rakumod`
- **Parallel?**: No
- **Notes**: Uses provides trait implementation from WP02.

### Subtask T019 – Implement domain metadata fast path

- **Purpose**: If domains declared, find walker supporting at least one domain
- **Steps**:
  1. In handover detection, call `check-domain-metadata($root)`
  2. If domains returned, iterate through candidate walkers
  3. For each walker, check if it supports any of the declared domains
  4. Return first walker that supports at least one domain, or Nil
- **Files**: `lib/Qwiratry/MasterWalker.rakumod`
- **Parallel?**: No (depends on T018)
- **Notes**: Fast path - use domain metadata before falling back to capability checks.

### Subtask T020 – Implement early failure for missing walkers

- **Purpose**: Fail with diagnostic error when domain metadata declares domains but no suitable walker exists
- **Steps**:
  1. After domain metadata check, if domains declared but no walker found
  2. Throw exception with diagnostic message: which domains were declared, which walkers were checked
  3. Exception should be X::Qwiratry::UnknownQueryElement or similar
- **Files**: `lib/Qwiratry/MasterWalker.rakumod`
- **Parallel?**: No (depends on T019)
- **Notes**: Early failure prevents wasted planning effort.

### Subtask T021 – Implement check-capability() method

- **Purpose**: Query walker about capability via `supports()` method
- **Steps**:
  1. Implement `method check-capability(RakuAST::Node $subtree, Walker $walker --> Bool)`
  2. Call `$walker.supports($subtree)`
  3. Return boolean result
- **Files**: `lib/Qwiratry/MasterWalker.rakumod`
- **Parallel?**: No
- **Notes**: Uses Walker.supports() method from feature 002.

### Subtask T022 – Implement capability check fallback

- **Purpose**: Query candidate walkers via `supports($subtree)`, delegate to first returning True
- **Steps**:
  1. If domain metadata check returns Nil (no metadata), proceed to capability checks
  2. Iterate through candidate walkers
  3. For each walker, call `check-capability($subtree, $walker)`
  4. Return first walker that returns True, or Nil if all return False
- **Files**: `lib/Qwiratry/MasterWalker.rakumod`
- **Parallel?**: No (depends on T021)
- **Notes**: Fallback mechanism when domain metadata is absent.

### Subtask T023 – Implement detect-handover() method

- **Purpose**: Combine domain metadata and capability checks following priority order
- **Steps**:
  1. Implement `method detect-handover(RakuAST::Node $subtree, Mu $root --> Walker?)`
  2. First, try domain metadata check (fast path)
  3. If domain metadata check fails or returns Nil, try capability checks
  4. Return Walker if found, Nil if not found
  5. Follow priority order strictly: domain metadata → capability
- **Files**: `lib/Qwiratry/MasterWalker.rakumod`
- **Parallel?**: No (depends on T018-T022)
- **Notes**: This is the main handover detection method that orchestrates the priority order.

### Subtask T024 – Unit tests: domain metadata check

- **Purpose**: Verify domain metadata check finds suitable walker
- **Steps**:
  1. Create root object with `provides<sql>` trait
  2. Create mock SQL walker
  3. Create MasterWalker with SQL walker in candidate list
  4. Call `detect-handover()` with query subtree
  5. Verify SQL walker is selected
- **Files**: `tests/unit/master-walker.rakutest`
- **Parallel?**: Yes (can be written once T018-T023 are complete)
- **Notes**: Test fast path works correctly.

### Subtask T025 – Unit tests: early failure

- **Purpose**: Verify early failure when domain metadata declares domains but no suitable walker exists
- **Steps**:
  1. Create root object with `provides<sql>` trait
  2. Create MasterWalker with no SQL-capable walkers
  3. Call `detect-handover()` or `plan()`
  4. Verify exception is thrown with diagnostic message
- **Files**: `tests/unit/master-walker.rakutest`
- **Parallel?**: Yes
- **Notes**: Test early failure mechanism.

### Subtask T026 – Unit tests: capability check

- **Purpose**: Verify capability check queries walkers via `supports()`
- **Steps**:
  1. Create root object without `provides` trait
  2. Create mock walkers with `supports()` methods
  3. Create MasterWalker with mock walkers
  4. Call `detect-handover()` with query subtree
  5. Verify `supports()` is called on walkers
  6. Verify walker returning True is selected
- **Files**: `tests/unit/master-walker.rakutest`
- **Parallel?**: Yes
- **Notes**: Test fallback mechanism works.

### Subtask T027 – Unit tests: capability delegation

- **Purpose**: Verify capability check delegates to first walker returning True
- **Steps**:
  1. Create multiple walkers that all return True for `supports()`
  2. Call `detect-handover()`
  3. Verify first walker in list is selected (or verify selection logic)
- **Files**: `tests/unit/master-walker.rakutest`
- **Parallel?**: Yes
- **Notes**: Test selection logic when multiple walkers support subtree.

## Test Strategy

- All tests in `tests/unit/master-walker.rakutest`
- Use Raku Test module
- Create mock walkers and root objects for testing
- Test domain metadata fast path, capability fallback, and early failure

## Risks & Mitigations

- **Multiple walkers support same subtree**: Select first one found (can be enhanced later with priority)
- **Walker `supports()` returns True but cannot execute**: Walker will throw exception during planning (acceptable behavior)
- **Domain metadata conflicts with capability checks**: Domain metadata is advisory, capability checks take precedence

## Definition of Done Checklist

- [ ] `check-domain-metadata()` implemented
- [ ] Domain metadata fast path implemented
- [ ] Early failure implemented with diagnostic errors
- [ ] `check-capability()` implemented
- [ ] Capability check fallback implemented
- [ ] `detect-handover()` method combines both checks following priority order
- [ ] All unit tests pass
- [ ] Documentation (Rakudoc) added to methods
- [ ] `tasks.md` updated with status change

## Review Guidance

- Verify handover detection follows priority order (domain metadata → capability)
- Verify early failure provides clear diagnostic messages
- Verify capability checks query walkers correctly
- Check code follows Raku style guidelines

## Activity Log

- 2025-01-27T00:00:00Z – system – lane=planned – Prompt created.
- 2025-12-19T09:18:01Z – claude – shell_pid=20070 – lane=doing – Started implementation
- 2025-12-19T09:30:00Z – claude – shell_pid=20070 – lane=doing – Completed implementation:
  - Implemented check-domain-metadata() method using provides-domains()
  - Implemented domain metadata fast path with find-walker-by-domain() using heuristic matching
  - Implemented early failure with X::Qwiratry::UnknownQueryElement when domains declared but no walker found
  - Implemented check-capability() method that calls walker.supports()
  - Implemented capability check fallback in detect-handover()
  - Implemented detect-handover() method combining domain metadata and capability checks with priority order
  - Updated plan() method to use detect-handover() for delegation
  - Created comprehensive unit tests for all handover detection methods
  - All code compiles successfully
- 2025-12-19T09:27:44Z – claude – shell_pid=21260 – lane=for_review – Ready for review - implementation complete
- 2025-12-19T11:40:00Z – claude-reviewer – shell_pid=37215 – lane=done – Review approved: All requirements met, implementation complete and correct
