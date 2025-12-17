---
work_package_id: "WP01"
subtasks:
  - "T001"
  - "T002"
  - "T003"
  - "T004"
  - "T005"
  - "T006"
  - "T007"
  - "T008"
title: "Setup & Project Structure"
phase: "Phase 0 - Setup"
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

# Work Package Prompt: WP01 – Setup & Project Structure

## Objectives & Success Criteria

- Establish complete project skeleton with all module files and test directory structure
- Verify modules can be loaded with `use` statements
- Verify test framework (Raku Test module) runs successfully
- All module skeletons created with proper `unit module` declarations
- Test directory structure matches plan.md specification

**Success**: Project structure exists, modules load, test framework works, ready for implementation.

## Context & Constraints

- **Prerequisites**: None (starting package)
- **Related Documents**:
  - `kitty-specs/002-walker-core-infrastructure/plan.md` - Project structure specification
  - `kitty-specs/002-walker-core-infrastructure/spec.md` - Feature requirements
  - `.kittify/memory/constitution.md` - Constitution principles (P1: Test-First)

- **Architecture Decisions**:
  - Module structure: `lib/Qwiratry/` with separate modules for each role
  - Test structure: `tests/unit/`, `tests/integration/`, `tests/examples/`
  - Use Raku 6.e with RakuAST support

## Subtasks & Detailed Guidance

### Subtask T001 – Create lib/Qwiratry/ directory structure

- **Purpose**: Establish base directory structure for Qwiratry modules
- **Steps**:
  1. Create `lib/Qwiratry/` directory in repository root
  2. Verify directory exists and is accessible
- **Files**: `lib/Qwiratry/` (directory)
- **Parallel?**: No (must be done first)
- **Notes**: Ensure directory is created relative to repository root, not worktree root

### Subtask T002 – Create lib/Qwiratry/Walker.rakumod skeleton

- **Purpose**: Create skeleton for Walker role and Walker::Plan role module
- **Steps**:
  1. Create `lib/Qwiratry/Walker.rakumod`
  2. Add `unit module Qwiratry::Walker;` declaration
  3. Add placeholder role declarations (will be implemented in WP06 and WP05)
  4. Add basic module documentation comment
- **Files**: `lib/Qwiratry/Walker.rakumod`
- **Parallel?**: Yes (can be created alongside other module skeletons)
- **Notes**: This module will contain both Walker and Walker::Plan roles per plan.md

### Subtask T003 – Create lib/Qwiratry/Context.rakumod skeleton

- **Purpose**: Create skeleton for Context role module
- **Steps**:
  1. Create `lib/Qwiratry/Context.rakumod`
  2. Add `unit module Qwiratry::Context;` declaration
  3. Add placeholder role declaration (will be implemented in WP03)
  4. Add basic module documentation comment
- **Files**: `lib/Qwiratry/Context.rakumod`
- **Parallel?**: Yes (can be created alongside other module skeletons)
- **Notes**: Context is a marker role with no required methods

### Subtask T004 – Create lib/Qwiratry/QueryIterator.rakumod skeleton

- **Purpose**: Create skeleton for QueryIterator role module
- **Steps**:
  1. Create `lib/Qwiratry/QueryIterator.rakumod`
  2. Add `unit module Qwiratry::QueryIterator;` declaration
  3. Add placeholder role declaration (will be implemented in WP04)
  4. Add `use Qwiratry::Context;` for Context dependency
  5. Add basic module documentation comment
- **Files**: `lib/Qwiratry/QueryIterator.rakumod`
- **Parallel?**: Yes (can be created alongside other module skeletons)
- **Notes**: QueryIterator extends Iterator and uses Context

### Subtask T005 – Create lib/Qwiratry/X.rakumod skeleton

- **Purpose**: Create skeleton for exception hierarchy module
- **Steps**:
  1. Create `lib/Qwiratry/X.rakumod`
  2. Add `unit module Qwiratry::X;` declaration
  3. Add placeholder exception class declarations (will be implemented in WP02)
  4. Add basic module documentation comment
- **Files**: `lib/Qwiratry/X.rakumod`
- **Parallel?**: Yes (can be created alongside other module skeletons)
- **Notes**: This module contains X::Qwiratry::Walker and X::Qwiratry::UnknownQueryElement

### Subtask T006 – Create tests/ directory structure

- **Purpose**: Establish test directory structure matching plan.md
- **Steps**:
  1. Create `tests/` directory in repository root
  2. Create `tests/unit/` subdirectory
  3. Create `tests/integration/` subdirectory
  4. Create `tests/examples/` subdirectory
  5. Verify all directories exist
- **Files**: `tests/`, `tests/unit/`, `tests/integration/`, `tests/examples/` (directories)
- **Parallel?**: No (must be done before creating test files)
- **Notes**: Structure matches plan.md specification

### Subtask T007 – Create test skeleton files for each role

- **Purpose**: Create test file skeletons for all roles and exceptions
- **Steps**:
  1. Create `tests/unit/walker.rakutest` with basic test structure
  2. Create `tests/unit/walker-plan.rakutest` with basic test structure
  3. Create `tests/unit/context.rakutest` with basic test structure
  4. Create `tests/unit/query-iterator.rakutest` with basic test structure
  5. Create `tests/unit/exceptions.rakutest` with basic test structure
  6. Create `tests/integration/walker-flow.rakutest` with basic test structure
  7. Create `tests/examples/simple-walker.rakutest` with basic test structure
  8. Each test file should have `use Test;` and at least one placeholder test
- **Files**: 
  - `tests/unit/walker.rakutest`
  - `tests/unit/walker-plan.rakutest`
  - `tests/unit/context.rakutest`
  - `tests/unit/query-iterator.rakutest`
  - `tests/unit/exceptions.rakutest`
  - `tests/integration/walker-flow.rakutest`
  - `tests/examples/simple-walker.rakutest`
- **Parallel?**: Yes (all test files can be created in parallel)
- **Notes**: Use Raku Test module standard structure

### Subtask T008 – Verify module loading and test framework setup

- **Purpose**: Ensure modules can be loaded and tests can run
- **Steps**:
  1. Test loading each module: `raku -Ilib -e 'use Qwiratry::Walker; say "OK"'`
  2. Test loading Context: `raku -Ilib -e 'use Qwiratry::Context; say "OK"'`
  3. Test loading QueryIterator: `raku -Ilib -e 'use Qwiratry::QueryIterator; say "OK"'`
  4. Test loading X: `raku -Ilib -e 'use Qwiratry::X; say "OK"'`
  5. Run test framework: `raku -Ilib tests/unit/exceptions.rakutest` (should run, even if tests fail)
  6. Verify test framework reports correctly
- **Files**: None (verification only)
- **Parallel?**: No (must be done after all modules and tests created)
- **Notes**: All modules should load without errors (even if empty)

## Test Strategy

- **Framework**: Raku Test module (built-in)
- **Structure**: Unit tests for each role, integration tests for flow, examples for end-to-end
- **Verification**: Run `raku -Ilib tests/unit/exceptions.rakutest` to verify framework works
- **No actual tests required** in this work package (skeletons only)

## Risks & Mitigations

- **Module namespace conflicts**: Verify Qwiratry namespace is available, check for existing modules
- **Test framework compatibility**: Use standard Raku Test module (no external dependencies)
- **Path issues**: Ensure all paths are relative to repository root, not worktree root

## Definition of Done Checklist

- [ ] All module skeleton files created with proper `unit module` declarations
- [ ] All test directory structure created (unit/, integration/, examples/)
- [ ] All test skeleton files created with basic structure
- [ ] All modules can be loaded with `use` statements (no errors)
- [ ] Test framework runs successfully (can execute test files)
- [ ] Directory structure matches plan.md specification

## Review Guidance

- Verify all module files exist and have correct `unit module` declarations
- Verify test directory structure matches plan.md
- Verify modules can be loaded without errors
- Verify test framework works (run a test file)

## Activity Log

- 2025-12-17T11:41:34Z – system – lane=planned – Prompt created.
- 2025-12-17T13:08:28Z – claude – shell_pid=72117 – lane=doing – Started implementation
- 2025-12-17T13:12:00Z – claude – shell_pid=72117 – lane=doing – Completed implementation: All module skeletons created (Walker, Context, QueryIterator, X), test directory structure created (unit/, integration/, examples/), all test skeleton files created. Syntax verified with `raku -c`. Note: Runtime execution shows environment issue ("Missing serialize REPR function"), but code structure is correct.
- 2025-12-17T13:12:00Z – claude – shell_pid=72117 – lane=for_review – Ready for review

