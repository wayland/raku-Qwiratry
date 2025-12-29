---
work_package_id: WP09
title: Traits & Advanced Features
lane: doing
history:
- timestamp: '2025-01-27T23:45:00Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
- timestamp: '2025-01-28T13:20:00Z'
  lane: doing
  agent: claude
  shell_pid: '86470'
  action: Started implementation
agent: claude
assignee: claude
phase: Phase 3 - Polish
review_status: ''
reviewed_by: ''
shell_pid: '86470'
subtasks:
- T052
- T053
- T054
- T055
- T056
- T057
- T058
- T059
- T060
---
*Path: [templates/task-prompt-template.md](templates/task-prompt-template.md)*

# Work Package Prompt: WP09 – Traits & Advanced Features

## Objectives & Success Criteria

- Implement `:streaming` trait for lazy iterator-based output
- Implement `returns(Type)` trait for output type checking
- Implement `does TreeRewrite` role for in-place rewriting
- Implement transformation modes: pre, inline, post, rewrite modes
- All traits and modes work correctly

## Context & Constraints

- **Prerequisites**: WP06 (APPLY & TRANSFORM methods)
- **Related Documents**: 
  - `plan.md` - Trait support, transformation modes
  - `spec.md` - FR-009, FR-010, FR-011, FR-021 (traits and modes)
  - `contracts/transformer-api.md` - Trait and mode specifications
- **Architecture**: Traits applied at compile-time, inspectable at runtime
- **Constraints**: Traits must not mutate input unless combined with TreeRewrite

## Subtasks & Detailed Guidance

### Subtask T052 – :streaming trait

- **Purpose**: Enable lazy iterator-based output using `gather/take`
- **Steps**:
  1. Detect `:streaming` trait on transformer or template (via `.^traits` or meta-object)
  2. If transformer has `:streaming`, use `gather/take` in `TRANSFORM` method
  3. If template has `:streaming`, use `gather/take` in `Template.execute` method
  4. Ensure results are produced lazily (iterator-based)
  5. Store `$.streaming` attribute on Transformer/Template
- **Files**: `lib/Qwiratry/Transformer.rakumod`, `lib/Qwiratry/Template.rakumod`
- **Parallel?**: No
- **Notes**: Streaming uses `gather/take` for lazy evaluation. Transformer-level affects all templates, template-level affects only that template.

### Subtask T053 – returns(Type) trait

- **Purpose**: Enforce output type checking for transformers and templates
- **Steps**:
  1. Detect `returns(Type)` trait on transformer or template
  2. Extract type from trait parameter
  3. Store type in `$.returns-type` attribute
  4. After transformation/template execution, check if result conforms to type
  5. Throw error if result doesn't conform to type
- **Files**: `lib/Qwiratry/Transformer.rakumod`, `lib/Qwiratry/Template.rakumod`
- **Parallel?**: No
- **Notes**: Type checking happens at runtime after execution. Use type smartmatch or similar.

### Subtask T054 – does TreeRewrite role

- **Purpose**: Override APPLY method for in-place rewriting
- **Steps**:
  1. Create `TreeRewrite` role (if not exists)
  2. Role should override `APPLY` method with rewriting behavior
  3. When `does TreeRewrite` is applied to transformer, mix in the role
  4. In rewriting APPLY, `make` immediately replaces current node
  5. Set `$.mutates-input = True` when TreeRewrite is applied
- **Files**: `lib/Qwiratry/Transformer.rakumod` (or separate role file)
- **Parallel?**: No
- **Notes**: TreeRewrite modifies APPLY behavior. `make` replaces node immediately in rewriting mode.

### Subtask T055 – prepare method

- **Purpose**: Pre-transformation stage (before traversal)
- **Steps**:
  1. Implement `prepare($data, :$ctx)` method on Transformer class
  2. Called when `transform` is called with `:mode<pre>`
  3. Operates on whole data structure before traversal
  4. Can modify or annotate structure
  5. Returns potentially modified structure
- **Files**: `lib/Qwiratry/Transformer.rakumod`
- **Parallel?**: No
- **Notes**: Pre-transformation happens before Walker traversal. Can prepare data for transformation.

### Subtask T056 – apply method (inline)

- **Purpose**: Inline transformation stage (during traversal)
- **Steps**:
  1. Implement `apply($element, :$ctx, :$mode)` method on Transformer class
  2. Called when `transform` is called with `:mode<inline>`
  3. Operates on each element during traversal
  4. Can mutate in-place if `$.mutates-input` is true
  5. Returns transformed element
- **Files**: `lib/Qwiratry/Transformer.rakumod`
- **Parallel?**: No
- **Notes**: Inline transformation happens during Walker traversal. Can mutate if allowed.

### Subtask T057 – Mode detection

- **Purpose**: Auto-detect transformation mode based on input type
- **Steps**:
  1. In `transform` method, if `:mode` is `default`, detect mode from input type
  2. If `$input` is QueryIterator, use `post` mode
  3. If `$input` is single element (heuristic), use `inline` mode
  4. If `$input` is whole structure, use `pre` or `default` mode
  5. Delegate to appropriate method based on detected mode
- **Files**: `lib/Qwiratry/Transformer.rakumod`
- **Parallel?**: No (depends on T055, T056)
- **Notes**: Mode detection enables convenient API. Use conservative heuristics.

### Subtask T058 – Rewrite modes

- **Purpose**: Implement `rewrite-optional` and `rewrite-mandatory` modes
- **Steps**:
  1. Handle `:mode<rewrite-optional>`: transformations may optionally mutate nodes
  2. Handle `:mode<rewrite-mandatory>`: forces rewrite if possible
  3. These modes inform how `apply` method behaves
  4. Coordinate with TreeRewrite role if applied
- **Files**: `lib/Qwiratry/Transformer.rakumod`
- **Parallel?**: No (depends on T056)
- **Notes**: Rewrite modes control mutation behavior. Coordinate with TreeRewrite.

### Subtask T059 – Unit tests for traits

- **Purpose**: Verify traits work correctly
- **Steps**:
  1. Test `:streaming` trait: verify lazy iterator output
  2. Test `returns(Type)` trait: verify type checking
  3. Test `does TreeRewrite` role: verify in-place rewriting
  4. Test trait combination: multiple traits can be combined
  5. Test trait introspection: traits inspectable at runtime
- **Files**: `tests/unit/transformer.rakutest`
- **Parallel?**: Yes
- **Notes**: Test all traits, combinations, introspection.

### Subtask T060 – Unit tests for modes

- **Purpose**: Verify transformation modes work correctly
- **Steps**:
  1. Test `pre` mode: `prepare` method called
  2. Test `inline` mode: `apply` method called during traversal
  3. Test `post` mode: consumes QueryIterator
  4. Test `default` mode: auto-detection works
  5. Test `rewrite-optional` and `rewrite-mandatory` modes
- **Files**: `tests/unit/transformer.rakutest`
- **Parallel?**: Yes
- **Notes**: Test all modes, mode detection, mode-specific behavior.

## Test Strategy

- **Unit tests**: Test all traits and transformation modes
- **Test location**: `tests/unit/transformer.rakutest`

## Risks & Mitigations

- **Trait introspection complexity**: Use Raku's `.^traits` mechanism
- **Streaming coordination**: Ensure proper iterator handling
- **Mode detection accuracy**: Use conservative heuristics, test thoroughly

## Definition of Done Checklist

- [ ] `:streaming` trait implemented and tested
- [ ] `returns(Type)` trait implemented and tested
- [ ] `does TreeRewrite` role implemented and tested
- [ ] All transformation modes implemented and tested
- [ ] Mode detection works correctly
- [ ] Traits can be combined
- [ ] Unit tests pass
- [ ] `tasks.md` updated with status change

## Activity Log

- 2025-01-27T23:45:00Z – system – lane=planned – Prompt created.

