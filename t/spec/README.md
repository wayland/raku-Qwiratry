# Spec-backed functional tests

Functional conformance tests for behaviour promised by:

- [`Specification.md`](../../Specification.md) — architecture, walkers, transformers, molds
- [`Operators.md`](../../Operators.md) — query operators and domain semantics

These are **not** unit or AST-construction tests. Assert observable results
(query output, mold transforms, documented errors), keyed to doc sections.

## Layout

```text
t/spec/
  Specification/     # Specification.md sections
  Operators/         # Operators.md sections
```

Filenames start with the section number so coverage is greppable:

| File | Doc section |
|------|-------------|
| `Operators/05.2-table-fk-navigation.rakutest` | Operators.md §5.2.1–5.2.5 |
| `Operators/05.2.8-ordered-row-navigation.rakutest` | Operators.md §5.2.8–5.2.11 |
| `Specification/3.2-walker.rakutest` | Specification.md §3.2.1 |
| `Specification/3.2.1-handover.rakutest` | Specification.md §3.2.1.6 |
| `Specification/3.2.5-strategy.rakutest` | Specification.md §3.2.5–3.2.6 |
| `Specification/3.3-transformer.rakutest` | Specification.md §3.3.2 |
| `Specification/3.3.3-molds.rakutest` | Specification.md §3.3.3 |
| `Specification/3.3.6-copy.rakutest` | Specification.md §3.3.6 |
| `Specification/7.1-tree-walker.rakutest` | Specification.md §7.1 |
| `Specification/7.2-table-walker.rakutest` | Specification.md §7.2 |

## Conventions

1. **Header cites the source**, e.g. `#| Operators.md §5.2 — table FK navigation`.
2. **One file ≈ one section** (or a tight cluster such as §5.2.8–5.2.11).
3. **Prefer examples from the docs** as seed cases; add edge cases only when the prose is normative.
4. **Shared fixtures** live in `t/lib/Qwiratry/Spec/` — do not invent divergent sample data per file.
5. Leave `t/unit/`, `t/operator/`, and `t/integration/` for implementation and multi-component scenarios that are not doc-indexed.

## Running

```bash
RAKUDO_RAKUAST=1 raku -Ilib -It/lib t/spec/Operators/05.2-table-fk-navigation.rakutest
# or the whole tree:
RAKUDO_RAKUAST=1 prove6 -Ilib -It/lib t/spec
```

## Planned coverage (not yet written)

| Area | Target files |
|------|----------------|
| Operators §2–§7 | **Done** — see `t/spec/Operators/` |
| Specification §3.2 / §3.3 / §7 | **Done** — see `t/spec/Specification/` |
