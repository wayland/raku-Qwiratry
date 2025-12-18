# Research: Strategy and ControlSignal

**Feature**: 003-strategy-and-controlsignal
**Date**: 2024-12-19

## Research Questions

### RQ-1: How should Strategy associate with Walker?

**Decision**: Constructor injection + Context storage

**Rationale**: 
- Walker accepts Strategy via constructor: `Walker.new(:$strategy)`
- At traversal start, Strategy is stored in Context
- Hooks access Strategy via `$ctx.strategy` during execution
- Avoids threading Strategy through every method call
- Context already exists as shared state between Walker and Strategy

**Alternatives considered**:
- Method parameter: Would require passing Strategy to every method, verbose
- Role composition: Would couple Strategy to Walker implementation, losing reusability
- Pure Context: No constructor config, harder to set up

### RQ-2: How should hook failures be handled?

**Decision**: Configurable via standard Raku CATCH blocks, default is fail-fast propagation

**Rationale**:
- Different strategies have different requirements:
  - Profiling/tracing/statistics: Should never kill traversal
  - Optimization/validation/planning: Must fail fast
- Standard Raku exception semantics (try/CATCH) give flexibility
- Strategy implementers can wrap hooks in CATCH if fault-tolerance needed
- Walker can provide optional exception capture mode via attribute

**Alternatives considered**:
- Pure propagation only: Insufficient for fault-tolerant use cases
- Pure capture only: Masks critical errors in validation strategies
- Custom exception handling: Reinvents what Raku already provides

### RQ-3: Module organization pattern

**Decision**: Follow existing `lib/Qwiratry/` pattern - one file per concept

**Rationale**:
- Matches feature 002 organization (Context.rakumod, Walker.rakumod, etc.)
- Clear separation of concerns
- Easy to find and modify individual types
- Supports incremental development (can implement ControlSignal before Strategy)

**Files**:
- `ControlSignal.rakumod` - enum definition
- `RewriteSpec.rakumod` - stub role for rewrites
- `FinishResult.rakumod` - class for finish hook results
- `Strategy.rakumod` - main Strategy role

### RQ-4: Existing Context and Walker interfaces

**Decision**: Minimal modifications to preserve backward compatibility

**Research findings** (from `lib/Qwiratry/Context.rakumod` and `lib/Qwiratry/Walker.rakumod`):

Context role is currently minimal:
```raku
role Context {
    # Generic ancestor for all Context roles
}
```

Walker role provides:
- `plan()` method - creates execution plan
- `iterator()` method - creates QueryIterator
- `start()` convenience method
- `PRE-PASS` and `POST-PASS` hooks

**Integration approach**:
- Add `has $.strategy` attribute to Context role
- Add `has $.strategy` attribute to Walker role
- Walker stores Strategy in Context at traversal start
- Walker calls Strategy hooks at appropriate points in traversal

### RQ-5: Hook call points in Walker traversal

**Decision**: Map hooks to Walker lifecycle

| Hook | When Called | Walker Method |
|------|-------------|---------------|
| `before` | Before visiting element | During iterator traversal |
| `on-match` | When query matches element | After match evaluation |
| `should-follow` | Before following relation | Before descending to children |
| `after` | After visiting element's relations | After children processed |
| `finish` | After complete traversal | End of iterator exhaustion |
| `should-continue` | After each pass | POST-PASS hook |

**Implementation note**: Walker.iterator() creates QueryIterator which performs actual traversal. Hooks are called from within QueryIterator logic, with Context providing access to Strategy.

## Dependencies Verified

| Dependency | Status | Notes |
|------------|--------|-------|
| Feature 002 (Walker Core) | Merged | Context, QueryIterator, Walker, X available |
| Specification.md 2.1.3 | Reviewed | Strategy Group overview |
| Specification.md 3.2.5 | Reviewed | Strategy role definition |
| Specification.md 3.2.6 | Reviewed | ControlSignal enum definition |

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Hook overhead affects performance | Low | Medium | Nil checks are O(1); only call implemented hooks |
| Walker changes break existing code | Medium | High | Add Strategy as optional; default to no-op if not provided |
| Complex hook interactions | Medium | Medium | Clear precedence rules; STOP_TRAVERSAL > SKIP_ELEMENT > others |

