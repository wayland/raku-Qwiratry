---
work_package_id: "WP07"
subtasks:
  - "T033"
  - "T034"
  - "T035"
  - "T036"
  - "T037"
  - "T038"
  - "T039"
  - "T040"
title: "Testing & Validation"
phase: "Phase 5 - Quality"
lane: "for_review"
assignee: "claude"
agent: "claude"
shell_pid: "25639"
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2025-12-16T22:24:05Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
  - timestamp: "2025-12-17T18:30:00Z"
    lane: "doing"
    agent: "claude"
    shell_pid: "25639"
    action: "Started implementation"
---

# Work Package Prompt: WP07 – Testing & Validation

## Objectives & Success Criteria

- All unit tests pass
- Integration tests verify end-to-end workflows
- Contract tests validate JSON output format
- Edge cases handled correctly

## Context & Constraints

- **Test framework**: Raku Test module (built-in)
- **Test locations**: `tests/unit/` and `tests/integration/`
- **Reference**: See `plan.md` Constitution Check for test requirements

## Subtasks & Detailed Guidance

### Subtask T033 – Write unit tests for spec parsing
- **Purpose**: Test Specification.md parsing logic.
- **Steps**: Create `tests/unit/spec-parser.t`, test section extraction, hierarchy building.
- **Files**: `tests/unit/spec-parser.t`.
- **Parallel?**: Yes (all tests can be written in parallel).

### Subtask T034 – Write unit tests for feature metadata reading
- **Purpose**: Test meta.json reading and parsing.
- **Steps**: Create `tests/unit/feature-metadata.t`, test JSON parsing, optional fields, error handling.
- **Files**: `tests/unit/feature-metadata.t`.
- **Parallel?**: Yes.

### Subtask T035 – Write unit tests for dependency graph
- **Purpose**: Test dependency graph generation and cycle detection.
- **Steps**: Create `tests/unit/dependency-graph.t`, test graph building, cycle detection, Mermaid generation.
- **Files**: `tests/unit/dependency-graph.t`.
- **Parallel?**: Yes.

### Subtask T036 – Write unit tests for coverage calculation
- **Purpose**: Test coverage calculation algorithm.
- **Steps**: Create `tests/unit/coverage-calc.t`, test coverage logic, subsection inheritance.
- **Files**: `tests/unit/coverage-calc.t`.
- **Parallel?**: Yes.

### Subtask T037 – Write integration test for traceability map generation
- **Purpose**: Test end-to-end map generation workflow.
- **Steps**: Create `tests/integration/traceability-map-gen.t`, test full generation process with real files.
- **Files**: `tests/integration/traceability-map-gen.t`.
- **Parallel?**: Yes.

### Subtask T038 – Write integration test for coverage script
- **Purpose**: Test full script execution with various flags.
- **Steps**: Create `tests/integration/coverage-script.t`, test script runs, outputs correct format.
- **Files**: `tests/integration/coverage-script.t`.
- **Parallel?**: Yes.

### Subtask T039 – Write contract tests for JSON output
- **Purpose**: Validate JSON output matches API contract schema.
- **Steps**: Test JSON structure matches `contracts/coverage-script-api.md` schema.
- **Files**: Same as T038 or separate contract test file.
- **Parallel?**: Yes.

### Subtask T040 – Test edge cases
- **Purpose**: Verify handling of missing files, malformed JSON, circular deps, broken links.
- **Steps**: Create test cases for each edge case, verify graceful handling.
- **Files**: Add to relevant test files or create edge-case-specific tests.
- **Parallel?**: Yes.

## Test Strategy

- Unit tests: Test individual functions/modules in isolation
- Integration tests: Test end-to-end workflows with real files
- Contract tests: Validate JSON output matches schema
- Edge cases: Missing files, invalid JSON, circular deps, broken links

## Risks & Mitigations

- **Test maintenance**: Keep tests updated as implementation evolves
- **Test data**: Use fixtures or generate programmatically

## Definition of Done Checklist

- [ ] All unit tests pass
- [ ] Integration tests pass
- [ ] Contract tests validate JSON
- [ ] Edge cases tested
- [ ] Test coverage adequate
- [ ] `tasks.md` updated

## Review Guidance

- Verify all tests pass
- Check test coverage is adequate
- Ensure edge cases are covered

## Activity Log

- 2025-12-16T22:24:05Z – system – lane=planned – Prompt created.
- 2025-12-17T18:30:00Z – claude – shell_pid=25639 – lane=doing – Started implementation
- 2025-12-17T19:00:00Z – claude – shell_pid=25639 – lane=doing – Completed implementation: All test files created (T033-T040). Unit tests, integration tests, contract tests, and edge case tests implemented.
