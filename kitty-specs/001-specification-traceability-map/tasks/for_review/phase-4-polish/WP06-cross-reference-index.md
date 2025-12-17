---
work_package_id: "WP06"
subtasks:
  - "T028"
  - "T029"
  - "T030"
  - "T031"
  - "T032"
title: "Cross-Reference Index"
phase: "Phase 4 - Polish"
lane: "doing"
assignee: "claude"
agent: "claude"
shell_pid: "22461"
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2025-12-16T22:24:05Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
  - timestamp: "2025-12-17T18:30:00Z"
    lane: "doing"
    agent: "claude"
    shell_pid: "22461"
    action: "Started implementation"
---

# Work Package Prompt: WP06 – Cross-Reference Index

## Objectives & Success Criteria

- Cross-reference table exists in traceability map
- All spec sections appear in table with correct feature links
- Reverse lookup (feature -> sections) works correctly
- Multiple features per section handled properly

## Context & Constraints

- **Table format**: Markdown table `| Spec Section | Feature Tickets |`
- **Location**: Embedded in traceability map after dependency graph
- **Reference**: See `spec.md` User Story 4, clarification: markdown table embedded

## Subtasks & Detailed Guidance

### Subtask T028 – Generate cross-reference table data structure
- **Purpose**: Build section -> features mapping optimized for table display.
- **Steps**: Create data structure mapping each section to list of covering features.
- **Files**: Data structure in script/module.
- **Parallel?**: No (foundational).

### Subtask T029 – Generate markdown table format
- **Purpose**: Convert data structure to markdown table syntax.
- **Steps**: Generate table header, iterate sections, create rows with section ID and comma-separated feature links.
- **Files**: Markdown generation.
- **Parallel?**: Yes (after T028).

### Subtask T030 – Implement reverse lookup
- **Purpose**: Support feature -> sections lookup.
- **Steps**: Build reverse index: feature slug -> list of sections it covers.
- **Files**: Same as T028.
- **Parallel?**: Yes.

### Subtask T031 – Embed cross-reference table in traceability map
- **Purpose**: Add table to markdown document.
- **Steps**: Insert table after dependency graph section, ensure valid markdown.
- **Files**: Markdown generation.
- **Parallel?**: Yes (after T029).

### Subtask T032 – Handle multiple features per section
- **Purpose**: Show all features covering a section in same table row.
- **Steps**: Join multiple feature links with commas, format as markdown links.
- **Files**: Same as T029.
- **Parallel?**: Yes.

## Test Strategy

- Verify table renders correctly in markdown viewer
- Test reverse lookup returns correct sections
- Verify multiple features appear correctly

## Risks & Mitigations

- **Table formatting**: Ensure valid markdown syntax
- **Large tables**: Consider pagination if needed

## Definition of Done Checklist

- [ ] Cross-reference table generated
- [ ] All sections appear in table
- [ ] Reverse lookup works
- [ ] Table embedded in traceability map
- [ ] Multiple features handled correctly
- [ ] `tasks.md` updated

## Review Guidance

- Verify table renders correctly
- Test all links work
- Check reverse lookup accuracy

## Activity Log

- 2025-12-16T22:24:05Z – system – lane=planned – Prompt created.
- 2025-12-17T18:30:00Z – claude – shell_pid=22461 – lane=doing – Started implementation
- 2025-12-17T19:00:00Z – claude – shell_pid=22461 – lane=doing – Completed implementation: All subtasks (T028-T032) implemented. Cross-reference table data structure, markdown table generation, reverse lookup, and embedding complete.
