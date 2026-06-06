---
work_package_id: "WP06"
subtasks:
  - "T051"
  - "T052"
  - "T053"
  - "T054"
  - "T055"
  - "T056"
  - "T057"
  - "T058"
  - "T059"
title: "I/O Operators"
phase: "Phase 2 - Extended Operators"
lane: "planned"
assignee: ""
agent: ""
shell_pid: ""
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2025-01-27T00:00:00Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
---

# Work Package Prompt: WP06 – I/O Operators

## Objectives & Success Criteria

- Implement all 4 I/O operators (source, parse, render, destination) as RakuAST::Node descendants
- Operators support file paths, URLs, and format handling
- All operators are immutable, composable, and introspectable
- Operators declare IOOperator capability
- Format module discovery implemented
- Unit and integration tests verify correct behavior
- Error handling for missing files, invalid formats, inaccessible URLs

## Context & Constraints

- **Reference Documents**:
  - [spec.md](../spec.md) - User Story 4: I/O Operations for External Data Sources (P2)
  - [data-model.md](../data-model.md) - I/O operator entities
  - [contracts/operator-api.md](../contracts/operator-api.md) - I/O operator API contracts
  - [Operators.md](../../../../Operators.md) - I/O operator specification

- **Architecture Decisions**:
  - All operators extend RakuAST::Node and implement IOOperator role
  - Format modules (`Qwiratry::IO::Parse::*`, `Qwiratry::IO::Render::*`) discovered dynamically
  - Location validation (file path vs URL) at AST construction
  - Format options passed via Associative hash

- **Constraints**:
  - Format modules to be implemented separately (not in this feature)
  - File system access requires path validation
  - URL fetching requires URL format validation
  - Error handling at planning-time and runtime

## Subtasks & Detailed Guidance

### Subtask T051 – Create IO module

- **Purpose**: Establish module structure for I/O operators
- **Steps**:
  1. Replace placeholder `lib/Qwiratry/Operator/IO.rakumod` from WP01
  2. Add module declaration and imports
  3. Export all I/O operator classes
- **Files**: 
  - `lib/Qwiratry/Operator/IO.rakumod`
- **Parallel?**: No

### Subtask T052 – Implement SourceOperator class (`⮳`)

- **Purpose**: Operator for reading from external sources (files, URLs)
- **Steps**:
  1. Create `class SourceOperator is RakuAST::Node does IOOperator`
  2. Add attribute: `has $.location is required;` (Str)
  3. Implement constructor with location validation:
     - Validate file path format
     - Validate URL format (http://, https://, file://)
     - Store location as-is (validation only, no execution)
  4. Implement `capabilities()` and `describe()` methods
  5. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/IO.rakumod`
- **Parallel?**: Yes (can be done alongside T053-T055)
- **Notes**: 
  - Location validation checks format, doesn't verify existence
  - Actual file/URL access happens during Walker execution

### Subtask T053 – Implement ParseOperator class (`↱`, `⮣`)

- **Purpose**: Operator for parsing input formats (JSON, XML, CSV, etc.)
- **Steps**:
  1. Create `class ParseOperator is RakuAST::Node does IOOperator`
  2. Add attribute: `has $.format is required;` (Str)
  3. Implement constructor with format validation:
     - Check if format module exists (optional, can defer to runtime)
     - Store format name
  4. Implement `capabilities()` including formats array
  5. Implement `describe()` method
  6. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/IO.rakumod`
- **Parallel?**: Yes
- **Notes**: 
  - Format modules: `Qwiratry::IO::Parse::{format}`
  - Format discovery handled in T056

### Subtask T054 – Implement RenderOperator class (`↴`, `⮧`)

- **Purpose**: Operator for rendering output formats with options
- **Steps**:
  1. Create `class RenderOperator is RakuAST::Node does IOOperator`
  2. Add attributes: `has $.format is required;` (Str), `has $.options;` (Associative?)
  3. Implement constructor with format and options
  4. Implement `capabilities()` including formats array
  5. Implement `describe()` method
  6. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/IO.rakumod`
- **Parallel?**: Yes
- **Notes**: 
  - Format modules: `Qwiratry::IO::Render::{format}`
  - Options: e.g., `{ pretty => True }` for JSON

### Subtask T055 – Implement DestinationOperator class (`⮷`)

- **Purpose**: Operator for writing to external destinations
- **Steps**:
  1. Create `class DestinationOperator is RakuAST::Node does IOOperator`
  2. Add attribute: `has $.location is required;` (Str)
  3. Implement constructor with location validation (similar to SourceOperator)
  4. Implement `capabilities()` and `describe()` methods
  5. Ensure immutability
- **Files**: 
  - `lib/Qwiratry/Operator/IO.rakumod`
- **Parallel?**: Yes
- **Notes**: 
  - Location validation checks format
  - Write permissions checked during execution

### Subtask T056 – Implement format module discovery

- **Purpose**: Discover available format modules dynamically
- **Steps**:
  1. Create helper method `discover-parse-formats()`:
     - Search for `Qwiratry::IO::Parse::*` modules
     - Return array of format names
  2. Create helper method `discover-render-formats()`:
     - Search for `Qwiratry::IO::Render::*` modules
     - Return array of format names
  3. Use Raku module introspection (`.^methods`, module loading)
  4. Cache results if needed (format modules don't change during execution)
  5. Add to IOOperator role or helper module
- **Files**: 
  - `lib/Qwiratry/Operator/IO.rakumod` (or separate helper)
- **Parallel?**: No (used by T053, T054)
- **Notes**: 
  - Format modules not implemented in this feature
  - Discovery should handle missing modules gracefully
  - Return empty array if no format modules found

### Subtask T057 – Write unit tests for I/O operators

- **Purpose**: Verify each I/O operator works correctly
- **Steps**:
  1. Create `t/operator/io.rakutest`
  2. For each operator (T052-T055):
     - Test AST construction with valid locations/formats
     - Test location validation (file paths, URLs)
     - Test format validation
     - Test immutability
     - Test capabilities
     - Test describe method
  3. Test format module discovery (T056)
  4. Run tests: `raku -Ilib t/operator/io.rakutest`
- **Files**: 
  - `t/operator/io.rakutest`
- **Parallel?**: No (depends on T052-T056)

### Subtask T058 – Write I/O pipeline integration tests

- **Purpose**: Verify I/O operators work in pipelines
- **Steps**:
  1. Create `t/integration/io-pipeline.rakutest`
  2. Test source + parse pipeline:
     - Create SourceOperator + ParseOperator
     - Verify AST structure
     - Test with mock Walker (if available)
  3. Test render + destination pipeline:
     - Create RenderOperator + DestinationOperator
     - Verify AST structure
  4. Test full pipeline: source → parse → query → render → destination
  5. Run tests: `raku -Ilib t/integration/io-pipeline.rakutest`
- **Files**: 
  - `t/integration/io-pipeline.rakutest`
- **Parallel?**: No (depends on T052-T056)

### Subtask T059 – Test I/O error handling

- **Purpose**: Verify error handling for I/O edge cases
- **Steps**:
  1. Create `t/operator/io-errors.rakutest`
  2. Test invalid location formats:
     - Invalid file paths
     - Invalid URLs
     - Test exception throwing
  3. Test missing format modules:
     - ParseOperator with non-existent format
     - RenderOperator with non-existent format
     - Test `X::Qwiratry::IO::FormatNotFound` exception
  4. Test location errors:
     - Non-existent files (if testable at AST construction)
     - Test `X::Qwiratry::IO::LocationError` exception
  5. Run tests: `raku -Ilib t/operator/io-errors.rakutest`
- **Files**: 
  - `t/operator/io-errors.rakutest`
- **Parallel?**: No (depends on T052-T056 and WP01 exceptions)

## Test Strategy

- **Unit Tests**: Each operator tested independently (T057)
- **Integration Tests**: I/O pipeline tested (T058)
- **Error Tests**: Error handling verified (T059)
- **Success Criteria**: All tests pass, error handling works correctly

## Risks & Mitigations

- **Risk**: Format module dependency
  - **Mitigation**: Document that format modules must exist separately, handle gracefully
- **Risk**: File system access
  - **Mitigation**: Validate paths, handle permissions gracefully, test error cases
- **Risk**: URL fetching
  - **Mitigation**: Validate URL format, handle network errors, test error cases

## Definition of Done Checklist

- [ ] All 4 I/O operators implemented (T052-T055)
- [ ] Format module discovery implemented (T056)
- [ ] All operators extend RakuAST::Node and implement IOOperator role
- [ ] All operators are immutable
- [ ] Unit tests pass (T057)
- [ ] Integration tests pass (T058)
- [ ] Error handling tests pass (T059)
- [ ] Code follows Raku style guide

## Review Guidance

- Verify location validation works correctly
- Check format module discovery handles missing modules
- Ensure error handling is comprehensive
- Validate I/O pipeline composition works

## Activity Log

- 2025-01-27T00:00:00Z – system – lane=planned – Prompt created.

