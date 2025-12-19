---
work_package_id: "WP05"
subtasks:
  - "T028"
  - "T029"
  - "T030"
  - "T031"
  - "T032"
  - "T033"
  - "T034"
  - "T035"
  - "T036"
  - "T037"
  - "T038"
title: "Plan-Level Handover with Embedded Subplans"
phase: "Phase 2 - Core"
lane: "for_review"
assignee: ""
agent: "claude"
shell_pid: "24784"
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2025-01-27T00:00:00Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
---

# Work Package Prompt: WP05 – Plan-Level Handover with Embedded Subplans

## Objectives & Success Criteria

- Implement CompositePlan class that implements Walker::Plan role with embedded subplans
- Implement MasterWalker.plan() method that detects handovers, delegates planning, and embeds subplans
- Master Walker detects handover, delegates planning to domain-specific walker, receives Walker::Plan, embeds as subplan
- Composite plan contains embedded subplans from multiple walkers

**Success**: Master Walker detects handover, delegates planning to domain-specific walker, receives Walker::Plan, embeds as subplan in composite plan. Composite plan.query() returns original query AST.

## Context & Constraints

- **Prerequisites**: WP04 (handover detection)
- **Related Documents**:
  - `kitty-specs/004-composite-walker-handovers/spec.md` - User Story 3, FR-008 to FR-010
  - `kitty-specs/004-composite-walker-handovers/plan.md` - Composite plan structure, plan-level handover
  - `kitty-specs/004-composite-walker-handovers/research.md` - RQ3: Composite plan structure with subplans
  - `kitty-specs/004-composite-walker-handovers/data-model.md` - Composite Plan entity

- **Architecture Decisions**:
  - CompositePlan implements Walker::Plan role
  - Subplans are Array[Walker::Plan] from delegated walkers
  - Plan immutability: don't mutate original query AST
  - All handover decisions made during planning phase

## Subtasks & Detailed Guidance

### Subtask T028 – Implement CompositePlan class

- **Purpose**: Create CompositePlan class implementing Walker::Plan role
- **Steps**:
  1. In `lib/Qwiratry/MasterWalker.rakumod` (or separate module), create `class CompositePlan does Walker::Plan`
  2. Implement required methods: `iterator()`, `query()`, `describe()`
  3. Add placeholder implementations (iterator will be implemented in WP06)
- **Files**: `lib/Qwiratry/MasterWalker.rakumod` (or `lib/Qwiratry/CompositePlan.rakumod`)
- **Parallel?**: No
- **Notes**: Can be in same module as MasterWalker or separate. Follow plan.md structure decision.

### Subtask T029 – Implement CompositePlan attributes

- **Purpose**: Store query AST, subplans, and execution metadata
- **Steps**:
  1. Add attribute `has RakuAST::Node $.query-ast`
  2. Add attribute `has Array[Walker::Plan] @.subplans`
  3. Add optional attribute `has Array[Int] $.execution-order` for future use
  4. Initialize in constructor
- **Files**: `lib/Qwiratry/MasterWalker.rakumod` (or CompositePlan module)
- **Parallel?**: No (depends on T028)
- **Notes**: Attributes must support plan immutability.

### Subtask T030 – Implement CompositePlan.subplans() method

- **Purpose**: Return array of embedded subplans
- **Steps**:
  1. Implement `method subplans(--> Array[Walker::Plan])`
  2. Return `@.subplans` array
  3. Ensure method signature matches Walker::Plan role
- **Files**: `lib/Qwiratry/MasterWalker.rakumod` (or CompositePlan module)
- **Parallel?**: No (depends on T029)
- **Notes**: Required method from Walker::Plan role.

### Subtask T031 – Implement MasterWalker.plan() method

- **Purpose**: Detect handovers, delegate planning, embed subplans
- **Steps**:
  1. Implement `method plan(RakuAST::Node $query, Mu $root --> Walker::Plan)`
  2. Call `detect-handover()` to find if handover needed
  3. If handover needed, extract subtree and delegate to domain-specific walker
  4. Receive Walker::Plan from delegated walker
  5. Create CompositePlan with original query AST and embedded subplan
  6. Return CompositePlan
- **Files**: `lib/Qwiratry/MasterWalker.rakumod`
- **Parallel?**: No (depends on T028-T030, WP04)
- **Notes**: This is the core planning method that orchestrates handovers.

### Subtask T032 – Implement AST subtree extraction

- **Purpose**: Extract relevant subtree from query for delegation
- **Steps**:
  1. Implement helper method to extract AST subtree
  2. Determine which part of query should be delegated (may be entire query or subtree)
  3. Extract subtree without mutating original query AST
  4. Return extracted subtree
- **Files**: `lib/Qwiratry/MasterWalker.rakumod`
- **Parallel?**: No (depends on T031)
- **Notes**: For MVP, may delegate entire query. Subtree extraction can be enhanced later.

### Subtask T033 – Implement delegation to walkers

- **Purpose**: Call domain-specific walker's plan() method and receive Walker::Plan
- **Steps**:
  1. After detecting handover and extracting subtree, call `$walker.plan($subtree, $root)`
  2. Receive Walker::Plan from delegated walker
  3. Handle exceptions if walker cannot plan (should throw X::Qwiratry::UnknownQueryElement)
- **Files**: `lib/Qwiratry/MasterWalker.rakumod`
- **Parallel?**: No (depends on T032)
- **Notes**: Delegation happens during planning phase, not execution.

### Subtask T034 – Implement subplan embedding

- **Purpose**: Add delegated plan to CompositePlan.subplans array
- **Steps**:
  1. After receiving Walker::Plan from delegated walker, add to CompositePlan's subplans array
  2. Ensure subplan is stored correctly
  3. CompositePlan should contain both original query AST and embedded subplans
- **Files**: `lib/Qwiratry/MasterWalker.rakumod` (or CompositePlan module)
- **Parallel?**: No (depends on T033)
- **Notes**: Subplans are embedded, not replacing the original plan.

### Subtask T035 – Unit tests: handover delegation

- **Purpose**: Verify handover detection triggers delegation
- **Steps**:
  1. Create MasterWalker with mock walkers
  2. Create root object with `provides<sql>` trait
  3. Call `plan()` with query
  4. Verify handover is detected and delegation occurs
  5. Verify delegated walker's `plan()` is called
- **Files**: `tests/unit/master-walker.rakutest`
- **Parallel?**: Yes (can be written once T031-T034 are complete)
- **Notes**: Test that handover triggers delegation correctly.

### Subtask T036 – Unit tests: composite plan subplans

- **Purpose**: Verify composite plan contains embedded subplans
- **Steps**:
  1. Create composite plan with subplans
  2. Call `subplans()` method
  3. Verify returned array contains expected subplans
  4. Verify subplans are valid Walker::Plan instances
- **Files**: `tests/unit/master-walker.rakutest`
- **Parallel?**: Yes
- **Notes**: Test subplan embedding works correctly.

### Subtask T037 – Unit tests: composite plan query()

- **Purpose**: Verify composite plan.query() returns original query AST
- **Steps**:
  1. Create composite plan with original query AST
  2. Call `query()` method
  3. Verify returned AST is the original query (not modified subtrees)
  4. Verify AST is not mutated
- **Files**: `tests/unit/master-walker.rakutest`
- **Parallel?**: Yes
- **Notes**: Test plan immutability.

### Subtask T038 – Unit tests: plan immutability

- **Purpose**: Verify subplans don't mutate original query AST
- **Steps**:
  1. Create original query AST
  2. Create composite plan with subplans
  3. Verify original query AST is unchanged after planning
  4. Verify subplans have their own query ASTs (extracted subtrees)
- **Files**: `tests/unit/master-walker.rakutest`
- **Parallel?**: Yes
- **Notes**: Test that planning doesn't mutate original query.

## Test Strategy

- All tests in `tests/unit/master-walker.rakutest`
- Use Raku Test module
- Create mock walkers and plans for testing
- Test handover delegation, subplan embedding, and plan immutability

## Risks & Mitigations

- **Subtree extraction complexity**: For MVP, delegate entire query. Subtree extraction can be enhanced later
- **Plan immutability**: Ensure delegated walkers don't mutate original query AST. Validate in tests
- **Multiple handovers**: For MVP, handle single handover. Multiple handovers can be enhanced later

## Definition of Done Checklist

- [ ] CompositePlan class implements Walker::Plan role
- [ ] CompositePlan attributes store query AST and subplans
- [ ] `subplans()` method returns embedded subplans
- [ ] `MasterWalker.plan()` detects handovers and delegates
- [ ] AST subtree extraction works (or delegates entire query for MVP)
- [ ] Delegation to walkers works correctly
- [ ] Subplan embedding works correctly
- [ ] All unit tests pass
- [ ] Documentation (Rakudoc) added to classes and methods
- [ ] `tasks.md` updated with status change

## Review Guidance

- Verify CompositePlan implements Walker::Plan correctly
- Verify handover triggers delegation correctly
- Verify subplans are embedded correctly
- Verify plan immutability (original query AST not mutated)
- Check code follows Raku style guidelines

## Activity Log

- 2025-01-27T00:00:00Z – system – lane=planned – Prompt created.
- 2025-12-19T09:53:37Z – claude – shell_pid=23956 – lane=doing – Started implementation
- 2025-12-19T10:10:00Z – claude – shell_pid=23956 – lane=doing – Completed implementation:
  - Implemented CompositePlan class implementing Walker::Plan role
  - Implemented CompositePlan attributes (query-ast, subplans, execution-order)
  - Implemented CompositePlan.subplans() method
  - Implemented MasterWalker.plan() method with handover detection and delegation
  - Implemented extract-subtree() method (for MVP, delegates entire query)
  - Implemented delegate-planning() method with exception handling
  - Updated plan() method to create CompositePlan with embedded subplans
  - Created comprehensive unit tests for CompositePlan and plan-level handover
  - All code compiles successfully
- 2025-12-19T10:00:06Z – claude – shell_pid=24784 – lane=for_review – Ready for review - implementation complete
