---
work_package_id: WP03
title: Template Declarator & Collection
lane: doing
history:
- timestamp: '2025-01-27T23:45:00Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
- timestamp: '2025-12-20T12:00:00Z'
  lane: doing
  agent: claude
  shell_pid: '93412'
  action: Started implementation
agent: claude
assignee: claude
phase: Phase 1 - Foundational
review_status: ''
reviewed_by: ''
shell_pid: '93412'
subtasks:
- T009
- T010
- T011
- T012
- T013
---
*Path: [templates/task-prompt-template.md](templates/task-prompt-template.md)*

# Work Package Prompt: WP03 – Template Declarator & Collection

## Objectives & Success Criteria

- Parse `template` declarations within transformer body
- Extract template components (name, signature, traits, when/do blocks)
- Create `Template` class to store template metadata
- Store templates in transformer's `@.templates` array
- Named templates become callable methods on transformer

## Context & Constraints

- **Prerequisites**: WP02 (transformer declarator)
- **Related Documents**: 
  - `plan.md` - Architecture decision #2 (template parsing approach)
  - `research.md` - RQ2 (template declarator parsing)
  - `data-model.md` - Template entity definition
  - `contracts/transformer-api.md` - Template declarator syntax
- **Architecture**: Manual AST traversal to find template declarations using RakuAST (not old Perl AST)
- **Constraints**: Templates are scoped to transformers, not standalone. Must use RakuAST for AST traversal.

## Subtasks & Detailed Guidance

### Subtask T009 – Parse template declarations

- **Purpose**: Identify `template` declarations in transformer body AST
- **Steps**:
  1. In HOW class body processing, traverse AST to find nodes representing `template` declarations
  2. **CRITICAL**: Use RakuAST (not old Perl AST) for AST traversal and introspection
  3. Use pattern matching on RakuAST node types to identify templates
  4. For each template declaration found, extract the declaration node
  5. Pass template nodes to extraction step (T010)
- **Files**: `lib/Qwiratry/Transformer.rakumod`
- **Parallel?**: No
- **Notes**: **Must use RakuAST** for AST introspection. Template declarations will appear as specific RakuAST node types in the body. Use RakuAST::Node and RakuAST introspection methods, not Perl6 AST.

### Subtask T010 – Extract template components

- **Purpose**: Extract all components from template declaration
- **Steps**:
  1. From template RakuAST node, extract optional name (if template is named)
  2. Extract optional signature (if template has parameters)
  3. Extract traits (`:priority`, `:tie-breaker`, `:streaming`, `returns(Type)`)
  4. Extract `when` block (matcher code block)
  5. Extract `do` block (action code block)
  6. Store extracted components for Template object creation
- **Files**: `lib/Qwiratry/Transformer.rakumod`
- **Parallel?**: No (depends on T009)
- **Notes**: **Must use RakuAST node methods** to access components. Use RakuAST::Node introspection methods, not Perl6 AST methods. Signature parsing leverages Raku's built-in Signature parsing.

### Subtask T011 – Create Template class

- **Purpose**: Define Template class to store template metadata
- **Steps**:
  1. In `lib/Qwiratry/Template.rakumod`, create `Template` class
  2. Add attributes: `$.name` (Str?), `$.signature` (Signature?), `$.when-block` (Block), `$.do-block` (Block)
  3. Add attributes: `$.priority` (Int, default 0), `$.specificity` (Int?), `$.tie-breaker` (Int, default 0)
  4. Add attributes: `$.streaming` (Bool, default False), `$.returns-type` (Type?)
  5. Add methods: `matches($node --> Bool)`, `execute($node, :$context --> Iterator|Mu|List|Nil)` (stubs for now)
  6. Export Template class
- **Files**: `lib/Qwiratry/Template.rakumod`
- **Parallel?**: No
- **Notes**: Template class stores all metadata needed for ordering and execution. Methods will be implemented in WP05.

### Subtask T012 – Store templates

- **Purpose**: Store collected templates in transformer's `@.templates` array
- **Steps**:
  1. In HOW class, create Template objects from extracted components
  2. Add Template objects to transformer class's `@.templates` attribute
  3. If template has name, create callable method on transformer class with that name
  4. Ensure templates are accessible at runtime via transformer instance
- **Files**: `lib/Qwiratry/Transformer.rakumod`
- **Parallel?**: No (depends on T010, T011)
- **Notes**: Templates should be stored as class-level attribute, accessible via `$transformer.templates` at runtime.

### Subtask T013 – Unit tests for templates

- **Purpose**: Verify template declarator and collection work correctly
- **Steps**:
  1. Test basic template declaration: `template TOP do { ... }`
  2. Test named template: `template section() do { ... }`
  3. Test template with when clause: `template node() when { ... } do { ... }`
  4. Test template with signature: `template node($name) when { ... } do { ... }`
  5. Test template with traits: `template node() :priority(10) do { ... }`
  6. Test template collection: verify templates are stored in `@.templates`
  7. Test named template method: verify named templates become callable methods
- **Files**: `tests/unit/template.rakutest`
- **Parallel?**: Yes
- **Notes**: Test template parsing, component extraction, and storage. Some tests may need updates when methods are implemented.

## Test Strategy

- **Unit tests**: Test template declaration syntax, component extraction, storage
- **Test location**: `tests/unit/template.rakutest`

## Risks & Mitigations

- **AST parsing complexity**: Use pattern matching on RakuAST node types (not Perl AST), start with simple cases. Study RakuAST::Node documentation for available methods.
- **RakuAST vs Perl AST**: **CRITICAL** - Must use RakuAST, not old Perl6 AST. RakuAST is the standard for Raku 6.e.
- **Signature parsing**: Leverage Raku's built-in Signature parsing capabilities
- **Template storage**: Ensure templates are accessible at runtime

## Definition of Done Checklist

- [ ] Template declarations can be parsed from transformer body
- [ ] Template components extracted correctly
- [ ] Template class created with all required attributes
- [ ] Templates stored in transformer's `@.templates` array
- [ ] Named templates become callable methods
- [ ] Unit tests pass
- [ ] `tasks.md` updated with status change

## Activity Log

- 2025-01-27T23:45:00Z – system – lane=planned – Prompt created.
- 2025-12-20T12:00:00Z – claude – shell_pid=93412 – lane=doing – Started implementation
- 2025-12-20T12:30:00Z – claude – shell_pid=93412 – lane=doing – Completed T011: Created Template class with all required attributes (name, signature, when-block, do-block, priority, specificity, tie-breaker, streaming, returns-type). Template class compiles successfully. Added stub methods matches() and execute() for WP05.
- 2025-12-20T12:45:00Z – claude – shell_pid=93412 – lane=doing – Progress on T009-T012: Added template collection infrastructure to Transformer class. Created !collect-templates-from-body() and !process-templates() methods as placeholders for HOW class integration. Added add-template() helper method for testing. Note: Full AST parsing requires custom HOW class (blocked by serialization issue from WP02). Structure is in place for when HOW class is implemented. Created basic unit tests for Template class (T013).

