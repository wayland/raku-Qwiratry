# Research: Transformer Templates System

**Feature**: Transformer Templates System  
**Date**: 2025-01-27  
**Phase**: 0 - Outline & Research

## Research Questions

### RQ1: EXPORTHOW::DECLARE Implementation Pattern

**Question**: How do we implement the `transformer` custom declarator using `EXPORTHOW::DECLARE`?

**Findings**:
- `EXPORTHOW::DECLARE` mechanism allows registering custom HOW classes for declarator keywords
- Pattern: Create a HOW class extending appropriate base (e.g., `Metamodel::ClassHOW`), export via `EXPORTHOW::DECLARE` package
- Constant name in `EXPORTHOW::DECLARE` package matches the declarator keyword
- Compiler uses the HOW when encountering the declarator keyword
- Red ORM uses this pattern for `model` declarator (reference implementation)
- HOW class handles class construction, trait application, method generation
- Body of declarator is parsed normally, HOW processes it during compilation

**Decision**: 
- Create `MetamodelX::TransformerHOW` class extending `Metamodel::ClassHOW`
- Export via `my package EXPORTHOW { package DECLARE { constant transformer = MetamodelX::TransformerHOW; } }`
- HOW class processes transformer body to collect templates, wrappers, and methods
- Templates stored in transformer class metadata for runtime access
- Automatically creates callable sub/method with transformer name that invokes `TRANSFORM`

**Rationale**: Follows established Raku pattern (Red ORM), integrates seamlessly with grammar, simpler than full slang, enables trait support and role composition.

**Alternatives Considered**: 
- Full slang implementation - rejected, too complex, unnecessary for declarator-only syntax
- Macro-based approach - rejected, less integrated with type system, harder to support traits/roles
- Manual parsing without declarator - rejected, loses declarator benefits (traits, roles, callable syntax)

---

### RQ2: Template Declarator Parsing Within Transformer Body

**Question**: How do we parse `template` declarations within a transformer body and collect them?

**Findings**:
- Transformer body is parsed as normal Raku code during compilation
- HOW class receives body AST during class construction
- Can traverse body AST to find `template` declarations
- Templates need to be collected and stored in transformer metadata
- Template structure: optional name/signature, optional traits, `when` clause, `do` clause
- Templates become methods on the transformer class (if named) or stored as anonymous templates

**Decision**:
- During transformer class construction, HOW traverses body AST
- Identify `template` declarations by pattern matching AST nodes
- Extract template components: name, signature, traits, `when` block, `do` block
- Create `Template` objects storing this metadata
- Store templates in transformer class attribute `@.templates` (or similar)
- Named templates also become callable methods on transformer class
- Templates accessible at runtime via transformer instance

**Rationale**: Manual parsing gives control over template collection, enables validation, allows storing template metadata for ordering algorithm.

**Alternatives Considered**:
- Separate `EXPORTHOW::DECLARE` for `template` - rejected, templates are scoped to transformers, not standalone
- Runtime template registration - rejected, loses compile-time validation, harder to support traits

---

### RQ3: Magic Variables ($*CONTEXT, $*CAPTURE) Implementation

**Question**: How do we set `$*CONTEXT` and `$*CAPTURE` dynamically during template execution?

**Findings**:
- Raku dynamic variables (twigil `*`) are scoped to call stack
- Set via assignment: `my $*CONTEXT = $node;` within appropriate scope
- Dynamic variables propagate down call stack but not up
- `$*CAPTURE` should contain template signature parameters (like `$/` in regex)
- `self` is automatically available in methods/blocks
- Need to set variables before executing template `do` block
- Variables should be scoped to template execution only

**Decision**:
- In `APPLY` method, before executing template `do` block:
  - Set `my $*CONTEXT = $node;` (current node being processed)
  - Set `my $*CAPTURE = $match;` (template signature parameters, if any)
  - `self` is already available (template executes as method on transformer)
- Use `CALLER::` or lexical scoping to ensure variables available in `do` block
- Variables automatically scoped to template execution (not visible outside)
- Clear variables after template execution (or let scope handle it)

**Rationale**: Uses Raku's native dynamic variable mechanism, scoped correctly, follows Raku idioms.

**Alternatives Considered**:
- Global variables - rejected, would leak between templates, not thread-safe
- Parameter passing instead of dynamic variables - rejected, doesn't match spec, less convenient for users
- Custom variable system - rejected, unnecessary, Raku dynamic variables are designed for this

---

### RQ4: Template Ordering Specificity Calculation

**Question**: How do we calculate template specificity from `when` clauses, especially for complex queries?

**Findings**:
- Specificity rules from spec: multilevel axis (-100), wildcards (-10), explicit path elements (+5), attribute axes (+5)
- Some aspects calculable at compile time (static query structure)
- Complex queries may require runtime evaluation (dynamic predicates, computed paths)
- Specificity calculation may need access to query AST structure
- Union queries: calculate each branch, take max
- Specificity needed for ordering when priority is equal

**Decision**:
- Hybrid approach: calculate what we can at compile time, defer complex cases to runtime
- Compile-time: analyze `when` clause AST for static patterns (axis operators, wildcards, path elements)
- Runtime: evaluate dynamic aspects when `ORDER-TEMPLATES` is called
- Cache specificity results to avoid recalculation
- If specificity cannot be determined statically, calculate during `ORDER-TEMPLATES`
- Specificity stored as numeric score for comparison

**Rationale**: Balances performance (compile-time optimization) with flexibility (runtime evaluation for complex queries). Caching avoids repeated calculation.

**Alternatives Considered**:
- Pure compile-time calculation - rejected, cannot handle dynamic queries
- Pure runtime calculation - rejected, loses optimization opportunity, slower
- Defer all to runtime - rejected, too slow, misses optimization opportunities

---

### RQ5: Walker Factory/Registry Pattern

**Question**: How should transformers obtain appropriate Walker instances based on input data type?

**Findings**:
- Transformers need Walkers to traverse input data
- Different data types may need different Walkers (trees vs tables vs other structures)
- Factory pattern: central registry that selects Walker based on data type
- Can use type checking, role composition, or heuristics to select Walker
- Should allow explicit Walker override for custom use cases
- Factory can cache Walker instances or create new ones as needed

**Decision**:
- Create `WalkerFactory` class (or extend existing infrastructure)
- Factory maintains registry of Walker types keyed by data type/role
- Selection logic: check if data does specific role (e.g., `Positional` for tables), use type name, or heuristic
- Default: factory selects appropriate Walker automatically
- Override: transformer can accept explicit `:$walker` parameter
- Factory can discover available Walkers via introspection (similar to Master Walker discovery)
- Cache Walker instances or create on-demand

**Rationale**: Enables automatic Walker selection (convenience) while maintaining flexibility (explicit override). Centralizes Walker selection logic.

**Alternatives Considered**:
- Require explicit Walker parameter - rejected, less convenient, requires users to know which Walker to use
- Hard-coded type-to-Walker mapping - rejected, not extensible, doesn't support custom Walkers
- No factory, transformers create Walkers directly - rejected, duplicates selection logic, harder to maintain

---

### RQ6: Copy and Deepcopy Implementation

**Question**: How should `copy()` and `deepcopy()` be implemented for transformable nodes?

**Findings**:
- Specification section 3.3.6 defines `Qwiratry::Copy` service class with `copy()` and `deepcopy()` multi subs
- Transformable nodes are those that have a Walker with the `supports-rewrite` capability (not a separate role)
- `copy()`: shallow copy, O(1) operation, children shared with original
- `deepcopy()`: recursive deep copy with cycle detection, DAG structure preservation
- Default implementations provided for `Positional` (via `clone` for copy, recursive map for deepcopy) and `Associative` types
- Nodes may implement their own `.copy()` method (should be checked before using default)
- Methods are attached to Transformer object for convenient access
- Cycle detection requires "visited" hash keyed by object identity
- DAG preservation: single clone per unique node regardless of parent count

**Decision**:
- Create `Qwiratry::Copy` module with `copy()` and `deepcopy()` multi subs as service functions
- `copy()` multi subs: `Positional` (via `clone`), `Associative` (via `clone`), `Mu` (identity - default)
- `deepcopy()` multi subs: `Positional` (recursive map), `Associative` (recursive map), `Mu` (identity - default)
- Check if node has custom `.copy()` method before using default implementation
- Methods attached to Transformer object (delegate to `Qwiratry::Copy` functions)
- Transformable nodes determined by Walker capability (`supports-rewrite`), not a role
- For immutable primitives (Str, Numeric, Bool), return as-is (handled by `Mu` case)

**Rationale**: Service class approach is simpler than role-based, provides defaults while allowing customization, follows spec section 3.3.6 exactly. Transformable nodes determined by Walker capability enables automatic detection.

**Alternatives Considered**:
- Transformable role approach - rejected, spec section 3.3.6 specifies service class
- Require all nodes to implement methods - rejected, too restrictive, adds boilerplate
- No default implementation - rejected, users would need to implement for every node type

---

### RQ7: Wrapper System Implementation

**Question**: How should wrappers (TRANSFORMER, TEMPLATE_MATCHER, TEMPLATE_ACTION) be implemented and called?

**Findings**:
- Wrappers are submethods called up the Transformer hierarchy (like `TWEAK`)
- Three wrapper types: TRANSFORMER (wraps entire output), TEMPLATE_MATCHER (wraps match evaluation), TEMPLATE_ACTION (wraps action execution)
- Wrappers defined in transformer body using `wrapper` declarator
- Wrappers should be callable during transformation execution
- Submethod mechanism: called in MRO order up the hierarchy

**Decision**:
- Parse `wrapper` declarations in transformer body (similar to template parsing)
- Create submethods: `WRAP_TRANSFORMER`, `WRAP_TEMPLATE_MATCHER`, `WRAP_TEMPLATE_ACTION`
- Call wrappers at appropriate points:
  - `WRAP_TRANSFORMER`: around entire `TRANSFORM` method output
  - `WRAP_TEMPLATE_MATCHER`: around `when` clause evaluation
  - `WRAP_TEMPLATE_ACTION`: around `do` block execution
- Use submethod call mechanism to traverse hierarchy (`.^find_method` or similar)
- Wrappers receive appropriate parameters (node, match result, action result, etc.)

**Rationale**: Follows spec pattern (submethods like `TWEAK`), enables customization without modifying core logic, maintains hierarchy traversal.

**Alternatives Considered**:
- Regular methods instead of submethods - rejected, doesn't follow spec, harder to traverse hierarchy
- Callback functions instead of submethods - rejected, less integrated, doesn't follow spec pattern
- No wrapper system - rejected, spec requires it, enables important customization

---

## Summary of Decisions

1. **Custom Declarator**: Use `EXPORTHOW::DECLARE` with `MetamodelX::TransformerHOW` extending `Metamodel::ClassHOW`
2. **Template Parsing**: Manual AST traversal during transformer class construction to collect templates
3. **Magic Variables**: Set `$*CONTEXT` and `$*CAPTURE` as dynamic variables before template execution
4. **Template Ordering**: Hybrid compile-time/runtime specificity calculation with caching
5. **Walker Integration**: Factory/registry pattern for automatic Walker selection with explicit override
6. **Copy Service Class**: `Qwiratry::Copy` module with multi subs, default implementations for Positional/Associative, methods attached to Transformer object, transformable nodes determined by Walker capability
7. **Wrapper System**: Submethods (`WRAP_TRANSFORMER`, etc.) called up hierarchy at appropriate points

All research questions resolved. Ready for Phase 1 design.

