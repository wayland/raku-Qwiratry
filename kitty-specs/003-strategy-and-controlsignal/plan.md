# Implementation Plan: Strategy and ControlSignal

**Branch**: `003-strategy-and-controlsignal` | **Date**: 2024-12-19 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `kitty-specs/003-strategy-and-controlsignal/spec.md`

## Summary

Implement the Strategy role with element-level traversal hooks and the ControlSignal enumeration as defined in Specification.md sections 2.1.3, 3.2.5, and 3.2.6. Strategy provides pluggable, walker-agnostic behaviour for element processing during traversal. Integration with the existing Walker infrastructure from feature 002.

## Technical Context

**Language/Version**: Raku 6.e (with RakuAST)
**Primary Dependencies**: Feature 002 (Walker, Context, QueryIterator)
**Storage**: N/A (in-memory roles/classes)
**Testing**: The built-in Test module with .rakutest files
**Target Platform**: Everything that Raku targets
**Project Type**: Raku module for use by other modules
**Performance Goals**: Hook calls should have minimal overhead; Strategy lookup via Context should be O(1)
**Constraints**: Must integrate with existing Walker role without breaking backward compatibility

### Engineering Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Strategy-Walker association | Constructor injection + Context storage | Clean configuration, no parameter threading during traversal |
| Hook error handling | Configurable via standard Raku CATCH | Fail-fast default; fault-tolerant strategies catch internally |
| Module organization | Separate files per concept | Matches existing lib/Qwiratry/ pattern |

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Tests-first**: 
  - Unit tests for ControlSignal enum values and semantics
  - Unit tests for Strategy role with mock implementations
  - Unit tests for RewriteSpec and FinishResult stub types
  - Integration tests for Walker calling Strategy hooks at correct traversal points
  - Integration tests for Context holding Strategy reference

- **Data contracts**: 
  - ControlSignal enum: 6 defined values with documented semantics
  - Strategy role: 6 hooks with defined signatures and return types
  - RewriteSpec role: stub interface (to be expanded in future feature)
  - FinishResult class: type + value fields
  - Context extension: strategy accessor method

- **CLI and observability**: 
  - N/A for this feature (library roles, no CLI entry point)
  - Hooks can log via Context if Strategy chooses to implement logging
  - Exception messages include walker-type and element context for debugging

- **Security/privacy**: 
  - N/A (pure computational logic, no I/O, auth, or data storage)
  - No secrets or sensitive data handling

- **Simplicity/operability**: 
  - Sliced into 4 increments: ControlSignal -> Stub types -> Strategy role -> Walker integration
  - Each increment independently testable
  - No deployment or rollback needed (library code)

- **Exceptions**: None required

## Project Structure

### Documentation (this feature)

```
kitty-specs/003-strategy-and-controlsignal/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 research output
├── data-model.md        # Phase 1 data model
├── quickstart.md        # Phase 1 usage guide
├── contracts/           # Phase 1 API contracts
│   └── strategy-api.md  # Strategy role contract
├── checklists/
│   └── requirements.md  # Specification quality checklist
└── tasks.md             # Phase 2 work packages (created by /spec-kitty.tasks)
```

### Source Code (repository root)

```
lib/Qwiratry/
├── Context.rakumod       # UPDATE: Add strategy accessor
├── ControlSignal.rakumod # NEW: ControlSignal enum
├── FinishResult.rakumod  # NEW: FinishResult class
├── QueryIterator.rakumod # (no changes)
├── RewriteSpec.rakumod   # NEW: RewriteSpec stub role
├── Strategy.rakumod      # NEW: Strategy role
├── Walker.rakumod        # UPDATE: Accept Strategy, call hooks
└── X.rakumod             # (no changes expected)

tests/
├── unit/
│   ├── control-signal.rakutest   # NEW
│   ├── strategy.rakutest         # NEW
│   ├── rewrite-spec.rakutest     # NEW
│   └── finish-result.rakutest    # NEW
└── integration/
    └── walker-strategy.rakutest  # NEW: Walker + Strategy integration
```

**Structure Decision**: Follow existing pattern from feature 002. One file per concept in `lib/Qwiratry/`. Unit tests per type, integration test for Walker-Strategy interaction.

## Parallel Work Analysis

*Not applicable - single developer feature with sequential dependencies*

### Dependency Graph

```
ControlSignal (no deps)
    ↓
RewriteSpec, FinishResult (no deps, parallel)
    ↓
Strategy (depends on ControlSignal, RewriteSpec, FinishResult, Context)
    ↓
Walker update (depends on Strategy, Context)
    ↓
Integration tests (depends on all above)
```

### Implementation Order

1. **Phase 1**: ControlSignal enum (standalone)
2. **Phase 2**: RewriteSpec role + FinishResult class (stubs, can be parallel)
3. **Phase 3**: Strategy role (depends on above)
4. **Phase 4**: Context update (add strategy accessor)
5. **Phase 5**: Walker update (accept Strategy, call hooks)
6. **Phase 6**: Integration tests

