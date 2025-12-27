---
work_package_id: WP02
title: Transformer Declarator Implementation
lane: doing
history:
- timestamp: '2025-01-27T23:45:00Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
- timestamp: '2025-01-28T00:05:00Z'
  lane: doing
  agent: claude
  shell_pid: '85610'
  action: Started implementation
agent: claude
assignee: claude
phase: Phase 1 - Foundational
review_status: ''
reviewed_by: ''
shell_pid: '85610'
subtasks:
- T004
- T005
- T006
- T007
- T008
---
*Path: [templates/task-prompt-template.md](templates/task-prompt-template.md)*

# Work Package Prompt: WP02 – Transformer Declarator Implementation

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately (right below this notice).
- **You must address all feedback** before your work is complete. Feedback items are your implementation TODO list.
- **Mark as acknowledged**: When you understand the feedback and begin addressing it, update `review_status: acknowledged` in the frontmatter.
- **Report progress**: As you address each feedback item, update the Activity Log explaining what you changed.

---

## Review Feedback

> **Populated by `/spec-kitty.review`** – Reviewers add detailed feedback here when work needs changes. Implementation must address every item listed below before returning for re-review.

*[This section is empty initially. Reviewers will populate it if the work is returned from review. If you see feedback here, treat each item as a must-do before completion.]*

---

## Objectives & Success Criteria

- Implement `transformer` custom declarator using `EXPORTHOW::DECLARE` mechanism
- Create `MetamodelX::TransformerHOW` class that extends `Metamodel::ClassHOW`
- Export declarator via `EXPORTHOW::DECLARE` package
- HOW class processes transformer body to collect templates and wrappers
- Automatically creates callable sub/method with transformer name
- Can declare `transformer MyTransform { }` and call `MyTransform($data)`

## Context & Constraints

- **Prerequisites**: WP01 (module structure)
- **Related Documents**: 
  - `plan.md` - Architecture decision #1 (EXPORTHOW::DECLARE approach)
  - `research.md` - RQ1 (EXPORTHOW::DECLARE implementation pattern)
  - `contracts/transformer-api.md` - Transformer declarator syntax
  - Reference: Red ORM's `model` declarator implementation
- **Architecture**: Use `EXPORTHOW::DECLARE` mechanism, simpler than full slang
- **Constraints**: Must integrate with Raku's grammar and type system, must support traits and roles

## Subtasks & Detailed Guidance

### Subtask T004 – Create TransformerHOW class

- **Purpose**: Create the HOW class that the compiler will use when encountering `transformer` declarator
- **Steps**:
  1. In `lib/Qwiratry/Transformer.rakumod`, create `MetamodelX::TransformerHOW` class
  2. Extend `Metamodel::ClassHOW` (or appropriate base HOW class)
  3. Override methods needed to process transformer body (e.g., `compose` or similar)
  4. Store templates and wrappers in class metadata during compilation
  5. Ensure HOW class can handle traits (`:streaming`, `returns(Type)`) and roles (`does TreeRewrite`)
- **Files**: 
  - `lib/Qwiratry/Transformer.rakumod`
- **Parallel?**: No
- **Notes**: Study Red ORM's Model.rakumod for reference. HOW class needs to process body AST to collect templates and wrappers. **CRITICAL**: Must use RakuAST (not old Perl AST) for AST traversal.

### Subtask T005 – Implement EXPORTHOW::DECLARE export

- **Purpose**: Register the declarator so compiler recognizes `transformer` keyword
- **Steps**:
  1. In `lib/Qwiratry/Transformer.rakumod`, create export block:
     ```raku
     my package EXPORTHOW {
         package DECLARE {
             constant transformer = MetamodelX::TransformerHOW;
         }
     }
     ```
  2. Ensure constant name matches declarator keyword exactly
  3. Export at module level so it's available when module is used
- **Files**: 
  - `lib/Qwiratry/Transformer.rakumod`
- **Parallel?**: No (depends on T004)
- **Notes**: This is the standard pattern for custom declarators in Raku. The compiler will use this HOW when it encounters `transformer` keyword.

### Subtask T006 – Process transformer body

- **Purpose**: HOW class must traverse transformer body AST to collect templates and wrappers
- **Steps**:
  1. In HOW class, override method that processes class body (likely during `compose` or similar)
  2. **CRITICAL**: Use RakuAST (not old Perl AST) for AST traversal
  3. Traverse body RakuAST to find `template` declarations (will be implemented in WP03)
  4. Traverse body RakuAST to find `wrapper` declarations (will be implemented in WP08)
  5. Store collected templates in class attribute `@.templates` (initialize as empty array)
  6. Store collected wrappers in class attribute `@.wrappers` (initialize as empty array)
  7. For now, just set up the structure - actual parsing will be in WP03
- **Files**: 
  - `lib/Qwiratry/Transformer.rakumod`
- **Parallel?**: No (depends on T004, T005)
- **Notes**: Body RakuAST traversal is complex. Start with minimal implementation, extend in WP03. **Must use RakuAST introspection methods** (RakuAST::Node), not Perl6 AST methods.

### Subtask T007 – Create callable method

- **Purpose**: Automatically create sub/method with transformer name that invokes `TRANSFORM`
- **Steps**:
  1. In HOW class, after class is composed, create a sub/method with transformer's name
  2. Method should accept data parameter and optional named parameters
  3. Method should call `TRANSFORM` method on transformer instance
  4. For now, `TRANSFORM` can be a stub (will be implemented in WP06)
  5. Ensure method is callable: `MyTransform($data)` should work
- **Files**: 
  - `lib/Qwiratry/Transformer.rakumod`
- **Parallel?**: No (depends on T006)
- **Notes**: This enables the convenient syntax where transformers are called as functions. The method should create transformer instance and call TRANSFORM.

### Subtask T008 – Unit tests for declarator

- **Purpose**: Verify transformer declarator works correctly
- **Steps**:
  1. In `tests/unit/transformer.rakutest`, add test for basic transformer declaration
  2. Test that `transformer MyTransform { }` creates a class
  3. Test that transformer can be called: `MyTransform($data)` (may fail until TRANSFORM is implemented)
  4. Test that traits can be applied: `transformer MyX :streaming { }`
  5. Test that roles can be applied: `transformer MyX does TreeRewrite { }`
  6. Test that transformer body is processed (templates collected - may be minimal until WP03)
- **Files**:
  - `tests/unit/transformer.rakutest`
- **Parallel?**: Yes (can be written in parallel with implementation)
- **Notes**: Start with basic tests, extend as functionality is added. Some tests may need to be updated in later packages.

## Test Strategy

- **Unit tests**: Test declarator syntax, class creation, callable behavior
- **Test location**: `tests/unit/transformer.rakutest`
- **Commands**: Run tests with `raku -Ilib -e 'use Test; use lib "tests"; require "tests/unit/transformer.rakutest"'` or use test runner

## Risks & Mitigations

- **HOW class complexity**: Start with minimal implementation, extend incrementally. Study Red ORM for patterns.
- **AST traversal complexity**: **CRITICAL** - Must use RakuAST (not old Perl AST) for AST introspection. Use RakuAST::Node methods. Start simple, add complexity in WP03.
- **Trait/role handling**: Ensure HOW class properly processes traits and roles during composition.

## Definition of Done Checklist

- [ ] `MetamodelX::TransformerHOW` class created and extends appropriate base
- [ ] `EXPORTHOW::DECLARE` export implemented correctly
- [ ] HOW class processes transformer body (structure in place)
- [ ] Callable method created with transformer name
- [ ] Unit tests pass for basic declarator functionality
- [ ] Can declare and call a basic transformer
- [ ] Traits and roles can be applied
- [ ] `tasks.md` updated with status change

## Review Guidance

- Verify declarator follows Red ORM pattern
- Check HOW class properly extends base HOW
- Ensure EXPORTHOW::DECLARE export is correct
- Validate callable method creation
- Review test coverage for declarator functionality

## Activity Log

- 2025-01-27T23:45:00Z – system – lane=planned – Prompt created.
- 2025-01-28T00:05:00Z – claude – shell_pid=85610 – lane=doing – Started implementation
- 2025-01-28T00:30:00Z – claude – shell_pid=85610 – lane=doing – Implemented EXPORTHOW::DECLARE export mechanism. Created Transformer base class with CALL-ME method. HOW class extension needs further investigation - encountering "Missing serialize REPR function" error when extending Metamodel::ClassHOW. Basic structure in place, but HOW class compose override needs debugging.
- 2025-01-28T01:00:00Z – claude – shell_pid=85610 – lane=doing – Continued investigation of HOW class. Tried multiple approaches: inheritance (is Metamodel::ClassHOW), composition/delegation, direct Metamodel::ClassHOW usage. All approaches result in "Missing serialize REPR function for REPR MVMContext (BOOTContext)" error. This appears to be a MoarVM-level issue. Current working approach: using Metamodel::ClassHOW directly as constant in EXPORTHOW::DECLARE, with Transformer base class providing structure. Custom HOW class compose override will need alternative implementation strategy or Rakudo/MoarVM fix.

