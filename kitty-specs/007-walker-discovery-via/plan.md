# Implementation Plan: Walker Discovery via Implementation::Loader

**Branch**: `007-walker-discovery-via` | **Date**: 2025-01-27 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/kitty-specs/007-walker-discovery-via/spec.md`

## Summary

Implement automatic Walker discovery in `WalkerFactory.discover-walkers()` using Implementation::Loader (v0.0.7+) to scan for Walker classes matching the `Qwiratry::Walker::*` pattern in the `lib` directory. Discovery results are cached for performance, with an optional parameter to force refresh. Discovered classes are assumed to implement Walker without runtime verification, avoiding unnecessary module loading.

## Technical Context

**Language/Version**: Raku 6.e (with RakuAST support)  
**Primary Dependencies**: 
- Implementation::Loader (version 0.0.7 or higher) - for efficient module discovery via glob patterns
- Existing Qwiratry::Walker role (from feature 002)
**Storage**: N/A (in-memory discovery cache)  
**Testing**: The built-in Test module (rakutest)  
**Target Platform**: Everything that Raku targets  
**Project Type**: Raku library module enhancement  
**Performance Goals**: 
- Discovery should complete without loading non-matching modules
- Cached discovery should return immediately on subsequent calls
- Discovery should handle cases with no matching classes efficiently
**Constraints**: 
- Must use Implementation::Loader v0.0.7+ for discovery mechanism
- Must use glob pattern `Qwiratry::Walker::*` in `lib` directory
- Must not perform runtime verification of Walker role (assume classes implement it)
- Must handle missing/incompatible Implementation::Loader gracefully
**Scale/Scope**: 
- Single method implementation in existing WalkerFactory class
- Supports discovery of unlimited Walker classes matching the pattern
- Cache per WalkerFactory instance (not global)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### P1. Test-First, Evidence-Backed Delivery
- ✅ **Tests Required**: Unit tests for `discover-walkers()` method covering:
  - Discovery of matching Walker classes
  - Empty result when no matches found
  - Caching behavior (returns cached result on second call)
  - Refresh parameter forces re-discovery
  - Error handling for missing Implementation::Loader
  - Error handling for incompatible version
- ✅ **Integration Tests**: Verify discovery works with actual Walker classes in test namespace

### P2. Explicit Data Contracts and Safe Mutation
- ✅ **Data Contract**: `discover-walkers()` returns `Array[Walker]` (type objects, not instances)
- ✅ **State Management**: Cache state is private (`@!discovered-walkers`, `$!discovery-performed`) and scoped to instance
- ✅ **Immutability**: Discovery results are cached but can be refreshed via parameter

### P3. CLI-First with Observable Text I/O
- ⚠️ **N/A**: This is a library method, not a CLI feature. No CLI surface required.

### P4. Security and Privacy by Default
- ✅ **Dependency Security**: Implementation::Loader is a trusted Raku module from ecosystem
- ✅ **No Sensitive Data**: Discovery only scans module structure, no user data involved
- ✅ **Error Handling**: Graceful handling of missing dependencies prevents information leakage

### P5. Simplicity, Small Increments, and Operability
- ✅ **Incremental**: Single method implementation, can be tested independently
- ✅ **Reversible**: Can revert to empty array return if issues arise
- ✅ **Simple Design**: Uses existing library (Implementation::Loader) rather than custom discovery logic

### P6. Raku Coding Style
- ✅ **Documentation**: Method will have embedded Rakudoc following project conventions
- ✅ **Style**: Follow Tim Nelson/Elizabeth Mattijsen coding style patterns

**Constitution Check Status**: ✅ PASS - All applicable principles satisfied

## Project Structure

### Documentation (this feature)

```
kitty-specs/007-walker-discovery-via/
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
└── Qwiratry/
    └── WalkerFactory.rakumod    # Modify discover-walkers() method

tests/
└── unit/
    └── walker-factory.rakutest  # Add tests for discovery mechanism
```

**Structure Decision**: Single Raku library project. Modification to existing `WalkerFactory.rakumod` file. Tests added to existing test structure.

## Complexity Tracking

*No violations - simple single-method enhancement using existing library*

## Phase 0 & Phase 1 Completion

**Phase 0 (Research)**: ✅ Complete
- Research questions answered in `research.md`
- Implementation::Loader usage patterns documented
- Caching strategy defined
- Error handling approach determined

**Phase 1 (Design)**: ✅ Complete
- Data model documented in `data-model.md`
- API contract defined in `contracts/walker-factory-api.md`
- Quickstart guide created in `quickstart.md`
- Constitution check passed

**Next Steps**: Ready for `/spec-kitty.tasks` to break down into work packages

