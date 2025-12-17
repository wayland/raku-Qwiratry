# Quickstart: Specification Traceability Map

**Feature**: 001-specification-traceability-map

## Overview

The Specification Traceability Map provides automated tracking of which sections of `Specification.md` are covered by which feature tickets, along with dependency visualization and coverage verification.

## Prerequisites

- Raku 6.e installed
- Repository with `Specification.md` in root
- Feature tickets in `kitty-specs/` directories with `meta.json` files

## Quick Start

### 1. Generate Traceability Map

Run the coverage verification script to generate/update the traceability map:

```bash
raku scripts/verify-spec-coverage.raku --generate-map
```

This creates `docs/spec-traceability-map.md` with:
- Section-to-feature mappings
- Auto-generated dependency graph (Mermaid)
- Cross-reference index table

### 2. Verify Coverage

Check which spec sections are covered:

```bash
raku scripts/verify-spec-coverage.raku
```

**Text output**:
```
Coverage: 95.5% (95/100 sections)
Uncovered sections:
  - 3.5.2: Some Section
Broken links: None
Dependency graph: Valid (no circular dependencies)
```

**JSON output** (for CI/CD):
```bash
raku scripts/verify-spec-coverage.raku --json
```

### 3. View Dependency Graph

Open `docs/spec-traceability-map.md` in a markdown viewer that supports Mermaid (GitHub, GitLab, etc.) to see the visual dependency graph.

## Adding Feature Metadata

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

**Fields**:
- `dependencies`: Array of feature slugs this feature depends on (optional)
- `spec_sections`: Array of spec section identifiers this feature covers (optional)

## Common Workflows

### Update Traceability Map After Adding Feature

1. Add `spec_sections` and `dependencies` to feature's `meta.json`
2. Run: `raku scripts/verify-spec-coverage.raku --generate-map`
3. Review generated `docs/spec-traceability-map.md`

### Check Coverage Before Release

```bash
raku scripts/verify-spec-coverage.raku --json | jq '.coverage_percent'
```

Use in CI/CD pipeline to fail if coverage drops below threshold.

### Find Which Feature Implements a Spec Section

1. Open `docs/spec-traceability-map.md`
2. Search for section identifier (e.g., "3.2.1")
3. Check cross-reference table or section mapping

## Troubleshooting

**Issue**: Script reports "directory_not_found" for a feature
- **Solution**: Verify feature directory exists in `kitty-specs/`

**Issue**: Dependency graph shows circular dependencies
- **Solution**: Review feature dependencies in `meta.json` files, remove circular references

**Issue**: Coverage shows sections as uncovered but they should be covered
- **Solution**: Verify `spec_sections` array in feature's `meta.json` includes the section identifier

**Issue**: Subsection not showing as covered
- **Solution**: Subsections inherit coverage from parent. Ensure parent section is in `spec_sections` array.

