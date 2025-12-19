---
work_package_id: "WP02"
subtasks:
  - "T010"
  - "T011"
  - "T012"
  - "T013"
  - "T014"
title: "ControlSignal Enum"
phase: "Phase 1 - Foundational"
lane: "for_review"
assignee: "claude"
agent: "claude"
shell_pid: "117738"
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2024-12-19T09:45:00Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
---

# Work Package Prompt: WP02 - ControlSignal Enum

## Objectives & Success Criteria

- ControlSignal enum with 6 values is defined and exported
- Each value has documented semantics
- Unit tests verify all values are accessible
- Enum can be used as return type from methods

## Context & Constraints

**Reference Documents**:
- `Specification.md` section 3.2.6 - ControlSignal definition
- `kitty-specs/003-strategy-and-controlsignal/data-model.md` - Value semantics table
- `kitty-specs/003-strategy-and-controlsignal/contracts/strategy-api.md` - API contract

**Specification Definition** (3.2.6):
```raku
enum ControlSignal <
    NO_REWRITE REWRITE_IMMEDIATE REWRITE_DEFERRED
    SKIP_ELEMENT STOP_TRAVERSAL FINAL_RESULT
>;
```

**Value Semantics**:
| Value | Semantics |
|-------|-----------|
| NO_REWRITE | Continue traversal, no changes |
| REWRITE_IMMEDIATE | Rewrite performed inline in hook |
| REWRITE_DEFERRED | Schedule rewrite for after current pass |
| SKIP_ELEMENT | Skip this element and its relations |
| STOP_TRAVERSAL | Halt traversal immediately |
| FINAL_RESULT | Signal end of traversal (used in finish) |

**Constraints**:
- Enum values must be exported
- Precedence: STOP_TRAVERSAL > SKIP_ELEMENT > REWRITE_* > NO_REWRITE

## Subtasks & Detailed Guidance

### Subtask T010 - Write unit tests for ControlSignal (tests-first)
- **Purpose**: Define expected behaviour before implementation
- **File**: `tests/unit/control-signal.rakutest`
- **Steps**:
  1. Test that all 6 enum values exist and are distinct
  2. Test that enum values can be compared with `===`
  3. Test that enum can be used in signatures: `sub foo(ControlSignal $sig) { }`
  4. Test stringification of each value
- **Example Tests**:
```raku
use Test;
use Qwiratry::ControlSignal;

plan 4;

subtest 'All enum values exist', {
    ok NO_REWRITE.defined, 'NO_REWRITE exists';
    ok REWRITE_IMMEDIATE.defined, 'REWRITE_IMMEDIATE exists';
    ok REWRITE_DEFERRED.defined, 'REWRITE_DEFERRED exists';
    ok SKIP_ELEMENT.defined, 'SKIP_ELEMENT exists';
    ok STOP_TRAVERSAL.defined, 'STOP_TRAVERSAL exists';
    ok FINAL_RESULT.defined, 'FINAL_RESULT exists';
}

subtest 'Values are distinct', {
    isnt NO_REWRITE, SKIP_ELEMENT, 'NO_REWRITE != SKIP_ELEMENT';
    isnt STOP_TRAVERSAL, SKIP_ELEMENT, 'STOP_TRAVERSAL != SKIP_ELEMENT';
}

subtest 'Enum usable in signatures', {
    my sub takes-signal(ControlSignal $s) { $s }
    is takes-signal(NO_REWRITE), NO_REWRITE, 'Can pass enum to typed parameter';
}

subtest 'Stringification', {
    is NO_REWRITE.Str, 'NO_REWRITE', 'NO_REWRITE stringifies correctly';
}
```

### Subtask T011 - Implement ControlSignal enum
- **Purpose**: Define the enum with all values
- **File**: `lib/Qwiratry/ControlSignal.rakumod`
- **Steps**:
  1. Define enum with `is export` trait
  2. Values in order: NO_REWRITE, REWRITE_IMMEDIATE, REWRITE_DEFERRED, SKIP_ELEMENT, STOP_TRAVERSAL, FINAL_RESULT
- **Implementation**:
```raku
unit module Qwiratry::ControlSignal;

#| Enumeration of signals communicating Strategy decisions to Walker.
#| These signals control traversal behaviour and rewrite scheduling.
enum ControlSignal is export <
    NO_REWRITE
    REWRITE_IMMEDIATE
    REWRITE_DEFERRED
    SKIP_ELEMENT
    STOP_TRAVERSAL
    FINAL_RESULT
>;
```

### Subtask T012 - Add Rakudoc documentation
- **Purpose**: Document each enum value's semantics
- **File**: `lib/Qwiratry/ControlSignal.rakumod`
- **Steps**:
  1. Add module-level Rakudoc describing the enum's purpose
  2. Document each value's Walker behaviour
- **Documentation Template**:
```raku
#| ControlSignal enum values and their Walker behaviours:
#|
#| =item NO_REWRITE - Continue traversal normally, no changes to element
#| =item REWRITE_IMMEDIATE - Element was rewritten in-place; continue with modified element
#| =item REWRITE_DEFERRED - Schedule rewrite for after current pass; continue normally
#| =item SKIP_ELEMENT - Do not visit this element's relations; move to next sibling
#| =item STOP_TRAVERSAL - Halt traversal immediately; proceed to finish()
#| =item FINAL_RESULT - Used by finish() hook to signal traversal complete
```

### Subtask T013 - Export enum from module
- **Purpose**: Ensure enum is accessible when module is used
- **File**: `lib/Qwiratry/ControlSignal.rakumod`
- **Steps**:
  1. Verify `is export` trait on enum definition
  2. Test import: `use Qwiratry::ControlSignal; say NO_REWRITE;`

### Subtask T014 - Verify tests pass
- **Purpose**: Confirm implementation matches tests
- **Steps**:
  1. Run: `raku tests/unit/control-signal.rakutest`
  2. All tests should pass
  3. Fix any failures before proceeding

## Risks & Mitigations

- **Export issues**: Use `is export` trait on enum definition
- **Naming conflicts**: Enum values are exported directly; users can qualify with `ControlSignal::` if needed

## Definition of Done Checklist

- [ ] Unit tests written (T010)
- [ ] Enum implemented with 6 values (T011)
- [ ] Rakudoc documentation added (T012)
- [ ] Enum exported correctly (T013)
- [ ] All tests pass (T014)
- [ ] `tasks.md` updated with status change

## Review Guidance

- Verify enum values match Specification.md 3.2.6 exactly
- Check documentation describes Walker behaviour for each signal
- Confirm export works: `raku -e 'use Qwiratry::ControlSignal; say NO_REWRITE'`

## Activity Log

- 2024-12-19T09:45:00Z - system - lane=planned - Prompt created.
- 2024-12-19T10:20:00Z - claude - shell_pid=117738 - lane=doing - Started implementation
- 2024-12-19T10:30:00Z - claude - shell_pid=117738 - lane=doing - Completed: Implemented ControlSignal enum with all 6 values, added Rakudoc documentation, wrote comprehensive unit tests. Code compiles correctly. Note: Test execution blocked by known Rakudo precompilation bug (MVMContext serialization) affecting entire repository, not code issue.
- 2024-12-19T10:31:00Z - claude - shell_pid=117738 - lane=for_review - Ready for review
- 2024-12-19T11:00:00Z - claude - shell_pid=126866 - lane=for_review - Tests verified: All 4 subtests, 20 assertions pass ✓

