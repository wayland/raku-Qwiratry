# Feature Shells from Specification.md

This document maps sections from `Specification.md` to feature shells that will be processed by `spec-kitty.specify` to generate detailed feature specifications and ticket breakdowns.

## Priority Order

1. **structure-spec** - Mapping document (this file)
2. **walker-core** - Core Walker infrastructure (highest priority)
3. **strategy-control** - Strategy hooks and ControlSignal
4. **composite-handover** - Multi-domain walker handovers
5. **slang-and-query** - Query AST and Slang support
6. **transformer-templates** - Transformer/Template system
7. **examples-and-demos** - Sample implementations

## Feature Shells

### structure-spec
**Spec References**: All sections (mapping document)  
**Purpose**: Create a traceability map between spec sections and feature tickets

### walker-core
**Spec References**: 
- Section 2.1.2 (Walker Group overview)
- Section 3.2 (Walker Group)
- Section 3.2.1 (Walker role)
- Section 3.2.2 (Walker::Plan role)
- Section 3.2.3 (Context role)
- Section 3.2.4 (QueryIterator role)
- Section 4 (Query Execution Flow)

**Purpose**: Implement core Walker infrastructure including Walker role, Walker::Plan, Context, and QueryIterator roles with their required methods and capabilities.

### strategy-control
**Spec References**:
- Section 2.1.3 (Strategy Group)
- Section 3.2.5 (Strategy role)
- Section 3.2.6 (ControlSignal enum)

**Purpose**: Implement Strategy role with hooks (before, on-match, should-follow, after, finish) and ControlSignal enumeration for traversal control.

### composite-handover
**Spec References**:
- Section 3.2.1.6 (Detecting Walker Handovers)
- Section 3.2.1.6.1 (Domain Metadata on Roots - `provides<...>` trait)
- Section 3.2.1.6.2-6 (Handover detection priority and execution)

**Purpose**: Implement master/composite walker system supporting handovers between domain-specific walkers using `provides<...>` trait and capability checks.

### slang-and-query
**Spec References**:
- Section 3.1 (Query Group)
- Section 6 (Slang for Query Expressions)
- Section 2.1.1 (Query Group overview)

**Purpose**: Define Query AST structure and Slang support for parsing query expressions into Query AST objects that walkers can consume.

### transformer-templates
**Spec References**:
- Section 2.1.4 (Transformer Group)
- Section 3.3 (Transformer Group)
- Section 3.3.1 (Purpose)
- Section 3.3.2 (Transformer Declarator)
- Section 3.3.3 (Templates)
- Section 3.3.4 (Wrappers)
- Section 3.3.5 (Magic Variables)

**Purpose**: Implement Transformer declarator, Template system with ordering/traits, Wrappers, and magic variables ($*CONTEXT, $*CAPTURE, etc.).

### examples-and-demos
**Spec References**:
- Section 7 (Examples)
- Section 7.1 (Tree Walker DFS)
- Section 7.2 (Table Walker)
- Section 7.3 (Logic Walker)

**Purpose**: Create sample walker implementations (Tree::Walker::DFS, Table::Walker::Scan, Logic::Walker::Backward) and demo scripts demonstrating the architecture.

