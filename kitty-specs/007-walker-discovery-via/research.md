# Research: Walker Discovery via Implementation::Loader

**Feature**: Walker Discovery via Implementation::Loader  
**Date**: 2025-01-27  
**Phase**: 0 - Outline & Research

## Research Questions

### RQ1: Implementation::Loader API and Usage Patterns

**Question**: How do we use Implementation::Loader (v0.0.7+) to discover classes by glob pattern without loading all modules?

**Findings**:
- Implementation::Loader provides efficient module discovery via glob patterns
- Can scan for classes matching namespace patterns without loading non-matching modules
- Supports scanning in specific directories (e.g., `lib`)
- Returns type objects for discovered classes

**Decision**: Use Implementation::Loader to scan for `Qwiratry::Walker::*` pattern in `lib` directory. Load discovered classes and return their type objects.

**Rationale**: Implementation::Loader is designed for this exact use case - efficient discovery without loading unrelated modules. This matches the requirement to avoid loading every module.

**Alternatives Considered**: 
- Manual module scanning via file system - rejected, more complex and error-prone
- Loading all modules and checking roles - rejected, violates requirement to avoid loading non-matching modules
- Using Metamodel introspection - rejected, requires modules to be loaded first

---

### RQ2: Caching Strategy for Discovery Results

**Question**: How should we implement caching with refresh capability in WalkerFactory?

**Findings**:
- MasterWalker uses `@!discovered-walkers` and `$!discovery-performed` flag for caching
- Caching improves performance by avoiding repeated discovery
- User requirement: cache by default, allow refresh via parameter

**Decision**: Implement caching similar to MasterWalker:
- Private attributes: `@!discovered-walkers` (Array) and `$!discovery-performed` (Bool)
- Method signature: `discover-walkers(Bool :$refresh = False)`
- If `$refresh` is True or discovery not performed, run discovery and cache results
- Otherwise return cached results

**Rationale**: Consistent with existing MasterWalker pattern. Refresh parameter gives users control when modules are dynamically loaded.

**Alternatives Considered**:
- No caching - rejected, poor performance for repeated calls
- Global cache - rejected, per-instance cache is more flexible
- Always refresh - rejected, violates performance requirement

---

### RQ3: Error Handling for Missing Dependencies

**Question**: How should we handle cases where Implementation::Loader is unavailable or incompatible?

**Findings**:
- Raku modules can be checked for availability using `try` blocks
- Version checking can be done via module metadata
- Graceful degradation: return empty array or throw descriptive exception

**Decision**: Use `try` block to load Implementation::Loader. If unavailable or version < 0.0.7:
- Throw `X::Qwiratry` exception with descriptive message
- Exception should indicate missing dependency and version requirement
- Do not silently fail - users need to know why discovery doesn't work

**Rationale**: Fail-fast with clear error message is better than silent failure. Users can fix dependency issues immediately.

**Alternatives Considered**:
- Return empty array silently - rejected, hides configuration problems
- Log warning and continue - rejected, violates fail-fast principle
- Compile-time check - rejected, too restrictive, some users may not need discovery

---

### RQ4: Glob Pattern Format for Implementation::Loader

**Question**: What is the correct glob pattern format for `Qwiratry::Walker::*` namespace?

**Findings**:
- Implementation::Loader uses namespace patterns, not file paths
- Pattern `Qwiratry::Walker::*` should match all classes in that namespace
- Directory parameter specifies where to search (e.g., `lib`)

**Decision**: Use pattern `Qwiratry::Walker::*` with directory `lib`. Implementation::Loader will find all classes matching this namespace pattern.

**Rationale**: Matches user requirement exactly. Namespace pattern is the standard way to discover classes in Raku.

**Alternatives Considered**:
- File glob pattern (e.g., `lib/Qwiratry/Walker/*.rakumod`) - rejected, Implementation::Loader uses namespace patterns
- Recursive search - rejected, pattern already covers namespace hierarchy

---

## Summary of Decisions

1. **Discovery Mechanism**: Use Implementation::Loader (v0.0.7+) with pattern `Qwiratry::Walker::*` in `lib` directory
2. **Caching**: Per-instance cache with `@!discovered-walkers` and `$!discovery-performed` flag, refresh via `:$refresh` parameter
3. **Error Handling**: Throw descriptive exception if Implementation::Loader unavailable or incompatible
4. **Pattern Format**: Use namespace pattern `Qwiratry::Walker::*` (not file glob)

All research questions resolved. Ready for Phase 1 design.

