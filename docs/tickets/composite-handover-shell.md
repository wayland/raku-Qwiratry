# Feature Shell: Composite Walker Handovers

**Title**: Composite Walker Handovers

**Scope**: Implement the master/composite walker system that supports handovers between domain-specific walkers using the `provides<...>` compile-time trait for domain metadata and Walker capability checks as specified in Specification.md section 3.2.1.6. This includes handover detection priority (domain metadata → capability checks → AST pattern suitability → heuristic probing), plan-level handover coordination, and composite execution for multi-domain queries.

**Key Deliverables**:
- `provides<domain-name>` compile-time trait implementation via `trait_mod:<provides>`
- Master Walker detection and delegation logic
- Walker capability checking via `supports()` method
- Plan-level handover with embedded subplans
- Composite execution coordination for multi-domain queries

