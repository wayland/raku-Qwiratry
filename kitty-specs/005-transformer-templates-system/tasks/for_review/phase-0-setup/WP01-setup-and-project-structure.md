---
work_package_id: WP01
title: Setup & Project Structure
lane: for_review
history:
- timestamp: '2025-01-27T23:45:00Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
- timestamp: '2025-01-27T23:50:00Z'
  lane: doing
  agent: claude
  shell_pid: '80649'
  action: Started implementation
- timestamp: '2025-01-27T23:55:00Z'
  lane: doing
  agent: claude
  shell_pid: '80649'
  action: Completed T001, T002, T003
- timestamp: '2025-01-28T00:00:00Z'
  lane: for_review
  agent: claude
  shell_pid: '85610'
  action: 'Completed all subtasks: modules, tests, exceptions. Ready for review'
agent: claude
assignee: claude
phase: Phase 0 - Setup
review_status: ''
reviewed_by: ''
shell_pid: '85610'
subtasks:
- T001
- T002
- T003
---
*Path: [templates/task-prompt-template.md](templates/task-prompt-template.md)*

# Work Package Prompt: WP01 – Setup & Project Structure

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately (right below this notice).
- **You must address all feedback** before your work is complete. Feedback items are your implementation TODO list.
- **Mark as acknowledged**: When you understand the feedback and begin addressing it, update `review_status: acknowledged` in the frontmatter.
- **Report progress**: As you address each feedback item, update the Activity Log explaining what you changed.

---

## Review Feedback

> **Populated by `/spec-kitty.review`** – Reviewers add detailed feedback here when work needs changes. Implementation must address every item listed below before returning for re-review.

*[This section is empty initially. Reviewers will populate it if the work is returned from review. If you see feedback here, treat each item as a must-do before completion.]*

---

## Objectives & Success Criteria

- Create module structure for Transformer, Template, and Copy classes
- Create test structure for unit and integration tests
- Create exception classes for transformer-specific errors
- All modules can be imported without errors
- Basic test structure allows tests to run

## Context & Constraints

- **Prerequisites**: None (starting package)
- **Related Documents**: 
  - `plan.md` - Module structure defined in section 6
  - `spec.md` - Error handling requirements
  - `.kittify/memory/constitution.md` - Test-first principles
- **Architecture**: Follow existing Qwiratry module structure in `lib/Qwiratry/`
- **Constraints**: Must follow Raku module naming conventions, must integrate with existing Qwiratry infrastructure

## Subtasks & Detailed Guidance

### Subtask T001 – Create module structure

- **Purpose**: Establish the basic module files for Transformer, Template, and Copy classes
- **Steps**:
  1. Create `lib/Qwiratry/Transformer.rakumod` with unit module declaration: `unit module Qwiratry::Transformer;`
  2. Create `lib/Qwiratry/Template.rakumod` with unit module declaration: `unit module Qwiratry::Template;`
  3. Create `lib/Qwiratry/Copy.rakumod` with unit module declaration: `unit module Qwiratry::Copy;`
  4. Add basic export statements for main classes (will be implemented later)
  5. Ensure modules follow existing Qwiratry module structure and naming
- **Files**: 
  - `lib/Qwiratry/Transformer.rakumod`
  - `lib/Qwiratry/Template.rakumod`
  - `lib/Qwiratry/Copy.rakumod`
- **Parallel?**: No (sequential file creation)
- **Notes**: Use existing Qwiratry modules as reference for structure and style

### Subtask T002 – Create test structure

- **Purpose**: Establish test files for unit and integration tests
- **Steps**:
  1. Create `tests/unit/transformer.rakutest` with basic test structure using Test module
  2. Create `tests/unit/template.rakutest` with basic test structure
  3. Create `tests/unit/copy.rakutest` with basic test structure
  4. Create `tests/integration/transformer-walker.rakutest` with basic test structure
  5. Ensure all test files can be run (even if tests are empty initially)
  6. Follow existing test structure from other Qwiratry features
- **Files**:
  - `tests/unit/transformer.rakutest`
  - `tests/unit/template.rakutest`
  - `tests/unit/copy.rakutest`
  - `tests/integration/transformer-walker.rakutest`
- **Parallel?**: Yes (different test files can be created in parallel)
- **Notes**: Use Test module, follow existing test patterns from features 002 and 003

### Subtask T003 – Create exception classes

- **Purpose**: Define exception hierarchy for transformer-specific errors
- **Steps**:
  1. Check existing `lib/Qwiratry/X.rakumod` for exception structure
  2. Add `X::Qwiratry::TemplateOrderingConflict` exception class for template ordering conflicts
  3. Add `X::Qwiratry::NoWalkerFound` exception class for missing Walker errors
  4. Add any other transformer-specific exceptions as needed
  5. Ensure exceptions provide diagnostic information (which templates, why conflict, etc.)
- **Files**:
  - `lib/Qwiratry/X.rakumod` (extend existing file)
- **Parallel?**: Yes (can be done in parallel with module structure)
- **Notes**: Follow existing exception patterns, ensure error messages are clear and actionable per spec requirements

## Test Strategy

- **Not required for this package**: This is setup work. Tests will be added in subsequent packages.
- **Validation**: Ensure modules can be imported and test files can be executed (even if empty)

## Risks & Mitigations

- **Module naming conflicts**: Follow existing Qwiratry naming conventions exactly
- **Test structure mismatch**: Review existing test files from features 002 and 003 for patterns
- **Exception structure**: Ensure exceptions integrate with existing Qwiratry exception hierarchy

## Definition of Done Checklist

- [ ] All module files created with proper unit module declarations
- [ ] All test files created with basic structure
- [ ] Exception classes added to X.rakumod
- [ ] Modules can be imported without errors
- [ ] Test files can be executed (even if empty)
- [ ] Code follows existing Qwiratry style and conventions
- [ ] `tasks.md` updated with status change

## Review Guidance

- Verify module structure matches plan.md section 6
- Ensure test structure follows existing patterns
- Check exception classes provide diagnostic information
- Validate modules integrate with existing Qwiratry infrastructure

## Activity Log

- 2025-01-27T23:45:00Z – system – lane=planned – Prompt created.
- 2025-01-27T23:50:00Z – claude – shell_pid=80649 – lane=doing – Started implementation
- 2025-01-27T23:55:00Z – claude – shell_pid=80649 – lane=doing – Completed T001: Created module structure (Transformer.rakumod, Template.rakumod, Copy.rakumod)
- 2025-01-27T23:55:00Z – claude – shell_pid=80649 – lane=doing – Completed T002: Created test structure (unit and integration test files)
- 2025-01-27T23:55:00Z – claude – shell_pid=80649 – lane=doing – Completed T003: Added exception classes (TemplateOrderingConflict, NoWalkerFound) to X.rakumod
- 2025-01-27T23:55:00Z – claude – shell_pid=80649 – lane=doing – Completed T001, T002, T003
- 2025-01-28T00:00:00Z – claude – shell_pid=85610 – lane=for_review – Completed all subtasks: modules, tests, exceptions. Ready for review

