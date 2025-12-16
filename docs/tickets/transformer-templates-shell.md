# Feature Shell: Transformer and Template System

**Title**: Transformer and Template System

**Scope**: Implement the Transformer declarator system with Templates, Wrappers, and magic variables as specified in Specification.md sections 2.1.4, 3.3, 3.3.1-3.3.5. Transformers walk data structures using Walkers and Queries, applying Templates (match-and-action rules) to produce transformed output. Includes template ordering (priority/specificity/tie-breaker), traits (:streaming, returns, does TreeRewrite), wrappers (TRANSFORMER, TEMPLATE_MATCHER, TEMPLATE_ACTION), and magic variables ($*CONTEXT, $*CAPTURE, self).

**Key Deliverables**:
- `transformer` custom declarator
- `Transformer` class with TRANSFORM, ORDER-TEMPLATES, APPLY methods
- `template` declarator with when/do blocks
- Template ordering algorithm (priority → specificity → tie-breaker)
- Wrapper system (TRANSFORMER, TEMPLATE_MATCHER, TEMPLATE_ACTION)
- Magic variables ($*CONTEXT, $*CAPTURE, self)
- copy() and deepcopy() methods for transformable nodes
- Support for :streaming, returns(), and does TreeRewrite traits

