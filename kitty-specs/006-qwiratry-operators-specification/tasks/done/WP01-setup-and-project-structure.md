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
title: "Setup & Project Structure"
phase: "Phase 0 - Setup"
lane: "done"
assignee: "cursor-reviewer"
agent: "cursor-reviewer"
shell_pid: "$$"
review_status: "approved without changes"
reviewed_by: "cursor-reviewer"
history:
  - timestamp: "2025-12-27T07:09:20Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
  - timestamp: "2025-01-27T00:00:00Z"
    lane: "doing"
    agent: "cursor"
    shell_pid: "12548"
    action: "Started implementation"
---

# Work Package Prompt: WP01 – Setup & Project Structure

## Objectives & Success Criteria

- Establish complete project structure for Qwiratry operators
- Create exception hierarchy for operator-specific errors
- Set up test directory structure
- All directories and base exception classes compile successfully
- Basic exception tests pass

## Context & Constraints

- **Reference Documents**:
  - [plan.md](../plan.md) - Project structure defined in "Source Code" section
  - [data-model.md](../data-model.md) - Exception entities defined
  - [contracts/operator-api.md](../contracts/operator-api.md) - Error handling contracts
  - [.kittify/memory/constitution.md](../../../../.kittify/memory/constitution.md) - Constitution principles

- **Architecture Decisions**:
  - Operators organized by category in `lib/Qwiratry/Operator/`
  - Exceptions extend `X::Qwiratry::Walker` base (from existing infrastructure)
  - Tests mirror source structure

- **Constraints**:
  - Must maintain backward compatibility with existing Walker interface
  - Exception classes must follow Raku naming conventions (`X::Qwiratry::*`)

## Subtasks & Detailed Guidance

### Subtask T001 – Create Operator directory structure

- **Purpose**: Establish directory structure for operator modules per plan.md
- **Steps**:
  1. Create `lib/Qwiratry/Operator/` directory
  2. Verify parent directory `lib/Qwiratry/` exists (from existing infrastructure)
  3. Create placeholder files for future modules:
     - `lib/Qwiratry/Operator/Navigation.rakumod` (empty for now)
     - `lib/Qwiratry/Operator/MapReduce.rakumod` (empty for now)
     - `lib/Qwiratry/Operator/Set.rakumod` (empty for now)
     - `lib/Qwiratry/Operator/IO.rakumod` (empty for now)
     - `lib/Qwiratry/Operator/Capability.rakumod` (empty for now)
- **Files**: 
  - `lib/Qwiratry/Operator/` (directory)
  - Placeholder `.rakumod` files listed above
- **Parallel?**: No (foundational structure)
- **Notes**: Use `unit module Qwiratry::Operator::*;` in each placeholder file

### Subtask T002 – Create Exception directory

- **Purpose**: Create directory for operator-specific exceptions
- **Steps**:
  1. Create `lib/Qwiratry/Exception/` directory (if not exists)
  2. Create `lib/Qwiratry/Exception/Operator.rakumod` file
  3. Add basic module structure: `unit module Qwiratry::Exception::Operator;`
- **Files**: 
  - `lib/Qwiratry/Exception/Operator.rakumod`
- **Parallel?**: No (foundational structure)
- **Notes**: Check if `lib/Qwiratry/Exception/` already exists from other features

### Subtask T003 – Create test directories

- **Purpose**: Establish test directory structure per plan.md
- **Steps**:
  1. Create `t/operator/` directory
  2. Create `t/integration/` directory
  3. Create `t/contract/` directory
  4. Verify parent `t/` directory exists
- **Files**: 
  - `t/operator/` (directory)
  - `t/integration/` (directory)
  - `t/contract/` (directory)
- **Parallel?**: No (foundational structure)
- **Notes**: These directories will hold test files for each operator category

### Subtask T004 – Create base operator exception

- **Purpose**: Create base exception class for operator errors
- **Steps**:
  1. In `lib/Qwiratry/Exception/Operator.rakumod`, create `X::Qwiratry::Operator` class
  2. Extend `X::Qwiratry::Walker` (from existing infrastructure)
  3. Add attributes: `$.query-ast` (RakuAST::Node), `$.operator-type` (Str), `$.message` (Str)
  4. Implement constructor with named parameters
  5. Add `.gist()` method for error message formatting
- **Files**: 
  - `lib/Qwiratry/Exception/Operator.rakumod`
- **Parallel?**: Yes (can be done alongside T005, T006)
- **Notes**: 
  - Check existing `X::Qwiratry::Walker` structure for inheritance pattern
  - Follow Raku exception conventions

### Subtask T005 – Create FormatNotFound exception

- **Purpose**: Exception for missing format modules in I/O operators
- **Steps**:
  1. In `lib/Qwiratry/Exception/Operator.rakumod`, create `X::Qwiratry::IO::FormatNotFound` class
  2. Extend `X::Qwiratry::Operator`
  3. Add attributes: `$.format` (Str), `$.parse-or-render` (Str) - "parse" or "render"
  4. Implement constructor: `new(:$format, :$parse-or-render)`
  5. Add `.gist()` method with helpful message: "Format module Qwiratry::IO::{$parse-or-render.tc}::{$format} not found"
- **Files**: 
  - `lib/Qwiratry/Exception/Operator.rakumod`
- **Parallel?**: Yes (can be done alongside T004, T006)
- **Notes**: Format names are case-sensitive (JSON, XML, CSV)

### Subtask T006 – Create LocationError exception

- **Purpose**: Exception for invalid file paths or URLs in I/O operators
- **Steps**:
  1. In `lib/Qwiratry/Exception/Operator.rakumod`, create `X::Qwiratry::IO::LocationError` class
  2. Extend `X::Qwiratry::Operator`
  3. Add attributes: `$.location` (Str), `$.reason` (Str) - "not_found", "permission_denied", "invalid_url", etc.
  4. Implement constructor: `new(:$location, :$reason)`
  5. Add `.gist()` method with helpful message including location and reason
- **Files**: 
  - `lib/Qwiratry/Exception/Operator.rakumod`
- **Parallel?**: Yes (can be done alongside T004, T005)
- **Notes**: Reason should be descriptive for debugging

### Subtask T007 – Write basic tests for exception classes

- **Purpose**: Verify exception classes compile and work correctly
- **Steps**:
  1. Create `t/operator/exceptions.rakutest`
  2. Write tests for `X::Qwiratry::Operator`:
     - Test construction with all parameters
     - Test `.gist()` method returns formatted message
     - Test inheritance from `X::Qwiratry::Walker`
  3. Write tests for `X::Qwiratry::IO::FormatNotFound`:
     - Test construction with format and parse-or-render
     - Test `.gist()` includes format name
     - Test exception can be thrown and caught
  4. Write tests for `X::Qwiratry::IO::LocationError`:
     - Test construction with location and reason
     - Test `.gist()` includes location and reason
     - Test exception can be thrown and caught
  5. Run tests: `raku -Ilib t/operator/exceptions.rakutest`
- **Files**: 
  - `t/operator/exceptions.rakutest`
- **Parallel?**: No (depends on T004, T005, T006)
- **Notes**: 
  - Use `use Test;` and `use lib 'lib';`
  - Import exception classes: `use Qwiratry::Exception::Operator;`
  - Test both construction and error message formatting

## Test Strategy

- **Unit Tests**: Each exception class tested independently
- **Test Coverage**: Construction, attribute access, `.gist()` method, exception throwing/catching
- **Test Commands**: `raku -Ilib t/operator/exceptions.rakutest`
- **Success Criteria**: All tests pass, exceptions can be thrown and caught correctly

## Risks & Mitigations

- **Risk**: Exception inheritance from non-existent base class
  - **Mitigation**: Verify `X::Qwiratry::Walker` exists in existing infrastructure before implementing
- **Risk**: Directory structure mismatch with plan.md
  - **Mitigation**: Follow plan.md exactly, verify paths match
- **Risk**: Test directory conflicts with existing tests
  - **Mitigation**: Check existing `t/` structure, use subdirectories as specified

## Definition of Done Checklist

- [ ] All directories created per plan.md structure
- [ ] All exception classes compile without errors
- [ ] Exception tests pass (T007)
- [ ] Exception classes follow Raku naming conventions
- [ ] Exception messages are helpful and actionable
- [ ] Code follows Raku style guide (Rakudoc comments, etc.)

## Review Guidance

- Verify directory structure matches plan.md exactly
- Check exception inheritance chain is correct
- Ensure exception messages are user-friendly
- Validate tests cover all exception scenarios
- Confirm code follows constitution principles (simplicity, testability)

## Activity Log

- 2025-12-27T07:09:20Z – system – lane=planned – Prompt created.
- 2025-01-27T00:00:00Z – cursor – shell_pid=12548 – lane=doing – Started implementation
- 2025-01-27T00:00:00Z – cursor – shell_pid=12548 – lane=doing – Completed T001: Created Operator directory structure with placeholder modules
- 2025-01-27T00:00:00Z – cursor – shell_pid=12548 – lane=doing – Completed T002: Created Exception directory and Operator.rakumod module
- 2025-01-27T00:00:00Z – cursor – shell_pid=12548 – lane=doing – Completed T003: Created test directories (t/operator/, t/integration/, t/contract/)
- 2025-01-27T00:00:00Z – cursor – shell_pid=12548 – lane=doing – Completed T004: Implemented X::Qwiratry::Operator base exception class
- 2025-01-27T00:00:00Z – cursor – shell_pid=12548 – lane=doing – Completed T005: Implemented X::Qwiratry::IO::FormatNotFound exception
- 2025-01-27T00:00:00Z – cursor – shell_pid=12548 – lane=doing – Completed T006: Implemented X::Qwiratry::IO::LocationError exception
- 2025-01-27T00:00:00Z – cursor – shell_pid=12548 – lane=doing – Completed T007: Wrote comprehensive unit tests for all exception classes
- 2025-01-27T00:00:00Z – cursor – shell_pid=12548 – lane=for_review – Ready for review: All subtasks completed, directory structure created, exception classes implemented, tests written
- 2025-01-27T00:00:00Z – cursor-reviewer – shell_pid=$$ – lane=done – Approved without changes: All requirements met, directory structure correct, exception classes properly implemented, comprehensive tests written


