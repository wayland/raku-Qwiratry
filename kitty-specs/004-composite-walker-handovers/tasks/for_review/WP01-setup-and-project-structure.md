---
work_package_id: "WP01"
subtasks:
  - "T001"
  - "T002"
  - "T003"
title: "Setup & Project Structure"
phase: "Phase 0 - Setup"
lane: "for_review"
assignee: "claude"
agent: "claude"
shell_pid: "13776"
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2025-01-27T00:00:00Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
---

# Work Package Prompt: WP01 – Setup & Project Structure

## Objectives & Success Criteria

- Establish project structure with module files for `provides` trait and Master Walker
- Create test directory structure for unit and integration tests
- Verify Walker core infrastructure (feature 002) is available and accessible
- All module skeletons created with proper `unit module` declarations
- Test directory structure matches plan.md specification

**Success**: Project structure exists, modules load, test framework works, ready for implementation.

## Context & Constraints

- **Prerequisites**: None (starting package, but assumes feature 002 is complete)
- **Related Documents**:
  - `kitty-specs/004-composite-walker-handovers/plan.md` - Project structure specification
  - `kitty-specs/004-composite-walker-handovers/spec.md` - Feature requirements
  - `kitty-specs/002-walker-core-infrastructure/` - Walker core infrastructure (dependency)
  - `.kittify/memory/constitution.md` - Constitution principles (P1: Test-First)

- **Architecture Decisions**:
  - Module structure: `lib/Qwiratry/Provides.rakumod`, `lib/Qwiratry/MasterWalker.rakumod`
  - Test structure: `tests/unit/`, `tests/integration/`
  - Use Raku 6.e with RakuAST support
  - Reuse existing Walker infrastructure from feature 002

## Subtasks & Detailed Guidance

### Subtask T001 – Create module structure

- **Purpose**: Create module files for `provides` trait and Master Walker
- **Steps**:
  1. Create `lib/Qwiratry/Provides.rakumod` with `unit module Qwiratry::Provides;` declaration
  2. Create `lib/Qwiratry/MasterWalker.rakumod` with `unit module Qwiratry::MasterWalker;` declaration
  3. Add basic module documentation comments (Rakudoc format)
  4. Add `use Qwiratry::Walker;` to MasterWalker (depends on Walker role from feature 002)
- **Files**: 
  - `lib/Qwiratry/Provides.rakumod`
  - `lib/Qwiratry/MasterWalker.rakumod`
- **Parallel?**: Yes (both modules can be created in parallel)
- **Notes**: Modules are skeletons at this stage, implementation comes in later work packages

### Subtask T002 – Create test structure

- **Purpose**: Create test directory structure and test file skeletons
- **Steps**:
  1. Create `tests/unit/provides.rakutest` with basic test structure using Raku Test module
  2. Create `tests/unit/master-walker.rakutest` with basic test structure
  3. Create `tests/integration/composite-handover.rakutest` with basic test structure
  4. Add `use Test;` and basic test plan to each file
  5. Add placeholder test cases (e.g., `ok True, "placeholder";`)
- **Files**:
  - `tests/unit/provides.rakutest`
  - `tests/unit/master-walker.rakutest`
  - `tests/integration/composite-handover.rakutest`
- **Parallel?**: Yes (all test files can be created in parallel)
- **Notes**: Test files are skeletons, actual tests will be written in later work packages

### Subtask T003 – Verify Walker infrastructure

- **Purpose**: Verify that Walker core infrastructure (feature 002) is available and accessible
- **Steps**:
  1. Check that `lib/Qwiratry/Walker.rakumod` exists (from feature 002)
  2. Check that `lib/Qwiratry/Context.rakumod` exists (from feature 002)
  3. Check that `lib/Qwiratry/QueryIterator.rakumod` exists (from feature 002)
  4. Verify modules can be loaded: `use Qwiratry::Walker;` works
  5. Verify Walker role is available: `Walker.^name` returns correct name
- **Files**: None (verification only)
- **Parallel?**: No (must verify before proceeding)
- **Notes**: If Walker infrastructure is missing, this work package cannot proceed. Report error and wait for feature 002 completion.

## Test Strategy

- No tests required at this stage (setup only)
- Verification that modules load and test framework works is sufficient

## Risks & Mitigations

- **Missing dependencies from feature 002**: Verify Walker infrastructure exists before proceeding. If missing, report error and wait.
- **Module loading issues**: Ensure proper `use` statements and module paths are correct.

## Definition of Done Checklist

- [ ] Module files created: `lib/Qwiratry/Provides.rakumod`, `lib/Qwiratry/MasterWalker.rakumod`
- [ ] Test files created: `tests/unit/provides.rakutest`, `tests/unit/master-walker.rakutest`, `tests/integration/composite-handover.rakutest`
- [ ] Walker infrastructure verified: modules exist and can be loaded
- [ ] All modules have proper `unit module` declarations
- [ ] All test files have basic test structure with `use Test;`
- [ ] `tasks.md` updated with status change

## Review Guidance

- Verify module structure matches plan.md specification
- Verify test structure matches plan.md specification
- Verify Walker infrastructure dependencies are accessible
- Ensure proper Raku module declarations and test framework setup

## Activity Log

- 2025-01-27T00:00:00Z – system – lane=planned – Prompt created.
- 2025-01-27T19:40:00Z – claude – shell_pid=13776 – lane=doing – Completed implementation of WP01:
  - Created lib/Qwiratry/Provides.rakumod with trait_mod skeleton
  - Created lib/Qwiratry/MasterWalker.rakumod with class skeleton
  - Created test structure: tests/unit/provides.rakutest, tests/unit/master-walker.rakutest, tests/integration/composite-handover.rakutest
  - Verified Walker infrastructure exists (Walker.rakumod, Context.rakumod, QueryIterator.rakumod)
  - All modules have proper unit module declarations
  - All test files have basic test structure with use Test;

