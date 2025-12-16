---
work_package_id: "WP01"
subtasks:
  - "T001"
  - "T002"
  - "T003"
  - "T004"
title: "Setup & Project Structure"
phase: "Phase 0 - Setup"
lane: "done"
assignee: ""
agent: "cursor-reviewer"
shell_pid: "299324"
review_status: "approved with minor fix"
reviewed_by: "cursor-reviewer"
history:
  - timestamp: "2025-12-16T22:24:05Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
  - timestamp: "2025-12-17T09:30:00Z"
    lane: "doing"
    agent: "cursor"
    shell_pid: "299324"
    action: "Started implementation"
  - timestamp: "2025-12-17T09:37:00Z"
    lane: "for_review"
    agent: "cursor"
    shell_pid: "299324"
    action: "Ready for review"
  - timestamp: "2025-12-17T09:45:00Z"
    lane: "done"
    agent: "cursor-reviewer"
    shell_pid: "299324"
    action: "Approved with minor fix: Fixed immutable variable assignment bug"
---

## Review Feedback

**Status**: ✅ **Approved with Minor Fix**

**Key Issues**:
1. **Script bug fixed**: The script attempted to assign to immutable variables (`my Bool $json-output`, etc.). Fixed by removing module-level variables and using MAIN sub parameters directly. This was a minor Raku syntax issue.

**What Was Done Well**:
- All directory structure created correctly (`scripts/`, `tests/unit/`, `tests/integration/`, `docs/`)
- All 6 test files created with proper Test module imports and valid Raku syntax
- Script stub has correct shebang, executable permissions, and comprehensive CLI argument parsing
- Help text is clear and matches API contract
- Test runner documentation is complete and helpful
- All test files execute successfully
- Script runs correctly after bug fix

**Action Items** (completed during review):
- [x] Fixed immutable variable assignment bug in script
- [x] Verified all CLI flags work correctly (`--help`, `--verbose`, `--json`, `--generate-map`)
- [x] Verified all test files execute successfully

---

# Work Package Prompt: WP01 – Setup & Project Structure

## Objectives & Success Criteria

- Project directory structure created (`scripts/`, `tests/unit/`, `tests/integration/`, `docs/`)
- Basic Raku test framework configured with Test module
- Script stub created with executable permissions and basic CLI argument parsing
- Test runner documented and ready for use
- All directories and files are in correct locations relative to repository root

## Context & Constraints

- **Repository root**: `/home/wayland/src/raku/Tims/DataOrientedProgramming/raku-Qwiratry`
- **Script location**: `scripts/verify-spec-coverage.raku` (repo root)
- **Test location**: `tests/unit/` and `tests/integration/` (repo root)
- **Documentation**: `docs/` directory (may already exist)
- **Language**: Raku 6.e, standard library only (no external dependencies)
- **Reference**: See `kitty-specs/001-specification-traceability-map/plan.md` for project structure

## Subtasks & Detailed Guidance

### Subtask T001 – Create project directory structure

- **Purpose**: Establish the directory layout for scripts, tests, and generated documentation.
- **Steps**:
  1. Navigate to repository root
  2. Create `scripts/` directory if it doesn't exist
  3. Create `tests/` directory if it doesn't exist
  4. Create `tests/unit/` subdirectory
  5. Create `tests/integration/` subdirectory
  6. Ensure `docs/` directory exists (create if missing)
- **Files**: 
  - Create directories: `scripts/`, `tests/unit/`, `tests/integration/`, `docs/`
- **Parallel?**: No (foundational structure)
- **Notes**: Check if directories already exist to avoid errors. Use absolute paths or paths relative to repo root.

### Subtask T002 – Create basic Raku test files

- **Purpose**: Set up test framework with placeholder test files for each test category.
- **Steps**:
  1. Create `tests/unit/spec-parser.t` with Test module import and basic test structure
  2. Create `tests/unit/feature-metadata.t` with Test module import
  3. Create `tests/unit/dependency-graph.t` with Test module import
  4. Create `tests/unit/coverage-calc.t` with Test module import
  5. Create `tests/integration/traceability-map-gen.t` with Test module import
  6. Create `tests/integration/coverage-script.t` with Test module import
  7. Each test file should have: `use Test; plan 1;` as placeholder
- **Files**:
  - `tests/unit/spec-parser.t`
  - `tests/unit/feature-metadata.t`
  - `tests/unit/dependency-graph.t`
  - `tests/unit/coverage-calc.t`
  - `tests/integration/traceability-map-gen.t`
  - `tests/integration/coverage-script.t`
- **Parallel?**: Yes (different files)
- **Notes**: Use Raku's built-in `Test` module. Each file should be a valid Raku test file that can be run with `raku -I. tests/unit/spec-parser.t`.

### Subtask T003 – Create script stub with CLI parsing

- **Purpose**: Create the main coverage verification script with basic structure and CLI argument handling.
- **Steps**:
  1. Create `scripts/verify-spec-coverage.raku`
  2. Add shebang: `#!/usr/bin/env raku`
  3. Add basic CLI argument parsing for: `--json`, `--verbose`, `--generate-map`, `--help`
  4. Add placeholder for main script logic (can be empty function for now)
  5. Set executable permissions: `chmod +x scripts/verify-spec-coverage.raku`
  6. Add basic help text when `--help` is used
- **Files**:
  - `scripts/verify-spec-coverage.raku`
- **Parallel?**: No (single file)
- **Notes**: Use Raku's `MAIN` sub for CLI argument parsing. See `contracts/coverage-script-api.md` for expected CLI interface. Script should exit with code 0 on success, 1 on error, 2 on invalid arguments.

### Subtask T004 – Configure test runner

- **Purpose**: Document how to run tests and ensure test framework is properly configured.
- **Steps**:
  1. Verify test files can be executed: `raku -I. tests/unit/spec-parser.t`
  2. Document test execution commands in README or test directory
  3. Consider creating a test runner script or documenting `prove6` usage if available
- **Files**:
  - Update `README.md` or create `tests/README.md` with test execution instructions
- **Parallel?**: Yes (documentation)
- **Notes**: Raku tests can be run directly with `raku` or using `prove6` if installed. Document the preferred method.

## Test Strategy

- **Not applicable for setup phase** - This work package establishes the testing infrastructure; actual tests come in WP07.

## Risks & Mitigations

- **Directory conflicts**: Check if directories exist before creating to avoid errors
  - *Mitigation*: Use conditional creation or check existence first
- **Permission issues**: Script must be executable
  - *Mitigation*: Use `chmod +x` and document in README
- **Path resolution**: Ensure paths work from repository root
  - *Mitigation*: Use absolute paths or paths relative to script location, test from repo root

## Definition of Done Checklist

- [ ] All directories created (`scripts/`, `tests/unit/`, `tests/integration/`, `docs/`)
- [ ] All test files created with Test module imports
- [ ] Script stub created with executable permissions
- [ ] CLI argument parsing works for all options (`--json`, `--verbose`, `--generate-map`, `--help`)
- [ ] Test execution documented
- [ ] Script can be run from repository root: `raku scripts/verify-spec-coverage.raku --help`
- [ ] `tasks.md` updated with status change

## Review Guidance

- Verify directory structure matches plan.md
- Check script has executable permissions
- Test CLI argument parsing with various combinations
- Ensure test files are valid Raku syntax
- Verify paths work from repository root

## Activity Log

- 2025-12-16T22:24:05Z – system – lane=planned – Prompt created.
- 2025-12-17T09:30:00Z – cursor – shell_pid=299324 – lane=doing – Started implementation
- 2025-12-17T09:37:00Z – cursor – shell_pid=299324 – lane=doing – Completed WP01: Created directory structure (scripts/, tests/unit/, tests/integration/, docs/), created all test files with Test module, created script stub with CLI parsing, documented test runner
- 2025-12-17T09:37:00Z – cursor – shell_pid=299324 – lane=for_review – Ready for review

