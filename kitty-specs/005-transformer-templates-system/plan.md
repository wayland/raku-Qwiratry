# Implementation Plan: Transformer Templates System

**Branch**: `005-transformer-templates-system` | **Date**: 2025-01-27 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/kitty-specs/005-transformer-templates-system/spec.md`

**Note**: This template is filled in by the `/spec-kitty.plan` command. See `.kittify/templates/commands/plan.md` for the execution workflow.

## Summary

Implement the Transformer and Template system that enables declarative data transformations using pattern-matching templates. The system provides custom declarators (`transformer` and `template`), template ordering (priority → specificity → tie-breaker), magic variables (`$*CONTEXT`, `$*CAPTURE`, `self`), wrapper system, `Qwiratry::Copy` service class for copy/deepcopy operations, and integration with existing Walker and Strategy systems. Transformers support streaming, tree rewriting, and multiple transformation modes (pre, inline, post) for flexible data transformation workflows. Transformable nodes are those that have a Walker with the `supports-rewrite` capability.

## Technical Context

**Language/Version**: Raku 6.e (with RakuAST support)
**Primary Dependencies**: 
- Walker core infrastructure (feature 002) - Walker role, Walker::Plan role, Context role, QueryIterator role
- Strategy and ControlSignal (feature 003) - Strategy role, ControlSignal enum
- Raku meta-object protocol (MOP) for custom declarators
- RakuAST (built-in for Raku 6.e)
**Storage**: N/A (compile-time declarator metadata, runtime transformer state)
**Testing**: The built-in Test module
**Target Platform**: Everything that Raku targets
**Project Type**: Raku library module extending Qwiratry framework
**Performance Goals**: 
- Template ordering should complete in O(n log n) where n is number of templates
- Template matching should be O(m) where m is number of templates (first match wins)
- Streaming transformers should maintain constant memory usage regardless of input size
- `Qwiratry::Copy::copy()` function must be O(1) with respect to descendant count
- `Qwiratry::Copy::deepcopy()` function should handle DAG structures efficiently with cycle detection
**Constraints**: 
- Must use `EXPORTHOW::DECLARE` mechanism for `transformer` declarator (no full slang required)
- Must integrate with existing Walker system via factory/registry pattern
- Must support all transformation modes (pre, inline, post) as specified
- Template ordering must be deterministic and report conflicts clearly
- Magic variables must be scoped correctly during template execution
**Scale/Scope**: 
- Supports unlimited templates per transformer
- Supports unlimited transformers per program
- No scalability concerns at this layer (deferred to concrete walker implementations)
- Must handle various data structure types (trees, tables, etc.)

**Architecture Decisions**:

1. **Custom Declarator Implementation**: Use `EXPORTHOW::DECLARE` mechanism:
   - Create a HOW class extending `Metamodel::ClassHOW` (or appropriate base)
   - Export via `EXPORTHOW::DECLARE` package where constant name matches `transformer` keyword
   - Compiler uses the HOW when encountering `transformer` declarator
   - Rationale: Simpler than full slang, integrates seamlessly with Raku's grammar and type system, follows Red ORM pattern

2. **Template Declarator Handling**: Combination approach:
   - Use `EXPORTHOW::DECLARE` for `transformer` declarator
   - Parse `template` declarations manually during transformer body compilation
   - Collect templates and store them in transformer metadata
   - Rationale: Templates are contained within transformers, manual parsing gives more control over template collection and validation

3. **Template Ordering Strategy**: Hybrid compile-time/runtime approach:
   - Calculate static aspects (priority, basic specificity) at compile time when possible
   - Defer dynamic/complex specificity calculations to runtime when `ORDER-TEMPLATES` is called
   - Cache ordering results to avoid recalculation
   - Rationale: Balances performance (compile-time optimization) with flexibility (runtime evaluation for complex queries)

4. **Walker Integration**: Factory/registry pattern:
   - Create Walker factory/registry that selects appropriate Walker based on input data type
   - Transformers obtain Walker instances automatically via factory
   - Allow explicit Walker override when needed
   - Rationale: Enables automatic Walker selection while maintaining flexibility for custom use cases

5. **Copy Service Class**: `Qwiratry::Copy` module approach:
   - Provide `copy()` and `deepcopy()` multi subs as service functions
   - Default implementations for `Positional` (via `clone` for copy, recursive map for deepcopy) and `Associative` types
   - Check for custom `.copy()` method on nodes before using default
   - Methods attached to Transformer object for convenient access
   - Transformable nodes are those with Walkers that have `supports-rewrite` capability
   - Rationale: Service class approach is simpler than role-based, provides defaults while allowing customization, follows spec section 3.3.6

6. **Module Structure**:
   - `lib/Qwiratry/Transformer.rakumod` - Transformer class and HOW implementation
   - `lib/Qwiratry/Template.rakumod` - Template class and metadata
   - `lib/Qwiratry/Copy.rakumod` - Copy service class with copy/deepcopy multi subs
   - `lib/Qwiratry/WalkerFactory.rakumod` - Walker factory/registry (if needed, or extend existing)
   - Tests: `tests/unit/transformer.rakutest`, `tests/unit/template.rakutest`, `tests/unit/copy.rakutest`, `tests/integration/transformer-walker.rakutest`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Tests-first**: 
  - Unit tests for `transformer` declarator: declaration, trait application, role composition
  - Unit tests for `template` declarator: declaration within transformer, when/do blocks, traits
  - Unit tests for template ordering: priority, specificity calculation, tie-breaker resolution, conflict detection
  - Unit tests for magic variables: `$*CONTEXT`, `$*CAPTURE`, `self` availability and correctness
  - Unit tests for `Qwiratry::Copy` service class: `copy()` and `deepcopy()` multi subs, shallow copy, deep copy, DAG handling, cycle detection, default implementations for Positional/Associative, custom method detection
  - Unit tests for wrapper system: TRANSFORMER, TEMPLATE_MATCHER, TEMPLATE_ACTION execution
  - Unit tests for transformation modes: pre, inline, post, rewrite modes
  - Integration tests: transformer with Walker, transformer with Strategy, end-to-end transformations
  - Contract tests: Transformer implements required methods, templates execute correctly, Walker integration
  - Tests written before implementation code

- **Data contracts**: 
  - Transformer declarator contract: creates class with specified name, traits, roles
  - Template declarator contract: creates template objects with when/do blocks, traits, metadata
  - Template ordering contract: `@.ordered-templates` array contains sorted templates
  - Magic variable contract: `$*CONTEXT` and `$*CAPTURE` available during template execution, `self` refers to Transformer
  - Walker factory contract: returns appropriate Walker for data type or Nil if none found
  - Transformation mode contract: `transform` method accepts `:mode` parameter with valid values
  - Copy service class contract: `Qwiratry::Copy::copy()` and `Qwiratry::Copy::deepcopy()` multi subs with default implementations for Positional/Associative, custom method detection
  - Transformable node contract: nodes with Walkers that have `supports-rewrite` capability are transformable
  - No schema migrations needed (compile-time declarators, runtime interfaces)

- **CLI and observability**: 
  - No CLI surface for this feature (library infrastructure)
  - Logging available via Transformer for debugging transformation decisions (optional, via Context or hooks)
  - Diagnostic error messages when template ordering conflicts occur (which templates, why conflict)
  - Diagnostic error messages when Walker not found (which data type, available walkers)
  - No metrics required at this foundational layer (deferred to concrete implementations)
  - Exception messages provide diagnostic information (which transformer, which template, why transformation failed)

- **Security/privacy**: 
  - No sensitive data involved
  - Template `when` clauses execute user code - ensure proper scoping and isolation
  - Magic variables scoped to template execution prevent leakage between templates
  - No secrets or credentials required
  - Exception handling prevents information leakage (no stack traces in production)

- **Simplicity/operability**: 
  - Incremental slices:
    1. `transformer` declarator implementation (EXPORTHOW::DECLARE)
    2. Basic Transformer class structure (TRANSFORM, ORDER-TEMPLATES, APPLY stubs)
    3. `template` declarator parsing within transformer body
    4. Template collection and storage
    5. Template ordering: priority sorting
    6. Template ordering: specificity calculation (basic cases)
    7. Template ordering: tie-breaker resolution
    8. Magic variables: `$*CONTEXT` and `self` setup
    9. Magic variables: `$*CAPTURE` for template parameters
    10. `APPLY` method: template matching and execution
    11. `TRANSFORM` method: walker integration, iteration, template application
    12. `Qwiratry::Copy` service class: `copy()` and `deepcopy()` multi subs with default implementations, method attachment to Transformer
    13. Wrapper system: TRANSFORMER, TEMPLATE_MATCHER, TEMPLATE_ACTION
    14. Trait support: `:streaming`, `returns(Type)`, `does TreeRewrite`
    15. Transformation modes: pre, inline, post
    16. Walker factory/registry integration
  - Each slice independently testable
  - Rollback: declarators can be versioned or deprecated if needed, transformers can be replaced
  - No operational runbooks needed (library code)

## Project Structure

### Documentation (this feature)

```
kitty-specs/005-transformer-templates-system/
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
├── Transformer.rakumod          # Transformer class and HOW implementation
├── Template.rakumod             # Template class and metadata
├── Copy.rakumod                 # Copy service class with copy/deepcopy multi subs
├── WalkerFactory.rakumod       # Walker factory/registry (if needed)
└── [Walker.rakumod]             # Existing Walker role (from feature 002)

tests/
├── unit/
│   ├── transformer.rakutest     # Transformer declarator and class tests
│   ├── template.rakutest        # Template declarator and execution tests
│   ├── template-ordering.rakutest # Template ordering algorithm tests
│   ├── magic-variables.rakutest # Magic variable tests
│   └── copy.rakutest            # Copy service class tests
└── integration/
    ├── transformer-walker.rakutest # Transformer-Walker integration tests
    └── transformer-strategy.rakutest # Transformer-Strategy integration tests
```

**Structure Decision**: Extend existing Qwiratry module structure. New modules for Transformer, Template, and supporting infrastructure. Tests organized by unit vs integration. Reuses existing Walker and Strategy infrastructure from previous features.

## Complexity Tracking

*No violations - all complexity is justified by feature requirements*

## Planning Questions Answered

1. **Custom Declarator Implementation**: Use `EXPORTHOW::DECLARE` mechanism (like Red ORM's `model` declarator) - simpler than full slang, integrates with Raku's grammar
2. **Template Declarator Handling**: Combination approach - `EXPORTHOW::DECLARE` for `transformer`, manual parsing for `template` declarations within transformer body
3. **Template Ordering Timing**: Hybrid approach - calculate static aspects at compile time, defer complex cases to runtime
4. **Walker Integration**: Factory/registry pattern - automatic Walker selection based on data type, with explicit override capability
5. **Copy Service Class**: `Qwiratry::Copy` module with multi subs - provides `copy()` and `deepcopy()` functions with default implementations for Positional/Associative, methods attached to Transformer object, transformable nodes determined by Walker capability (supports-rewrite)

