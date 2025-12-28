---
work_package_id: WP04
title: Template Ordering Algorithm
lane: for_review
history:
- timestamp: '2025-01-27T23:45:00Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
- timestamp: '2025-01-28T07:15:00Z'
  lane: doing
  agent: claude
  shell_pid: '24046'
  action: Started implementation
- timestamp: '2025-01-28T07:45:00Z'
  lane: for_review
  agent: claude
  shell_pid: '24046'
  action: 'WP04 implementation complete: All subtasks (T014-T020) implemented. ORDER-TEMPLATES method with priority → specificity → tie-breaker sorting, conflict detection, caching. All unit tests passing (6/6).'
agent: claude
assignee: claude
phase: Phase 1 - Foundational
review_status: ''
reviewed_by: ''
shell_pid: '24046'
subtasks:
- T014
- T015
- T016
- T017
- T018
- T019
- T020
---
*Path: [templates/task-prompt-template.md](templates/task-prompt-template.md)*

# Work Package Prompt: WP04 – Template Ordering Algorithm

## Objectives & Success Criteria

- Implement `ORDER-TEMPLATES` method that sorts templates by priority → specificity → tie-breaker
- Calculate template specificity from `when` clause AST
- Detect and report template ordering conflicts
- Populate `@.ordered-templates` array with sorted templates
- Ordering must be deterministic

## Context & Constraints

- **Prerequisites**: WP03 (template collection)
- **Related Documents**: 
  - `plan.md` - Architecture decision #3 (hybrid compile-time/runtime approach)
  - `research.md` - RQ4 (template ordering specificity calculation)
  - `spec.md` - FR-003, FR-004, FR-005 (ordering requirements)
- **Architecture**: Hybrid approach - calculate static aspects at compile time, defer complex cases to runtime
- **Constraints**: Ordering must be deterministic, conflicts must be reported clearly

## Subtasks & Detailed Guidance

### Subtask T014 – Priority sorting

- **Purpose**: Sort templates by priority (highest first)
- **Steps**:
  1. Extract `:priority` trait from each template (default 0 if not specified)
  2. Sort templates by priority in descending order (highest first)
  3. Store priority value in template's `$.priority` attribute
- **Files**: `lib/Qwiratry/Transformer.rakumod`
- **Parallel?**: No
- **Notes**: Priority is explicit trait, easy to extract and sort.

### Subtask T015 – Basic specificity calculation

- **Purpose**: Analyze `when` clause AST for static patterns
- **Steps**:
  1. For each template, analyze its `when` block AST
  2. Identify static patterns: axis operators, wildcards, path elements, attribute axes
  3. Calculate specificity score based on patterns found
  4. Store specificity in template's `$.specificity` attribute (may be Nil if calculation deferred)
- **Files**: `lib/Qwiratry/Transformer.rakumod`
- **Parallel?**: No
- **Notes**: Start with basic cases. Complex queries may need runtime evaluation (defer to runtime if needed).

### Subtask T016 – Specificity scoring

- **Purpose**: Implement specificity scoring rules
- **Steps**:
  1. Implement scoring: multilevel axis (-100), wildcards (-10), explicit path elements (+5), attribute axes (+5)
  2. For Union queries, calculate each branch and take max
  3. Apply scoring to `when` clause AST
  4. Store calculated specificity score
- **Files**: `lib/Qwiratry/Transformer.rakumod`
- **Parallel?**: No (depends on T015)
- **Notes**: Scoring rules from spec. May need refinement based on actual query operator implementations.

### Subtask T017 – Tie-breaker resolution

- **Purpose**: Sort by tie-breaker when priority and specificity are equal
- **Steps**:
  1. Extract `:tie-breaker` trait from each template (default 0 if not specified)
  2. For templates with equal priority and specificity, sort by tie-breaker (highest first)
  3. Store tie-breaker value in template's `$.tie-breaker` attribute
- **Files**: `lib/Qwiratry/Transformer.rakumod`
- **Parallel?**: No (depends on T014, T016)
- **Notes**: Tie-breaker is explicit trait, used as final sort key.

### Subtask T018 – Conflict detection

- **Purpose**: Detect and report when two templates have equal values and could match same node
- **Steps**:
  1. After sorting, check for templates with equal priority, specificity, and tie-breaker
  2. Determine if templates could match the same node (conservative approach: if uncertain, report conflict)
  3. If conflict detected, throw `X::Qwiratry::TemplateOrderingConflict` exception
  4. Exception should include: template1, template2, priority, specificity, tie-breaker values
  5. Exception message should ask user to set explicit `:tie-breaker` value
- **Files**: `lib/Qwiratry/Transformer.rakumod`, `lib/Qwiratry/X.rakumod`
- **Parallel?**: No (depends on T017)
- **Notes**: Use conservative approach - if uncertain whether templates could match, report conflict.

### Subtask T019 – ORDER-TEMPLATES method

- **Purpose**: Implement method that performs ordering and populates `@.ordered-templates`
- **Steps**:
  1. Create `ORDER-TEMPLATES` method on Transformer class
  2. Method should: sort by priority → specificity → tie-breaker
  3. Populate `@.ordered-templates` array with sorted templates
  4. Cache result to avoid recalculation
  5. Call conflict detection if needed
- **Files**: `lib/Qwiratry/Transformer.rakumod`
- **Parallel?**: No (depends on T014-T018)
- **Notes**: This method is called by `TRANSFORM` before applying templates. Should cache result.

### Subtask T020 – Unit tests for ordering

- **Purpose**: Verify template ordering works correctly
- **Steps**:
  1. Test priority sorting: templates with different priorities are ordered correctly
  2. Test specificity calculation: templates with different specificity are ordered correctly
  3. Test tie-breaker: templates with equal priority/specificity use tie-breaker
  4. Test conflict detection: exception thrown when templates conflict
  5. Test deterministic ordering: same templates always produce same order
  6. Test caching: ordering result is cached
- **Files**: `tests/unit/template-ordering.rakutest`
- **Parallel?**: Yes
- **Notes**: Test all ordering scenarios, including edge cases and conflicts.

## Test Strategy

- **Unit tests**: Test priority, specificity, tie-breaker, conflict detection
- **Test location**: `tests/unit/template-ordering.rakutest`

## Risks & Mitigations

- **Specificity calculation complexity**: Start with basic cases, defer complex queries to runtime
- **Conflict detection accuracy**: Use conservative approach (report if uncertain)
- **Performance**: Cache ordering results to avoid recalculation

## Definition of Done Checklist

- [x] Priority sorting implemented and tested
- [x] Specificity calculation implemented (basic cases)
- [x] Tie-breaker resolution implemented
- [x] Conflict detection implemented with clear error messages
- [x] ORDER-TEMPLATES method populates @.ordered-templates
- [x] Ordering is deterministic
- [x] Unit tests pass
- [x] `tasks.md` updated with status change

## Activity Log

- 2025-01-27T23:45:00Z – system – lane=planned – Prompt created.
- 2025-01-28T07:15:00Z – claude – shell_pid=24046 – lane=doing – Started implementation: Implementing ORDER-TEMPLATES method with priority sorting, specificity calculation, tie-breaker resolution, and conflict detection.
- 2025-01-28T07:30:00Z – claude – shell_pid=24046 – lane=doing – Completed T014-T019: Implemented ORDER-TEMPLATES method with priority → specificity → tie-breaker sorting. Added @.ordered-templates attribute and caching. Implemented basic specificity calculation (placeholder for complex queries). Conflict detection throws X::Qwiratry::TemplateOrderingConflict. All core functionality complete.
- 2025-01-28T07:45:00Z – claude – shell_pid=24046 – lane=doing – Completed T020: Added comprehensive unit tests for template ordering. All tests passing (6/6 subtests). Tests cover priority sorting, specificity/tie-breaker sorting, conflict detection, deterministic ordering, caching, and empty templates. Ready for review.

