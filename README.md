# Specification Traceability Map

A comprehensive traceability system that maps all sections of `Specification.md` to feature tickets, providing automated coverage verification, dependency visualization, and cross-reference indexing.

## Features

- **Section-to-Feature Mapping**: Automatically maps every section of Specification.md to feature tickets
- **Dependency Graph**: Visual Mermaid diagram showing blocking relationships between features
- **Coverage Verification**: Script to verify all spec sections are covered by at least one feature
- **Cross-Reference Index**: Quick lookup table for finding which features implement which spec sections
- **Broken Link Detection**: Automatically detects when feature directories are missing or renamed

## Installation

Requires Raku 6.e or later:

```bash
# Check Raku version
raku --version
```

## Usage

### Generate Traceability Map

Generate or update the traceability map document:

```bash
raku scripts/verify-spec-coverage.raku --generate-map
```

This creates `docs/spec-traceability-map.md` containing:
- Coverage summary
- Dependency graph (Mermaid format)
- Cross-reference index table
- Detailed section mappings

### Check Coverage

Verify which spec sections are covered:

```bash
# Text output (human-readable)
raku scripts/verify-spec-coverage.raku

# JSON output (for CI/CD)
raku scripts/verify-spec-coverage.raku --json
```

**Text Output Example**:
```
Coverage Report
================

Coverage: 0% (0/45 sections)

Covered sections: 0
Uncovered sections: 45

Uncovered Sections:
  - Section 1 (Introduction)
  - Section 1.1 (Purpose)
  ...
```

**JSON Output Example**:
```json
{
  "coverage_percent": 0,
  "total_sections": 45,
  "covered_sections": 0,
  "uncovered_sections": [
    {"section": "1", "title": "Introduction", "level": 1},
    ...
  ],
  "broken_links": [],
  "dependency_graph": {
    "valid": true,
    "circular_dependencies": [],
    "validation_errors": []
  }
}
```

### Script Options

```bash
# Generate traceability map
raku scripts/verify-spec-coverage.raku --generate-map

# Check coverage (text output)
raku scripts/verify-spec-coverage.raku

# Check coverage (JSON output)
raku scripts/verify-spec-coverage.raku --json

# Verbose output (includes debug information)
raku scripts/verify-spec-coverage.raku --verbose

# Custom paths
raku scripts/verify-spec-coverage.raku \
  --spec-file=path/to/Specification.md \
  --specs-dir=path/to/kitty-specs \
  --output-dir=path/to/docs

# Help
raku scripts/verify-spec-coverage.raku --help
```

## Feature Metadata Format

To include a feature in the traceability system, add metadata to its `meta.json`:

```json
{
  "feature_number": "002",
  "slug": "002-strategy-control",
  "friendly_name": "Strategy and ControlSignal",
  "dependencies": ["001-walker-core"],
  "spec_sections": ["3.2.5", "3.2.6"]
}
```

**Required Fields**:
- `feature_number`: Unique feature identifier (e.g., "001", "002")
- `slug`: Feature directory name (e.g., "001-walker-core")
- `friendly_name`: Human-readable feature name

**Optional Fields**:
- `dependencies`: Array of feature slugs this feature depends on (for dependency graph)
- `spec_sections`: Array of spec section identifiers this feature covers (e.g., ["3.2.1", "3.2.2"])

## Common Workflows

### Adding a New Feature

1. Create feature directory: `kitty-specs/002-feature-name/`
2. Add `meta.json` with feature metadata:
   ```json
   {
     "feature_number": "002",
     "slug": "002-feature-name",
     "friendly_name": "Feature Name",
     "dependencies": [],
     "spec_sections": ["2.1", "2.2"]
   }
   ```
3. Regenerate traceability map:
   ```bash
   raku scripts/verify-spec-coverage.raku --generate-map
   ```

### Checking Coverage Before Release

```bash
# Get coverage percentage
raku scripts/verify-spec-coverage.raku --json | jq '.coverage_percent'

# Check for uncovered sections
raku scripts/verify-spec-coverage.raku --json | jq '.uncovered_sections'

# Use in CI/CD (fail if coverage < 100%)
COVERAGE=$(raku scripts/verify-spec-coverage.raku --json | jq -r '.coverage_percent')
if [ "$COVERAGE" -lt 100 ]; then
  echo "Coverage is $COVERAGE%, must be 100%"
  exit 1
fi
```

### Finding Which Feature Implements a Spec Section

1. Open `docs/spec-traceability-map.md`
2. Search for section identifier (e.g., "3.2.1")
3. Check the cross-reference index table or section mappings

### Viewing Dependency Graph

Open `docs/spec-traceability-map.md` in a markdown viewer that supports Mermaid:
- GitHub (renders automatically)
- GitLab (renders automatically)
- VS Code with Mermaid extension
- Online Mermaid editor: https://mermaid.live/

## Troubleshooting

### Script reports "directory_not_found" for a feature

**Problem**: A feature referenced in `dependencies` or `spec_sections` doesn't exist.

**Solution**: 
- Verify the feature directory exists in `kitty-specs/`
- Check that the `slug` in `meta.json` matches the directory name
- Ensure the feature directory contains a `meta.json` file

### Dependency graph shows circular dependencies

**Problem**: Features have circular dependency chains (A depends on B, B depends on A).

**Solution**: 
- Review feature dependencies in `meta.json` files
- Remove circular references
- Restructure features to break the cycle

### Coverage shows sections as uncovered but they should be covered

**Problem**: `spec_sections` array doesn't include the section identifier.

**Solution**: 
- Verify `spec_sections` array in feature's `meta.json` includes the exact section identifier
- Check that section identifiers match the format in Specification.md (e.g., "3.2.1", not "3.2.1.1" if you want to cover the parent)
- Note: Subsections inherit coverage from parent sections

### Subsection not showing as covered

**Problem**: Only parent section is in `spec_sections`, but subsection should be covered.

**Solution**: 
- Subsections automatically inherit coverage from parent sections
- If section "3.2.1" is in `spec_sections`, then "3.2.1.1", "3.2.1.2", etc. are automatically covered
- No need to list all subsections explicitly

### Script exits with code 2

**Problem**: Missing or invalid specification file.

**Solution**: 
- Verify `Specification.md` exists at the specified path
- Check file permissions
- Ensure the file is valid markdown

### JSON output is empty or invalid

**Problem**: Script errors are written to stderr, not stdout.

**Solution**: 
- Check stderr for error messages: `raku scripts/verify-spec-coverage.raku --json 2>&1`
- Verify all required files exist
- Check that Raku version is 6.e or later

## Error Messages

### "ERROR: Specification file not found: ..."

The specification file path is incorrect or the file doesn't exist.

**Fix**: Verify the `--spec-file` path is correct, or use the default `Specification.md` in the current directory.

### "ERROR: Invalid JSON in meta.json: ..."

A feature's `meta.json` file contains invalid JSON syntax.

**Fix**: Validate JSON syntax using a JSON validator or `jq`:
```bash
jq . kitty-specs/001-feature-name/meta.json
```

### "WARN: Section X is not covered by any feature"

A spec section has no features assigned to it.

**Fix**: Add the section identifier to a feature's `spec_sections` array in `meta.json`.

### "ERROR: Feature directory not found: ..."

A feature referenced in `dependencies` doesn't exist.

**Fix**: Create the feature directory or remove the dependency reference.

### "ERROR: Circular dependency detected: ..."

Features have circular dependencies that create a cycle.

**Fix**: Review and restructure feature dependencies to break the cycle.

## Exit Codes

- `0`: Success (coverage check passed or map generated successfully)
- `1`: Coverage check failed (uncovered sections found)
- `2`: Error (missing files, invalid input, etc.)

## Examples

See `docs/example-meta.json` for a complete example of feature metadata with dependencies and spec_sections.

## Testing

Run the test suite:

```bash
# All unit tests
for test in tests/unit/*.t; do raku -I. "$test"; done

# All integration tests
for test in tests/integration/*.t; do raku -I. "$test"; done
```

See `tests/README.md` for more details.

## License

[Add license information here]

## Contributing

[Add contributing guidelines here]

