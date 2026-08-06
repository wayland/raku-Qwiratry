# Universe / Topic Slang — Implementation Plan

*RakuAST slang that makes caller topic (`$_`) an explicit operand for
universe-based set operators (and optionally bare navigation), eliminating
`nqp::ctxcaller` / `getlexrel` digs.*

Related: [Raku/problem-solving#524](https://github.com/Raku/problem-solving/issues/524)
(callsite `$_` injection — we do **not** wait on a core `will ast` trait;
we use a Qwiratry slang instead).

# Goals

1. **Universe ops work under `given`** (and any lexical `$_`), including inside
   `Test` `subtest` blocks.
2. **No runtime topic dig** for those ops (`universe-from-caller` /
   `navigation-topic` via `ctxcaller` retired for this path).
3. **RakuAST only** — legacy grammar unsupported for Qwiratry.
4. **`query-ast { }` still returns Qwiratry operator nodes** with the universe
   captured as a real AST operand (not resolved only at eval time via NQP).
5. Prefer a **Slangify Grammar + Actions** approach (same family as Mold slang).

Non-goals for the first landing (historical; Phase 3 bare-nav also landed):

* Supporting non-RakuAST Rakudo builds.
* Lizmat’s proposed core `will ast` trait.
* One-`use` Topic activation (blocked by infix categoricals / MAIN refresh).

# Problem (short)

Universe operators (`parens` `⩂` `⊙` `⊡` `∁`) and bare nav prefixes used to call
`navigation-topic(nqp::ctxcaller(…))`. After 6.d, `$_` is not dynamic; `given`’s
topic is often invisible to NQP lexpad walks from a callee. Explicit
`$_ = $universe` works; `given` often does not. **Fixed** by Topic slang +
explicit `$universe` / bare-nav helpers (no dig).

# Target semantics

## Universe infixes / prefix

| Form today | Meaning | Target lowering |
| ---------- | ------- | ---------------- |
| `@A ⋂ @B` with topic `$_` = U | U − (A ∩ B) | Call / apply with **third** operand = lexical `$_` (name **`$universe`** in the op sub if easy; otherwise the injected AST node is still `$_`) |
| `@A ⩂ @B`, `⊙`, `⊡` | same pattern | same |
| `∁ @A` | U − A | Unary becomes binary in the op API: universe + collection, or keep prefix but Actions wrap as a call with `$_` first |

Preferred runtime signature sketch:

```raku
multi sub infix:<⋂>(Mu $left, Mu $right, Mu $universe = $*QWIRATRY-UNIVERSE) { ... }
# Actions always pass $universe explicitly as lexical $_ from the callsite AST.
# Default optional only as a safety net during migration; remove dig entirely.
```

If a three-arg infix is awkward in RakuAST ApplyInfix (binary-only), Actions emit an
explicit **call** to `&infix:<⋂>` (or a named helper `&qwiratry-universe-nand`)
with three args: `$left, $right, $_`.

## Bare navigation (Phase B)

| Form | Target |
| ---- | ------ |
| `⪪ $sel` (prefix) | Lower to infix/call with LHS = lexical `$_` |
| `$node ⪪ $sel` | Unchanged |

# Architecture

**Landed load order** (two `use`s — one-use activation is not viable on current Rakudo):

```
use Qwiratry::Query::Slang;         # re-exports Ops (operators)
use Qwiratry::Query::Slang::Topic;  # Slangify TopicGrammar/TopicActions — AFTER Ops
        │
        ▼
Importer CU parse → Actions rewrite PREFIX/INFIX / given
        │
        ▼
Rewrite matching universe and bare-nav nodes:
  inject RakuAST::Var::Lexical.new('$_') as universe / LHS
        │
        ▼
Runtime helpers: no ctxcaller; universe/LHS is a normal argument
```

Why two uses: (1) Slangify + many `infix is export` in the same CU prevents Topic
activation; (2) importing operator categoricals refreshes MAIN and wipes a Topic
mixin applied in the same `use`. Thin `Query::Slang` re-exports Ops via
`sub EXPORT { Map.new(Ops::EXPORT::DEFAULT.WHO.pairs) }`.

Reuse patterns from `lib/Qwiratry/Mold/Slang.rakumod`:

* Topic is a file-level compunit (no `unit module`) so Slangify runs in the importer.
* `use v6.e.PREVIEW`.
* RakuAST-only actions (no legacy grammar role).
* Mold slang loads Ops then Topic so mold `when` bodies get the same rewrites.

# Phases

## Phase 0 — Spike (½–1 day)

Prove Actions can rewrite one universe form end-to-end.

1. Minimal Slangify actions that intercept **`∁`** (simplest: one operand today).
2. User code: `given @U { say (∁ @A).List }` must work inside a `subtest`.
3. Confirm injected node is lexical `$_` (DEPARSE / AST dump).
4. Confirm `query-ast({ given …; ∁ @A })` or `query-ast({ $_ = …; ∁ @A })`
   still yields a `SetDifferenceOperator` (or successor) with universe operand
   represented somehow (literal capture vs topic sentinel — decide in spike).

**Exit:** spike branch or throwaway script + short note of which AST node types
were rewritten (`ApplyPrefix` vs `Call::Name` vs custom).

## Phase 1 — Runtime API without dig

1. Change universe multis to take explicit `$universe` (positional 3rd or
   leading, pick one and stick to it).
2. Remove `universe-from-caller` from those multis (keep `navigation-topic` for
   bare nav until Phase B).
3. Temporary bridge: if `$universe` undefined, throw a clear error pointing at
   slang/`given`/`$_ =` — **do not** silently dig.
4. Update unit tests that used `$_ = @U` to keep working; restore `given` once
   slang lands.

## Phase 2 — Topic slang for all universe glyphs

Ops: `⋂` `⩂` `⊙` `⊡` `∁`.

1. Grammar/Actions: identify applications of these operators in the importer AST.
2. Rewrite to pass lexical `$_` as `$universe`.
3. Document: universe must be the topic (`given U { … }` or `$_ = U; …`).
4. Tests:
   * `t/spec/Operators/06.1-set-relational.rakutest` §6.1.2 with **`given @U`**
   * nested `subtest` + `given`
   * `query-ast` round-trip / planner smoke
5. Changelog + Operators.md note (RakuAST required; topic = universe).

## Phase 3 — Bare navigation (optional follow-up)

1. Same slang: rewrite bare nav prefixes to supply LHS = `$_`.
2. Fix `t/spec/Operators/05-navigation-topic.rakutest` under `given`.
3. Retire `navigation-topic` / `ctxcaller` from those prefixes.
4. Infix `$x ⪪ $y` unchanged.

## Phase 4 — Cleanup

1. [x] Delete unused NQP topic helpers (`navigation-topic` / `universe-from-caller` / `use nqp` dig).
2. [x] META6 provides `Query::Slang`, `::Ops`, `::Topic`; Extending / Operators / README document **two-use** load order; RakuAST-only.
3. [x] Full `zef test` on moar-2026.07+ — Topic acceptance green; remaining FAIL
   is table FK/catalog / `t/operator/io` skip-all (pre-existing vs Topic work).

# Design choices (settled)

| Choice | Decision |
| ------ | -------- |
| Mechanism | Slangify Grammar + Actions (not core `will ast` trait; not CHECK-only unless spike shows Actions insufficient) |
| Compiler | RakuAST only |
| Universe parameter | Prefer explicit `$universe`; inject AST as lexical `$_` |
| Binary ApplyInfix limit | If needed, emit **call** with 3 args instead of ternary ApplyInfix |
| Bare nav | Phase B after universe |
| `query-ast` | Must keep building Qwiratry nodes; universe operand explicit in AST or evaluated arg list per spike |

# Open points for the spike

1. Exact RakuAST node shape for custom ops under 2026.07+ (`ApplyPrefix` /
   `ApplyInfix` / `Call`).
2. Whether Actions should mixin and wrap existing `prefix:sym` / `infix:sym`
   methods, or post-process statement ASTs.
3. How `query-ast` represents “universe is topic”: store `NavQueryTopic`-like
   sentinel vs require topic to be resolvable when the block runs under
   `$*QWIRATRY-BUILD-QUERY`.
4. Interaction with Mold slang when both are `use`d in one CU (activation order).

# Test plan (acceptance)

- [x] `given @U { (@A ⩃ @B).List }` inside `subtest` → expected NAND result
- [x] Same for `⩂` `⊙` `⊡` `∁`
- [x] `query-ast({ … })` still returns non-`Seq` operator AST for planners
- [x] Clear error if universe op used with undefined topic (no silent wrong U)
- [x] (Phase B) `given %repo { (⪪ <owner>).List }` works
- [x] Full `zef test` on moar-2026.07+ (06.1 + 05-navigation-topic verified;
      suite still FAIL on pre-existing table FK/catalog, `io` skip-all, unrelated)

## Landing notes

Ops live in `Qwiratry::Query::Slang::Ops`. Topic slang is a **separate**
`use Qwiratry::Query::Slang::Topic` **after** Ops/Slang: infix categoricals from
operator import overwrite MAIN if Topic is mixed in the same `use`. Public entry
`Qwiratry::Query::Slang` re-exports Ops via `sub EXPORT`.

# Suggested first PR

Phase 0 spike + Phase 1 API change + Phase 2 for `∁` and `⋂` only, with
§6.1.2 tests restored to `given`. Remaining glyphs and bare nav in follow-ups.
