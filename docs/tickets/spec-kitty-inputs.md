# Feature Descriptions for spec-kitty.specify

Copy each section below and use it as input to `/spec-kitty.specify`
Process them in order (dependencies respected).

---

=== Specification to Feature Mapping ===

Create a comprehensive traceability document mapping all sections of Specification.md to feature tickets, ensuring complete coverage and clear dependencies. This mapping document will serve as the master reference for tracking which parts of the specification are implemented by which features, and will be used to verify that all spec requirements are addressed.

Key deliverables:
  - Complete section-by-section mapping of Specification.md to feature tickets
  - Dependency graph showing feature ordering
  - Coverage verification checklist
  - Cross-reference index for spec sections

---

=== Walker Core Infrastructure ===

Implement the core Walker infrastructure including the `Walker` role, `Walker::Plan` role, `Context` role, and `QueryIterator` role as specified in Specification.md sections 2.1.2, 3.2, 3.2.1-3.2.4, and 4. This includes all required methods (plan, iterator, start), optional hooks (PRE-PASS, POST-PASS), capability introspection methods, and the query execution flow that connects queries to incremental result streams.

Key deliverables:
  - `Walker` role with plan/iterator/start methods and optional hooks
  - `Walker::Plan` role with iterator/query/describe/optimise/subplans/capabilities methods
  - `Context` role for per-traversal mutable state
  - `QueryIterator` role extending Iterator with next() method
  - Error handling via `UnknownQueryElementException`

---

=== Strategy and ControlSignal ===

Implement the `Strategy` role with element-level traversal hooks (before, on-match, should-follow, after, finish) and the `ControlSignal` enumeration (NO_REWRITE, REWRITE_IMMEDIATE, REWRITE_DEFERRED, SKIP_ELEMENT, STOP_TRAVERSAL, FINAL_RESULT) as specified in Specification.md sections 2.1.3, 3.2.5, and 3.2.6. Strategies are walker-agnostic and reusable across data models, providing pluggable behavior for element processing during traversal.

Key deliverables:
  - `Strategy` role with all hook methods (before, on-match, should-follow, after, finish, should-continue)
  - `ControlSignal` enum with all signal values
  - Integration with Walker and Context for traversal control
  - Support for rewrites via RewriteSpec return values

---

=== Composite Walker Handovers ===

Implement the master/composite walker system that supports handovers between domain-specific walkers using the `provides<...>` compile-time trait for domain metadata and Walker capability checks as specified in Specification.md section 3.2.1.6. This includes handover detection priority (domain metadata → capability checks → AST pattern suitability → heuristic probing), plan-level handover coordination, and composite execution for multi-domain queries.

Key deliverables:
  - `provides<domain-name>` compile-time trait implementation via `trait_mod:<provides>`
  - Master Walker detection and delegation logic
  - Walker capability checking via `supports()` method
  - Plan-level handover with embedded subplans
  - Composite execution coordination for multi-domain queries

---

=== Query AST and Slang Support ===

Define the Query AST structure as immutable Raku AST objects representing query expressions, and implement Slang support for parsing query operators into Query AST nodes as specified in Specification.md sections 3.1 and 6. Queries must be immutable, composable, and introspectable, allowing multiple walkers to safely interpret the same query. The Slang extends Raku grammar to support trailing blocks on operators that become Query AST objects.

Key deliverables:
  - Query AST node classes (immutable, composable, introspectable)
  - Slang grammar extensions for operator-term with trailing blocks
  - Slang actions producing Query AST nodes
  - Query AST introspection capabilities for walkers
  - Support for query normalization and optimization hints

---

=== Transformer and Mold System ===

Implement the Transformer declarator system with Molds, Wrappers, and magic variables as specified in Specification.md sections 2.1.4, 3.3, 3.3.1-3.3.5. Transformers walk data structures using Walkers and Queries, applying Molds (match-and-action rules) to produce transformed output. Includes mold ordering (priority/specificity/tie-breaker), traits (:streaming, returns, does TreeRewrite), wrappers (TRANSFORMER, MOLD_MATCHER, MOLD_ACTION), and magic variables ($*CONTEXT, $*CAPTURE, self).

Key deliverables:
  - `transformer` custom declarator
  - `Transformer` class with TRANSFORM, ORDER-MOLDS, APPLY methods
  - `mold` declarator with when/do blocks
  - Mold ordering algorithm (priority → specificity → tie-breaker)
  - Wrapper system (TRANSFORMER, MOLD_MATCHER, MOLD_ACTION)
  - Magic variables ($*CONTEXT, $*CAPTURE, self)
  - copy() and deepcopy() methods for transformable nodes
  - Support for :streaming, returns(), and does TreeRewrite traits

---

=== Example Walker Implementations and Demos ===

Create sample walker implementations demonstrating the Qwiratry architecture across different domains as specified in Specification.md section 7. This includes Tree::Walker::DFS for tree traversal, Table::Walker::Scan for table/row iteration, and Logic::Walker::Backward for logic programming with backtracking. Also includes demo scripts showing query execution flows and transformer usage.

Key deliverables:
  - `Tree::Walker::DFS` class implementing Walker role for depth-first tree traversal
  - `Table::Walker::Scan` class implementing Walker role for table row scanning
  - `Logic::Walker::Backward` class implementing Walker role for backward-chaining logic
  - Demo scripts showing query execution with each walker type
  - Example transformers demonstrating mold usage
  - Documentation showing how to use the examples

---

