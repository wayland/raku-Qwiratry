---
work_package_id: "WP05"
subtasks:
  - "T038"
  - "T039"
  - "T040"
  - "T041"
  - "T042"
  - "T043"
  - "T044"
  - "T045"
  - "T046"
  - "T047"
  - "T048"
  - "T049"
  - "T050"
title: "Set Operators"
phase: "Phase 2 - Extended Operators"
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

# Work Package Prompt: WP05 – Set Operators

## Objectives & Success Criteria

- Implement all set theory and relational algebra operators as RakuAST::Node descendants
- Operators support membership, subset, set operations, and joins
- All operators are immutable, composable, and introspectable
- Operators declare SetOperator capability
- Unit and integration tests verify correct behavior
- Operators work with Associative collections

## Context & Constraints

- **Reference Documents**:
  - [spec.md](../spec.md) - User Story 3: Set Operations on Query Results (P2)
  - [data-model.md](../data-model.md) - Set operator entities
  - [contracts/operator-api.md](../contracts/operator-api.md) - Set operator API contracts
  - [Operators.md](../../../../Operators.md) - Complete operator specification

- **Architecture Decisions**:
  - All operators extend RakuAST::Node and implement SetOperator role
  - Binary operators accept left and right operands (RakuAST::Node)
  - Join operators may accept optional condition blocks
  - Operators must handle Associative collections

- **Constraints**:
  - Collection type compatibility must be validated
  - Join condition complexity - start with natural join, add conditions incrementally
  - Must maintain immutability

## Subtasks & Detailed Guidance

### Subtask T038 – Create Set module

- **Purpose**: Establish module structure for set operators
- **Steps**:
  1. Replace placeholder `lib/Qwiratry/Operator/Set.rakumod` from WP01
  2. Add module declaration and imports
  3. Export all set operator classes
- **Files**: 
  - `lib/Qwiratry/Operator/Set.rakumod`
- **Parallel?**: No

### Subtask T039 – Implement membership operators

- **Purpose**: Implement `ElementOfOperator` (`∈`) and `ContainsOperator` (`∋`)
- **Steps**:
  1. Create `class ElementOfOperator is RakuAST::Node does SetOperator`
  2. Add attributes: `has $.element;`, `has $.collection;` (both RakuAST::Node)
  3. Implement constructor, capabilities, describe methods
  4. Create `class ContainsOperator` (inverse of ElementOf)
  5. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/Set.rakumod`
- **Parallel?**: Yes (can be done alongside T040-T047)

### Subtask T040 – Implement subset operators

- **Purpose**: Implement `SubsetOperator` (`⊂`) and `SubsetOrEqualOperator` (`⊆`)
- **Steps**:
  1. Create subset operator classes
  2. Add left/right operand attributes
  3. Implement constructor, capabilities, describe methods
  4. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/Set.rakumod`
- **Parallel?**: Yes

### Subtask T041 – Implement identity operator

- **Purpose**: Implement `IdentityOperator` (`≡`)
- **Steps**:
  1. Create `class IdentityOperator is RakuAST::Node does SetOperator`
  2. Add left/right operand attributes
  3. Implement constructor, capabilities, describe methods
  4. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/Set.rakumod`
- **Parallel?**: Yes

### Subtask T042 – Implement basic set operations

- **Purpose**: Implement `UnionOperator` (`∪`), `IntersectionOperator` (`∩`), `SymmetricDifferenceOperator` (`⊖`), `SetDifferenceOperator` (`∖`)
- **Steps**:
  1. Create union, intersection, symmetric difference, set difference operator classes
  2. Each has left/right operand attributes
  3. Implement constructors, capabilities, describe methods
  4. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/Set.rakumod`
- **Parallel?**: Yes (can implement each operator in parallel)

### Subtask T043 – Implement relational operators

- **Purpose**: Implement `ProjectionOperator` (`Π`) and `RenameOperator` (`ρ`)
- **Steps**:
  1. Create projection and rename operator classes
  2. ProjectionOperator: `has $.columns;` (Array of selectors)
  3. RenameOperator: `has $.renames;` (Associative of old => new names)
  4. Implement constructors, capabilities, describe methods
  5. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/Set.rakumod`
- **Parallel?**: Yes

### Subtask T044 – Implement join operators

- **Purpose**: Implement `InnerJoinOperator` (`⨝`), `LeftOuterJoinOperator` (`⟕`), `RightOuterJoinOperator` (`⟖`), `FullOuterJoinOperator` (`⟗`)
- **Steps**:
  1. Create join operator classes
  2. Add attributes: `has $.left;`, `has $.right;`, `has $.condition;` (Code?)
  3. Implement constructors, capabilities, describe methods
  4. Start with natural join (no condition), condition support can be added later
  5. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/Set.rakumod`
- **Parallel?**: Yes (can implement each join type in parallel)

### Subtask T045 – Implement semijoin operators

- **Purpose**: Implement `LeftSemijoinOperator` (`⋉`) and `RightSemijoinOperator` (`⋊`)
- **Steps**:
  1. Create semijoin operator classes
  2. Add left/right operand attributes
  3. Implement constructors, capabilities, describe methods
  4. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/Set.rakumod`
- **Parallel?**: Yes

### Subtask T046 – Implement antijoin operators

- **Purpose**: Implement `LeftAntijoinOperator` (`▷`) and `RightAntijoinOperator` (`◁`)
- **Steps**:
  1. Create antijoin operator classes
  2. Add left/right operand attributes
  3. Implement constructors, capabilities, describe methods
  4. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/Set.rakumod`
- **Parallel?**: Yes

### Subtask T047 – Implement division and cross join

- **Purpose**: Implement `DivisionOperator` (`÷`) and `CrossJoinOperator` (`×` U+00D7)
- **Steps**:
  1. Create division and cross join operator classes
  2. Add operand attributes
  3. Implement constructors, capabilities, describe methods
  4. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/Set.rakumod`
- **Parallel?**: Yes

### Subtask T048 – Write unit tests for set operators

- **Purpose**: Verify each set operator works correctly
- **Steps**:
  1. Create `t/operator/set.rakutest`
  2. For each operator category:
     - Test AST construction
     - Test immutability
     - Test capabilities
     - Test describe method
     - Test inheritance and role composition
  3. Test operand handling (left/right)
  4. Test join condition handling (if implemented)
  5. Run tests: `raku -Ilib t/operator/set.rakutest`
- **Files**: 
  - `t/operator/set.rakutest`
- **Parallel?**: No (depends on T039-T047)

### Subtask T049 – Write walker-set integration tests

- **Purpose**: Verify set operators work with Walkers
- **Steps**:
  1. Create `t/integration/walker-set.rakutest`
  2. Test Walker compatibility checking
  3. Test operator passing to Walker.plan()
  4. Test domain-specific semantics
  5. Run tests: `raku -Ilib t/integration/walker-set.rakutest`
- **Files**: 
  - `t/integration/walker-set.rakutest`
- **Parallel?**: No (depends on T039-T047)

### Subtask T050 – Test set operator composition

- **Purpose**: Verify set operators compose with navigation and map-reduce
- **Steps**:
  1. Add composition tests to `t/operator/composition.rakutest`
  2. Test set operations with navigation results
  3. Test set operations with map-reduce results
  4. Test nested set operations (union of intersections, etc.)
  5. Verify AST structure and immutability
  6. Run tests: `raku -Ilib t/operator/composition.rakutest`
- **Files**: 
  - `t/operator/composition.rakutest`
- **Parallel?**: No (depends on T039-T047 and WP03, WP04)

## Test Strategy

- **Unit Tests**: Each operator category tested (T048)
- **Integration Tests**: Walker-operator interaction (T049)
- **Composition Tests**: Operator chaining (T050)
- **Success Criteria**: All tests pass, operators handle Associative collections

## Risks & Mitigations

- **Risk**: Join condition complexity
  - **Mitigation**: Start with natural join, add condition support incrementally
- **Risk**: Collection type compatibility
  - **Mitigation**: Validate Associative interface, document constraints
- **Risk**: Large number of operators (many similar patterns)
  - **Mitigation**: Use consistent patterns, consider helper methods for common code

## Definition of Done Checklist

- [ ] All set operators implemented (T039-T047)
- [ ] All operators extend RakuAST::Node and implement SetOperator role
- [ ] All operators are immutable
- [ ] Unit tests pass (T048)
- [ ] Integration tests pass (T049)
- [ ] Composition tests pass (T050)
- [ ] Code follows Raku style guide

## Review Guidance

- Verify operand handling (left/right) is consistent
- Check join operators start simple (natural join)
- Ensure immutability maintained
- Validate composition works correctly

## Activity Log

- 2025-01-27T00:00:00Z – system – lane=planned – Prompt created.

