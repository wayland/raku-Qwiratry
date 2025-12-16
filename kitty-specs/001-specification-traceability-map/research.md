# Research: Specification Traceability Map

**Feature**: 001-specification-traceability-map  
**Date**: 2025-12-16

## Research Tasks

### Task 1: Raku Markdown Parsing

**Question**: How to parse markdown headings and extract section hierarchy from Specification.md?

**Decision**: Use Raku's built-in text processing capabilities with regex patterns to extract markdown headings.

**Rationale**: 
- Specification.md uses standard markdown heading syntax (`#`, `##`, `###`, etc.)
- Raku's regex engine is powerful enough for this task
- No external dependencies needed
- Headings follow predictable patterns (e.g., `# 3.2.1`, `## 3.2.1.1`)

**Alternatives considered**:
- External markdown parser library: Adds dependency, overkill for heading extraction only
- Manual line-by-line parsing: More error-prone, regex is cleaner

**Implementation approach**:
- Use regex to match markdown heading patterns: `^#+\s+(\d+\.?)+`
- Build section tree structure from heading levels
- Track parent-child relationships for subsection inheritance

---

### Task 2: JSON Metadata Structure

**Question**: What structure should dependency metadata have in `meta.json` files?

**Decision**: Add optional `dependencies` array field to existing `meta.json` structure.

**Rationale**:
- `meta.json` already exists for feature metadata
- Array format allows multiple dependencies
- Backward compatible (optional field)
- Simple to parse and validate

**Alternatives considered**:
- Separate `dependencies.json` file: More files to manage, less discoverable
- YAML format: Requires additional dependency, JSON is standard for Raku

**Implementation approach**:
```json
{
  "feature_number": "001",
  "slug": "001-feature-name",
  "friendly_name": "Feature Name",
  "dependencies": ["000-other-feature", "002-another-feature"],
  "spec_sections": ["3.2.1", "3.2.2"]
}
```

---

### Task 3: Mermaid Diagram Generation

**Question**: How to generate Mermaid dependency graphs from feature metadata?

**Decision**: Generate Mermaid flowchart syntax programmatically from dependency relationships.

**Rationale**:
- Mermaid is text-based, easy to generate
- Widely supported in markdown viewers (GitHub, GitLab, etc.)
- No external rendering needed
- Standard syntax: `A --> B` for "A blocks B"

**Alternatives considered**:
- Graphviz DOT format: Requires external rendering tool
- SVG generation: More complex, harder to maintain
- Image generation: Not version-control friendly

**Implementation approach**:
- Build dependency graph from `meta.json` files
- Generate Mermaid flowchart: `graph TD\n  A[001-feature] --> B[002-feature]`
- Embed in markdown as code block with `mermaid` language tag

---

### Task 4: Coverage Calculation Algorithm

**Question**: How to determine if a spec section is "covered" by a feature?

**Decision**: Check if section identifier appears in feature's `spec_sections` array in `meta.json`, with subsection inheritance from parent.

**Rationale**:
- Explicit mapping is clearest
- Subsection inheritance matches clarification (3.2.1.1 inherits from 3.2.1)
- Allows multiple features to cover same section
- Easy to verify and debug

**Alternatives considered**:
- Parse spec.md comments: Fragile, requires modifying spec
- Separate mapping file: More maintenance overhead
- Heuristic matching: Unreliable, hard to debug

**Implementation approach**:
- Extract all section identifiers from Specification.md
- For each section, check if it or any parent is in a feature's `spec_sections`
- Mark as covered if found, uncovered if not

---

### Task 5: Cross-Reference Table Format

**Question**: What structure should the cross-reference markdown table have?

**Decision**: Two-column table: `| Spec Section | Feature Tickets |` with section identifiers and comma-separated feature links.

**Rationale**:
- Simple, readable format
- Supports multiple features per section
- Easy to generate programmatically
- Standard markdown table syntax

**Alternatives considered**:
- Multi-column with separate columns per feature: Harder to maintain, doesn't scale
- Nested lists: Less structured, harder to scan
- Separate file: Against clarification (should be embedded)

**Implementation approach**:
```markdown
| Spec Section | Feature Tickets |
|--------------|----------------|
| 3.2.1 | [001-walker-core](../kitty-specs/001-walker-core/) |
| 3.2.2 | [001-walker-core](../kitty-specs/001-walker-core/) |
```

---

## Consolidated Findings

**Key Technologies**:
- Raku standard library for file I/O, JSON parsing, regex
- Markdown text generation (no parser needed, just text output)
- Mermaid diagram syntax (text-based)

**Key Patterns**:
- Parse markdown headings with regex
- Read JSON metadata from `meta.json` files
- Generate markdown tables and diagrams programmatically
- Validate coverage by checking section identifiers against feature metadata

**Dependencies**: None (Raku standard library only)

**Performance Considerations**:
- Script should cache parsed Specification.md to avoid re-parsing
- Process features in single pass for efficiency
- Target: <5 seconds execution time (SC-002)

