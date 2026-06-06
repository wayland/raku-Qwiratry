# Implementation Plan: Qwiratry Operators Specification

**Branch**: `006-qwiratry-operators-specification` | **Date**: 2025-01-27 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/kitty-specs/006-qwiratry-operators-specification/spec.md`

**Note**: This template is filled in by the `/spec-kitty.plan` command. See `.kittify/templates/commands/plan.md` for the execution workflow.

## Summary

Implement comprehensive query operators for Qwiratry as RakuAST::Node descendants that work both in Query Slang expressions and regular Raku code. Operators include navigation (child, parent, descendant, etc.), map-reduce (selection, sort, map, reduce), set operations (union, intersection, joins), and I/O (parse, render, source, destination). Operators use a capability/interface system for domain-specific semantics, with hybrid error handling (compile-time syntax, planning-time compatibility, runtime data validation). All operators are immutable, composable, and introspectable, enabling Walkers to optimize query execution.

## Technical Context

**Language/Version**: Raku 6.e (with RakuAST support required)
**Primary Dependencies**: 
- Existing Qwiratry infrastructure: `Qwiratry::Walker`, `Qwiratry::QueryIterator`, `Qwiratry::Context`
- RakuAST (built into Raku 6.e)
- Future: `Qwiratry::IO::Parse::*` and `Qwiratry::IO::Render::*` modules (to be implemented separately)

**Storage**: N/A (operators are in-memory AST nodes)

**Testing**: The built-in Test module (`use Test`)

**Target Platform**: Everything that Raku 6.e targets (Linux, macOS, Windows, etc.)

**Project Type**: Raku library module - operators extend Qwiratry query capabilities

**Performance Goals**: 
- Operator AST construction: O(1) for simple operators, O(n) for composed operators where n is operator count
- Walker introspection: O(1) for capability checks, O(n) for AST traversal where n is AST depth
- No specific runtime performance targets (delegated to Walkers and QueryIterators)

**Constraints**: 
- Must maintain backward compatibility with existing Walker interface (`Walker.plan(RakuAST::Node $query, Mu $root)`)
- Operators must be immutable (no observable mutations)
- Must work with existing QueryIterator infrastructure

**Scale/Scope**: 
- ~50+ operators across 4 categories (navigation, map-reduce, set, I/O)
- Operators must support composition into complex query pipelines
- Must integrate with Query Slang (to be implemented in separate feature)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Tests-first**: 
  - Unit tests for each operator class (AST construction, immutability, capability declarations)
  - Unit tests for operator composition (chaining, set operations)
  - Integration tests for Walker-operator interaction (capability checking, planning)
  - Integration tests for QueryIterator execution with operators
  - Contract tests for operator-walker interface (capability system)
  - Tests for error handling at each stage (compile-time, planning-time, runtime)

- **Data contracts**: 
  - Operator AST nodes: RakuAST::Node type constraint, immutable structure
  - Capability metadata: Associative hash with standardized keys
  - Walker-operator interface: `supports(RakuAST::Node $query) -> Bool` method contract
  - Error exceptions: `X::Qwiratry::UnknownQueryElement` and domain-specific exceptions
  - No data migration needed (new feature, no existing operators)

- **CLI and observability**: 
  - N/A: Operators are library components, not CLI tools
  - Debugging support: Operators provide `.describe()` or `.gist()` methods for introspection
  - Error messages: Include operator type, context, and actionable guidance

- **Security/privacy**: 
  - I/O operators (source, destination) handle external data - validate file paths and URLs
  - Parse/render operators process external formats - validate format modules exist before use
  - No authentication/authorization needed (operators are pure AST nodes)
  - Dependency health: Format modules (`Qwiratry::IO::Parse::*`, `Qwiratry::IO::Render::*`) checked at runtime

- **Simplicity/operability**: 
  - Incremental delivery: Implement operators by category (navigation → map-reduce → set → I/O)
  - Each category independently testable and usable
  - Reversible: Operators are additive, can be disabled via capability checks if needed
  - Small increments: Start with core navigation operators, add complexity incrementally
  - No runbooks needed (library feature, not operational service)

- **Exceptions**: None - all principles satisfied

## Project Structure

### Documentation (this feature)

```
kitty-specs/[###-feature]/
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
├── Operator/
│   ├── Navigation.rakumod        # Navigation operators (child, parent, descendant, etc.)
│   ├── MapReduce.rakumod          # Map-reduce operators (selection, sort, map, reduce)
│   ├── Set.rakumod               # Set operators (union, intersection, joins, etc.)
│   ├── IO.rakumod                # I/O operators (source, parse, render, destination)
│   └── Capability.rakumod        # Capability roles and interfaces
├── Exception/
│   └── Operator.rakumod          # Operator-specific exceptions
└── [existing modules: Walker.rakumod, QueryIterator.rakumod, Context.rakumod]

t/
├── operator/
│   ├── navigation.rakutest       # Navigation operator tests
│   ├── mapreduce.rakutest        # Map-reduce operator tests
│   ├── set.rakutest              # Set operator tests
│   ├── io.rakutest               # I/O operator tests
│   └── composition.rakutest      # Operator composition tests
├── integration/
│   ├── walker-operator.rakutest  # Walker-operator integration tests
│   └── iterator-operator.rakutest # QueryIterator-operator integration tests
└── contract/
    └── capability.rakutest       # Capability system contract tests
```

**Structure Decision**: Single project structure following existing Qwiratry module organization. Operators organized by category in `lib/Qwiratry/Operator/` with capability system in separate module. Tests mirror source structure with category-specific test files plus integration and contract tests.

## Complexity Tracking

*Fill ONLY if Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |

## Parallel Work Analysis

*Include this section if multiple developers/agents will implement this feature*

### Dependency Graph

```
[Identify what must be built sequentially vs what can be done in parallel]
Example:
Foundation (Day 1) → Wave 1 (Days 2-3, parallel) → Wave 2 (Days 4-5, parallel) → Integration (Day 6)
```

### Work Distribution

- **Sequential work**: [What must be done first before parallel work can begin]
- **Parallel streams**: [Independent work that can be done simultaneously]
- **Agent assignments**: [Who owns which files/modules to avoid conflicts]

### Coordination Points

- **Sync schedule**: [When parallel workers merge their changes]
- **Integration tests**: [How to verify parallel work integrates correctly]
