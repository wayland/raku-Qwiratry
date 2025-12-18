# Feature Shell: Walker Core Infrastructure

**Title**: Walker Core Infrastructure

**Scope**: Implement the core Walker infrastructure including the `Walker` role, `Walker::Plan` role, `Context` role, and `QueryIterator` role as specified in Specification.md sections 2.1.2, 3.2, 3.2.1-3.2.4, and 4. This includes all required methods (plan, iterator, start), optional hooks (PRE-PASS, POST-PASS), capability introspection methods, and the query execution flow that connects queries to incremental result streams.

**Key Deliverables**: 
- `Walker` role with plan/iterator/start methods and optional hooks (Query AST type: RakuAST::Node)
- `Walker::Plan` role with iterator/query/describe/optimise/subplans/capabilities methods
- `Context` role for per-traversal mutable state
- `QueryIterator` role extending Iterator with next() method
- Error handling via `X::Qwiratry::UnknownQueryElement` exception

