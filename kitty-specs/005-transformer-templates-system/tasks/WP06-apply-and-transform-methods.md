---
work_package_id: WP06
title: APPLY & TRANSFORM Methods
lane: for_review
history:
- timestamp: '2025-01-27T23:45:00Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
- timestamp: '2025-01-28T09:30:00Z'
  lane: doing
  agent: claude
  shell_pid: '60476'
  action: Started implementation
- timestamp: '2025-01-28T10:15:00Z'
  lane: for_review
  agent: claude
  shell_pid: '61293'
  action: 'WP06 implementation complete: All subtasks (T027-T032) implemented. APPLY, TRANSFORM, transform methods working. WalkerFactory created. Default iterator implemented. All integration tests passing (5/5).'
agent: claude
assignee: claude
phase: Phase 2 - Core
review_status: ''
reviewed_by: ''
shell_pid: '61293'
subtasks:
- T027
- T028
- T029
- T030
- T031
- T032
---
*Path: [templates/task-prompt-template.md](templates/task-prompt-template.md)*

# Work Package Prompt: WP06 – APPLY & TRANSFORM Methods

## Objectives & Success Criteria

- Implement `APPLY` method that applies templates to a single node
- Implement Walker factory/registry for automatic Walker selection
- Implement `TRANSFORM` method that orchestrates full transformation
- Implement `transform` method that determines mode and delegates
- Can transform data structures using transformers with templates

## Context & Constraints

- **Prerequisites**: WP04 (template ordering), WP05 (template execution)
- **Related Documents**: 
  - `plan.md` - Architecture decision #4 (Walker integration), TRANSFORM/APPLY methods
  - `research.md` - RQ5 (Walker factory pattern)
  - `spec.md` - FR-012, FR-014, FR-019, FR-021 (transformation methods)
- **Architecture**: Walker factory pattern for automatic selection, default iterator for traversal
- **Constraints**: Must integrate with existing Walker system, must support all transformation modes

## Subtasks & Detailed Guidance

### Subtask T027 – APPLY method

- **Purpose**: Apply templates to a single node, return first matching template result
- **Steps**:
  1. Implement `APPLY($node --> Iterator|Mu|List|Nil)` method on Transformer class
  2. Iterate through `@.ordered-templates` (call `ORDER-TEMPLATES` if not already ordered)
  3. For each template, call `template.matches($node)` to check if it matches
  4. For first matching template, call `template.execute($node)` and return result
  5. Stop processing after first match (no fallback to other templates)
  6. If no templates match, return empty sequence (Nil or empty List)
- **Files**: `lib/Qwiratry/Transformer.rakumod`
- **Parallel?**: No
- **Notes**: First match wins. No fallback. Deterministic behavior.

### Subtask T028 – Walker factory

- **Purpose**: Create factory/registry for selecting appropriate Walker based on data type
- **Steps**:
  1. Create `WalkerFactory` class in `lib/Qwiratry/WalkerFactory.rakumod` (or extend existing)
  2. Implement `get-walker($data --> Walker?)` method
  3. Selection logic: check if data does specific role (e.g., `Positional` for tables), use type name, or heuristic
  4. Support explicit registration: `register-walker($type, Walker)`
  5. Support automatic discovery: `discover-walkers(--> Array[Walker])` (optional)
  6. Return Walker instance or Nil if none found
- **Files**: `lib/Qwiratry/WalkerFactory.rakumod` (or existing file)
- **Parallel?**: No
- **Notes**: Factory enables automatic Walker selection. Can be extended later.

### Subtask T029 – TRANSFORM method

- **Purpose**: Main transformation method that orchestrates full transformation
- **Steps**:
  1. Implement `TRANSFORM($data, Iterator :$iterator --> Iterator|Mu|List|Nil)` method
  2. Call `ORDER-TEMPLATES` to prepare templates (cache result)
  3. Obtain Walker via factory: `WalkerFactory.get-walker($data)`
  4. Create iterator: use provided `:$iterator` or default (depth-first, top-down)
  5. Iterate over data nodes using iterator
  6. For each node, call `APPLY($node)` to apply templates
  7. Collect results (handle streaming if transformer has `:streaming` trait)
  8. Return results (Iterator if streaming, List or single value otherwise)
- **Files**: `lib/Qwiratry/Transformer.rakumod`
- **Parallel?**: No (depends on T027, T028)
- **Notes**: This is the main transformation orchestration. Handles Walker integration and iteration.

### Subtask T030 – Default iterator

- **Purpose**: Provide default iterator (depth-first, top-down) or use Walker-provided iterator
- **Steps**:
  1. If no iterator provided, create default depth-first, top-down iterator
  2. Or use Walker's iterator if Walker provides one
  3. Iterator should produce nodes lazily (for streaming support)
  4. Iterator should work with various data structure types
- **Files**: `lib/Qwiratry/Transformer.rakumod`
- **Parallel?**: No (depends on T029)
- **Notes**: Default iterator may be provided by Walker system or implemented here. Check existing Walker infrastructure.

### Subtask T031 – transform method

- **Purpose**: Transformation entrypoint that determines mode and delegates
- **Steps**:
  1. Implement `transform($input, :$context, :$streaming, :$mode --> Iterator|Mu|List|Nil)` method
  2. Determine mode: if `:mode` provided, use it; otherwise auto-detect based on input type
  3. Mode detection: if `$input` is QueryIterator, use `post` mode; if single element, use `inline`; if whole structure, use `pre` or `default`
  4. Delegate to appropriate method: `prepare()` for `pre`, `apply()` for `inline`, `_transform_iterator()` for `post`
  5. For `default` mode, call `TRANSFORM` directly
  6. Handle `:streaming` override (if provided, override trait setting)
- **Files**: `lib/Qwiratry/Transformer.rakumod`
- **Parallel?**: No (depends on T029)
- **Notes**: This is the public API entrypoint. Handles mode detection and delegation.

### Subtask T032 – Integration tests

- **Purpose**: Verify transformer integrates correctly with Walker system
- **Steps**:
  1. Test transformer with existing Walker (from feature 002)
  2. Test end-to-end transformation: declare transformer, apply to data, verify output
  3. Test Walker factory: automatic selection and explicit override
  4. Test transformation modes: pre, inline, post (basic cases)
  5. Test streaming: verify lazy evaluation works
- **Files**: `tests/integration/transformer-walker.rakutest`
- **Parallel?**: Yes
- **Notes**: Test integration with existing infrastructure. Verify end-to-end scenarios.

## Test Strategy

- **Integration tests**: Test transformer-Walker integration, end-to-end transformations
- **Test location**: `tests/integration/transformer-walker.rakutest`

## Risks & Mitigations

- **Walker integration complexity**: Start with simple Walker, extend for complex cases
- **Iterator coordination**: Ensure proper state management, test thoroughly
- **Mode detection**: Use conservative approach, test all modes

## Definition of Done Checklist

- [x] `APPLY` method implemented and tested
- [x] Walker factory implemented and tested
- [x] `TRANSFORM` method implemented and tested
- [x] Default iterator implemented or uses Walker-provided iterator
- [x] `transform` method implemented with mode detection
- [x] Integration tests pass
- [x] Can transform data structures end-to-end
- [x] `tasks.md` updated with status change

## Activity Log

- 2025-01-27T23:45:00Z – system – lane=planned – Prompt created.
- 2025-01-28T09:30:00Z – claude – shell_pid=60476 – lane=doing – Started implementation: Implementing APPLY, TRANSFORM, transform methods and Walker factory.
- 2025-01-28T10:00:00Z – claude – shell_pid=61293 – lane=doing – Completed T027-T031: Implemented APPLY method (first match wins), WalkerFactory class with get-walker and register-walker, TRANSFORM method with Walker integration, default iterator for basic structures, transform() entrypoint with mode detection. Updated CALL-ME to delegate to transform().
- 2025-01-28T10:15:00Z – claude – shell_pid=61293 – lane=doing – Completed T032: Added comprehensive integration tests. All tests passing (5/5 subtests). Tests cover APPLY, Walker factory, TRANSFORM, default iterator, and transform() entrypoint. Ready for review.

