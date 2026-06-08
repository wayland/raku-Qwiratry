---
work_package_id: "WP07"
subtasks:
  - "T060"
  - "T061"
  - "T062"
  - "T063"
  - "T064"
  - "T065"
  - "T066"
  - "T067"
title: "Integration Tests & Polish"
phase: "Phase 3 - Polish"
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

# Work Package Prompt: WP07 – Integration Tests & Polish

## Objectives & Success Criteria

- Comprehensive end-to-end integration testing across all operator categories
- Operator precedence validation in complex expressions
- Error handling verification across all stages (compile/plan/runtime)
- Edge case testing (null values, empty collections, circular references)
- Quickstart.md examples validated
- Documentation updated with usage examples
- Code cleanup and refactoring
- Performance validation

## Context & Constraints

- **Reference Documents**:
  - [spec.md](../spec.md) - User Story 5: Operator Composition and Complex Queries (P3)
  - [quickstart.md](../quickstart.md) - Usage examples to validate
  - [plan.md](../plan.md) - Performance goals and constraints
  - [Operators.md](../../../../Operators.md) - Operator precedence specification

- **Architecture Decisions**:
  - End-to-end tests combine all operator categories
  - Precedence tests verify operator evaluation order
  - Error handling covers all three stages
  - Edge cases validate graceful degradation

- **Constraints**:
  - Must validate all quickstart examples
  - Performance validation establishes baseline metrics
  - Documentation must be comprehensive

## Subtasks & Detailed Guidance

### Subtask T060 – Write end-to-end integration tests

- **Purpose**: Verify complete operator pipelines work correctly
- **Steps**:
  1. Create `t/integration/end-to-end.rakutest`
  2. Test complete pipeline: source → parse → navigate → filter → transform → render → destination
  3. Test multi-operator composition:
     - Navigation + selection + sort
     - Set operations with navigation results
     - I/O with query operations
  4. Test complex queries:
     - Nested operators
     - Multiple operator types in sequence
     - Chained operations
  5. Verify AST structure is correct
  6. Run tests: `raku -Ilib t/integration/end-to-end.rakutest`
- **Files**: 
  - `t/integration/end-to-end.rakutest`
- **Parallel?**: No (depends on WP03-WP06)

### Subtask T061 – Test operator precedence

- **Purpose**: Verify operator precedence is correctly enforced
- **Steps**:
  1. Create `t/operator/precedence.rakutest`
  2. Test precedence levels from Operators.md:
     - Symbolic Unary (⇤)
     - Replication (σ, Π, ρ, ⪪, etc.)
     - Concatenation (⋉, ⋊, ⨝, etc.)
     - Junctive operations (∩, ∪, etc.)
     - Chaining (∈, ⊂, etc.)
  3. Test complex expressions with multiple precedence levels
  4. Verify AST structure reflects correct precedence
  5. Run tests: `raku -Ilib t/operator/precedence.rakutest`
- **Files**: 
  - `t/operator/precedence.rakutest`
- **Parallel?**: No (depends on all operators)

### Subtask T062 – Test error handling stages

- **Purpose**: Verify error handling at compile-time, planning-time, and runtime
- **Steps**:
  1. Create `t/integration/error-handling.rakutest`
  2. Test compile-time errors:
     - Invalid operator syntax
     - Missing required attributes
     - Type errors
  3. Test planning-time errors:
     - Unsupported operators (Walker.supports() returns False)
     - Incompatible capabilities
     - X::Qwiratry::UnknownQueryElement exceptions
  4. Test runtime errors:
     - Invalid data (null values, wrong types)
     - Missing format modules
     - File/URL access errors
     - Domain-specific exceptions
  5. Verify error messages are helpful and actionable
  6. Run tests: `raku -Ilib t/integration/error-handling.rakutest`
- **Files**: 
  - `t/integration/error-handling.rakutest`
- **Parallel?**: No (depends on all operators and exceptions)

### Subtask T063 – Test edge cases

- **Purpose**: Verify graceful handling of edge cases
- **Steps**:
  1. Create `t/integration/edge-cases.rakutest`
  2. Test null value handling:
     - Null foreign keys in navigation
     - Null elements in collections
     - Null operands in set operations
  3. Test empty collection handling:
     - Empty collections in set operations
     - Empty results from navigation
     - Empty collections in map-reduce
  4. Test circular reference handling:
     - Circular foreign keys (if applicable)
     - Self-referential structures
  5. Test incompatible data types:
     - Navigation operators on scalars
     - Set operations on incompatible collections
  6. Test boundary conditions:
     - Single-element collections
     - Very large AST structures
  7. Run tests: `raku -Ilib t/integration/edge-cases.rakutest`
- **Files**: 
  - `t/integration/edge-cases.rakutest`
- **Parallel?**: No (depends on all operators)

### Subtask T064 – Validate quickstart examples

- **Purpose**: Ensure all quickstart.md examples compile and run
- **Steps**:
  1. Extract examples from `quickstart.md`
  2. Create test file `t/integration/quickstart-examples.rakutest`
  3. For each example:
     - Verify code compiles
     - Test AST construction (if applicable)
     - Verify no syntax errors
     - Test with mock data if possible
  4. Update quickstart.md if examples need fixes
  5. Run tests: `raku -Ilib t/integration/quickstart-examples.rakutest`
- **Files**: 
  - `t/integration/quickstart-examples.rakutest`
  - `quickstart.md` (if updates needed)
- **Parallel?**: No (depends on all operators)

### Subtask T065 – Update operator documentation

- **Purpose**: Add comprehensive usage examples to documentation
- **Steps**:
  1. Review existing documentation (Operators.md, quickstart.md)
  2. Add usage examples for each operator category:
     - Navigation operator examples
     - Map-reduce operator examples
     - Set operator examples
     - I/O operator examples
  3. Add composition examples:
     - Chaining operators
     - Combining operator types
     - Complex query pipelines
  4. Add error handling examples:
     - Common error scenarios
     - How to handle exceptions
  5. Update API documentation if needed
- **Files**: 
  - `quickstart.md` (or create `docs/operators-usage.md`)
  - Update existing docs as needed
- **Parallel?**: No (can proceed alongside testing)

### Subtask T066 – Code cleanup and refactoring

- **Purpose**: Improve code quality, consistency, and maintainability
- **Steps**:
  1. Review all operator modules for:
     - Code duplication (DRY violations)
     - Inconsistent patterns
     - Missing Rakudoc comments
     - Style guide violations
  2. Refactor common patterns:
     - Extract common constructor patterns
     - Create helper methods for capability declarations
     - Standardize error handling
  3. Improve code organization:
     - Group related operators
     - Add module-level documentation
     - Improve naming consistency
  4. Run linter/formatter if available
  5. Verify all tests still pass after refactoring
- **Files**: 
  - All operator modules in `lib/Qwiratry/Operator/`
- **Parallel?**: No (requires review of all code)

### Subtask T067 – Performance validation

- **Purpose**: Establish baseline performance metrics
- **Steps**:
  1. Create `t/performance/operator-performance.rakutest` (or separate benchmark script)
  2. Measure AST construction time:
     - Simple operators
     - Composed operators
     - Large AST structures
  3. Measure memory usage:
     - Single operator instances
     - Composed operators
     - Large query ASTs
  4. Measure Walker introspection time:
     - Capability checking
     - AST traversal
  5. Document baseline metrics
  6. Identify performance bottlenecks if any
  7. Run benchmarks: `raku -Ilib t/performance/operator-performance.rakutest`
- **Files**: 
  - `t/performance/operator-performance.rakutest` (or benchmark script)
  - Performance metrics documentation
- **Parallel?**: No (requires all operators complete)

## Test Strategy

- **End-to-End Tests**: Complete pipelines tested (T060)
- **Precedence Tests**: Operator evaluation order verified (T061)
- **Error Handling Tests**: All error stages covered (T062)
- **Edge Case Tests**: Boundary conditions validated (T063)
- **Documentation Validation**: Examples verified (T064)
- **Performance Tests**: Baseline metrics established (T067)
- **Success Criteria**: All tests pass, documentation complete, code quality high

## Risks & Mitigations

- **Risk**: Integration test complexity
  - **Mitigation**: Start with simple pipelines, add complexity incrementally
- **Risk**: Performance regressions
  - **Mitigation**: Establish baseline metrics early, monitor during development
- **Risk**: Documentation gaps
  - **Mitigation**: Review all operator categories, add examples systematically

## Definition of Done Checklist

- [ ] End-to-end integration tests pass (T060)
- [ ] Operator precedence tests pass (T061)
- [ ] Error handling tests pass (T062)
- [ ] Edge case tests pass (T063)
- [ ] Quickstart examples validated (T064)
- [x] Documentation updated (T065)
- [ ] Code cleanup complete (T066)
- [ ] Performance validation complete (T067)
- [ ] All tests pass
- [ ] Code follows Raku style guide

## Review Guidance

- Verify end-to-end tests cover realistic use cases
- Check precedence tests match Operators.md specification
- Ensure error handling is comprehensive across all stages
- Validate edge cases are handled gracefully
- Review documentation completeness and clarity
- Confirm code quality improvements
- Check performance metrics are reasonable

## Activity Log

- 2025-01-27T00:00:00Z – system – lane=planned – Prompt created.

