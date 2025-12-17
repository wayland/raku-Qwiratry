---
work_package_id: "WP05"
subtasks:
  - "T020"
  - "T021"
  - "T022"
  - "T023"
  - "T024"
  - "T025"
  - "T026"
  - "T027"
title: "Coverage Verification Script"
phase: "Phase 3 - Enhancement"
lane: "doing"
assignee: "claude"
agent: "claude"
shell_pid: "19978"
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2025-12-16T22:24:05Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
  - timestamp: "2025-12-17T17:00:00Z"
    lane: "doing"
    agent: "claude"
    shell_pid: "19978"
    action: "Started implementation"
---

# Work Package Prompt: WP05 – Coverage Verification Script

## Objectives & Success Criteria

- Script runs in under 5 seconds (SC-002)
- Correctly identifies covered/uncovered sections including subsections
- Reports broken links when feature directories don't exist
- Outputs valid JSON when --json flag used
- Outputs human-readable text by default

## Context & Constraints

- **CLI interface**: `raku scripts/verify-spec-coverage.raku [--json] [--verbose] [--generate-map]`
- **Performance target**: <5 seconds execution
- **Output formats**: Text (default) and JSON (--json flag)
- **Reference**: See `contracts/coverage-script-api.md` for API contract, `spec.md` User Story 3

## Subtasks & Detailed Guidance

### Subtask T020 – Implement coverage calculation algorithm
- **Purpose**: Check if each section is covered by at least one feature's spec_sections array.
- **Steps**: For each section, check if identifier or any parent is in feature's spec_sections, mark as covered if found.
- **Files**: Core algorithm in script.
- **Parallel?**: No (foundational).

### Subtask T021 – Implement subsection coverage inheritance
- **Purpose**: Ensure 3.2.1.1 is covered if 3.2.1 is covered (inheritance).
- **Steps**: When checking coverage, also check all parent sections, mark covered if any parent covered.
- **Files**: Same as T020.
- **Parallel?**: Yes (after T020).

### Subtask T022 – Implement broken link detection
- **Purpose**: Verify all feature directories referenced in mappings actually exist.
- **Steps**: Check each feature directory exists, report missing directories as broken links.
- **Files**: Same as T020.
- **Parallel?**: Yes.

### Subtask T023 – Implement CLI argument parsing
- **Purpose**: Handle --json, --verbose, --generate-map, --help flags.
- **Steps**: Use Raku MAIN sub, parse arguments, set flags, show help text.
- **Files**: Script main entry point.
- **Parallel?**: Yes.

### Subtask T024 – Implement text output formatter
- **Purpose**: Generate human-readable coverage report.
- **Steps**: Format coverage percentage, list uncovered sections, broken links, dependency status.
- **Files**: Output formatting module/function.
- **Parallel?**: Yes.

### Subtask T025 – Implement JSON output formatter
- **Purpose**: Generate structured JSON output for CI/CD integration.
- **Steps**: Create JSON object matching contract schema, output to stdout.
- **Files**: Same as T024.
- **Parallel?**: Yes.

### Subtask T026 – Add logging
- **Purpose**: Log script execution steps and errors.
- **Steps**: INFO level for steps, ERROR for failures, WARN for uncovered sections, respect --verbose flag.
- **Files**: Logging module/function.
- **Parallel?**: Yes.

### Subtask T027 – Add file path validation
- **Purpose**: Prevent directory traversal attacks.
- **Steps**: Validate all file paths, reject paths with `..` components, validate against repo root.
- **Files**: Path validation function.
- **Parallel?**: Yes.

## Test Strategy

- Unit tests for coverage calculation, inheritance, link detection
- Integration test for full script execution with various flags
- Contract tests verify JSON output matches schema

## Risks & Mitigations

- **Performance**: Cache parsed data, optimize algorithms, single-pass processing
- **Invalid JSON**: Validate structure before output, test with jq

## Definition of Done Checklist

- [ ] Coverage calculation works correctly
- [ ] Subsection inheritance implemented
- [ ] Broken links detected
- [ ] CLI arguments parsed correctly
- [ ] Text output formatted properly
- [ ] JSON output matches contract
- [ ] Logging works with --verbose
- [ ] Path validation prevents traversal
- [ ] Script runs in <5 seconds
- [ ] `tasks.md` updated

## Review Guidance

- Test with actual Specification.md and features
- Verify JSON output with jq
- Check performance meets <5 second target
- Test all CLI flags and combinations

## Activity Log

- 2025-12-16T22:24:05Z – system – lane=planned – Prompt created.
- 2025-12-17T17:00:00Z – claude – shell_pid=19978 – lane=doing – Started implementation
- 2025-12-17T17:30:00Z – claude – shell_pid=19978 – lane=doing – Completed implementation: All subtasks (T020-T027) implemented. Coverage calculation, broken link detection, text/JSON output formatters, logging, and path validation complete.
