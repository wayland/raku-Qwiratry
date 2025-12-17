---
work_package_id: "WP04"
subtasks:
  - "T015"
  - "T016"
  - "T017"
  - "T018"
  - "T019"
title: "Dependency Graph Generation"
phase: "Phase 3 - Enhancement"
lane: "doing"
assignee: "claude"
agent: "claude"
shell_pid: "319772"
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2025-12-16T22:24:05Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
  - timestamp: "2025-12-17T01:09:26Z"
    lane: "doing"
    agent: "claude"
    shell_pid: "319772"
    action: "Started implementation"
---

# Work Package Prompt: WP04 – Dependency Graph Generation

## Objectives & Success Criteria

- Dependency graph correctly shows all blocking relationships from feature metadata
- Mermaid diagram syntax is valid and renders correctly
- Circular dependencies are detected and reported as errors
- Graph is embedded in traceability map document

## Context & Constraints

- **Dependency source**: `meta.json` files with `dependencies` array field
- **Graph format**: Mermaid flowchart syntax
- **Relationship**: Feature A --> Feature B means "A blocks B"
- **Reference**: See `research.md` for Mermaid syntax, `data-model.md` for DependencyRelationship entity

## Subtasks & Detailed Guidance

### Subtask T015 – Build dependency graph from feature metadata
- **Purpose**: Read dependencies arrays from all meta.json files and build directed graph.
- **Steps**: Iterate features, read dependencies arrays, build graph structure (from_feature -> to_feature).
- **Files**: Core logic in script/module.
- **Parallel?**: No (foundational).

### Subtask T016 – Detect circular dependencies
- **Purpose**: Identify cycles in dependency graph and report as errors.
- **Steps**: Use graph traversal (DFS) to detect cycles, report circular dependencies clearly.
- **Files**: Same as T015.
- **Parallel?**: Yes (after T015 graph built).

### Subtask T017 – Generate Mermaid flowchart syntax
- **Purpose**: Convert dependency graph to Mermaid diagram syntax.
- **Steps**: Generate `graph TD\n  A[001-feature] --> B[002-feature]` format, use feature slugs as node IDs.
- **Files**: Same as T015.
- **Parallel?**: Yes (after T015).

### Subtask T018 – Embed Mermaid diagram in traceability map
- **Purpose**: Add Mermaid diagram to markdown document.
- **Steps**: Embed as code block with `mermaid` language tag, place after section mappings.
- **Files**: Markdown generation logic.
- **Parallel?**: Yes (after T017).

### Subtask T019 – Validate graph structure
- **Purpose**: Ensure no self-dependencies and all feature references are valid.
- **Steps**: Check no feature depends on itself, validate all dependency targets exist.
- **Files**: Same as T015.
- **Parallel?**: Yes (validation).

## Test Strategy

- Unit tests verify graph building, cycle detection, Mermaid generation
- Integration test verifies diagram renders correctly in markdown viewer

## Risks & Mitigations

- **Circular dependencies**: Detect and report clearly, prevent infinite loops
- **Invalid references**: Validate all dependencies reference existing features

## Definition of Done Checklist

- [ ] Dependency graph built from all feature metadata
- [ ] Circular dependencies detected and reported
- [ ] Mermaid syntax generated correctly
- [ ] Diagram embedded in traceability map
- [ ] Graph structure validated (no self-deps, valid refs)
- [ ] `tasks.md` updated

## Review Guidance

- Verify graph shows all blocking relationships correctly
- Test Mermaid diagram renders in GitHub/GitLab
- Check circular dependency detection works
- Validate all feature references exist

## Activity Log

- 2025-12-16T22:24:05Z – system – lane=planned – Prompt created.
- 2025-12-17T01:09:26Z – claude – shell_pid=319772 – lane=doing – Started implementation
