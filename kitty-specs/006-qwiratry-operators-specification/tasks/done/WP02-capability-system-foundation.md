---
work_package_id: "WP02"
subtasks:
  - "T008"
  - "T009"
  - "T010"
  - "T011"
  - "T012"
  - "T013"
  - "T014"
  - "T015"
title: "Capability System Foundation"
phase: "Phase 0 - Foundation"
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

# Work Package Prompt: WP02 – Capability System Foundation

## Objectives & Success Criteria

- Implement capability roles that operators can use to declare their semantics
- Create base operator mixin with common functionality
- Enable Walkers to check operator compatibility via capability system
- All capability roles compile and can be composed with operator classes
- Capability contract tests verify walker-operator interface works correctly

## Context & Constraints

- **Reference Documents**:
  - [data-model.md](../data-model.md) - Capability roles and metadata structure defined
  - [contracts/operator-api.md](../contracts/operator-api.md) - Capability system contract
  - [research.md](../research.md) - Decision: capability/interface system for domain semantics
  - [plan.md](../plan.md) - Technical context: capability system enables domain-specific interpretation

- **Architecture Decisions**:
  - Capability roles declare operator semantics (NavigationOperator, MapReduceOperator, SetOperator, IOOperator)
  - Operators implement `capabilities()` method returning Associative hash
  - Walkers check compatibility via `supports()` method examining capabilities
  - Base operator mixin provides common functionality (describe method, etc.)

- **Constraints**:
  - Capability metadata must follow standardized hash structure from data-model.md
  - Roles must be composable with RakuAST::Node descendants
  - Must work with existing Walker interface

## Subtasks & Detailed Guidance

### Subtask T008 – Create Capability module

- **Purpose**: Create module structure for capability system
- **Steps**:
  1. Create `lib/Qwiratry/Operator/Capability.rakumod` (replace placeholder from WP01)
  2. Add module declaration: `unit module Qwiratry::Operator::Capability;`
  3. Export capability roles for use by operator classes
- **Files**: 
  - `lib/Qwiratry/Operator/Capability.rakumod`
- **Parallel?**: No (foundational module)
- **Notes**: This module will contain all capability role definitions

### Subtask T009 – Implement NavigationOperator role

- **Purpose**: Role for operators that perform navigation (tree, table, graph traversal)
- **Steps**:
  1. In `Capability.rakumod`, create `role NavigationOperator`
  2. Define `method capabilities(--> Associative)` that returns:
     ```raku
     {
         navigation => True,
         domains => ['tree', 'table', 'graph'],
         lazy => True
     }
     ```
  3. Export role: `role NavigationOperator is export { ... }`
- **Files**: 
  - `lib/Qwiratry/Operator/Capability.rakumod`
- **Parallel?**: Yes (can be done alongside T010, T011, T012)
- **Notes**: 
  - Role provides default capability declaration
  - Operators can override `capabilities()` if needed
  - Domains array indicates supported data models

### Subtask T010 – Implement MapReduceOperator role

- **Purpose**: Role for operators that perform map-reduce operations (filter, sort, transform, aggregate)
- **Steps**:
  1. In `Capability.rakumod`, create `role MapReduceOperator`
  2. Define `method capabilities(--> Associative)` that returns:
     ```raku
     {
         map-reduce => True,
         lazy => True
     }
     ```
  3. Export role
- **Files**: 
  - `lib/Qwiratry/Operator/Capability.rakumod`
- **Parallel?**: Yes (can be done alongside T009, T011, T012)
- **Notes**: Map-reduce operators work on collections, support lazy evaluation

### Subtask T011 – Implement SetOperator role

- **Purpose**: Role for operators that perform set theory and relational algebra operations
- **Steps**:
  1. In `Capability.rakumod`, create `role SetOperator`
  2. Define `method capabilities(--> Associative)` that returns:
     ```raku
     {
         set-operation => True,
         relational => True,  # Some set ops are relational (joins), some aren't
         lazy => True
     }
     ```
  3. Export role
- **Files**: 
  - `lib/Qwiratry/Operator/Capability.rakumod`
- **Parallel?**: Yes (can be done alongside T009, T010, T012)
- **Notes**: 
  - Set operators include both set theory (union, intersection) and relational (joins, projection)
  - `relational` flag distinguishes relational algebra operations

### Subtask T012 – Implement IOOperator role

- **Purpose**: Role for operators that perform I/O operations (read, parse, render, write)
- **Steps**:
  1. In `Capability.rakumod`, create `role IOOperator`
  2. Define `method capabilities(--> Associative)` that returns:
     ```raku
     {
         io => True,
         formats => ['json', 'xml', 'csv'],  # Supported formats (may be extended)
         lazy => False  # I/O typically requires eager evaluation
     }
     ```
  3. Export role
- **Files**: 
  - `lib/Qwiratry/Operator/Capability.rakumod`
- **Parallel?**: Yes (can be done alongside T009, T010, T011)
- **Notes**: 
  - I/O operators may need format-specific capabilities
  - Formats list indicates what formats are supported (discovered dynamically)

### Subtask T013 – Create base operator mixin

- **Purpose**: Provide common functionality for all operators (describe method, etc.)
- **Steps**:
  1. In `Capability.rakumod`, create `role OperatorBase`
  2. Define `method describe(--> Str)` that returns human-readable description
  3. Default implementation: `"{self.^name}"`
  4. Operators can override for more detailed descriptions
  5. Export role
- **Files**: 
  - `lib/Qwiratry/Operator/Capability.rakumod`
- **Parallel?**: No (used by all operators)
- **Notes**: 
  - This mixin provides common operator functionality
  - `describe()` method used for debugging and introspection
  - Can be extended with more common methods as needed

### Subtask T014 – Write capability unit tests

- **Purpose**: Verify capability roles work correctly
- **Steps**:
  1. Create `t/operator/capability.rakutest`
  2. Test each capability role:
     - Create test class implementing role
     - Verify `capabilities()` method returns correct hash structure
     - Verify role can be composed with RakuAST::Node descendant
  3. Test base operator mixin:
     - Verify `describe()` method works
     - Test default implementation
  4. Run tests: `raku -Ilib t/operator/capability.rakutest`
- **Files**: 
  - `t/operator/capability.rakutest`
- **Parallel?**: No (depends on T008-T013)
- **Notes**: 
  - Create mock operator classes for testing
  - Verify capability metadata structure matches data-model.md

### Subtask T015 – Write capability contract tests

- **Purpose**: Verify walker-operator interface contract works correctly
- **Steps**:
  1. Create `t/contract/capability.rakutest`
  2. Test Walker compatibility checking:
     - Create mock Walker with `supports()` method
     - Create operator with NavigationOperator role
     - Verify Walker can check capabilities via `supports()`
     - Test positive and negative cases
  3. Test capability introspection:
     - Verify Walkers can introspect operator capabilities
     - Test domain checking (e.g., 'tree' in domains array)
  4. Run tests: `raku -Ilib t/contract/capability.rakutest`
- **Files**: 
  - `t/contract/capability.rakutest`
- **Parallel?**: No (depends on T008-T013)
- **Notes**: 
  - Use existing Walker infrastructure for testing
  - Verify contract matches contracts/operator-api.md specification

## Test Strategy

- **Unit Tests**: Each capability role tested independently (T014)
- **Contract Tests**: Walker-operator interface tested (T015)
- **Test Coverage**: Role composition, capability metadata structure, walker compatibility checking
- **Test Commands**: 
  - `raku -Ilib t/operator/capability.rakutest`
  - `raku -Ilib t/contract/capability.rakutest`
- **Success Criteria**: All tests pass, capability system enables walker-operator compatibility checking

## Risks & Mitigations

- **Risk**: Capability metadata structure inconsistency
  - **Mitigation**: Follow data-model.md exactly, use standardized hash keys
- **Risk**: Role composition conflicts with RakuAST::Node
  - **Mitigation**: Test role composition early, verify RakuAST::Node compatibility
- **Risk**: Walker interface changes break capability checking
  - **Mitigation**: Use existing Walker infrastructure, test with real Walker classes

## Definition of Done Checklist

- [ ] All capability roles implemented and exported
- [ ] Base operator mixin provides common functionality
- [ ] Capability unit tests pass (T014)
- [ ] Capability contract tests pass (T015)
- [ ] Capability metadata structure matches data-model.md
- [ ] Roles can be composed with operator classes
- [ ] Walkers can check operator compatibility via capabilities

## Review Guidance

- Verify capability roles follow data-model.md structure
- Check role composition works with RakuAST::Node
- Ensure capability metadata is standardized and consistent
- Validate contract tests verify walker-operator interface correctly
- Confirm capability system enables domain-specific operator semantics

## Activity Log

- 2025-12-27T07:09:20Z – system – lane=planned – Prompt created.
- 2025-01-27T00:00:00Z – cursor – shell_pid=12548 – lane=doing – Started implementation
- 2025-01-27T00:00:00Z – cursor – shell_pid=12548 – lane=doing – Completed T008: Replaced placeholder Capability.rakumod with full implementation
- 2025-01-27T00:00:00Z – cursor – shell_pid=12548 – lane=doing – Completed T009: Implemented NavigationOperator role with capabilities method
- 2025-01-27T00:00:00Z – cursor – shell_pid=12548 – lane=doing – Completed T010: Implemented MapReduceOperator role with capabilities method
- 2025-01-27T00:00:00Z – cursor – shell_pid=12548 – lane=doing – Completed T011: Implemented SetOperator role with capabilities method
- 2025-01-27T00:00:00Z – cursor – shell_pid=12548 – lane=doing – Completed T012: Implemented IOOperator role with capabilities method
- 2025-01-27T00:00:00Z – cursor – shell_pid=12548 – lane=doing – Completed T013: Implemented OperatorBase mixin with describe method
- 2025-01-27T00:00:00Z – cursor – shell_pid=12548 – lane=doing – Completed T014: Wrote comprehensive unit tests for all capability roles (20 test cases)
- 2025-01-27T00:00:00Z – cursor – shell_pid=12548 – lane=doing – Completed T015: Wrote contract tests for walker-operator interface (16 test cases)
- 2025-01-27T00:00:00Z – cursor – shell_pid=12548 – lane=for_review – Ready for review: All capability roles implemented, base mixin created, unit and contract tests written
- 2025-01-27T00:00:00Z – cursor-reviewer – shell_pid=$$ – lane=done – Approved without changes: All capability roles correctly implemented, metadata structure matches data-model.md, comprehensive unit and contract tests written


