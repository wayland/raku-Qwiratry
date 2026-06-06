# Research: Qwiratry Operators Specification

**Feature**: Qwiratry Operators Specification  
**Date**: 2025-01-27  
**Phase**: 0 - Outline & Research

## Research Questions

### RQ1: RakuAST::Node Structure for Operator Implementation

**Question**: How should operators be implemented as RakuAST::Node descendants while maintaining compatibility with regular Raku code?

**Findings**:
- RakuAST::Node is the base class for all AST nodes in Raku 6.e
- Operators need to work both in Query Slang expressions and regular Raku code (hybrid approach)
- RakuAST nodes are immutable and composable by design
- Operators can be defined as custom RakuAST node classes that extend RakuAST::Node
- For hybrid usage, operators must be callable/iterable in regular Raku contexts

**Decision**: Implement operators as RakuAST::Node descendants that:
- Extend RakuAST::Node for Query AST integration
- Implement callable/iterable interfaces for regular Raku usage
- Support both Query Slang parsing and direct instantiation in code

**Rationale**: Hybrid approach enables operators to work seamlessly in Query Slang while remaining usable in regular Raku code, maximizing flexibility and composability.

**Alternatives Considered**:
- Pure AST nodes only - rejected, limits usability outside Query Slang
- Wrapper functions only - rejected, breaks Query AST integration

---

### RQ2: Operator Precedence Integration with Raku Grammar

**Question**: How should Qwiratry operators integrate with Raku's operator precedence hierarchy?

**Findings**:
- Raku has a well-defined operator precedence system
- Custom operators can be defined with specific precedence levels
- Qwiratry operators need to fit into existing precedence levels or add new levels
- Precedence affects parsing and evaluation order
- Operators.md specifies precedence levels (some standard Raku, some custom)

**Decision**: 
- Use standard Raku precedence levels where operators fit naturally
- Add custom precedence levels for Qwiratry-specific operators (e.g., Junctive Exponentiation, Junctive unary)
- Ensure precedence is correctly handled in Query Slang grammar extensions
- Document precedence clearly for users

**Rationale**: Following Raku's precedence system ensures predictable behavior and compatibility with existing Raku code patterns.

**Alternatives Considered**:
- Completely custom precedence - rejected, breaks Raku compatibility
- All standard precedence - rejected, doesn't accommodate Qwiratry-specific needs

---

### RQ3: Capability/Interface System for Domain-Specific Semantics

**Question**: How should operators declare capabilities and how should Walkers check compatibility?

**Findings**:
- Operators need to work across different domains (trees, tables, graphs)
- Same operator may have different semantics per domain
- Walkers need to introspect operator capabilities to determine compatibility
- Raku roles and interfaces can be used to declare capabilities
- Pattern matching on operator types is possible but less flexible

**Decision**: Implement a capability/interface system where:
- Operators declare capabilities via roles or metadata (e.g., `does NavigationOperator`, `does SetOperator`)
- Operators provide capability metadata (e.g., `capabilities()` method returning hash)
- Walkers check compatibility via `supports()` method that examines operator capabilities
- Walkers can introspect operator structure for domain-specific interpretation

**Rationale**: Capability system provides flexibility for domain-specific semantics while maintaining clear contracts between operators and walkers.

**Alternatives Considered**:
- Pattern matching only - rejected, less flexible and harder to extend
- Visitor pattern - rejected, adds complexity without clear benefit

---

### RQ4: Error Handling Strategy for Operators

**Question**: When and how should operator errors be detected and handled?

**Findings**:
- Different error types occur at different stages:
  - Syntax errors: compile-time (invalid operator syntax)
  - Domain compatibility: planning-time (operator not supported by walker)
  - Data validation: runtime (null values, missing data, circular references)
- Raku provides compile-time checks via grammar/actions
- Walker.plan() can validate operator compatibility
- QueryIterator execution can validate data at runtime

**Decision**: Implement hybrid error handling:
- **Compile-time**: Basic syntax validation during Query Slang parsing
- **Planning-time**: Domain compatibility checks in Walker.plan() (throws `X::Qwiratry::UnknownQueryElement`)
- **Runtime**: Data validation during QueryIterator execution (throws domain-specific exceptions)

**Rationale**: Hybrid approach catches errors as early as possible while allowing domain-specific validation where needed.

**Alternatives Considered**:
- Compile-time only - rejected, can't validate domain compatibility without walker context
- Runtime only - rejected, delays error discovery and reduces user experience

---

### RQ5: Operator Composition and Query AST Structure

**Question**: How should operators compose into complex Query AST structures?

**Findings**:
- Operators must be composable to form complex queries
- RakuAST nodes naturally compose into tree structures
- Operators can be chained (e.g., `$root ⪪ * ⪪ *`)
- Operators can be combined with set operations (e.g., `$query1 ∪ $query2`)
- Query AST must remain immutable and introspectable

**Decision**:
- Operators compose naturally as RakuAST nodes form tree structures
- Chaining creates nested operator nodes
- Set operations create composite operator nodes
- All composition maintains immutability
- Walkers introspect AST structure for optimization

**Rationale**: RakuAST's natural composition model fits operator composition needs perfectly, maintaining immutability and introspectability.

**Alternatives Considered**:
- Custom composition system - rejected, unnecessary complexity when RakuAST provides this
- Mutable composition - rejected, violates immutability requirement

---

### RQ6: Integration with Existing Walker Infrastructure

**Question**: How do operators integrate with existing Walker and QueryIterator infrastructure?

**Findings**:
- Walker.plan() accepts RakuAST::Node $query parameter
- Operators as RakuAST::Node descendants fit this interface
- Walkers introspect query AST during planning
- QueryIterator produces results incrementally
- Operators don't execute themselves; execution delegated to Walkers

**Decision**:
- Operators are passed to Walker.plan() as RakuAST::Node
- Walkers pattern-match or introspect operator types during planning
- Walkers create execution plans that QueryIterators execute
- Operators remain declarative; execution is walker's responsibility

**Rationale**: This maintains separation of concerns: operators describe intent, walkers determine execution strategy.

**Alternatives Considered**:
- Operators execute themselves - rejected, breaks declarative model and walker flexibility
- Separate query language - rejected, loses Raku integration benefits

---

## Key Decisions Summary

| Decision | Rationale | Impact |
|----------|-----------|--------|
| Hybrid operator implementation (AST + regular Raku) | Maximizes flexibility and usability | Operators work in both contexts |
| Capability/interface system for domain semantics | Flexible domain-specific interpretation | Walkers can check compatibility |
| Hybrid error handling (compile/plan/runtime) | Early error detection with domain validation | Better user experience |
| Natural RakuAST composition | Leverages existing infrastructure | Simpler implementation |

## Open Questions

None - all research questions resolved through planning interrogation and existing infrastructure analysis.

## Next Actions

1. Proceed to Phase 1 design with confirmed architecture decisions
2. Design operator class hierarchy and capability system
3. Define Query Slang grammar extensions for operator parsing
4. Create API contracts for operator-walker interaction

