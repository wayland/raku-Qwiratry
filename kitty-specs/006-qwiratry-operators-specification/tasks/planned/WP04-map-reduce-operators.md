---
work_package_id: "WP04"
subtasks:
  - "T030"
  - "T031"
  - "T032"
  - "T033"
  - "T034"
  - "T035"
  - "T036"
  - "T037"
title: "Map-Reduce Operators"
phase: "Phase 1 - Core Operators (MVP)"
lane: "planned"
assignee: ""
agent: ""
shell_pid: ""
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2025-01-27T00:00:00Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
---

# Work Package Prompt: WP04 – Map-Reduce Operators

## Objectives & Success Criteria

- Implement all 4 map-reduce operators (selection, sort, map, reduce) as RakuAST::Node descendants
- Operators support filtering, sorting, transformation, and aggregation
- All operators are immutable, composable, and introspectable
- Operators declare MapReduceOperator capability
- Unit and integration tests verify correct behavior
- Operators can be composed with navigation operators

## Context & Constraints

- **Reference Documents**:
  - [spec.md](../spec.md) - User Story 2: Data Filtering and Transformation (P1)
  - [data-model.md](../data-model.md) - Map-reduce operator entities
  - [contracts/operator-api.md](../contracts/operator-api.md) - Map-reduce operator API contracts
  - [Operators.md](../../../../Operators.md) - Operator specification

- **Architecture Decisions**:
  - All operators extend RakuAST::Node and implement MapReduceOperator role
  - Operators accept Code blocks (predicates, key functions, operations)
  - MapOperator uses Raku hyper operator semantics (may delegate to RakuAST::ApplyHyperOp)
  - Operators are immutable with read-only attributes

- **Constraints**:
  - Code blocks must be validated at AST construction where possible
  - MapOperator integration with Raku hyper operator needs research
  - Must maintain immutability

## Subtasks & Detailed Guidance

### Subtask T030 – Create MapReduce module

- **Purpose**: Establish module structure for map-reduce operators
- **Steps**:
  1. Replace placeholder `lib/Qwiratry/Operator/MapReduce.rakumod` from WP01
  2. Add module declaration: `unit module Qwiratry::Operator::MapReduce;`
  3. Import capability role: `use Qwiratry::Operator::Capability;`
  4. Export all map-reduce operator classes
- **Files**: 
  - `lib/Qwiratry/Operator/MapReduce.rakumod`
- **Parallel?**: No (foundational module)

### Subtask T031 – Implement SelectionOperator class (`σ`)

- **Purpose**: Operator for filtering collections with predicate
- **Steps**:
  1. Create `class SelectionOperator is RakuAST::Node does MapReduceOperator`
  2. Add attribute: `has $.predicate is required;` (Code type)
  3. Implement constructor: `method new(:$predicate!) { self.bless(:$predicate) }`
  4. Implement `capabilities()` returning map-reduce capabilities
  5. Implement `describe()` returning "SelectionOperator(predicate: ...)"
  6. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/MapReduce.rakumod`
- **Parallel?**: Yes (can be done alongside T032-T034)
- **Notes**: 
  - Predicate is Code block that returns Bool
  - Used for filtering: `σ { $_.age > 18 }`

### Subtask T032 – Implement SortOperator class (`⇅`)

- **Purpose**: Operator for sorting collections by key function
- **Steps**:
  1. Create `class SortOperator is RakuAST::Node does MapReduceOperator`
  2. Add attribute: `has $.key-function is required;` (Code type)
  3. Implement constructor, capabilities, describe methods
  4. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/MapReduce.rakumod`
- **Parallel?**: Yes
- **Notes**: 
  - Key function extracts sort key from each item
  - Used for sorting: `⇅ { $_.name }`

### Subtask T033 – Implement MapOperator class (`».`)

- **Purpose**: Operator for transforming values (uses Raku hyper operator)
- **Steps**:
  1. Create `class MapOperator is RakuAST::Node does MapReduceOperator`
  2. Add attribute: `has $.transform is required;` (Code type)
  3. Implement constructor, capabilities, describe methods
  4. Research RakuAST::ApplyHyperOp structure if needed
  5. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/MapReduce.rakumod`
- **Parallel?**: Yes
- **Notes**: 
  - Uses Raku hyper operator semantics
  - May need to delegate to RakuAST::ApplyHyperOp
  - Used for transformation: `». { $_.name.uc }`

### Subtask T034 – Implement ReduceOperator class (`⌿`)

- **Purpose**: Operator for aggregating collection to single value
- **Steps**:
  1. Create `class ReduceOperator is RakuAST::Node does MapReduceOperator`
  2. Add attribute: `has $.operation is required;` (Code type)
  3. Implement constructor, capabilities, describe methods
  4. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/MapReduce.rakumod`
- **Parallel?**: Yes
- **Notes**: 
  - Operation is Code block that combines two values
  - Used for aggregation: `⌿ { $^a + $^b.age }`

### Subtask T035 – Write unit tests for map-reduce operators

- **Purpose**: Verify each map-reduce operator works correctly
- **Steps**:
  1. Create `t/operator/mapreduce.rakutest`
  2. For each operator (T031-T034):
     - Test AST construction with Code blocks
     - Test immutability
     - Test `capabilities()` returns correct metadata
     - Test `describe()` method
     - Test inheritance from RakuAST::Node
     - Test MapReduceOperator role composition
  3. Test Code block validation (if possible at AST construction)
  4. Run tests: `raku -Ilib t/operator/mapreduce.rakutest`
- **Files**: 
  - `t/operator/mapreduce.rakutest`
- **Parallel?**: No (depends on T031-T034)

### Subtask T036 – Write walker-mapreduce integration tests

- **Purpose**: Verify map-reduce operators work with Walkers
- **Steps**:
  1. Create `t/integration/walker-mapreduce.rakutest`
  2. Test Walker compatibility checking for map-reduce operators
  3. Test operator passing to Walker.plan()
  4. Test domain-specific semantics if test Walker available
  5. Run tests: `raku -Ilib t/integration/walker-mapreduce.rakutest`
- **Files**: 
  - `t/integration/walker-mapreduce.rakutest`
- **Parallel?**: No (depends on T031-T034)

### Subtask T037 – Test map-reduce composition with navigation

- **Purpose**: Verify map-reduce operators compose with navigation operators
- **Steps**:
  1. Add composition tests to `t/operator/composition.rakutest`
  2. Test navigation + selection: `ChildOperator` + `SelectionOperator`
  3. Test navigation + sort: `DescendantOperator` + `SortOperator`
  4. Test chained map-reduce: `SelectionOperator` + `SortOperator`
  5. Verify AST structure and immutability
  6. Run tests: `raku -Ilib t/operator/composition.rakutest`
- **Files**: 
  - `t/operator/composition.rakutest`
- **Parallel?**: No (depends on T031-T034 and WP03)

## Test Strategy

- **Unit Tests**: Each operator tested independently (T035)
- **Integration Tests**: Walker-operator interaction (T036)
- **Composition Tests**: Operator chaining with navigation (T037)
- **Test Coverage**: AST construction, immutability, capabilities, Code block handling
- **Success Criteria**: All tests pass, operators compose correctly

## Risks & Mitigations

- **Risk**: MapOperator integration with Raku hyper operator
  - **Mitigation**: Research RakuAST::ApplyHyperOp, may need to delegate or wrap
- **Risk**: Code block validation complexity
  - **Mitigation**: Validate at AST construction where possible, document Walker responsibility
- **Risk**: Predicate/key-function/operation block type safety
  - **Mitigation**: Use Code type constraint, document expected signatures

## Definition of Done Checklist

- [ ] All 4 map-reduce operators implemented (T031-T034)
- [ ] All operators extend RakuAST::Node and implement MapReduceOperator role
- [ ] All operators are immutable
- [ ] Unit tests pass (T035)
- [ ] Integration tests pass (T036)
- [ ] Composition tests pass (T037)
- [ ] Code follows Raku style guide

## Review Guidance

- Verify Code block handling is correct
- Check MapOperator integration with hyper operator
- Ensure immutability maintained
- Validate composition with navigation operators works

## Activity Log

- 2025-01-27T00:00:00Z – system – lane=planned – Prompt created.

