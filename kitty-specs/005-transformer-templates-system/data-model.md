# Data Model: Transformer Templates System

**Feature**: Transformer Templates System  
**Date**: 2025-01-27  
**Phase**: 1 - Design & Contracts

## Entities

### Transformer Class

**Purpose**: Declarative object that transforms input data structures using templates. Created via `transformer` custom declarator.

**Attributes**:
- `@.templates` (Array[Template]) - All templates defined in transformer body
- `@.ordered-templates` (Array[Template]) - Templates sorted by priority → specificity → tie-breaker
- `@.wrappers` (Array[Wrapper]) - Wrapper definitions (TRANSFORMER, TEMPLATE_MATCHER, TEMPLATE_ACTION)
- `$.streaming` (Bool) - Whether transformer has `:streaming` trait
- `$.mutates-input` (Bool) - Whether transformer can mutate input (from `does TreeRewrite`)
- `$.mode` (Str) - Transformation mode: 'output-only'|'rewrite-optional'|'rewrite-mandatory'
- `$.walker` (Walker?) - Walker instance for traversal (obtained from factory or explicit)

**Methods**:
- `TRANSFORM($data, Iterator :$iterator --> Iterator|Mu|List|Nil)` - Main transformation method, called when transformer is invoked
- `ORDER-TEMPLATES(--> Array[Template])` - Orders templates by priority → specificity → tie-breaker, populates `@.ordered-templates`
- `APPLY($node --> Iterator|Mu|List|Nil)` - Applies templates to a single node, returns first matching template result
- `transform($input, :$context = $*CONTEXT, :$streaming = Nil, :$mode = 'default' --> Iterator|Mu|List|Nil)` - Transformation entrypoint, determines mode and delegates
- `prepare($data, :$ctx)` - Pre-transformation: modifies structure before traversal
- `apply($element, :$ctx, :$mode)` - Inline transformation: transforms element during traversal
- `WRAP_TRANSFORMER(...)` - Submethod wrapper for entire transformer output
- `WRAP_TEMPLATE_MATCHER(...)` - Submethod wrapper for template match evaluation
- `WRAP_TEMPLATE_ACTION(...)` - Submethod wrapper for template action execution

**Lifecycle**:
- Created at compile-time via `transformer` declarator
- Templates and wrappers collected during compilation
- Template ordering performed on first `TRANSFORM` call (cached)
- Walker obtained from factory or provided explicitly
- Reusable across multiple transformations

**Relationships**:
- Contains `Array[Template]` (templates defined in body)
- Contains `Array[Wrapper]` (wrappers defined in body)
- Uses `Walker` (for data traversal)
- Uses `Context` (for per-traversal state)
- Produces transformed output (Iterator, List, or single value)

**Constraints**:
- Must implement all required methods (TRANSFORM, ORDER-TEMPLATES, APPLY, transform)
- Template ordering must be deterministic
- Must report conflicts when templates have equal priority/specificity/tie-breaker
- Magic variables must be scoped correctly during template execution

---

### Template Class

**Purpose**: Match-and-action rule within a Transformer. Defines how nodes are selected and transformed.

**Attributes**:
- `$.name` (Str?) - Optional template name (makes template callable as method)
- `$.signature` (Signature?) - Optional template signature (for parameters)
- `$.when-block` (Block) - Code block for matching nodes (template matcher)
- `$.do-block` (Block) - Code block for producing output (template action)
- `$.priority` (Int) - Template priority (from `:priority` trait, default 0)
- `$.specificity` (Int?) - Calculated specificity score (cached after calculation)
- `$.tie-breaker` (Int) - Tie-breaker value (from `:tie-breaker` trait, default 0)
- `$.streaming` (Bool) - Whether template has `:streaming` trait
- `$.returns-type` (Type?) - Output type constraint (from `returns(Type)` trait)

**Methods**:
- `matches($node --> Bool)` - Evaluates `when` block against node, returns True if matches
- `execute($node, :$context --> Iterator|Mu|List|Nil)` - Executes `do` block with magic variables set, returns result

**Lifecycle**:
- Created during transformer compilation (from `template` declarations in body)
- Stored in transformer's `@.templates` array
- Ordered during `ORDER-TEMPLATES` call
- Executed during `APPLY` when `when` block matches node

**Relationships**:
- Belongs to `Transformer` (contained in transformer's template array)
- Uses `$*CONTEXT` and `$*CAPTURE` (magic variables during execution)
- Can call `NextTemplate.throw` (to continue with next matching template)

**Constraints**:
- `when` block must return Bool (True if matches, False otherwise)
- `do` block must produce output (via `make` or return value)
- Priority, specificity, tie-breaker must be comparable for ordering
- Template name must be unique within transformer (if provided)

---

### Transformable Node

**Purpose**: Node in data structure being transformed. Transformable nodes are those that have a Walker with the `supports-rewrite` capability. Copy operations are provided via `Qwiratry::Copy` service class.

**Attributes**:
- Node-specific attributes (varies by data structure type)
- No fixed attributes (determined by Walker capability, not a role)

**Methods**:
- Copy operations provided via `Qwiratry::Copy` service class (not methods on node itself)
- Nodes may implement custom `.copy()` method (checked by Copy service before using default)

**Lifecycle**:
- Created by user/data source
- Transformed by transformers
- May be copied during transformation (non-destructive)
- Transformability determined by associated Walker's `supports-rewrite` capability

**Relationships**:
- Processed by `Transformer` (via Walker traversal)
- Matched by `Template` (via `when` blocks)
- Referenced by `$*CONTEXT` (current node during template execution)
- Copy operations provided by `Qwiratry::Copy` service class

**Constraints**:
- Transformable if associated Walker has `supports-rewrite` capability
- `Qwiratry::Copy::copy()` must be O(1) with respect to descendant count
- `Qwiratry::Copy::deepcopy()` must handle cycles (prevent infinite recursion)
- `Qwiratry::Copy::deepcopy()` must preserve DAG structure (single clone per unique node)
- Custom `.copy()` method on node is checked before using default implementation

---

### Wrapper

**Purpose**: Custom pre- or post-processing logic for transformers. Wraps transformer output, template matching, or template actions.

**Attributes**:
- `$.type` (Str) - Wrapper type: 'TRANSFORMER'|'TEMPLATE_MATCHER'|'TEMPLATE_ACTION'
- `$.body` (Block) - Code block to execute as wrapper
- `$.name` (Str?) - Optional wrapper name

**Methods**:
- Wrapper execution (handled by transformer system, not direct method calls)

**Lifecycle**:
- Created during transformer compilation (from `wrapper` declarations in body)
- Stored in transformer's `@.wrappers` array
- Executed as submethods during transformation at appropriate points

**Relationships**:
- Belongs to `Transformer` (contained in transformer's wrapper array)
- Called by transformer system (not directly by users)

**Constraints**:
- Must be one of three recognized types (TRANSFORMER, TEMPLATE_MATCHER, TEMPLATE_ACTION)
- Wrapper body receives appropriate parameters (varies by type)
- Wrappers called up transformer hierarchy (submethod mechanism)

---

### Template Ordering

**Purpose**: Sorted list of templates used during transformation. Determines which template applies when multiple could match.

**Attributes**:
- `@.ordered-templates` (Array[Template]) - Templates sorted by: priority (highest first) → specificity (highest first) → tie-breaker (highest first)

**Methods**:
- Ordering algorithm (implemented in `ORDER-TEMPLATES` method)

**Lifecycle**:
- Created during `ORDER-TEMPLATES` call
- Cached in transformer's `@.ordered-templates` attribute
- Used during `APPLY` for template matching

**Relationships**:
- Belongs to `Transformer` (stored as attribute)
- Contains `Array[Template]` (sorted templates)

**Constraints**:
- Ordering must be deterministic (same templates always produce same order)
- Must report error if two templates have equal priority/specificity/tie-breaker and could match same node
- Specificity calculation may be compile-time or runtime (hybrid approach)

---

### Magic Variables

**Purpose**: Dynamic variables available during template execution. Provide access to current node and template parameters.

**Attributes**:
- `$*CONTEXT` (Mu) - Current input context node (set to current item being processed)
- `$*CAPTURE` (Match?) - Capture of template signature parameters (set to template parameters if any)
- `self` (Transformer) - Reference to current Transformer object (automatically available)

**Methods**:
- Variable access (via Raku dynamic variable mechanism)

**Lifecycle**:
- Set before template `do` block execution
- Available during template execution
- Scoped to template execution (not visible outside)

**Relationships**:
- Used by `Template` (accessed in `when` and `do` blocks)
- Set by `Transformer` (in `APPLY` method before template execution)

**Constraints**:
- Must be set correctly for each template execution
- Must not leak between templates (proper scoping)
- `$*CONTEXT` must contain current node being processed
- `$*CAPTURE` must contain template parameters (if template has signature)

---

### Copy Service Class

**Purpose**: Service module providing `copy()` and `deepcopy()` multi subs for transformable nodes. Provides default implementations and attaches methods to Transformer object.

**Attributes**:
- Multi subs: `copy(Mu)`, `copy(Positional)`, `copy(Associative)`, `deepcopy(Mu)`, `deepcopy(Positional)`, `deepcopy(Associative)`

**Methods**:
- `multi sub copy(Mu $x --> Mu)` - Default: identity (returns as-is)
- `multi sub copy(Positional $p --> Positional)` - Shallow copy via `clone`
- `multi sub copy(Associative $a --> Associative)` - Shallow copy via `clone`
- `multi sub deepcopy(Mu $x --> Mu)` - Default: identity (atoms, objects with identity)
- `multi sub deepcopy(Positional $p --> Positional)` - Recursive deep copy via `map`
- `multi sub deepcopy(Associative $a --> Associative)` - Recursive deep copy via `map`
- Methods attached to Transformer object (delegate to service functions)

**Lifecycle**:
- Module-level service functions (no instance needed)
- Methods attached to Transformer objects at compile time or runtime
- Used during transformation for non-destructive copying

**Relationships**:
- Used by `Transformer` (methods attached to Transformer object)
- Operates on transformable nodes (nodes with Walkers that have `supports-rewrite` capability)
- Checks for custom `.copy()` method on nodes before using default

**Constraints**:
- `copy()` must be O(1) with respect to descendant count
- `deepcopy()` must handle cycles (prevent infinite recursion)
- `deepcopy()` must preserve DAG structure (single clone per unique node)
- Must check for custom `.copy()` method before using default implementation
- Default implementations for Positional and Associative types

---

### Walker Factory

**Purpose**: Registry/factory for selecting appropriate Walker instances based on input data type.

**Attributes**:
- `%.walker-registry` (Hash) - Registry mapping data types/roles to Walker types
- `@.discovered-walkers` (Array[Walker]) - Cached discovered walkers (optional)

**Methods**:
- `get-walker($data --> Walker?)` - Selects appropriate Walker for data type, returns Walker or Nil
- `register-walker($type, Walker)` - Registers Walker for specific data type/role
- `discover-walkers(--> Array[Walker])` - Discovers available Walkers via introspection (optional)

**Lifecycle**:
- Created once (singleton or module-level)
- Registry populated at module load or via registration
- Used by transformers to obtain Walkers

**Relationships**:
- Used by `Transformer` (to obtain Walker for traversal)
- Returns `Walker` instances

**Constraints**:
- Must return appropriate Walker or Nil (if none found)
- Should support explicit registration and automatic discovery
- Selection logic should be extensible

---

## Relationships Summary

```
Transformer
  ├── contains: Array[Template]
  ├── contains: Array[Wrapper]
  ├── uses: Walker (via factory)
  ├── uses: Context (per-traversal state)
  └── produces: transformed output

Template
  ├── belongs to: Transformer
  ├── uses: $*CONTEXT, $*CAPTURE (magic variables)
  └── matches: Transformable Node

Transformable Node
  ├── processed by: Transformer
  ├── matched by: Template
  ├── referenced by: $*CONTEXT
  └── copy operations via: Copy Service Class

Copy Service Class
  ├── used by: Transformer (methods attached)
  └── operates on: Transformable Node

Wrapper
  └── belongs to: Transformer

Template Ordering
  └── belongs to: Transformer

Magic Variables
  ├── set by: Transformer
  └── used by: Template

Walker Factory
  └── used by: Transformer
```

## Validation Rules

1. **Transformer**: Template ordering must complete successfully or report conflicts
2. **Template**: `when` block must return Bool, `do` block must produce output
3. **Transformable Node**: Determined by Walker capability (`supports-rewrite`), copy operations via `Qwiratry::Copy` service class
4. **Copy Service Class**: `copy()` must be O(1), `deepcopy()` must handle cycles, must check for custom `.copy()` method
4. **Wrapper**: Must be one of three recognized types
5. **Template Ordering**: Must be deterministic, must report conflicts
6. **Magic Variables**: Must be scoped correctly, must not leak between templates
7. **Walker Factory**: Must return Walker or Nil (never throw for missing Walker)

