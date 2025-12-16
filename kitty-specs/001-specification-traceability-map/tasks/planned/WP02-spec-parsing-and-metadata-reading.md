---
work_package_id: "WP02"
subtasks:
  - "T005"
  - "T006"
  - "T007"
  - "T008"
  - "T009"
title: "Specification Parsing & Feature Metadata Reading"
phase: "Phase 1 - Foundation"
lane: "planned"
assignee: ""
agent: ""
shell_pid: ""
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2025-12-16T22:24:05Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
---

# Work Package Prompt: WP02 – Specification Parsing & Feature Metadata Reading

## Objectives & Success Criteria

- Parser correctly extracts all section identifiers and hierarchy levels from Specification.md
- Subsection inheritance logic works (3.2.1.1 inherits parent 3.2.1)
- Feature metadata reader successfully loads all feature data from kitty-specs/ directories
- JSON parsing handles optional fields (`dependencies`, `spec_sections`) gracefully
- Missing or malformed meta.json files are handled without crashing

## Context & Constraints

- **Specification.md location**: Repository root
- **Feature directories**: `kitty-specs/*/` (repo root)
- **Metadata file**: `kitty-specs/*/meta.json`
- **Section identifier patterns**: `^\d+(\.\d+)*$` (e.g., "3.2.1") or `^Section \d+$` (e.g., "Section 7")
- **Markdown heading patterns**: `^#+\s+(\d+\.?)+` or `^#+\s+Section\s+\d+`
- **Reference**: See `research.md` for parsing approach, `data-model.md` for data structures

## Subtasks & Detailed Guidance

### Subtask T005 – Implement Specification.md parser

- **Purpose**: Extract all section identifiers, titles, and hierarchy levels from Specification.md.
- **Steps**:
  1. Read Specification.md file from repository root
  2. Parse markdown headings using regex: `^#+\s+((\d+\.?)+|Section\s+\d+)`
  3. Extract section identifier (number pattern or "Section N")
  4. Extract heading level (count of `#` characters)
  5. Extract section title (text after identifier)
  6. Build section tree structure tracking parent-child relationships
  7. Return list of SpecificationSection objects with: identifier, title, level, parent_id
- **Files**: 
  - Create parsing module/class (can be in script or separate module)
  - `scripts/verify-spec-coverage.raku` (or separate `lib/SpecParser.rakumod`)
- **Parallel?**: No (foundational)
- **Notes**: Handle edge cases like malformed headings, empty sections. Store sections in data structure that supports tree traversal.

### Subtask T006 – Implement subsection inheritance logic

- **Purpose**: Ensure subsections (e.g., 3.2.1.1) inherit coverage from parent sections (3.2.1).
- **Steps**:
  1. For each section, identify parent section by matching identifier prefix
  2. Example: 3.2.1.1 → parent is 3.2.1 → parent is 3.2 → parent is 3
  3. Build parent_id field for each section
  4. Implement function to get all ancestors of a section
  5. Use this for coverage calculation (section covered if itself or any ancestor is covered)
- **Files**:
  - Same as T005 (parsing module)
- **Parallel?**: Yes (can proceed after T005 section tree is built)
- **Notes**: Handle root sections (no parent). Ensure efficient lookup of parent sections.

### Subtask T007 – Implement feature metadata reader

- **Purpose**: Scan kitty-specs/ directories and collect feature metadata.
- **Steps**:
  1. Scan `kitty-specs/` directory for subdirectories
  2. For each subdirectory, check for `meta.json` file
  3. Extract feature slug from directory name (e.g., "001-feature-name")
  4. Build list of feature directories to process
  5. Return list of feature directory paths
- **Files**:
  - `scripts/verify-spec-coverage.raku` (or separate module)
- **Parallel?**: Yes (independent of parsing)
- **Notes**: Handle non-feature directories gracefully. Validate directory names match expected pattern.

### Subtask T008 – Implement JSON parsing for meta.json

- **Purpose**: Parse meta.json files and extract feature metadata including optional dependency and spec_sections fields.
- **Steps**:
  1. Read meta.json file from feature directory
  2. Parse JSON using Raku's JSON::Tiny or built-in JSON support
  3. Extract required fields: `feature_number`, `slug`, `friendly_name`
  4. Extract optional fields: `dependencies` (array), `spec_sections` (array)
  5. Validate field types (dependencies and spec_sections must be arrays if present)
  6. Return FeatureTicket object with all fields
- **Files**:
  - Same as T007
- **Parallel?**: Yes (can proceed after T007 finds directories)
- **Notes**: Handle missing optional fields (default to empty array). Validate JSON structure before parsing.

### Subtask T009 – Handle missing or malformed meta.json files

- **Purpose**: Gracefully handle errors when meta.json is missing or invalid JSON.
- **Steps**:
  1. Check if meta.json exists before reading
  2. If missing, log warning and skip feature (don't crash)
  3. If exists but invalid JSON, catch parse exception
  4. Log error with feature directory name and continue processing
  5. Return partial results (valid features only)
- **Files**:
  - Same as T007/T008
- **Parallel?**: Yes (error handling)
- **Notes**: Use try/catch for JSON parsing. Log errors at appropriate level (WARN for missing, ERROR for invalid).

## Test Strategy

- Unit tests should verify:
  - Parser extracts correct section identifiers and levels
  - Subsection inheritance correctly identifies parents
  - Metadata reader finds all feature directories
  - JSON parsing handles optional fields correctly
  - Error handling works for missing/invalid files

## Risks & Mitigations

- **Regex complexity**: Markdown headings may have variations
  - *Mitigation*: Test with actual Specification.md, handle edge cases
- **JSON parsing errors**: Invalid JSON crashes script
  - *Mitigation*: Wrap in try/catch, validate structure, provide clear errors
- **Performance**: Parsing large Specification.md may be slow
  - *Mitigation*: Cache parsed results, optimize regex, single-pass parsing

## Definition of Done Checklist

- [ ] Parser extracts all sections from Specification.md correctly
- [ ] Subsection inheritance identifies parent sections correctly
- [ ] Metadata reader finds all feature directories in kitty-specs/
- [ ] JSON parsing extracts all fields (required and optional)
- [ ] Missing meta.json files are handled gracefully
- [ ] Invalid JSON is caught and logged without crashing
- [ ] `tasks.md` updated with status change

## Review Guidance

- Test parser with actual Specification.md file
- Verify subsection inheritance with nested sections (3.2.1.1 → 3.2.1 → 3.2 → 3)
- Test with various meta.json structures (with/without optional fields)
- Verify error handling with missing and malformed files
- Check performance with realistic number of features

## Activity Log

- 2025-12-16T22:24:05Z – system – lane=planned – Prompt created.

