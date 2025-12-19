# Implementation Plan: Composite Walker Handovers

**Branch**: `004-composite-walker-handovers` | **Date**: 2025-01-27 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/kitty-specs/004-composite-walker-handovers/spec.md`

**Note**: This template is filled in by the `/spec-kitty.plan` command. See `.kittify/templates/commands/plan.md` for the execution workflow.

## Summary

Implement the master/composite walker system that supports handovers between domain-specific walkers using the `provides<...>` compile-time trait for domain metadata and Walker capability checks. This includes handover detection priority (domain metadata → capability checks → AST pattern suitability → heuristic probing), plan-level handover coordination with embedded subplans, and composite execution for multi-domain queries. The system enables efficient multi-domain query planning and execution while maintaining walker independence.

## Technical Context

**Language/Version**: Raku 6.e (with RakuAST support)
**Primary Dependencies**: 
- Walker core infrastructure (feature 002) - Walker role, Walker::Plan role, Context role, QueryIterator role
- RakuAST (built-in for Raku 6.e)
- Raku meta-object protocol for trait introspection
**Storage**: N/A (compile-time trait metadata, runtime walker registry)
**Testing**: The built-in Test module
**Target Platform**: Everything that Raku targets
**Project Type**: Raku library module extending Qwiratry framework
**Performance Goals**: 
- Trait metadata discovery should be O(1) or O(n) where n is number of traits (not number of objects)
- Walker discovery should be efficient (cached after first discovery)
- Handover detection should minimize capability checks (use domain metadata fast path when available)
- Plan-level handover should avoid runtime overhead (all decisions made during planning)
**Constraints**: 
- Must use Raku's built-in trait introspection mechanisms (`.^traits` or meta-object protocol)
- Must maintain backward compatibility with existing Walker role interface
- Must not require changes to domain-specific walkers (they remain independent)
- Trait metadata must be discoverable by Slangs and Walkers during planning phase
**Scale/Scope**: 
- Supports unlimited domain-specific walkers
- Supports unlimited domains per root object (via `provides<domain1 domain2 ...>`)
- No scalability concerns at this layer (deferred to concrete walker implementations)

**Architecture Decisions**:

1. **Walker Discovery Mechanism**: Hybrid approach with discovery as default:
   - **Default**: Master Walker discovers candidate walkers via introspection (scanning for classes/roles that do Walker)
   - **Override**: Master Walker can accept explicit list of candidate walkers via constructor parameter
   - Discovery results cached per Master Walker instance to avoid repeated introspection
   - Rationale: Convenience by default (auto-discovery), explicit control when needed (performance, testing, specific walker selection)

2. **Trait Metadata Storage**: Use Raku's built-in trait introspection:
   - Implement `trait_mod:<provides>` to attach metadata via meta-object protocol
   - Access metadata at runtime via `.^traits` or meta-object introspection
   - Metadata stored in object's meta-object, discoverable during planning phase
   - Rationale: Leverages Raku's native trait system, no custom registry needed, idiomatic Raku approach

3. **Master Walker Implementation**:
   - New class `Qwiratry::MasterWalker` implementing Walker role
   - Constructor accepts optional `:@candidate-walkers` parameter (overrides discovery)
   - Handover detection follows priority order: domain metadata → capability checks → AST pattern → heuristics
   - Creates composite plans with embedded subplans via `Walker::Plan.subplans()`
   - Rationale: Centralizes handover logic, maintains Walker role interface, enables composite execution

4. **Composite Plan Structure**:
   - Extend `Walker::Plan.subplans()` to return array of embedded subplans
   - Master Walker's plan contains its own execution strategy plus subplans
   - Subplans are Walker::Plan instances from delegated domain-specific walkers
   - Rationale: Reuses existing subplans mechanism, enables introspection, maintains plan immutability

5. **Module Structure**:
   - `lib/Qwiratry/Provides.rakumod` - `provides` trait implementation (`trait_mod:<provides>`)
   - `lib/Qwiratry/MasterWalker.rakumod` - Master Walker class
   - `lib/Qwiratry/CompositePlan.rakumod` - Composite plan implementation (if needed, or extend Walker::Plan)
   - Tests: `tests/unit/provides.rakutest`, `tests/unit/master-walker.rakutest`, `tests/integration/composite-handover.rakutest`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Tests-first**: 
  - Unit tests for `provides` trait: trait application, metadata attachment, runtime discovery
  - Unit tests for Master Walker: discovery mechanism, explicit registration override, handover detection priority
  - Unit tests for handover detection: domain metadata check, capability checks, AST pattern suitability, heuristic fallback
  - Unit tests for composite plans: subplan embedding, plan introspection, plan immutability
  - Integration tests: end-to-end multi-domain query planning and execution
  - Contract tests: Master Walker implements Walker role correctly, composite plans implement Walker::Plan correctly
  - Tests written before implementation code

- **Data contracts**: 
  - Trait metadata contract: `provides<domain-name>` attaches metadata discoverable via `.^traits` or meta-object protocol
  - Master Walker constructor contract: optional `:@candidate-walkers` parameter (Array[Walker])
  - Handover detection contract: returns Walker or Nil (Nil if no suitable walker found)
  - Composite plan contract: `subplans()` returns Array[Walker::Plan], plan.query() returns original query AST
  - Walker capability contract: `supports(RakuAST::Node --> Bool)` method signature
  - No schema migrations needed (compile-time traits, runtime interfaces)

- **CLI and observability**: 
  - No CLI surface for this feature (library infrastructure)
  - Logging available via Master Walker for debugging handover decisions (optional, via Context or hooks)
  - Diagnostic error messages when handover fails (no suitable walker found, capability check fails)
  - No metrics required at this foundational layer (deferred to concrete implementations)
  - Exception messages provide diagnostic information (which walker, which domain, why handover failed)

- **Security/privacy**: 
  - No sensitive data involved
  - Trait metadata is advisory only, does not affect runtime security
  - Walker discovery via introspection is safe (only discovers classes/roles, no code execution)
  - No secrets or credentials required
  - Exception handling prevents information leakage (no stack traces in production)

- **Simplicity/operability**: 
  - Incremental slices:
    1. `provides` trait implementation (`trait_mod:<provides>`)
    2. Trait metadata discovery mechanism (runtime introspection)
    3. Master Walker basic structure (discovery, explicit registration)
    4. Handover detection: domain metadata check (fast path)
    5. Handover detection: capability checks via `supports()`
    6. Plan-level handover: delegate planning, embed subplans
    7. Composite execution coordination: execution ordering, data flow
    8. AST pattern suitability (optimization, optional)
    9. Heuristic probing (last resort, optional)
  - Each slice independently testable
  - Rollback: traits can be versioned or deprecated if needed, Master Walker can be replaced
  - No operational runbooks needed (library code)

## Project Structure

### Documentation (this feature)

```
kitty-specs/004-composite-walker-handovers/
├── plan.md              # This file (/spec-kitty.plan command output)
├── research.md          # Phase 0 output (/spec-kitty.plan command)
├── data-model.md        # Phase 1 output (/spec-kitty.plan command)
├── quickstart.md        # Phase 1 output (/spec-kitty.plan command)
├── contracts/           # Phase 1 output (/spec-kitty.plan command)
└── tasks.md             # Phase 2 output (/spec-kitty.tasks command - NOT created by /spec-kitty.plan)
```

### Source Code (repository root)

```
lib/Qwiratry/
├── Provides.rakumod          # provides trait implementation (trait_mod:<provides>)
├── MasterWalker.rakumod      # Master Walker class implementing Walker role
└── [Walker.rakumod]          # Existing Walker role (from feature 002)

tests/
├── unit/
│   ├── provides.rakutest     # Trait application and discovery tests
│   └── master-walker.rakutest # Master Walker discovery and handover tests
└── integration/
    └── composite-handover.rakutest # End-to-end multi-domain query tests
```

**Structure Decision**: Extend existing Qwiratry module structure. New modules for `provides` trait and Master Walker. Tests organized by unit vs integration. Reuses existing Walker infrastructure from feature 002.

## Complexity Tracking

*No violations - all complexity is justified by feature requirements*

## Planning Questions Answered

1. **Walker Discovery**: Default to discovery via introspection, override with explicit registration via constructor parameter
2. **Trait Metadata Storage**: Use Raku's built-in trait introspection (`.^traits` or meta-object protocol)
