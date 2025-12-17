---
work_package_id: "WP02"
subtasks:
  - "T009"
  - "T010"
  - "T011"
  - "T012"
title: "Exception Hierarchy"
phase: "Phase 1 - Foundational"
lane: "planned"
assignee: ""
agent: ""
shell_pid: ""
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2025-12-17T11:41:34Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
---

# Work Package Prompt: WP02 – Exception Hierarchy

## Objectives & Success Criteria

- Implement X::Qwiratry::Walker base exception class with $.message and $.walker-type attributes
- Implement X::Qwiratry::UnknownQueryElement exception extending base, adding $.query-ast attribute
- Write comprehensive unit tests verifying exception behavior
- Exceptions follow Raku exception conventions (is Exception)
- Exceptions provide clear diagnostic messages

**Success**: Exceptions can be thrown and caught, contain expected attributes, provide diagnostic messages, tests pass.

## Context & Constraints

- **Prerequisites**: WP01 (module structure)
- **Related Documents**:
  - `kitty-specs/002-walker-core-infrastructure/contracts/walker-api.md` - Exception API contracts
  - `kitty-specs/002-walker-core-infrastructure/data-model.md` - Exception entity model
  - `kitty-specs/002-walker-core-infrastructure/spec.md` - FR-005 exception requirement

- **Architecture Decisions**:
  - Exception hierarchy: Base X::Qwiratry::Walker with X::Qwiratry::UnknownQueryElement subclass
  - Attributes: $.message, $.walker-type (base), $.query-ast (specific)
  - Follow Raku exception conventions (is Exception role)

## Subtasks & Detailed Guidance

### Subtask T009 – Implement X::Qwiratry::Walker base exception class

- **Purpose**: Create base exception class for all Walker-related errors
- **Steps**:
  1. Open `lib/Qwiratry/X.rakumod`
  2. Define `class X::Qwiratry::Walker is Exception`
  3. Add `has Str $.message` attribute
  4. Add `has Str $.walker-type` attribute
  5. Add constructor that accepts message and walker-type
  6. Add basic documentation comment
- **Files**: `lib/Qwiratry/X.rakumod`
- **Parallel?**: No
- **Notes**: Base class must extend Exception role, attributes should be public (Str type)

### Subtask T010 – Implement X::Qwiratry::UnknownQueryElement exception class

- **Purpose**: Create specific exception for uninterpretable Query AST
- **Steps**:
  1. In `lib/Qwiratry/X.rakumod`, define `class X::Qwiratry::UnknownQueryElement is X::Qwiratry::Walker`
  2. Add `has RakuAST::Node $.query-ast` attribute
  3. Add constructor that accepts query-ast, message, and walker-type
  4. Ensure constructor calls parent constructor
  5. Add documentation explaining when this exception is thrown
- **Files**: `lib/Qwiratry/X.rakumod`
- **Parallel?**: No (depends on T009)
- **Notes**: Must extend X::Qwiratry::Walker, query-ast attribute type is RakuAST::Node

### Subtask T011 – Write unit tests for exception hierarchy

- **Purpose**: Verify exception behavior, attributes, and message formatting
- **Steps**:
  1. Open `tests/unit/exceptions.rakutest`
  2. Add `use Qwiratry::X;` and `use Test;`
  3. Test X::Qwiratry::Walker can be thrown and caught
  4. Test X::Qwiratry::Walker attributes (message, walker-type) are accessible
  5. Test X::Qwiratry::UnknownQueryElement extends base correctly
  6. Test X::Qwiratry::UnknownQueryElement can be thrown and caught
  7. Test X::Qwiratry::UnknownQueryElement attributes (query-ast, message, walker-type) are accessible
  8. Test exception message formatting
  9. Test exception in CATCH block
- **Files**: `tests/unit/exceptions.rakutest`
- **Parallel?**: Yes (can be written alongside implementation)
- **Notes**: Use Raku Test module, verify all attributes are accessible

### Subtask T012 – Verify exception message formatting and attribute access

- **Purpose**: Ensure exceptions provide useful diagnostic information
- **Steps**:
  1. Create test that throws X::Qwiratry::UnknownQueryElement with sample query AST
  2. Verify exception message is non-empty and descriptive
  3. Verify all attributes (query-ast, message, walker-type) are accessible
  4. Verify exception can be caught and attributes read
  5. Test exception stringification (if applicable)
- **Files**: `tests/unit/exceptions.rakutest`
- **Parallel?**: No (depends on T011)
- **Notes**: Ensure diagnostic information is useful for debugging

## Test Strategy

- **Framework**: Raku Test module
- **Coverage**: Exception creation, throwing, catching, attribute access, message formatting
- **Commands**: `raku -Ilib tests/unit/exceptions.rakutest`
- **Fixtures**: Sample RakuAST::Node for testing (can be minimal/mock)

## Risks & Mitigations

- **Exception inheritance**: Verify proper Raku exception role composition (is Exception)
- **Attribute access**: Ensure all attributes are public and accessible
- **Query AST type**: Verify RakuAST::Node type constraint works correctly

## Definition of Done Checklist

- [ ] X::Qwiratry::Walker base exception implemented
- [ ] X::Qwiratry::UnknownQueryElement exception implemented
- [ ] Unit tests written and passing
- [ ] Exception message formatting verified
- [ ] All attributes accessible and tested
- [ ] Exceptions follow Raku conventions

## Review Guidance

- Verify exception hierarchy is correct (UnknownQueryElement extends Walker)
- Verify all attributes are accessible
- Verify exceptions can be thrown and caught correctly
- Verify diagnostic messages are useful

## Activity Log

- 2025-12-17T11:41:34Z – system – lane=planned – Prompt created.

