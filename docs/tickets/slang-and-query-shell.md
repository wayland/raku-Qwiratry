# Feature Shell: Query AST and Slang Support

**Title**: Query AST and Slang Support

**Scope**: Define the Query AST structure as immutable Raku AST objects representing query expressions, and implement Slang support for parsing query operators into Query AST nodes as specified in Specification.md sections 3.1 and 6. Queries must be immutable, composable, and introspectable, allowing multiple walkers to safely interpret the same query. The Slang extends Raku grammar to support trailing blocks on operators that become Query AST objects.

**Key Deliverables**:
- Query AST node classes (immutable, composable, introspectable)
- Slang grammar extensions for operator-term with trailing blocks
- Slang actions producing Query AST nodes
- Query AST introspection capabilities for walkers
- Support for query normalization and optimization hints

