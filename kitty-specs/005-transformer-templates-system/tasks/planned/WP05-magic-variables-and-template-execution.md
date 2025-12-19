---
work_package_id: "WP05"
subtasks:
  - "T021"
  - "T022"
  - "T023"
  - "T024"
  - "T025"
  - "T026"
title: "Magic Variables & Template Execution"
phase: "Phase 1 - Foundational"
lane: "planned"
assignee: ""
agent: ""
shell_pid: ""
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2025-01-27T23:45:00Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
---
*Path: [templates/task-prompt-template.md](templates/task-prompt-template.md)*

# Work Package Prompt: WP05 – Magic Variables & Template Execution

## Objectives & Success Criteria

- Set magic variables (`$*CONTEXT`, `$*CAPTURE`, `self`) during template execution
- Implement `Template.matches()` method to evaluate `when` blocks
- Implement `Template.execute()` method to execute `do` blocks
- Magic variables correctly scoped and accessible in template actions
- Templates can match nodes and produce output

## Context & Constraints

- **Prerequisites**: WP03 (template collection), WP04 (template ordering)
- **Related Documents**: 
  - `plan.md` - Magic variables implementation
  - `research.md` - RQ3 (magic variables implementation)
  - `spec.md` - FR-006, FR-007, FR-008 (magic variable requirements)
- **Architecture**: Use Raku dynamic variables (twigil `*`) for `$*CONTEXT` and `$*CAPTURE`
- **Constraints**: Variables must be scoped to template execution, must not leak between templates

## Subtasks & Detailed Guidance

### Subtask T021 – $*CONTEXT and $_ setup

- **Purpose**: Set `$*CONTEXT` and `$_` to current node before template execution
- **Steps**:
  1. In `Template.execute()` method, before executing `do` block, set `my $*CONTEXT = $node;`
  2. Also set `$_ = $node;` (convenience alias)
  3. Ensure variables are scoped to template execution (use lexical scoping)
  4. Variables should be available in `when` and `do` blocks
- **Files**: `lib/Qwiratry/Template.rakumod`
- **Parallel?**: No
- **Notes**: Use Raku dynamic variables. Set before block execution, scope properly.

### Subtask T022 – $*CAPTURE and $/ setup

- **Purpose**: Set `$*CAPTURE` and `$/` to template signature parameters if template has signature
- **Steps**:
  1. In `Template.execute()` method, check if template has signature
  2. If signature exists, match node against signature to capture parameters
  3. Set `my $*CAPTURE = $match;` where `$match` contains captured parameters
  4. Also set `$/ = $*CAPTURE;` (convenience alias)
  5. If no signature, set `$*CAPTURE` to Nil or empty Match
- **Files**: `lib/Qwiratry/Template.rakumod`
- **Parallel?**: No (depends on T021)
- **Notes**: Template signature matching may need coordination with query system. Start with basic cases.

### Subtask T023 – self reference

- **Purpose**: Ensure `self` refers to Transformer object in template actions
- **Steps**:
  1. Verify that `self` is automatically available in template `do` blocks (Raku default behavior)
  2. Ensure template execution context has `self` referring to Transformer
  3. Test that `self` can be used in template actions
- **Files**: `lib/Qwiratry/Template.rakumod`
- **Parallel?**: No (depends on T021)
- **Notes**: `self` should be automatic in Raku methods/blocks. Verify it works correctly.

### Subtask T024 – Template.matches method

- **Purpose**: Evaluate `when` block against node to determine if template matches
- **Steps**:
  1. Implement `Template.matches($node --> Bool)` method
  2. Set `$*CONTEXT = $node` and `$_ = $node` before evaluating `when` block
  3. Execute `when` block with magic variables set
  4. Return result (must be Bool - coerce if needed)
  5. Handle errors gracefully (return False if evaluation fails)
- **Files**: `lib/Qwiratry/Template.rakumod`
- **Parallel?**: No (depends on T021)
- **Notes**: `when` block should return Bool. Coerce result if needed. Handle exceptions.

### Subtask T025 – Template.execute method

- **Purpose**: Execute `do` block with magic variables set and return result
- **Steps**:
  1. Implement `Template.execute($node, :$context --> Iterator|Mu|List|Nil)` method
  2. Set all magic variables: `$*CONTEXT`, `$_`, `$*CAPTURE`, `$/`, `self`
  3. Execute `do` block with magic variables set
  4. Handle `make` calls (add results to output stream)
  5. Handle return values (if no `make`, use return value)
  6. Return result (Iterator, List, single value, or Nil)
- **Files**: `lib/Qwiratry/Template.rakumod`
- **Parallel?**: No (depends on T021-T023)
- **Notes**: Support both `make` and return value patterns. Handle streaming if template has `:streaming` trait.

### Subtask T026 – Unit tests for magic variables

- **Purpose**: Verify magic variables are correctly set and accessible
- **Steps**:
  1. Test `$*CONTEXT` contains current node in template action
  2. Test `$_` contains current node (alias for `$*CONTEXT`)
  3. Test `$*CAPTURE` contains template parameters when template has signature
  4. Test `$/` contains template parameters (alias for `$*CAPTURE`)
  5. Test `self` refers to Transformer object
  6. Test magic variables don't leak between templates
  7. Test magic variables are Nil/undefined outside template execution
- **Files**: `tests/unit/magic-variables.rakutest`
- **Parallel?**: Yes
- **Notes**: Test all magic variables, scoping, and edge cases.

## Test Strategy

- **Unit tests**: Test magic variable availability, correctness, scoping
- **Test location**: `tests/unit/magic-variables.rakutest`

## Risks & Mitigations

- **Dynamic variable scoping**: Ensure proper lexical scoping, test thoroughly
- **Variable leakage**: Use proper scope boundaries, test isolation
- **Signature matching**: May need coordination with query system

## Definition of Done Checklist

- [ ] `$*CONTEXT` and `$_` set correctly before template execution
- [ ] `$*CAPTURE` and `$/` set correctly for templates with signatures
- [ ] `self` refers to Transformer object
- [ ] `Template.matches()` method implemented and tested
- [ ] `Template.execute()` method implemented and tested
- [ ] Magic variables don't leak between templates
- [ ] Unit tests pass
- [ ] `tasks.md` updated with status change

## Activity Log

- 2025-01-27T23:45:00Z – system – lane=planned – Prompt created.

