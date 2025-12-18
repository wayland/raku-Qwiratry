# Implementation Plan: Walker Core Infrastructure

**Branch**: `002-walker-core-infrastructure` | **Date**: 2025-12-17 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/kitty-specs/002-walker-core-infrastructure/spec.md`

**Note**: This template is filled in by the `/spec-kitty.plan` command. See `.kittify/templates/commands/plan.md` for the execution workflow.

## Summary

Implement the core Walker infrastructure as foundational Raku roles for the Qwiratry query execution framework. This includes four roles (`Walker`, `Walker::Plan`, `Context`, `QueryIterator`) with default implementations for common patterns, an exception hierarchy for error handling, and a logical module structure. The implementation provides the execution planning and incremental result streaming infrastructure that enables domain-specific walkers (e.g., Tree::Walker::DFS, Table::Walker::Scan) to execute queries over various data structures.

## Technical Context

**Language/Version**: Raku 6.e (with RakuAST support)
**Primary Dependencies**: 
- RakuAST (built-in for Raku 6.e)
- Raku Iterator role (built-in)
**Storage**: N/A (in-memory roles and interfaces)
**Testing**: The built-in Test module
**Target Platform**: Everything that Raku targets
**Project Type**: Raku library module providing roles for other modules to consume
**Performance Goals**: 
- Role method dispatch should have minimal overhead
- QueryIterator.next() should support lazy evaluation efficiently
- No specific performance targets for this foundational layer (deferred to concrete walker implementations)
**Constraints**: 
- Must use RakuAST::Node for Query AST types (not CompUnit::Perl5AST::Node)
- Roles must be composable and follow Raku role conventions
- Must maintain backward compatibility for role method signatures
**Scale/Scope**: 
- Core infrastructure layer - no direct user-facing functionality
- Supports unlimited concrete walker implementations
- No scalability concerns at this layer (deferred to concrete implementations)

**Architecture Decisions**:
1. **Role Implementation**: Provide default implementations for common patterns:
   - Default `start` method implementation (calls `plan` then `plan.iterator()`)
   - Empty default implementations for optional hooks (`PRE-PASS`, `POST-PASS`)
   - Default `capabilities()` returning empty hash (concrete walkers override)
   - Default `supports()` returning False (concrete walkers override)

2. **Exception Hierarchy**: 
   - Base exception: `X::Qwiratry::Walker`
   - Specific exception: `X::Qwiratry::UnknownQueryElement` (extends base)
   - Exception attributes include Query AST node, Walker type, and diagnostic message

3. **Module Structure**: Logical grouping:
   - `lib/Qwiratry/Walker.rakumod` - Walker role + Walker::Plan role
   - `lib/Qwiratry/Context.rakumod` - Context role
   - `lib/Qwiratry/QueryIterator.rakumod` - QueryIterator role
   - `lib/Qwiratry/X.rakumod` - Exception hierarchy (X::Qwiratry::Walker, X::Qwiratry::UnknownQueryElement)

4. **Testing Strategy**: Hybrid approach:
   - Role contract tests: Verify method signatures, return types, and behavior contracts
   - Concrete implementation tests: Minimal example walker (e.g., SimpleWalker) implementing all roles to verify end-to-end flow
   - Integration tests: Test query execution flow from plan → iterator → results

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Tests-first**: 
  - Unit tests for each role: Walker, Walker::Plan, Context, QueryIterator
  - Role contract tests verifying method signatures and return types
  - Exception tests for X::Qwiratry::UnknownQueryElement
  - Integration tests: plan → iterator → results flow
  - Concrete walker example tests (SimpleWalker) to verify end-to-end behavior
  - Tests written before implementation code

- **Data contracts**: 
  - Role method signatures define type constraints (RakuAST::Node, Walker::Plan, Context, QueryIterator)
  - Query AST immutability contract (Walker::Plan MUST NOT mutate Query AST)
  - Context lifecycle contract (created fresh per traversal, not shared)
  - QueryIterator.next() contract (returns Mu or Nil)
  - No schema migrations needed (role definitions)

- **CLI and observability**: 
  - No CLI surface for this feature (library roles)
  - Logging available via Context or Walker hooks for debugging
  - No metrics required at this foundational layer
  - Exception messages provide diagnostic information

- **Security/privacy**: 
  - No sensitive data involved
  - Roles are type-safe interfaces
  - No secrets or credentials required
  - Exception handling prevents information leakage (no stack traces in production)

- **Simplicity/operability**: 
  - Incremental slices:
    1. Basic Walker role with plan method
    2. Walker::Plan role with iterator method
    3. Context role
    4. QueryIterator role
    5. start convenience method
    6. Optional hooks (PRE-PASS, POST-PASS)
    7. Exception hierarchy
  - Each slice independently testable
  - Rollback: roles can be versioned or deprecated if needed
  - No operational runbooks needed (library code)

**No exceptions required** - all principles satisfied.

## Project Structure

### Documentation (this feature)

```
kitty-specs/002-walker-core-infrastructure/
├── plan.md              # This file (/spec-kitty.plan command output)
├── research.md          # Phase 0 output (/spec-kitty.plan command)
├── data-model.md        # Phase 1 output (/spec-kitty.plan command)
├── quickstart.md        # Phase 1 output (/spec-kitty.plan command)
├── contracts/           # Phase 1 output (/spec-kitty.plan command)
└── tasks.md             # Phase 2 output (/spec-kitty.tasks command - NOT created by /spec-kitty.plan)
```

### Source Code (repository root)

```
lib/
├── Qwiratry/
│   ├── Walker.rakumod           # Walker role + Walker::Plan role
│   ├── Context.rakumod          # Context role
│   ├── QueryIterator.rakumod    # QueryIterator role
│   └── X.rakumod                # Exception hierarchy

tests/
├── unit/
│   ├── walker.rakutest          # Walker role contract tests
│   ├── walker-plan.rakutest     # Walker::Plan role contract tests
│   ├── context.rakutest         # Context role contract tests
│   ├── query-iterator.rakutest # QueryIterator role contract tests
│   └── exceptions.rakutest     # Exception hierarchy tests
├── integration/
│   └── walker-flow.rakutest     # Plan → iterator → results flow
└── examples/
    └── simple-walker.rakutest  # Concrete walker example tests
```

**Structure Decision**: Single-module library structure with logical grouping of roles into separate modules. Tests organized by type (unit/integration/examples) for clarity. Example concrete walker included in tests to verify end-to-end behavior.

## Complexity Tracking

*No violations - all Constitution principles satisfied*

## Parallel Work Analysis

*Single developer/agent implementation - no parallel work required*

---

## Phase 0: Outline & Research

**Status**: ✅ Complete

**Research Tasks**:
1. ✅ Research RakuAST::Node structure and introspection capabilities
2. ✅ Research Raku role default method implementations and best practices
3. ✅ Research Raku exception hierarchy patterns (X:: namespace conventions)
4. ✅ Research Raku Iterator role contract and lazy evaluation patterns
5. ✅ Research module organization patterns for Raku libraries

**Outputs**:
- ✅ `research.md` with findings and decisions
- All research questions resolved

---

## Phase 1: Design & Contracts

**Status**: ✅ Complete

**Design Tasks**:
1. ✅ Extract entities from spec → `data-model.md`:
   - Walker role (methods, attributes, lifecycle)
   - Walker::Plan role (methods, immutability constraints)
   - Context role (mutable state, lifecycle)
   - QueryIterator role (Iterator contract, Context integration)
   - Exception hierarchy (X::Qwiratry::Walker, X::Qwiratry::UnknownQueryElement)

2. ✅ Generate API contracts → `contracts/`:
   - Role method signatures (from spec)
   - Exception constructors and attributes
   - Type constraints and return types

3. ✅ Create `quickstart.md`:
   - Example: Creating a simple walker
   - Example: Planning and executing a query
   - Example: Error handling

**Outputs**:
- ✅ `data-model.md` - Complete entity model with relationships
- ✅ `contracts/walker-api.md` - Complete API contracts
- ✅ `quickstart.md` - Usage examples and patterns

---

## Phase 2: Task Breakdown

**Prerequisites**: Phase 1 design complete

**Note**: Phase 2 is executed by `/spec-kitty.tasks` command, not `/spec-kitty.plan`

**Output**: `tasks.md` with work packages and subtasks

