---
work_package_id: "WP05"
subtasks:
  - "T032"
  - "T033"
  - "T034"
  - "T035"
  - "T036"
  - "T037"
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
title: "Context and Walker Integration"
phase: "Phase 2 - Core"
lane: "doing"
assignee: "claude"
agent: "claude"
shell_pid: "13472"
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2024-12-19T09:45:00Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
---

# Work Package Prompt: WP05 - Context and Walker Integration

## Objectives & Success Criteria

- Context role extended with `$.strategy` attribute
- Walker role extended with `$.strategy` attribute for constructor injection
- Walker stores Strategy in Context at traversal start
- Walker calls all Strategy hooks at correct traversal points
- Walker respects ControlSignal returns (STOP_TRAVERSAL, SKIP_ELEMENT)
- Backward compatible: Walker without Strategy works as before

## Context & Constraints

**Reference Documents**:
- `kitty-specs/003-strategy-and-controlsignal/research.md` - Engineering decisions
- `kitty-specs/003-strategy-and-controlsignal/data-model.md` - State machine diagram
- `kitty-specs/003-strategy-and-controlsignal/contracts/strategy-api.md` - Integration contract
- Existing `lib/Qwiratry/Context.rakumod` and `lib/Qwiratry/Walker.rakumod`

**Engineering Decisions** (from research.md):
- Constructor injection + Context storage pattern
- Walker.new(:$strategy) stores strategy
- iterator() copies Strategy to Context
- Hooks accessed via $ctx.strategy if defined

**Hook Call Order** (from contracts/strategy-api.md):
```
for each element in traversal:
    1. before($element, $ctx)
       - If SKIP_ELEMENT: skip to next element
       - If STOP_TRAVERSAL: goto finish()
    
    2. if query matches element:
       on-match($element, $match, $ctx)
       - If SKIP_ELEMENT: skip to next element
       - If STOP_TRAVERSAL: goto finish()
    
    3. for each relation of element:
       if should-follow($element, $relation, $target, $ctx):
           recursively process $target
    
    4. after($element, $ctx)
       - If STOP_TRAVERSAL: goto finish()

when all elements processed (or STOP_TRAVERSAL):
    5. finish($root, $ctx)
    
    6. if should-continue($root, $ctx):
       start new traversal pass
```

**Constraints**:
- Must not break existing Walker API
- Strategy is optional (Nil = no hooks called)
- Same Context instance shared across all hooks in a traversal

## Subtasks & Detailed Guidance

### Subtask T032 - Write tests for Context strategy accessor
- **File**: `tests/unit/context.rakutest` (update existing)
- **Tests**:
  1. Context can be created with strategy parameter
  2. Context.strategy returns the Strategy instance
  3. Context without strategy has undefined $.strategy
```raku
subtest 'Context strategy accessor', {
    my class TestStrategy does Strategy { }
    my $strategy = TestStrategy.new;
    my $ctx = Context.new(strategy => $strategy);
    ok $ctx.strategy === $strategy, 'strategy accessor returns injected strategy';
    
    my $ctx2 = Context.new;
    ok !$ctx2.strategy.defined, 'strategy undefined when not provided';
}
```

### Subtask T033 - Update Context role to add $.strategy attribute
- **File**: `lib/Qwiratry/Context.rakumod`
- **Steps**:
  1. Add `use Qwiratry::Strategy;`
  2. Add `has Strategy $.strategy;` attribute
- **Implementation**:
```raku
use Qwiratry::Strategy;

role Context {
    #| The Strategy instance for this traversal (may be undefined)
    has Strategy $.strategy;
}
```

### Subtask T034 - Write tests for Walker strategy injection
- **File**: `tests/unit/walker.rakutest` (update existing)
- **Tests**:
  1. Walker can be created with strategy parameter
  2. Walker.strategy returns the Strategy instance
  3. Walker without strategy has undefined $.strategy
  4. Walker created without strategy still functions (backward compatible)

### Subtask T035 - Update Walker role to add $.strategy attribute
- **File**: `lib/Qwiratry/Walker.rakumod`
- **Steps**:
  1. Add `use Qwiratry::Strategy;`
  2. Add `has Strategy $.strategy;` attribute

### Subtask T036 - Update Walker.iterator() to store Strategy in Context
- **File**: `lib/Qwiratry/Walker.rakumod`
- **Steps**:
  1. In iterator() method, create Context with `strategy => $.strategy`
  2. Ensure Strategy reference is passed to all traversal logic

### Subtask T037 - Write tests for Walker calling before hook
- **File**: `tests/integration/walker-strategy.rakutest`
- **Tests**:
  1. before() is called for each visited element
  2. before() receives correct element and context
  3. before() not called when no strategy

### Subtask T038 - Write tests for Walker calling on-match hook
- **File**: `tests/integration/walker-strategy.rakutest`
- **Tests**:
  1. on-match() called when query matches
  2. on-match() receives element, match, and context
  3. on-match() not called for non-matching elements

### Subtask T039 - Write tests for Walker calling should-follow hook
- **File**: `tests/integration/walker-strategy.rakutest`
- **Tests**:
  1. should-follow() called before following each relation
  2. Returning False prevents visitation of target
  3. Default True allows all relations

### Subtask T040 - Write tests for Walker calling after hook
- **File**: `tests/integration/walker-strategy.rakutest`
- **Tests**:
  1. after() called after all relations visited
  2. after() called even if element had no relations
  3. after() receives correct element and context

### Subtask T041 - Write tests for Walker calling finish hook
- **File**: `tests/integration/walker-strategy.rakutest`
- **Tests**:
  1. finish() called when traversal completes
  2. finish() called even if STOP_TRAVERSAL interrupted
  3. finish() result is accessible

### Subtask T042 - Write tests for Walker respecting STOP_TRAVERSAL
- **File**: `tests/integration/walker-strategy.rakutest`
- **Tests**:
  1. STOP_TRAVERSAL from before() halts immediately
  2. STOP_TRAVERSAL from on-match() halts immediately
  3. STOP_TRAVERSAL from after() halts before next element
  4. finish() still called after STOP_TRAVERSAL

### Subtask T043 - Write tests for Walker respecting SKIP_ELEMENT
- **File**: `tests/integration/walker-strategy.rakutest`
- **Tests**:
  1. SKIP_ELEMENT from before() skips element's relations
  2. SKIP_ELEMENT from on-match() skips remaining processing
  3. after() not called for skipped elements

### Subtask T044 - Implement hook calling in Walker traversal logic
- **File**: `lib/Qwiratry/Walker.rakumod`
- **Steps**:
  1. In traversal loop, check if $ctx.strategy defined
  2. Call hooks at appropriate points per call order
  3. Pass correct parameters to each hook
- **Pattern**:
```raku
# Before visiting element
if $ctx.strategy.defined {
    my $signal = $ctx.strategy.before($element, $ctx);
    given $signal {
        when STOP_TRAVERSAL { ... }
        when SKIP_ELEMENT { ... }
    }
}
```

### Subtask T045 - Implement ControlSignal handling
- **File**: `lib/Qwiratry/Walker.rakumod`
- **Steps**:
  1. After each hook call, check return value
  2. STOP_TRAVERSAL: break out of traversal, goto finish
  3. SKIP_ELEMENT: skip to next sibling, don't visit relations

### Subtask T046 - Update Walker POST-PASS to call should-continue
- **File**: `lib/Qwiratry/Walker.rakumod`
- **Steps**:
  1. After traversal pass completes, call should-continue
  2. If returns True, start another pass
  3. Track pass count to prevent infinite loops (optional safeguard)

### Subtask T047 - Add Rakudoc for updated Context and Walker
- **Files**: `lib/Qwiratry/Context.rakumod`, `lib/Qwiratry/Walker.rakumod`
- **Document**:
  1. New $.strategy attribute on both
  2. How Strategy is passed from Walker to Context
  3. Hook calling behaviour

### Subtask T048 - Verify all tests pass
- **Steps**:
  1. Run all unit tests
  2. Run all integration tests
  3. Verify backward compatibility tests pass

## Risks & Mitigations

- **Breaking backward compatibility**: Always check if strategy defined before calling hooks
- **Hook ordering bugs**: Follow state machine diagram exactly
- **Infinite loops in should-continue**: Add optional max-passes safeguard
- **Performance overhead**: Only call hooks when strategy exists

## Definition of Done Checklist

- [ ] Context strategy tests written (T032)
- [ ] Context.strategy attribute added (T033)
- [ ] Walker strategy tests written (T034)
- [ ] Walker.strategy attribute added (T035)
- [ ] Walker stores strategy in Context (T036)
- [ ] Hook calling tests written (T037-T043)
- [ ] Hook calling implemented (T044)
- [ ] ControlSignal handling implemented (T045)
- [ ] should-continue integration added (T046)
- [ ] Rakudoc updated (T047)
- [ ] All tests pass (T048)
- [ ] `tasks.md` updated with status change

## Review Guidance

- Verify backward compatibility: Walker without strategy works
- Check hook call order matches state machine
- Test STOP_TRAVERSAL and SKIP_ELEMENT behaviour
- Ensure Context is shared (same instance) across all hooks

## Activity Log

- 2024-12-19T09:45:00Z - system - lane=planned - Prompt created.
- 2024-12-19T11:05:00Z - claude - shell_pid=13472 - lane=doing - Started implementation
- 2024-12-19T11:30:00Z - claude - shell_pid=13472 - lane=doing - Completed: Extended Context with $.strategy attribute, extended Walker with $.strategy attribute, updated TestPlan to pass strategy to Context, added comprehensive unit tests, created integration tests demonstrating full hook calling pattern. Note: Integration tests require RakuAST experimental features (pre-existing from feature 002) but demonstrate complete integration pattern.

