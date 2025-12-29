# Feature Specification: Transformer Templates System

*Path: [templates/spec-template.md](templates/spec-template.md)*

**Feature Branch**: `005-transformer-templates-system`  
**Created**: 2025-01-27  
**Last Revised**: 2025-01-27  
**Status**: Draft  
**Input**: User description: "Please work on the transformer-templates feature shell"  
**Revision**: Updated to reflect Specification.md section 3.3.6 (Copy service class)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Declare and Execute Basic Transformer (Priority: P1)

As a developer, I need to declare a transformer with templates using the `transformer` declarator, so I can transform data structures declaratively without writing manual traversal code.

**Why this priority**: This is the foundation of the transformer system. Without the ability to declare and execute basic transformers, none of the other functionality can be used. This enables the core value proposition of declarative data transformation.

**Independent Test**: Can be fully tested by declaring a simple transformer with one template, calling it on a data structure, and verifying it produces transformed output. Delivers immediate value by enabling declarative transformations.

**Acceptance Scenarios**:

1. **Given** a transformer declared with `transformer MyTransform { template TOP do { ... } }`, **When** I call `MyTransform($data)`, **Then** the transformer executes and produces output
2. **Given** a transformer with a template that matches nodes, **When** I apply it to matching data, **Then** the template's `do` block executes and produces transformed output
3. **Given** a transformer with multiple templates, **When** I apply it to data, **Then** templates are evaluated in the correct order (priority → specificity → tie-breaker)

---

### User Story 2 - Template Matching with When Clauses (Priority: P1)

As a developer, I need to define templates with `when` clauses that match nodes based on queries, so I can selectively apply transformations to specific parts of the data structure.

**Why this priority**: Template matching is essential for selective transformation. Without this, all templates would apply to all nodes, making the system unusable. This enables the XSLT-like pattern matching behavior.

**Independent Test**: Can be fully tested by creating a transformer with templates that have different `when` clauses, applying it to data, and verifying only matching templates execute. Delivers value by enabling selective transformations.

**Acceptance Scenarios**:

1. **Given** a template with a `when` clause that matches specific nodes, **When** the transformer processes data, **Then** the template only executes for matching nodes
2. **Given** a template with a `when` clause that doesn't match any nodes, **When** the transformer processes data, **Then** the template doesn't execute and no output is produced for those nodes
3. **Given** multiple templates with different `when` clauses, **When** the transformer processes data, **Then** each template executes only for nodes matching its `when` clause

---

### User Story 3 - Template Ordering and Priority Resolution (Priority: P1)

As a developer, I need templates to be ordered deterministically (priority → specificity → tie-breaker), so I can control which template applies when multiple templates could match the same node.

**Why this priority**: Deterministic template ordering is critical for predictable behavior. Without this, the same transformer could produce different results, making the system unreliable. This ensures XSLT-like deterministic transformation behavior.

**Independent Test**: Can be fully tested by creating multiple templates that could match the same node with different priorities, applying the transformer, and verifying the highest priority template executes. Delivers value by ensuring predictable transformation behavior.

**Acceptance Scenarios**:

1. **Given** multiple templates with different `:priority` values that could match the same node, **When** the transformer processes the node, **Then** the template with the highest priority executes
2. **Given** templates with equal priority but different specificity scores, **When** the transformer processes a matching node, **Then** the template with higher specificity executes
3. **Given** templates with equal priority and specificity that could match the same node, **When** the transformer processes the node, **Then** an error is reported asking the user to set a `:tie-breaker` value
4. **Given** templates with equal priority, specificity, and tie-breaker values, **When** the transformer processes a matching node, **Then** the first template in the ordered list executes

---

### User Story 4 - Magic Variables in Template Actions (Priority: P1)

As a developer writing template actions, I need access to magic variables (`$*CONTEXT`, `$*CAPTURE`, `self`) that are automatically set during transformation, so I can reference the current node and template parameters in my transformation logic.

**Why this priority**: Magic variables are essential for writing useful template actions. Without them, templates cannot access the current node or template parameters, making transformations impossible. This enables the core template functionality.

**Independent Test**: Can be fully tested by writing a template action that uses `$*CONTEXT` to access the current node, applying the transformer, and verifying the variable contains the correct node. Delivers value by enabling template actions to access transformation context.

**Acceptance Scenarios**:

1. **Given** a template action that uses `$*CONTEXT`, **When** the template executes, **Then** `$*CONTEXT` contains the current node being processed
2. **Given** a template with parameters that uses `$*CAPTURE`, **When** the template executes, **Then** `$*CAPTURE` contains the captured parameters from the template signature
3. **Given** a template action that uses `self`, **When** the template executes, **Then** `self` refers to the Transformer object
4. **Given** multiple templates execute in sequence, **When** each template accesses `$*CONTEXT`, **Then** each template sees the correct node for its execution

---

### User Story 5 - Streaming Transformations (Priority: P2)

As a developer processing large datasets, I need transformers to support streaming output using the `:streaming` trait, so I can transform data incrementally without loading everything into memory.

**Why this priority**: Streaming enables handling large datasets efficiently. While not required for basic functionality, it's essential for production use cases with large data structures. This enables memory-efficient transformations.

**Independent Test**: Can be fully tested by declaring a transformer with `:streaming` trait, applying it to a large dataset, and verifying output is produced incrementally (lazily) rather than all at once. Delivers value by enabling memory-efficient transformations.

**Acceptance Scenarios**:

1. **Given** a transformer declared with `:streaming` trait, **When** I apply it to a large dataset, **Then** results are produced lazily as an iterator
2. **Given** a transformer with `:streaming` at the template level, **When** that template executes, **Then** only that template produces streaming output
3. **Given** a streaming transformer, **When** I consume results incrementally, **Then** memory usage remains constant regardless of input size

---

### User Story 6 - Tree Rewriting with TreeRewrite Role (Priority: P2)

As a developer transforming tree structures, I need transformers to support in-place rewriting using the `does TreeRewrite` role, so I can modify trees during traversal without creating new structures.

**Why this priority**: Tree rewriting enables efficient in-place transformations. While not required for all use cases, it's essential for scenarios where creating new structures is expensive or undesirable. This enables efficient tree manipulation.

**Independent Test**: Can be fully tested by declaring a transformer with `does TreeRewrite`, applying it to a tree, and verifying nodes are modified in-place when `make` is called. Delivers value by enabling efficient tree transformations.

**Acceptance Scenarios**:

1. **Given** a transformer with `does TreeRewrite` role, **When** a template calls `make` with a new node, **Then** the current node is immediately replaced in the tree
2. **Given** a transformer with `does TreeRewrite`, **When** templates execute, **Then** traversal continues with the rewritten structure
3. **Given** a transformer without `does TreeRewrite`, **When** templates execute, **Then** the original tree structure remains unchanged

---

### User Story 7 - Copy and Deep Copy Operations (Priority: P2)

As a developer writing transformations, I need `copy()` and `deepcopy()` functions available via the `Qwiratry::Copy` service class for transformable nodes (nodes with Walkers that have supports-rewrite capability), so I can create shallow or deep copies of nodes during transformation without mutating the original data.

**Why this priority**: Copy operations are essential for non-destructive transformations. While not required for all use cases, they're needed when transformers should not modify input data. This enables safe transformation operations.

**Independent Test**: Can be fully tested by calling `Qwiratry::Copy::copy()` and `Qwiratry::Copy::deepcopy()` on a transformable node, modifying the copies, and verifying the original node remains unchanged. Delivers value by enabling non-destructive transformations.

**Acceptance Scenarios**:

1. **Given** a transformable node (with a Walker that has supports-rewrite capability), **When** I call `Qwiratry::Copy::copy()`, **Then** I receive a shallow copy where children are shared with the original
2. **Given** a transformable node, **When** I call `Qwiratry::Copy::deepcopy()`, **Then** I receive a deep copy where all descendants are recursively cloned
3. **Given** a node with a custom `copy()` method, **When** I call `Qwiratry::Copy::copy()`, **Then** the custom method is used (checked first before default implementation)
4. **Given** a deep copy of a DAG structure, **When** I examine the copy, **Then** shared children are correctly cloned once and referenced by multiple parents
5. **Given** the Copy service class, **When** I use it with Positional or Associative types, **Then** appropriate default implementations are used

---

### User Story 8 - Wrapper System for Custom Processing (Priority: P3)

As a developer extending transformer behavior, I need to define wrappers (TRANSFORMER, TEMPLATE_MATCHER, TEMPLATE_ACTION) that wrap transformer output, template matching, and template actions, so I can add custom pre- or post-processing logic.

**Why this priority**: Wrappers enable extensibility and customization. While not required for basic functionality, they're valuable for advanced use cases like logging, debugging, or adding cross-cutting concerns. This enables transformer extensibility.

**Independent Test**: Can be fully tested by defining a TRANSFORMER wrapper, applying a transformer, and verifying the wrapper's code executes around the transformation. Delivers value by enabling transformer customization.

**Acceptance Scenarios**:

1. **Given** a transformer with a TRANSFORMER wrapper defined, **When** the transformer executes, **Then** the wrapper's code executes around the entire transformation output
2. **Given** a transformer with a TEMPLATE_MATCHER wrapper, **When** templates are matched, **Then** the wrapper's code executes around each match evaluation
3. **Given** a transformer with a TEMPLATE_ACTION wrapper, **When** template actions execute, **Then** the wrapper's code executes around each action execution

---

### User Story 9 - Integration with Walker and Strategy Systems (Priority: P1)

As a developer using the Qwiratry architecture, I need transformers to integrate with existing Walker and Strategy systems, so I can leverage existing traversal and processing logic in my transformations.

**Why this priority**: Integration with existing systems is essential for the transformer to work within the Qwiratry architecture. Without this, transformers would be isolated and unable to leverage the query and traversal infrastructure. This enables architectural consistency.

**Independent Test**: Can be fully tested by creating a transformer that uses a Walker to traverse data, applying it, and verifying the transformer correctly uses the Walker's traversal logic. Delivers value by enabling reuse of existing infrastructure.

**Acceptance Scenarios**:

1. **Given** a transformer and a Walker, **When** the transformer processes data, **Then** it uses the Walker to traverse the data structure
2. **Given** a transformer processing data via a Walker, **When** templates match nodes, **Then** the matching uses queries compatible with the Walker's query system
3. **Given** a transformer and Strategy hooks, **When** the transformer processes data, **Then** Strategy hooks can interact with the transformation process appropriately

---

### User Story 10 - Multi-Phase Transformation Support (Priority: P2)

As a developer implementing complex transformations, I need transformers to support pre-transformation, inline transformation, and post-transformation phases, so I can apply transformations at different points in the query execution pipeline.

**Why this priority**: Multi-phase support enables flexible transformation integration. While not required for basic use cases, it's essential for advanced scenarios where transformations need to occur at specific pipeline stages. This enables flexible transformation architecture.

**Independent Test**: Can be fully tested by calling a transformer with different `:mode` values (`pre`, `inline`, `post`), and verifying the transformer behaves appropriately for each mode. Delivers value by enabling flexible transformation timing.

**Acceptance Scenarios**:

1. **Given** a transformer called with `:mode<pre>`, **When** it executes, **Then** it operates on the whole data structure before traversal
2. **Given** a transformer called with `:mode<inline>`, **When** it executes, **Then** it operates on each element during traversal
3. **Given** a transformer called with `:mode<post>`, **When** it executes, **Then** it consumes a QueryIterator and produces transformed output
4. **Given** a transformer called with `:mode<default>`, **When** it executes, **Then** it automatically determines the appropriate mode based on input type

---

### Edge Cases

- What happens when no templates match a node? (No output is produced for that node, transformation continues)
- How does the system handle templates with invalid `when` clauses? (Should throw an appropriate exception during template ordering or execution)
- What happens when template specificity calculation fails? (Should report an error and ask user to set explicit priority or tie-breaker)
- How does the system handle circular references in deepcopy? (Should detect cycles and reuse existing clones to prevent infinite recursion)
- What happens when a streaming transformer's iterator is exhausted? (Returns Nil consistently, no errors)
- How does the system handle transformers applied to non-transformable data types (nodes without Walkers that have supports-rewrite capability)? (Should either throw an error or provide a default transformation behavior)
- What happens when `make` is called multiple times in a single template action? (Should use the last value or accumulate values, depending on transformer behavior)
- How does the system handle template actions that throw exceptions? (Should propagate the exception and stop transformation, or handle gracefully depending on configuration)
- What happens when `$*CONTEXT` or `$*CAPTURE` are accessed outside of template execution? (Should be Nil or throw an error indicating they're only available during transformation)
- How does the system handle transformers with no templates? (Should either produce no output or apply a default template, depending on design)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a `transformer` custom declarator that creates a Transformer class with the specified name
- **FR-002**: System MUST support `template` declarator with optional `when` (matcher) and `do` (action) blocks
- **FR-003**: System MUST implement template ordering algorithm that sorts templates by: priority (highest first), then specificity (highest first), then tie-breaker (highest first)
- **FR-004**: System MUST calculate template specificity based on `when` clause: multilevel axis (-100), wildcards (-10), explicit path elements (+5), attribute axes (+5)
- **FR-005**: System MUST report an error when two templates have equal priority, specificity, and tie-breaker and could match the same node, asking user to set a tie-breaker
- **FR-006**: System MUST provide `$*CONTEXT` magic variable set to the current node during template execution
- **FR-007**: System MUST provide `$*CAPTURE` magic variable set to template signature parameters during template execution
- **FR-008**: System MUST provide `self` variable referring to the Transformer object in template actions
- **FR-009**: System MUST support `:streaming` trait at transformer and template levels to enable lazy iterator-based output
- **FR-010**: System MUST support `returns(Type)` trait to enforce output type checking for transformers and templates
- **FR-011**: System MUST support `does TreeRewrite` role to enable in-place tree rewriting behavior
- **FR-012**: System MUST implement `TRANSFORM` method that orders templates, walks input data, and applies templates using `APPLY` method
- **FR-013**: System MUST implement `ORDER-TEMPLATES` method that populates `@.ordered-templates` array with correctly sorted templates
- **FR-014**: System MUST implement `APPLY` method that selects and invokes the first matching template for a given node
- **FR-015**: System MUST provide `Qwiratry::Copy` service class with `copy()` multi sub that performs shallow copy (O(1) operation, children shared) for transformable nodes (nodes with Walkers that have supports-rewrite capability)
- **FR-016**: System MUST provide `Qwiratry::Copy` service class with `deepcopy()` multi sub that performs recursive deep copy with cycle detection and DAG structure preservation for transformable nodes
- **FR-031**: System MUST attach `copy()` and `deepcopy()` methods to Transformer object (methods delegate to `Qwiratry::Copy` service functions)
- **FR-032**: System MUST provide default `copy()` implementations for `Positional` (via `clone`) and `Associative` (via `clone`) types in `Qwiratry::Copy` service class
- **FR-033**: System MUST provide default `deepcopy()` implementations for `Positional` (recursive map) and `Associative` (recursive map) types in `Qwiratry::Copy` service class
- **FR-034**: System MUST check if node has custom `.copy()` method before using default implementation in `Qwiratry::Copy::copy()`
- **FR-017**: System MUST support wrapper declarator for TRANSFORMER, TEMPLATE_MATCHER, and TEMPLATE_ACTION wrappers
- **FR-018**: System MUST call wrappers as submethods (e.g., `WRAP_TRANSFORMER`) up the Transformer hierarchy similar to `TWEAK`
- **FR-019**: System MUST integrate with existing Walker system for data traversal
- **FR-020**: System MUST integrate with existing Strategy system for element-level processing hooks
- **FR-021**: System MUST support `transform` method with `:mode` parameter accepting values: `default`, `pre`, `inline`, `post`, `rewrite-optional`, `rewrite-mandatory`
- **FR-022**: System MUST support calling transformer as a function (e.g., `TransformerName($data)`) which invokes `TRANSFORM` method
- **FR-023**: System MUST support template actions that use `make` to add results to output stream
- **FR-024**: System MUST support template actions that return values directly as output (when `make` is not used)
- **FR-025**: System MUST support `NextTemplate.throw` in template actions to continue with next matching template instead of using current result
- **FR-026**: System MUST handle cases where no templates match a node (produces no output for that node)
- **FR-027**: System MUST support template signatures with parameters that are captured in `$*CAPTURE`
- **FR-028**: System MUST use depth-first, top-down iterator as default traversal strategy
- **FR-029**: System MUST support direct calls to named templates that bypass walk ordering
- **FR-030**: System MUST support `when` clauses that use query operators, axis operators, and predicates for node selection

### Key Entities *(include if feature involves data)*

- **Transformer**: A declarative object that transforms input data structures. Contains templates, wrappers, and configuration. Provides `TRANSFORM`, `ORDER-TEMPLATES`, `APPLY`, and `transform` methods. Can have traits like `:streaming`, `returns(Type)`, and roles like `does TreeRewrite`.

- **Template**: A match-and-action rule within a Transformer. Consists of optional name/signature, optional traits, `when` clause (matcher), and `do` clause (action). Can have `:priority`, `:tie-breaker`, and `:streaming` traits. Executes when its `when` clause matches a node.

- **Transformable Node**: A node in the data structure being transformed. Transformable nodes are those that have a Walker with the `supports-rewrite` capability. Copy operations are provided via `Qwiratry::Copy` service class. Can be any hierarchical data structure (trees, tables, etc.). Accessed via `$*CONTEXT` during template execution.

- **Wrapper**: Custom pre- or post-processing logic for transformers. Three types: TRANSFORMER (wraps entire output), TEMPLATE_MATCHER (wraps match evaluation), TEMPLATE_ACTION (wraps action execution). Implemented as submethods called up the hierarchy.

- **Template Ordering**: The sorted list of templates used during transformation. Determined by priority (explicit `:priority` trait, default 0), specificity (calculated from `when` clause), and tie-breaker (explicit `:tie-breaker` trait, default 0). Stored in `@.ordered-templates` array.

- **Magic Variables**: Dynamic variables available during template execution. `$*CONTEXT` (current node), `$*CAPTURE` (template parameters), `self` (Transformer object). Set automatically by the transformer system.

- **Copy Service Class**: `Qwiratry::Copy` module providing `copy()` and `deepcopy()` multi subs for transformable nodes. Provides default implementations for `Positional` and `Associative` types, with fallback to identity for `Mu` types. Methods are attached to Transformer object for convenient access.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developers can declare a working transformer with at least one template and execute it on a data structure, producing transformed output, within 5 minutes of reading the documentation
- **SC-002**: Template ordering algorithm correctly resolves conflicts for 100% of test cases with explicit priority, specificity, or tie-breaker values
- **SC-003**: System reports clear, actionable errors for 100% of template ordering conflicts that cannot be automatically resolved
- **SC-004**: Magic variables (`$*CONTEXT`, `$*CAPTURE`, `self`) are correctly set and accessible in 100% of template action executions
- **SC-005**: Streaming transformers can process datasets 10x larger than available memory without running out of memory
- **SC-006**: `Qwiratry::Copy::copy()` function completes in O(1) time with respect to number of descendants for all supported node types (transformable nodes with Walkers that have supports-rewrite capability)
- **SC-007**: `Qwiratry::Copy::deepcopy()` function correctly handles DAG structures with shared children, producing a single clone per unique node regardless of parent count
- **SC-008**: Transformers integrate successfully with existing Walker implementations, correctly using Walker traversal logic in 100% of integration test cases
- **SC-009**: Transformers support all three transformation modes (pre, inline, post) and correctly determine mode from input type in default mode
- **SC-010**: Template matching correctly identifies matching nodes for 100% of test cases with various `when` clause patterns (queries, axis operators, predicates)

## Assumptions

- Existing Walker and Strategy systems are available and functional (from previous features)
- Query AST system is available for use in template `when` clauses
- Transformable nodes are those that have a Walker with the `supports-rewrite` capability
- `Qwiratry::Copy` service class provides `copy()` and `deepcopy()` functions with default implementations for `Positional` and `Associative` types
- Copy/deepcopy methods are attached to Transformer object for convenient access
- Template specificity calculation may need refinement based on actual query operator implementations
- Walker and Strategy systems may need adjustments to fully support transformer integration (bidirectional dependency)
- The `NextTemplate` exception mechanism will be implemented as part of this feature or a follow-up
- Default iterator (depth-first, top-down) will be provided by the Walker system or implemented as part of this feature
- Template `when` clauses will use query operators that are compatible with the query system (may need coordination with query implementation)

