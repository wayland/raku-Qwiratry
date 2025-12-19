# Feature Shell: Transformer and Template System

**Title**: Transformer and Template System

**Scope**: Implement the Transformer declarator system with Templates, Wrappers, and magic variables as specified in Specification.md sections 2.1.4, 3.3, 3.3.1-3.3.6. Transformers walk data structures using Walkers and Queries, applying Templates (match-and-action rules) to produce transformed output. Includes template ordering (priority/specificity/tie-breaker), traits (:streaming, returns, does TreeRewrite), wrappers (TRANSFORMER, TEMPLATE_MATCHER, TEMPLATE_ACTION), magic variables ($*CONTEXT, $*CAPTURE, self), and the Copy service class for transformable nodes. Transformable nodes are those that have a Walker with the supports-rewrite capability.

**Key Deliverables**:
- `transformer` custom declarator
- `Transformer` class with TRANSFORM, ORDER-TEMPLATES, APPLY methods
- `template` declarator with when/do blocks
- Template ordering algorithm (priority → specificity → tie-breaker)
- Wrapper system (TRANSFORMER, TEMPLATE_MATCHER, TEMPLATE_ACTION)
- Magic variables ($*CONTEXT, $*CAPTURE, self)
- `Qwiratry::Copy` service class with `copy()` and `deepcopy()` functions for transformable nodes (nodes with Walkers that have supports-rewrite capability)
- Support for :streaming, returns(), and does TreeRewrite traits

