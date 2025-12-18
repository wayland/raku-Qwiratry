# Data Model: Specification Traceability Map

**Feature**: 001-specification-traceability-map  
**Date**: 2025-12-16

## Entities

### SpecificationSection

Represents a section or subsection from Specification.md.

**Attributes**:
- `identifier` (Str): Unique section identifier (e.g., "3.2.1", "Section 7")
- `title` (Str): Section heading text
- `level` (Int): Heading depth (1 = `#`, 2 = `##`, etc.)
- `parent_id` (Str?): Parent section identifier if subsection, Nil if top-level
- `content` (Str): Section content (optional, for reference)

**Relationships**:
- Has many subsections (children)
- Belongs to one parent section (if subsection)
- Covered by zero or more FeatureTickets

**Validation Rules**:
- Identifier must match pattern: `^\d+(\.\d+)*$` or `^Section \d+$`
- Level must be between 1 and 6 (markdown heading levels)
- If parent_id exists, parent must exist in section tree

**State Transitions**: None (immutable, read from Specification.md)

---

### FeatureTicket

Represents a spec-kitty feature ticket.

**Attributes**:
- `feature_number` (Str): Three-digit feature number (e.g., "001")
- `slug` (Str): Feature branch slug (e.g., "001-feature-name")
- `friendly_name` (Str): Human-readable feature name
- `spec_sections` (Array[Str]): List of spec section identifiers this feature covers
- `dependencies` (Array[Str]): List of feature slugs this feature depends on (blocks)
- `directory_path` (Str): Path to feature directory (e.g., "kitty-specs/001-feature-name/")

**Relationships**:
- Covers zero or more SpecificationSections
- Blocks zero or more FeatureTickets (dependencies)
- Blocked by zero or more FeatureTickets (reverse dependencies)

**Validation Rules**:
- Feature number must be three digits
- Slug must match pattern: `^\d{3}-[\w-]+$`
- All dependencies must reference existing feature tickets
- Spec sections must reference valid section identifiers

**State Transitions**: None (read from meta.json files)

---

### DependencyRelationship

Represents a blocking relationship between two features.

**Attributes**:
- `from_feature` (Str): Feature slug that blocks (Feature A)
- `to_feature` (Str): Feature slug that is blocked (Feature B)
- `relationship_type` (Str): Always "blocks" for this feature

**Relationships**:
- From one FeatureTicket (blocker)
- To one FeatureTicket (blocked)

**Validation Rules**:
- Both features must exist
- No circular dependencies (must be acyclic)
- Self-dependencies not allowed

**State Transitions**: None (derived from FeatureTicket dependencies)

---

### CoverageStatus

Represents whether a spec section is covered by features.

**Attributes**:
- `section_id` (Str): Specification section identifier
- `is_covered` (Bool): Whether section has at least one covering feature
- `covering_features` (Array[Str]): List of feature slugs that cover this section
- `inherited_from` (Str?): Parent section if coverage is inherited

**Relationships**:
- References one SpecificationSection
- References zero or more FeatureTickets

**Validation Rules**:
- If inherited_from exists, parent section must be covered
- covering_features must reference existing features

**State Transitions**: Recalculated when features are added/removed

---

## Data Flow

1. **Parse Specification.md** → Extract SpecificationSection entities
2. **Read meta.json files** → Extract FeatureTicket entities
3. **Build dependency graph** → Create DependencyRelationship entities from FeatureTicket.dependencies
4. **Calculate coverage** → Generate CoverageStatus for each SpecificationSection
5. **Generate traceability map** → Output markdown document with mappings
6. **Generate dependency graph** → Output Mermaid diagram
7. **Generate cross-reference** → Output markdown table

## Storage Format

- **Input**: 
  - `Specification.md` (markdown text file)
  - `kitty-specs/*/meta.json` (JSON files)
- **Output**: 
  - `docs/spec-traceability-map.md` (markdown text file)
  - Coverage script output (JSON or text to stdout)

## Data Contracts

### meta.json Schema Extension

```json
{
  "feature_number": "001",
  "slug": "001-feature-name",
  "friendly_name": "Feature Name",
  "source_description": "...",
  "created_at": "2025-12-16T00:00:00Z",
  "dependencies": ["000-other-feature"],  // NEW: optional array
  "spec_sections": ["3.2.1", "3.2.2"]     // NEW: optional array
}
```

**Validation**:
- `dependencies`: Array of strings, each must match feature slug pattern
- `spec_sections`: Array of strings, each must match section identifier pattern
- Both fields optional (backward compatible)

### Coverage Script JSON Output

```json
{
  "coverage_percent": 95.5,
  "total_sections": 100,
  "covered_sections": 95,
  "uncovered_sections": [
    {"section": "3.5.2", "title": "Some Section"}
  ],
  "broken_links": [
    {"feature": "005-missing-feature", "reason": "directory_not_found"}
  ],
  "dependency_graph_valid": true,
  "circular_dependencies": []
}
```

