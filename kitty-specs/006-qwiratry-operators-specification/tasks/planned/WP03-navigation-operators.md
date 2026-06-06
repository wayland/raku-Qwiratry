---
work_package_id: "WP03"
subtasks:
  - "T016"
  - "T017"
  - "T018"
  - "T019"
  - "T020"
  - "T021"
  - "T022"
  - "T023"
  - "T024"
  - "T025"
  - "T026"
  - "T027"
  - "T028"
  - "T029"
title: "Navigation Operators"
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

# Work Package Prompt: WP03 – Navigation Operators

## Objectives & Success Criteria

- Implement all 10 navigation operators as RakuAST::Node descendants
- Operators support tree, table, and graph navigation semantics
- All operators are immutable, composable, and introspectable
- Operators declare NavigationOperator capability
- Unit and integration tests verify correct behavior
- Operators can be chained and composed

## Context & Constraints

- **Reference Documents**:
  - [spec.md](../spec.md) - User Story 1: Basic Query Construction with Navigation Operators (P1)
  - [data-model.md](../data-model.md) - Navigation operator entities and attributes
  - [contracts/operator-api.md](../contracts/operator-api.md) - Navigation operator API contracts
  - [Operators.md](../../../../Operators.md) - Complete operator specification with examples

- **Architecture Decisions**:
  - All operators extend RakuAST::Node and implement NavigationOperator role
  - Operators are immutable with read-only attributes
  - RootOperator is unary postfix (different from binary operators)
  - Domain-specific semantics (tree vs table) handled by Walkers, not operators

- **Constraints**:
  - Must maintain immutability (no observable mutations)
  - Must work with existing Walker interface
  - Foreign key navigation complexity deferred to Walker implementation

## Subtasks & Detailed Guidance

### Subtask T016 – Create Navigation module

- **Purpose**: Establish module structure for navigation operators
- **Steps**:
  1. Replace placeholder `lib/Qwiratry/Operator/Navigation.rakumod` from WP01
  2. Add module declaration: `unit module Qwiratry::Operator::Navigation;`
  3. Import capability role: `use Qwiratry::Operator::Capability;`
  4. Export all navigation operator classes
- **Files**: 
  - `lib/Qwiratry/Operator/Navigation.rakumod`
- **Parallel?**: No (foundational module)
- **Notes**: Module will contain all 10 navigation operator classes

### Subtask T017 – Implement ChildOperator class (`⪪`)

- **Purpose**: Operator for selecting direct children of current node
- **Steps**:
  1. Create `class ChildOperator is RakuAST::Node does NavigationOperator`
  2. Add attributes: `has $.selector is required;` (Mu type), `has $.adverbs;` (Associative?)
  3. Implement constructor: `method new(:$selector!, :$adverbs) { self.bless(:$selector, :$adverbs) }`
  4. Implement `capabilities()` returning navigation capabilities
  5. Implement `describe()` returning "ChildOperator(selector: ...)"
  6. Ensure immutability (read-only attributes)
- **Files**: 
  - `lib/Qwiratry/Operator/Navigation.rakumod`
- **Parallel?**: Yes (can be done alongside T018-T026)
- **Notes**: 
  - Selector can be wildcard `*`, label, or selector expression
  - Adverbs optional (none for child operator currently)
  - Tree: returns direct children; Table: follows foreign keys; Graph: follows edges

### Subtask T018 – Implement ParentOperator class (`⪫`)

- **Purpose**: Operator for selecting parent of current node
- **Steps**:
  1. Create `class ParentOperator is RakuAST::Node does NavigationOperator`
  2. Add attributes: `has $.selector is required;`, `has $.adverbs;`
  3. Implement constructor with `:reference` adverb support
  4. Implement `capabilities()` and `describe()` methods
  5. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/Navigation.rakumod`
- **Parallel?**: Yes
- **Notes**: 
  - `:reference` adverb navigates backwards through foreign keys (for tables)
  - Tree: returns direct parent; Table: returns table or referencing rows (with :reference)

### Subtask T019 – Implement DescendantOperator class (`⪪⪪`)

- **Purpose**: Operator for selecting all descendants at any depth
- **Steps**:
  1. Create `class DescendantOperator is RakuAST::Node does NavigationOperator`
  2. Add attributes: `has $.selector is required;`, `has $.adverbs;`
  3. Implement constructor, capabilities, describe methods
  4. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/Navigation.rakumod`
- **Parallel?**: Yes
- **Notes**: 
  - Returns all descendants recursively
  - Table: returns all rows (same as child for tables, or recursively follows FKs if Walker supports)

### Subtask T020 – Implement AncestorOperator class (`⪫⪫`)

- **Purpose**: Operator for selecting all ancestors up to root
- **Steps**:
  1. Create `class AncestorOperator is RakuAST::Node does NavigationOperator`
  2. Add attributes: `has $.selector is required;`, `has $.adverbs;`
  3. Implement constructor, capabilities, describe methods
  4. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/Navigation.rakumod`
- **Parallel?**: Yes
- **Notes**: Returns all ancestors recursively up to root

### Subtask T021 – Implement FollowingSiblingOperator class (`⪨`)

- **Purpose**: Operator for selecting next siblings after current node
- **Steps**:
  1. Create `class FollowingSiblingOperator is RakuAST::Node does NavigationOperator`
  2. Add attributes: `has $.selector is required;`
  3. Implement constructor, capabilities, describe methods
  4. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/Navigation.rakumod`
- **Parallel?**: Yes
- **Notes**: 
  - Returns siblings that follow in document order
  - Table: returns next rows if table is ordered

### Subtask T022 – Implement PrecedingSiblingOperator class (`⪩`)

- **Purpose**: Operator for selecting previous siblings before current node
- **Steps**:
  1. Create `class PrecedingSiblingOperator is RakuAST::Node does NavigationOperator`
  2. Add attributes: `has $.selector is required;`
  3. Implement constructor, capabilities, describe methods
  4. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/Navigation.rakumod`
- **Parallel?**: Yes
- **Notes**: Returns siblings that precede in document order

### Subtask T023 – Implement FollowingOperator class (`⪨⪨`)

- **Purpose**: Operator for selecting all nodes following current node (not just siblings)
- **Steps**:
  1. Create `class FollowingOperator is RakuAST::Node does NavigationOperator`
  2. Add attributes: `has $.selector is required;`
  3. Implement constructor, capabilities, describe methods
  4. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/Navigation.rakumod`
- **Parallel?**: Yes
- **Notes**: Returns all nodes following in document order (descendants of following siblings, etc.)

### Subtask T024 – Implement PrecedingOperator class (`⪩⪩`)

- **Purpose**: Operator for selecting all nodes preceding current node (not just siblings)
- **Steps**:
  1. Create `class PrecedingOperator is RakuAST::Node does NavigationOperator`
  2. Add attributes: `has $.selector is required;`
  3. Implement constructor, capabilities, describe methods
  4. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/Navigation.rakumod`
- **Parallel?**: Yes
- **Notes**: Returns all nodes preceding in document order

### Subtask T025 – Implement RootOperator class (`⇤`)

- **Purpose**: Unary postfix operator for selecting root node
- **Steps**:
  1. Create `class RootOperator is RakuAST::Node does NavigationOperator`
  2. No attributes (unary postfix operator)
  3. Implement constructor: `method new() { self.bless }`
  4. Implement `capabilities()` and `describe()` methods
  5. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/Navigation.rakumod`
- **Parallel?**: Yes
- **Notes**: 
  - **IMPORTANT**: This is a unary postfix operator, different from binary operators
  - Returns root of tree/namespace hierarchy
  - Document clearly that this is postfix, not binary

### Subtask T026 – Implement AttributeOperator class (`⥷`)

- **Purpose**: Operator for accessing attributes/key-value pairs
- **Steps**:
  1. Create `class AttributeOperator is RakuAST::Node does NavigationOperator`
  2. Add attributes: `has $.key is required;` (Str or selector)
  3. Implement constructor, capabilities, describe methods
  4. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/Navigation.rakumod`
- **Parallel?**: Yes
- **Notes**: 
  - Tree: returns attribute value; Table: returns column value
  - Different from ChildOperator which follows foreign keys

### Subtask T027 – Write unit tests for navigation operators

- **Purpose**: Verify each navigation operator works correctly
- **Steps**:
  1. Create `t/operator/navigation.rakutest`
  2. For each operator (T017-T026):
     - Test AST construction with valid parameters
     - Test immutability (cannot modify after creation)
     - Test `capabilities()` returns correct metadata
     - Test `describe()` returns helpful description
     - Test inheritance from RakuAST::Node
     - Test NavigationOperator role composition
  3. Test RootOperator separately (unary postfix, no attributes)
  4. Test ParentOperator with `:reference` adverb
  5. Run tests: `raku -Ilib t/operator/navigation.rakutest`
- **Files**: 
  - `t/operator/navigation.rakutest`
- **Parallel?**: No (depends on T017-T026)
- **Notes**: 
  - Test AST construction, not execution (execution tested in integration)
  - Verify immutability by attempting mutations
  - Test capability metadata structure matches data-model.md

### Subtask T028 – Write walker-navigation integration tests

- **Purpose**: Verify navigation operators work with Walkers
- **Steps**:
  1. Create `t/integration/walker-navigation.rakutest`
  2. Test Walker compatibility checking:
     - Create mock Walker that supports navigation
     - Create navigation operators
     - Verify Walker.supports() returns True for navigation operators
  3. Test operator passing to Walker.plan():
     - Pass navigation operator to Walker.plan()
     - Verify no exceptions thrown (if Walker supports navigation)
     - Verify plan can be created
  4. Test domain-specific semantics (if test Walker available):
     - Test tree navigation semantics
     - Test table navigation semantics (if applicable)
  5. Run tests: `raku -Ilib t/integration/walker-navigation.rakutest`
- **Files**: 
  - `t/integration/walker-navigation.rakutest`
- **Parallel?**: No (depends on T017-T026)
- **Notes**: 
  - Use existing Walker infrastructure for testing
  - May need mock Walker implementation if none exists
  - Focus on interface, not execution semantics

### Subtask T029 – Test operator composition (chaining)

- **Purpose**: Verify navigation operators can be chained and composed
- **Steps**:
  1. Add composition tests to `t/operator/composition.rakutest` (create if needed)
  2. Test chaining:
     - Create `ChildOperator` with selector containing another `ChildOperator`
     - Verify AST structure is correct
     - Test nested operators maintain immutability
  3. Test composition with other operator types (if available):
     - Navigation + Selection (if SelectionOperator exists)
     - Multiple navigation operators in sequence
  4. Test RootOperator in composition:
     - Verify RootOperator can be used with other operators
  5. Run tests: `raku -Ilib t/operator/composition.rakutest`
- **Files**: 
  - `t/operator/composition.rakutest`
- **Parallel?**: No (depends on T017-T026)
- **Notes**: 
  - Focus on AST structure, not execution
  - Verify composition maintains immutability
  - Test that composed operators can be introspected

## Test Strategy

- **Unit Tests**: Each operator tested independently (T027)
- **Integration Tests**: Walker-operator interaction tested (T028)
- **Composition Tests**: Operator chaining and nesting tested (T029)
- **Test Coverage**: AST construction, immutability, capabilities, describe method, role composition
- **Test Commands**: 
  - `raku -Ilib t/operator/navigation.rakutest`
  - `raku -Ilib t/integration/walker-navigation.rakutest`
  - `raku -Ilib t/operator/composition.rakutest`
- **Success Criteria**: All tests pass, operators are immutable and composable, Walker integration works

## Risks & Mitigations

- **Risk**: Unary vs binary operator confusion (RootOperator)
  - **Mitigation**: Clearly document RootOperator as unary postfix, add tests specifically for this
- **Risk**: Foreign key navigation complexity
  - **Mitigation**: Defer to Walker implementation, test via integration tests, document Walker responsibility
- **Risk**: Immutability violations
  - **Mitigation**: Use read-only attributes (`has $.attr`), add immutability tests, no mutator methods
- **Risk**: Capability metadata inconsistency
  - **Mitigation**: Follow data-model.md exactly, use standardized hash structure

## Definition of Done Checklist

- [ ] All 10 navigation operators implemented (T017-T026)
- [ ] All operators extend RakuAST::Node and implement NavigationOperator role
- [ ] All operators are immutable (read-only attributes, no mutators)
- [ ] Unit tests pass (T027)
- [ ] Integration tests pass (T028)
- [ ] Composition tests pass (T029)
- [ ] RootOperator clearly documented as unary postfix
- [ ] ParentOperator supports `:reference` adverb
- [ ] All operators have `capabilities()` and `describe()` methods
- [ ] Code follows Raku style guide (Rakudoc comments, etc.)

## Review Guidance

- Verify all operators follow RakuAST::Node pattern correctly
- Check immutability (no observable mutations possible)
- Ensure capability metadata matches data-model.md structure
- Validate RootOperator is clearly unary postfix (not binary)
- Confirm ParentOperator `:reference` adverb works correctly
- Review test coverage (AST construction, immutability, capabilities, composition)
- Verify operators can be composed and chained

## Activity Log

- 2025-01-27T00:00:00Z – system – lane=planned – Prompt created.

