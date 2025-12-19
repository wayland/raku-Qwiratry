---
work_package_id: "WP03"
subtasks:
  - "T015"
  - "T016"
  - "T017"
  - "T018"
  - "T019"
  - "T020"
  - "T021"
title: "RewriteSpec and FinishResult Stub Types"
phase: "Phase 1 - Foundational"
lane: "doing"
assignee: "claude"
agent: "claude"
shell_pid: "126866"
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2024-12-19T09:45:00Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
---

# Work Package Prompt: WP03 - RewriteSpec and FinishResult Stub Types

## Objectives & Success Criteria

- RewriteSpec role exists as a type marker (stub for future expansion)
- FinishResult class has `type` (required) and `value` (optional) attributes
- FinishResult has a `gist` method for human-readable output
- Both types can be used in method signatures and return values
- Unit tests verify construction and basic usage

## Context & Constraints

**Reference Documents**:
- `kitty-specs/003-strategy-and-controlsignal/data-model.md` - Entity definitions
- `kitty-specs/003-strategy-and-controlsignal/contracts/strategy-api.md` - API contract

**RewriteSpec** (from data-model.md):
- Stub role for rewrite specifications
- No attributes or methods defined (marker role)
- Purpose: Type marker for rewrite return values from on-match and after hooks

**FinishResult** (from data-model.md):
- `$.type` - Str, required - Result type identifier
- `$.value` - Mu, optional - The result value (can be any type)
- `gist()` method for human-readable representation

**Constraints**:
- RewriteSpec intentionally minimal (stub)
- FinishResult.new(:type!) requires type parameter

## Subtasks & Detailed Guidance

### Subtask T015 - Write unit tests for RewriteSpec role [P]
- **Purpose**: Define expected behaviour for stub role
- **File**: `tests/unit/rewrite-spec.rakutest`
- **Steps**:
  1. Test that a class can compose RewriteSpec
  2. Test that objects doing RewriteSpec can be type-checked
- **Example Tests**:
```raku
use Test;
use Qwiratry::RewriteSpec;

plan 2;

subtest 'RewriteSpec can be composed', {
    my class TestRewrite does RewriteSpec { }
    my $r = TestRewrite.new;
    ok $r.defined, 'Can create instance of class doing RewriteSpec';
    ok $r ~~ RewriteSpec, 'Instance does RewriteSpec role';
}

subtest 'Type checking works', {
    my class TestRewrite does RewriteSpec { }
    my sub takes-rewrite(RewriteSpec $r) { $r }
    my $r = TestRewrite.new;
    is takes-rewrite($r), $r, 'Can pass to typed parameter';
}
```

### Subtask T016 - Write unit tests for FinishResult class [P]
- **Purpose**: Define expected behaviour for FinishResult
- **File**: `tests/unit/finish-result.rakutest`
- **Steps**:
  1. Test construction with required type parameter
  2. Test construction with type and value
  3. Test that type is required (dies without it)
  4. Test gist() output format
- **Example Tests**:
```raku
use Test;
use Qwiratry::FinishResult;

plan 4;

subtest 'Construction with type only', {
    my $r = FinishResult.new(type => 'final-result');
    is $r.type, 'final-result', 'type attribute set';
    ok !$r.value.defined, 'value is undefined by default';
}

subtest 'Construction with type and value', {
    my $r = FinishResult.new(type => 'aggregated', value => [1, 2, 3]);
    is $r.type, 'aggregated', 'type attribute set';
    is-deeply $r.value, [1, 2, 3], 'value attribute set';
}

subtest 'Type is required', {
    dies-ok { FinishResult.new() }, 'Dies without type parameter';
    dies-ok { FinishResult.new(value => 42) }, 'Dies with only value';
}

subtest 'Gist output', {
    my $r = FinishResult.new(type => 'test', value => 'hello');
    like $r.gist, /FinishResult/, 'gist contains class name';
    like $r.gist, /test/, 'gist contains type';
}
```

### Subtask T017 - Implement RewriteSpec as empty marker role [P]
- **Purpose**: Create the stub role
- **File**: `lib/Qwiratry/RewriteSpec.rakumod`
- **Implementation**:
```raku
unit module Qwiratry::RewriteSpec;

#| Stub role for rewrite specifications.
#| To be expanded in future feature when rewrite functionality is implemented.
#| Currently serves as a type marker for return values from on-match and after hooks.
role RewriteSpec is export {
    # Marker role - no methods required
}
```

### Subtask T018 - Implement FinishResult class [P]
- **Purpose**: Create the result class with type and value
- **File**: `lib/Qwiratry/FinishResult.rakumod`
- **Implementation**:
```raku
unit module Qwiratry::FinishResult;

#| Result object returned from Strategy.finish() hook.
#| Contains the traversal outcome with a type identifier and optional value.
class FinishResult is export {
    #| Result type identifier (e.g., 'final-result', 'aggregated', 'error')
    has Str $.type is required;
    
    #| The result value (can be any type including Nil)
    has $.value;
}
```

### Subtask T019 - Add gist method to FinishResult [P]
- **Purpose**: Human-readable representation
- **File**: `lib/Qwiratry/FinishResult.rakumod`
- **Steps**:
  1. Add `method gist(--> Str)` to class
  2. Format: `FinishResult(type: <type>, value: <value.gist>)`
- **Implementation**:
```raku
#| Human-readable representation
method gist(--> Str) {
    "FinishResult(type: $.type, value: {$.value.gist})"
}
```

### Subtask T020 - Add Rakudoc documentation
- **Purpose**: Document both types
- **Files**: `lib/Qwiratry/RewriteSpec.rakumod`, `lib/Qwiratry/FinishResult.rakumod`
- **Steps**:
  1. Add module-level Rakudoc for each file
  2. Document RewriteSpec as a stub for future expansion
  3. Document FinishResult attributes and construction

### Subtask T021 - Verify all tests pass
- **Purpose**: Confirm implementations match tests
- **Steps**:
  1. Run: `raku tests/unit/rewrite-spec.rakutest`
  2. Run: `raku tests/unit/finish-result.rakutest`
  3. All tests should pass

## Parallel Opportunities

- T015-T019 can all proceed in parallel (different files/concerns)
- T020 can run after T017-T019
- T021 runs last

## Risks & Mitigations

- **Required attribute enforcement**: Use `is required` trait on FinishResult.type
- **Value type flexibility**: Use `$.value` without type constraint to accept any type

## Definition of Done Checklist

- [ ] RewriteSpec unit tests written (T015)
- [ ] FinishResult unit tests written (T016)
- [ ] RewriteSpec role implemented (T017)
- [ ] FinishResult class implemented (T018)
- [ ] FinishResult.gist() method added (T019)
- [ ] Rakudoc documentation added (T020)
- [ ] All tests pass (T021)
- [ ] `tasks.md` updated with status change

## Review Guidance

- RewriteSpec should be intentionally empty (stub)
- FinishResult.new(:type!) should fail without type
- FinishResult.value can hold any type including Nil

## Activity Log

- 2024-12-19T09:45:00Z - system - lane=planned - Prompt created.
- 2024-12-19T10:35:00Z - claude - shell_pid=126866 - lane=doing - Started implementation

