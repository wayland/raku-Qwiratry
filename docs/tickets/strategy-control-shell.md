# Feature Shell: Strategy and ControlSignal

**Title**: Strategy and ControlSignal

**Scope**: Implement the `Strategy` role with element-level traversal hooks (before, on-match, should-follow, after, finish) and the `ControlSignal` enumeration (NO_REWRITE, REWRITE_IMMEDIATE, REWRITE_DEFERRED, SKIP_ELEMENT, STOP_TRAVERSAL, FINAL_RESULT) as specified in Specification.md sections 2.1.3, 3.2.5, and 3.2.6. Strategies are walker-agnostic and reusable across data models, providing pluggable behavior for element processing during traversal.

**Key Deliverables**:
- `Strategy` role with all hook methods (before, on-match, should-follow, after, finish, should-continue)
- `ControlSignal` enum with all signal values
- Integration with Walker and Context for traversal control
- Support for rewrites via RewriteSpec return values

