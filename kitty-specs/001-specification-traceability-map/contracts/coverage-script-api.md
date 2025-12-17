# API Contract: Coverage Verification Script

**Script**: `scripts/verify-spec-coverage.raku`  
**Version**: 1.0.0

## Command-Line Interface

### Synopsis

```bash
raku scripts/verify-spec-coverage.raku [OPTIONS]
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `--json` | Output results as JSON instead of human-readable text | false |
| `--verbose` | Include detailed logging output | false |
| `--generate-map` | Generate/update traceability map document | false |
| `--spec-file` | Path to Specification.md | `Specification.md` (repo root) |
| `--specs-dir` | Path to kitty-specs directory | `kitty-specs/` (repo root) |
| `--output-dir` | Directory for generated traceability map | `docs/` (repo root) |
| `--help` | Show help message | - |

### Exit Codes

- `0`: Success (coverage check passed or map generated successfully)
- `1`: Error (uncovered sections found, broken links, or script error)
- `2`: Invalid arguments or missing files

## Text Output Format

### Standard Output (Human-Readable)

```
Coverage Report
================
Coverage: 95.5% (95/100 sections)

Covered sections: 95
Uncovered sections: 5

Uncovered Sections:
  - 3.5.2: Some Section Title
  - 3.5.3: Another Section
  ...

Broken Links:
  - 005-missing-feature: directory_not_found

Dependency Graph Status: Valid
Circular Dependencies: None
```

### Error Output (Stderr)

```
ERROR: Failed to parse Specification.md: invalid heading at line 42
ERROR: Feature 005-missing-feature: directory not found
WARN: Section 3.5.2 is not covered by any feature
```

## JSON Output Format

### Success Response

```json
{
  "status": "success",
  "coverage_percent": 95.5,
  "total_sections": 100,
  "covered_sections": 95,
  "uncovered_sections": [
    {
      "section": "3.5.2",
      "title": "Some Section Title",
      "level": 3
    }
  ],
  "broken_links": [
    {
      "feature": "005-missing-feature",
      "reason": "directory_not_found",
      "expected_path": "kitty-specs/005-missing-feature"
    }
  ],
  "dependency_graph": {
    "valid": true,
    "circular_dependencies": [],
    "total_relationships": 12
  },
  "traceability_map_generated": false
}
```

### Error Response

```json
{
  "status": "error",
  "error_code": "PARSE_ERROR",
  "message": "Failed to parse Specification.md: invalid heading at line 42",
  "details": {}
}
```

## Input Contracts

### Specification.md Structure

- Must be valid markdown
- Headings must follow pattern: `^#+\s+(\d+\.?)+` or `^#+\s+Section\s+\d+`
- Section identifiers extracted from headings

### meta.json Structure

```json
{
  "feature_number": "001",
  "slug": "001-feature-name",
  "friendly_name": "Feature Name",
  "dependencies": ["000-other-feature"],  // optional
  "spec_sections": ["3.2.1", "3.2.2"]     // optional
}
```

**Validation Rules**:
- `dependencies`: Array of strings, each must be valid feature slug
- `spec_sections`: Array of strings, each must match section identifier pattern
- Both fields optional (backward compatible)

## Output Contracts

### Traceability Map Document

**Location**: `docs/spec-traceability-map.md`

**Structure**:
1. Header with generation timestamp
2. Section-to-feature mappings (organized by spec section)
3. Dependency graph (Mermaid diagram)
4. Cross-reference index table

**Markdown Format**:
- Standard markdown syntax
- Mermaid code blocks for diagrams
- Markdown tables for cross-reference

## Performance Contract

- Execution time: < 5 seconds (SC-002)
- Memory usage: O(n) where n = number of sections + features
- File I/O: Single pass through Specification.md, single pass through feature directories

## Error Handling

### Recoverable Errors

- Missing `meta.json` file: Skip feature, log warning
- Invalid JSON in `meta.json`: Skip feature, log error
- Malformed section identifier: Skip section, log warning

### Fatal Errors

- Specification.md not found: Exit with code 2
- Invalid command-line arguments: Exit with code 2
- Permission errors: Exit with code 1

## Versioning

- API version follows semantic versioning
- Breaking changes increment MAJOR version
- New options increment MINOR version
- Bug fixes increment PATCH version

