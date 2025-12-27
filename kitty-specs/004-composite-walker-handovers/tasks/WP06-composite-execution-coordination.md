---
work_package_id: WP06
title: Composite Execution Coordination
lane: done
history:
- timestamp: '2025-01-27T00:00:00Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
agent: claude-reviewer
assignee: claude-reviewer
phase: Phase 3 - Execution
review_status: approved without changes
reviewed_by: claude-reviewer
shell_pid: '37215'
subtasks:
- T039
- T040
- T041
- T042
- T043
- T044
- T045
- T046
---

# Work Package Prompt: WP06 – Composite Execution Coordination

## Review Feedback

**Status**: ✅ **Approved Without Changes**

**Key Findings**:
- `CompositePlan.iterator()` method correctly implemented: creates CompositeIterator with proper context
- CompositeIterator class correctly implements QueryIterator role and coordinates subplan iterators
- Execution ordering correctly implemented: supports explicit execution-order or defaults to sequential
- Data flow materialization correctly implemented: materializes all results from subplans (for MVP)
- Result combination correctly implemented: simple concatenation for MVP (join semantics deferred)
- Comprehensive integration tests cover all requirements: composite execution, execution ordering, data flow, and result combination
- Excellent Rakudoc documentation for all classes and methods
- Code follows Raku style guidelines

**What Was Done Well**:
- Clean implementation of CompositeIterator with lazy materialization
- Proper execution ordering support (explicit or sequential)
- Smart materialization strategy (collects all results before returning any - acceptable for MVP)
- Well-structured tests covering single/multiple subplans, execution ordering, and data flow
- Future-proof design: materialization can be enhanced to streaming later
- Proper separation of concerns (CompositeIterator separate from CompositePlan)

**Action Items**: None - implementation is complete and correct.

**Note**: For MVP, results are materialized (all collected before returning any), which is acceptable. Streaming coordination can be added later to reduce memory usage. Result combination uses simple concatenation (join semantics deferred to future enhancement).

---

## Objectives & Success Criteria

- Implement composite execution coordination where Master Walker orchestrates execution of multiple subplans
- Coordinate data flow and result materialization between domains
- Composite plan with multiple subplans executes correctly, results are combined, data flows between domains as expected

**Success**: Composite plan with multiple subplans executes correctly. Results are combined according to query structure. Data flows between domains as expected.

## Context & Constraints

- **Prerequisites**: WP05 (plan-level handover)
- **Related Documents**:
  - `kitty-specs/004-composite-walker-handovers/spec.md` - User Story 4, FR-011 to FR-013
  - `kitty-specs/004-composite-walker-handovers/plan.md` - Composite execution coordination, execution ordering
  - `kitty-specs/004-composite-walker-handovers/research.md` - RQ5: Composite execution coordination
  - `kitty-specs/004-composite-walker-handovers/data-model.md` - Composite Plan execution

- **Architecture Decisions**:
  - For MVP: materialize results from subplans (streaming coordination deferred to future)
  - Execution ordering determined during planning phase
  - Result combination according to query structure (join semantics deferred to future enhancement)

## Subtasks & Detailed Guidance

### Subtask T039 – Implement CompositePlan.iterator() method

- **Purpose**: Create composite iterator that coordinates subplan iterators
- **Steps**:
  1. Implement `method iterator(--> QueryIterator)` in CompositePlan
  2. Create composite iterator class that wraps subplan iterators
  3. Composite iterator implements QueryIterator role
  4. Return composite iterator instance
- **Files**: `lib/Qwiratry/MasterWalker.rakumod` (or CompositePlan module)
- **Parallel?**: No
- **Notes**: Composite iterator coordinates multiple subplan iterators.

### Subtask T040 – Implement composite iterator

- **Purpose**: Coordinate subplan iterators in execution order
- **Steps**:
  1. Create composite iterator class that holds array of subplan iterators
  2. Implement `pull-one()` method that coordinates iteration
  3. For MVP: materialize results from each subplan iterator
  4. Combine results according to execution order
- **Files**: `lib/Qwiratry/MasterWalker.rakumod` (or CompositePlan module)
- **Parallel?**: No (depends on T039)
- **Notes**: For MVP, materialize results. Streaming can be added later.

### Subtask T041 – Implement execution ordering

- **Purpose**: Determine order during planning (dependency analysis or explicit order)
- **Steps**:
  1. During planning phase, determine execution order for subplans
  2. Store execution order in CompositePlan (e.g., `$.execution-order` array of indices)
  3. For MVP: use simple sequential order or explicit order from plan
  4. Dependency analysis can be enhanced later
- **Files**: `lib/Qwiratry/MasterWalker.rakumod` (or CompositePlan module)
- **Parallel?**: No (depends on T040)
- **Notes**: Execution ordering determined during planning, used during execution.

### Subtask T042 – Implement data flow materialization

- **Purpose**: Materialize results from one subplan before feeding to next (for MVP)
- **Steps**:
  1. In composite iterator, iterate through subplans in execution order
  2. For each subplan, materialize all results (collect into array)
  3. Make materialized results available to next subplan (if needed)
  4. For MVP: simple materialization, streaming can be added later
- **Files**: `lib/Qwiratry/MasterWalker.rakumod` (or CompositePlan module)
- **Parallel?**: No (depends on T041)
- **Notes**: For MVP, materialize. Streaming coordination deferred to future.

### Subtask T043 – Implement result combination

- **Purpose**: Combine results from subplans according to query structure
- **Steps**:
  1. After materializing results from all subplans, combine them
  2. For MVP: simple concatenation or list combination
  3. Join semantics (inner join, outer join) deferred to future enhancement
  4. Return combined results as QueryIterator
- **Files**: `lib/Qwiratry/MasterWalker.rakumod` (or CompositePlan module)
- **Parallel?**: No (depends on T042)
- **Notes**: Result combination follows query structure. Join semantics can be enhanced later.

### Subtask T044 – Integration tests: composite execution

- **Purpose**: Verify composite plan execution with multiple subplans
- **Steps**:
  1. Create composite plan with multiple subplans from different walkers
  2. Call `iterator()` on composite plan
  3. Iterate through results
  4. Verify all subplans execute correctly
  5. Verify results are combined correctly
- **Files**: `tests/integration/composite-handover.rakutest`
- **Parallel?**: Yes (can be written once T039-T043 are complete)
- **Notes**: Integration test covering end-to-end execution.

### Subtask T045 – Integration tests: execution ordering

- **Purpose**: Verify execution ordering is correct
- **Steps**:
  1. Create composite plan with subplans that have dependencies
  2. Execute composite plan
  3. Verify subplans execute in correct order
  4. Verify data flows correctly between subplans
- **Files**: `tests/integration/composite-handover.rakutest`
- **Parallel?**: Yes
- **Notes**: Test execution ordering logic.

### Subtask T046 – Integration tests: data flow

- **Purpose**: Verify data flow between domains works correctly
- **Steps**:
  1. Create composite plan with subplans from different domains
  2. Execute composite plan
  3. Verify results from one subplan are available to next (if needed)
  4. Verify data flows correctly between domains
- **Files**: `tests/integration/composite-handover.rakutest`
- **Parallel?**: Yes
- **Notes**: Test data flow coordination.

## Test Strategy

- All tests in `tests/integration/composite-handover.rakutest`
- Use Raku Test module
- Create mock walkers and plans for testing
- Test composite execution, execution ordering, and data flow

## Risks & Mitigations

- **Result materialization memory usage**: For MVP, materialize. Streaming can be added later to reduce memory
- **Join semantics complexity**: Defer to future enhancement. Focus on basic coordination first
- **Execution ordering complexity**: For MVP, use simple sequential order. Dependency analysis can be enhanced later

## Definition of Done Checklist

- [ ] `CompositePlan.iterator()` implemented
- [ ] Composite iterator coordinates subplan iterators
- [ ] Execution ordering determined during planning
- [ ] Data flow materialization works (for MVP)
- [ ] Result combination works according to query structure
- [ ] All integration tests pass
- [ ] Documentation (Rakudoc) added to classes and methods
- [ ] `tasks.md` updated with status change

## Review Guidance

- Verify composite iterator coordinates subplan iterators correctly
- Verify execution ordering is correct
- Verify data flow between domains works correctly
- Verify result combination follows query structure
- Check code follows Raku style guidelines

## Activity Log

- 2025-01-27T00:00:00Z – system – lane=planned – Prompt created.
- 2025-12-19T10:18:17Z – claude – shell_pid=27677 – lane=doing – Started implementation
- 2025-12-19T10:30:00Z – claude – shell_pid=27677 – lane=doing – Completed implementation:
  - Implemented CompositePlan.iterator() method that creates CompositeIterator
  - Implemented CompositeIterator class that coordinates subplan iterators
  - Implemented execution ordering (sequential by default, explicit order supported)
  - Implemented data flow materialization (for MVP, materializes all results)
  - Implemented result combination (for MVP, simple concatenation)
  - Created comprehensive integration tests for composite execution
  - All code compiles successfully
- 2025-12-19T10:25:12Z – claude – shell_pid=28696 – lane=for_review – Ready for review - implementation complete
- 2025-12-19T11:50:00Z – claude-reviewer – shell_pid=37215 – lane=done – Review approved: All requirements met, implementation complete and correct
