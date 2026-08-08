# Cursor Proposal

*Proposed factorization of query traversal position into a first-class Cursor,
between Walker Plan and QueryIterator — and a generic `Cursor` role suitable
for Raku-wide use, with Qwiratry’s `QueryCursor` as the first specialization.*

Related:

* [Walkable vs Streamable (Metanoia 2.3)](https://wayland.github.io/table-oriented-programming/Metanoias/Walkable-vs-Streamable.xml)
* [Streaming-Qwiratry-Proposal.md](Streaming-Qwiratry-Proposal.md) — I/O-boundary walkable/pull (different “Walkable”)
* [Qwiratry-TOP-Prerequisites.md](Qwiratry-TOP-Prerequisites.md) — streaming / TypedIterator / WalkCursor tree (§5.6 done)
* [Qwiratry-TOP-Basics.md](Qwiratry-TOP-Basics.md) — Relation, Memory, Postgres, Tables (Memory/SQL cursors still open)
* `lib/Qwiratry/QueryIterator.rakumod`, `lib/Qwiratry/Context.rakumod`,
  `lib/Qwiratry/Walker.rakumod`, `lib/Qwiratry/Tree/Navigator/Base.rakumod`,
  `lib/WalkCursor.rakumod`, `lib/Qwiratry/QueryCursor.rakumod`

# Status

Tree first landing implemented: `lib/WalkCursor.rakumod` (role `WalkCursor`;
Raku’s `CORE::Cursor` is already `Match`), `lib/Qwiratry/QueryCursor.rakumod`,
walk-local multi-step Navigators, `TreePlan.cursor`, Strategy optional
`WalkCursor :$cursor`, Evaluator navigation helpers delegated to Navigator
multi-step APIs, `QueryCursor.iterator` match bridge, Extending docs updated.
Spec details remain in Decisions below.

# Motivation

Qwiratry already separates:

| Piece | Role today |
| ----- | ---------- |
| **Walker** | Model-specific query planning and execution semantics |
| **Plan** | Reusable prepared query/root; no live position |
| **QueryIterator** | Lazy result stream (`pull-one`); also owns most traversal state |
| **Context** | Per-traversal mutable workspace shared with Strategy hooks |
| **Navigator** | Tree shape adaptor (children/parent/…); **walk-local** instances may cache; multi-step sector APIs (this plan) |

That works, but it conflates two jobs inside `QueryIterator`:

1. **Position / movement** — where the traversal is, and how it can step.
2. **Result projection** — which visited values are yielded as query matches.

The [Walkable vs Streamable](https://wayland.github.io/table-oriented-programming/Metanoias/Walkable-vs-Streamable.xml)
metanoia calls the first job a **Cursor**: a pointer that can move through a
data source, distinct from pull (`Iterator`) and push (`Supply`). A Cursor is
what makes walkabout navigation (including backtracking) first-class, rather
than private iterator fields.

Qwiratry’s query docs already admit the conflation: concrete iterators maintain
“traversal cursor, stack, queue, or backend cursor.” This proposal names that
object and places it in the plan → iterate pipeline.

# Design Goals

* Design a **generic `Cursor` interface (role)** that could be used Raku-wide —
  the same conceptual slot as `Iterator` / `Supply`: a first-class position and
  movement API, not tied to Qwiratry query internals.
* Ship the first concrete shape as a Qwiratry **`QueryCursor`** (Plan-bound,
  Context-aware, match-`iterator`) that **does** / extends that generic role.
  Other domains (regex/`Match`, tables, SQL, filesystems) should be able to
  implement the same `Cursor` contract later without inventing a parallel API.
* Make **position** first-class; stop burying it only on `QueryIterator` fields.
* Support **tree cursors**, not only record/row cursors: a Cursor must be able to
  **step along navigation sectors** (child, parent, descendant, following, … —
  Qwiratry’s existing sector vocabulary; the former “axis” naming in the
  codebases has already been renamed to **sector**), using Navigators where the
  model is tree-shaped. Cursor-layer **Axis** means a *pair* of opposite
  sectors (bidirectional line) — new terminology, not a rename target.
* Support **PostgreSQL-cursor-class movement** where the model allows it:
  next / prior, first / last, absolute / relative, forward / backward — each as
  a **`fetch-*`** (reposition and return the item) and a **`move-*`**
  (reposition only) pair, mirroring PostgreSQL `FETCH` / `MOVE`. Optional
  `:axis` / `:sector` on those methods (former `move($sector, $n)` parameters).
  Relation and SQL Locations should map cleanly onto this.
* Keep **Plan** free of live mutable position (mint a fresh cursor per run).
* Keep **QueryIterator** as the pull stream of **results** (usually matches).
* Keep **Context** as per-pass workspace / strategy slot — not the cursor.
* Keep **Walker** as choreography: which moves to take, what matches, when to
  stop, when to run Strategy hooks.
* Allow a Cursor **without** an associated Walkable surface, just as an
  `Iterator` need not expose an `Iterable` and a `Supply` need not expose a
  `Supplier`. **Walkable is deferred** — design Cursor first; Walkable (as a
  “structure that mints Cursors”) can come later.
* Preserve today’s external behaviour: `plan.iterator` can remain as sugar that
  builds cursor then iterator.
* Stay compatible with tree Navigators: Cursor holds `$current` + `$origin`;
  walk-local Navigators answer one-step and **multi-step** sector questions and
  may cache (invalidated on `TreeRewrite`).
* Count-taking `fetch-*` are `Int` | `Range` multis (open and closed Ranges;
  `*` / `Inf` = ALL); `move-*` are `Int`-only and return a step count.

# Non-Goals

* Replacing Navigators with Cursors.
* Designing or requiring a Raku-wide **Walkable** role in this pass (metanoia
  still relevant; not in scope until Cursor settles).
* Landing the generic role in Rakudo/core immediately — the goal is a contract
  *suitable* for Raku-wide use; Qwiratry can host the first implementation.
* Full push/`Supply` query execution (see Streaming v2).
* Requiring every Cursor implementation to support every sector/Axis and every
  SQL scroll op on day one — advertise capabilities; unsupported moves fail clearly.
* **Implementing Memory or Postgres (SQL) Cursor backends in this pass** — the
  contract should be ready so TOP / Location work can merge those in later; this
  proposal does not ship those implementations.
* **Introducing Walkable-as-cursor-factory** (metanoia Walkable that mints
  Cursors) — not part of this plan; Cursor stands alone first.
* Renaming navigation “axis” → “sector” in Qwiratry — **already done** in the
  codebases; this proposal only adds Cursor-layer Axis (= sector pair).
* Renaming I/O `*Walkable` contracts — those mean whole-value transfer at
  Format/Location boundaries, not “has a Cursor.”

# Conceptual Split

## Cursor vs Walker

* **Cursor** — *where* we are and *how* we can move (step, maybe back/skip,
  absolute/relative when the model allows).
* **Walker** — *which* moves to take under the query and strategy, *what*
  counts as a match, *what* to yield, *when* to finish.

Visiting nodes/rows is **Walker-directed movement of a Cursor**, not “the Cursor
is the visitor.” Strategy hooks on Walkable walks take optional
`Cursor :$cursor` at the end of each hook (omit on Streamable-Pull). Walk
ownership stays with Runtime/Evaluator or Strategy iterator; they **use** the
Cursor (match-directed advance for matches; Strategy walk still steps the
Cursor over intermediates it already visits).

## Cursor vs QueryIterator

Three backend shapes (metanoia / Streaming vocabulary):

| Backend | Role in this design |
| ------- | ------------------- |
| **Walkable** | Bidirectional / random-access walkabout → **Cursor** (this proposal) |
| **Streamable-Pull** | Consumer pulls results → **QueryIterator** (`pull-one`) |
| **Streamable-Push** | Producer emits → `Supply` / push edges (out of scope here; see Streaming v2) |

* **Cursor** is for **Walkable** backends only.
* **QueryIterator** sits on the **Streamable-Pull** side. It must **not** require
  a `$.cursor`: pull-only backends produce iterators without one. That includes
  **streaming trees** (e.g. streaming XML) as well as row Sources — forward
  pull of nodes/rows without a Walkable Cursor.
* **QueryCursor** may optionally expose `.iterator` as a **bridge** from a
  Walkable cursor to a match-oriented pull stream — convenience, not a
  requirement that every `QueryIterator` wrap a Cursor.

Do not assume `pull-one` ≡ “move one Cursor step.”

## Cursor vs Context

* **Context** — counters, memo, queues that are *not* the position API,
  plus `$.strategy`.
* **Cursor** — the navigable “here.”

A concrete Context may still hold auxiliary structures; the Cursor is the
stable place callers ask for position and movement. Prefer not to bury “current
node” only on Context.

## Cursor vs Walkable (metanoia) vs `*Walkable` (I/O)

| Term | Meaning |
| ---- | ------- |
| Metanoia **Walkable** | Structure that can provide Cursors (Str, Tree, Relation, …) — **deferred** |
| Qwiratry I/O **Walkable** | Whole-value parse/read/render/write |
| Generic **Cursor** | Raku-wide position / movement role (this proposal’s shared contract) |
| **QueryCursor** | Qwiratry query Cursor: Plan + Context + match `iterator` |

A QueryCursor minted from a Plan is coherent even when no Walkable role exists
yet: the Plan’s root + query define the space being walked. A future Walkable
“mint a Cursor” factory is **not part of this plan**.

## Cursor vs Navigator

Navigators are **shape adaptors** for a node model. Shared registry instances
from `tree-navigator-for` stay reusable and cache-free. A Cursor (or walk owner)
holds a **walk-local** Navigator that may **cache** (parent, siblings, …) and
exposes **multi-step** sector helpers as well as one-step `tree-children` /
`tree-parent`. `Tree::Replace` invalidates those caches on successful
`TreeRewrite`. The Cursor holds `$current` + `$origin` (not a universal path
stack or full node snapshot). New node shapes still prefer a Navigator when
tree semantics apply; a new Cursor subclass is for new *position/movement*
models (e.g. SQL cursor, keyset pagination).

**Why not merge Navigator into `QueryCursor`?** They answer different questions
and have different clients:

| | **Navigator** | **Cursor** (`QueryCursor`, …) |
| --- | --- | --- |
| Job | *How is this node shaped?* (children, parent, sector lists) | *Where am I in this walk?* (position + fetch/move) |
| Varies with | Node / data model (`Match`, `IO::Path`, RakuAST, …) | Movement model (tree walkabout, SQL scroll, …) |
| Other clients | Evaluators, `Tree::Replace`, Walkers — not only cursors | Plan / Strategy / match bridge |
| Lifetime | Registry type + optional walk-local session/caches | One run’s position (`clone-position` for backtrack) |

Merging would force every new node shape to ship a query Cursor, and every
non-tree Cursor (rows, SQL) to drag tree-navigation APIs. Keep composition:
Tree `QueryCursor` *uses* a walk-local Navigator; it does not *become* one.

# Proposed Pipeline

Walkable path (this proposal’s focus):

```text
Walker.plan($query, $root)  →  Plan
Plan.cursor()               →  QueryCursor   (does Cursor; fresh position + Context)
QueryCursor.iterator()      →  QueryIterator (optional bridge to Streamable-Pull)
QueryIterator.pull-one()    →  match | IterationEnd
```

Streamable-Pull path (unchanged in spirit; no Cursor required):

```text
Plan.iterator()             →  QueryIterator   # may be built without any Cursor
QueryIterator.pull-one()    →  match | IterationEnd
```

Compatibility: today’s `Plan.iterator` / `Walker.iterator` stay valid. On a
Walkable backend, `Plan.iterator` *may* be implemented as
`Plan.cursor.iterator`, but that is not the only allowed implementation, and
`QueryIterator` must not require `$.cursor`.

Multiple independent cursors from one Plan must not share mutable position
(same independence rule as today’s iterators).

# Movement Model

Two complementary movement vocabularies share one Cursor role. Implementations
advertise what they support; callers probe capabilities or handle clear errors.

## Tree / sector movement

For document- and tree-shaped data, oriented half-lines from the current node
are **Sectors** (XPath/Qwiratry names: `following`, `preceding`, `child`, …).
An **Axis** is a **matched pair of opposite sectors** — one bidirectional line:

| Axis (line) | Forward sector (+) | Backward sector (−) |
| ----------- | ------------------ | ------------------- |
| `preceding-following` | `following` | `preceding` |
| `preceding-following-sibling` | `following-sibling` | `preceding-sibling` |
| `ancestor-descendant` | `descendant` | `ancestor` |

`Sector::child` / `Sector::parent` remain navigation names (and Cursor
`:sector` values) but do **not** get their own Axis: they are
`move-relative(+1)` / `move-relative(-1)` (or the `fetch-*` twins) on
`Axis.ancestor-descendant` (one step along descendant / ancestor). Same idea as
XPath child ≈ descendant at distance 1.

Qwiratry already implements the sector operators (including `⪨⪨` / `⪩⪩` for
document order). Cursor `fetch-next` / `fetch-relative(+n)` (and `move-*`
twins) walk the **forward** sector of `$.default-axis`; `fetch-prior` /
`fetch-relative(-n)` walk the **backward** sector — same signed-motion story as
Postgres, without flipping `default-axis` to the opposite sector name.

Postgres/relation cursors use the same **`preceding-following`** Axis on the
result row sequence (one ordered line; forward/backward only). Tree cursors may
offer additional Axes; switching `$.default-axis` changes which line
`fetch-next`/`fetch-prior` (and `move-*`) mean.

## PostgreSQL-style scroll movement

For ordered sequences (table rows, query result sets, SQL cursors), support the
same class of operations PostgreSQL exposes on cursors — **twice**, so the name
says whether the call returns data:

| Direction | `fetch-*` (like `FETCH`) | `move-*` (like `MOVE`) |
| --------- | ------------------------ | ---------------------- |
| next | `fetch-next` — forward one; return item | `move-next` — forward one; no item |
| prior / previous | `fetch-prior` / `fetch-previous` | `move-prior` / `move-previous` |
| first / last | `fetch-first` / `fetch-last` | `move-first` / `move-last` |
| absolute | `fetch-absolute($n)` — **0-based**; `Int` or `Range` | `move-absolute($n)` |
| relative | `fetch-relative($n)` — `Int` or `Range` | `move-relative($n)` |
| forward / backward | `fetch-forward($n)` / `fetch-backward($n)` — `Int` or `Range` | `move-forward($n)` / `move-backward($n)` |
| Axis vs Sector | Supported **Axes are always bidirectional**; one-way-only → advertise **Sectors**, not an Axis |

* **`fetch-*`** — reposition, then return data. The `Int` multi of each
  count-taking method returns the item at the new position (`Mu`), or
  `IterationEnd` if the step is empty. The `Range` multi returns a `Seq` of
  items over that span; endpoints may be `Int`, `Inf`, or `Whatever` (`*`) —
  `*` / open end means “until exhausted” (Postgres `FORWARD ALL` /
  `BACKWARD ALL` — e.g. `fetch-forward(1..*)`). **Closed and open** Ranges
  (`^` exclusivity) are both supported. Range endpoints: any `Int`
  (including negative) when using `:axis` / default axis; **non-negative**
  only when using `:sector` (same sign rule as scalar `$n`).
* **`move-*`** — reposition to **one** position, **without** returning an item.
  Return an **`Int` count** (Postgres `MOVE count` spirit: how many positions
  were advanced; `0` if none). Count-taking `move-*` take **`Int` only** — a
  Range is not a destination (see Decisions).

Forward-only backends advertise forward **sectors** (not a
`preceding-following` Axis) — same honesty rule as Location capabilities,
without a separate `scrollable` flag.

Tree sector/Axis moves and SQL scroll moves share signed relative motion on
`$.default-axis`. Optional `:axis` / `:sector` on scroll methods select the line
or half-line for that call; passing **both** is an error (see Decisions).

# Sketch API

Prefer a **generic** role that Qwiratry’s `QueryCursor` specializes. Settled
pieces: **Sector** / Cursor-layer **Axis**; no `exhausted`; `IterationEnd` on
empty `fetch-*`; `$.default-axis`; dual `fetch-*` / `move-*`; count-taking
`fetch-*` are **`multi`s on `Int` and `Range`** (open + closed; `*`/`Inf` =
ALL; axis vs sector sign rules); `move-*` are `Int`-only → `Int` count;
`lib/Cursor.rakumod` exports `Cursor` / `Sector` / `Axis`;
`lib/Qwiratry/QueryCursor.rakumod` provides `Qwiratry::QueryCursor`.

```raku
# Oriented half-lines from the current node (XPath/Qwiratry navigation names).
# Prefer Sector:: qualification so barewords do not collide with slang infix
# aliases such as infix:<child>, infix:<parent>, … (Sector::child is fine).
# Navigation codebases already use “sector” for these; no further rename planned.
enum Sector <
    self
    child parent descendant ancestor
    following preceding
    following-sibling preceding-sibling
    attribute
>;

# Cursor-layer Axis: matched opposite pair of Sectors (one bidirectional “line”).
# Forward (+n / fetch-next) uses .forward; backward (−n / fetch-prior) uses .backward.
# Not the old navigation word “axis” (that is now Sector in Qwiratry).
class Axis {
    has Sector $.forward  is required;
    has Sector $.backward is required;

    method WHICH { ValueObjAt.new("Axis|{$!forward.Str}|{$!backward.Str}") }

    method preceding-following {
        Axis.new(:forward(Sector::following), :backward(Sector::preceding))
    }
    method preceding-following-sibling {
        Axis.new(
            :forward(Sector::following-sibling),
            :backward(Sector::preceding-sibling),
        )
    }
    method ancestor-descendant {
        Axis.new(:forward(Sector::descendant), :backward(Sector::ancestor))
        # child ≈ fetch/move-relative(+1); parent ≈ …(-1) — no separate Axis
    }
    # Postgres / relation row sequences use Axis.preceding-following on result order.
}

# Raku-wide contract — lib/Cursor.rakumod (exports Cursor, Sector, Axis)
role Cursor {
    has Axis $.default-axis is rw;   # usually Axis.preceding-following

    method current(--> Mu) { ... }

    method cursor-capabilities(--> Associative) { ... }

    # PostgreSQL-class scroll as fetch-* (return item) and move-* (reposition
    # only). Same optional :axis / :sector on every method; defaults use
    # $.default-axis; :sector selects one half-line. Passing both :axis and
    # :sector → error. Empty fetch step → IterationEnd; unsupported → throw.
    #
    # Algebra (both families share it):
    #   *-relative(+n) along axis forward (or along :sector);
    #   *-relative(-n) along axis backward only when using :axis (not :sector).
    #   With :sector, require $n >= 0; $n == 0 → self (current).
    #   Former informal move($sector, $n) ≈ *-relative($n, :$sector) with $n >= 1.
    #   *-absolute($n, :$sector) → same as *-relative($n, :$sector).
    #   *-first(:$sector) → *-relative(1, :$sector) (next on that sector).
    #   *-last(:$sector) → last reachable on that sector from current.
    #   Count-taking fetch-* are multis: Int (single Mu) and Range (Seq).
    #   Range endpoints: Int|Inf|Whatever; closed and open (^) both OK;
    #   :axis → any Int; :sector → >= 0; * / Inf = until exhausted (ALL).
    #   move-* take Int only → Int count.

    method fetch-next(Axis :$axis, Sector :$sector --> Mu) { ... }
    method fetch-prior(Axis :$axis, Sector :$sector --> Mu) { ... }
    method fetch-previous(|c) { self.fetch-prior(|c) }

    method fetch-first(Axis :$axis, Sector :$sector --> Mu) { ... }
    method fetch-last(Axis :$axis, Sector :$sector --> Mu) { ... }

    multi method fetch-absolute(
        Int $n,                    # 0-based (Raku); Postgres adaptor +1 later
        Axis :$axis,
        Sector :$sector
        --> Mu
    ) { ... }
    multi method fetch-absolute(
        Range $n,                  # endpoints: Int|Inf|Whatever; sector → >= 0
        Axis :$axis,
        Sector :$sector
        --> Seq
    ) { ... }

    multi method fetch-relative(
        Int $n,
        Axis :$axis,
        Sector :$sector
        --> Mu
    ) { ... }
    multi method fetch-relative(
        Range $n,
        Axis :$axis,
        Sector :$sector
        --> Seq
    ) { ... }

    multi method fetch-forward(
        Int $n = 1,
        Axis :$axis,
        Sector :$sector
        --> Mu
    ) { ... }
    multi method fetch-forward(
        Range $n,                  # e.g. 1..* ≡ FORWARD ALL
        Axis :$axis,
        Sector :$sector
        --> Seq
    ) { ... }

    multi method fetch-backward(
        Int $n = 1,
        Axis :$axis,
        Sector :$sector
        --> Mu
    ) { ... }
    multi method fetch-backward(
        Range $n,                  # e.g. 1..* ≡ BACKWARD ALL
        Axis :$axis,
        Sector :$sector
        --> Seq
    ) { ... }

    method move-next(Axis :$axis, Sector :$sector --> Int) { ... }
    method move-prior(Axis :$axis, Sector :$sector --> Int) { ... }
    method move-previous(|c) { self.move-prior(|c) }

    method move-first(Axis :$axis, Sector :$sector --> Int) { ... }
    method move-last(Axis :$axis, Sector :$sector --> Int) { ... }

    method move-absolute(
        Int $n,
        Axis :$axis,
        Sector :$sector
        --> Int
    ) { ... }

    method move-relative(
        Int $n,
        Axis :$axis,
        Sector :$sector
        --> Int
    ) { ... }

    method move-forward(
        Int $n = 1,
        Axis :$axis,
        Sector :$sector
        --> Int
    ) { ... }

    method move-backward(
        Int $n = 1,
        Axis :$axis,
        Sector :$sector
        --> Int
    ) { ... }

    method clone-position(--> ::?CLASS) { ... }
}

role Qwiratry::QueryCursor does Cursor {
    # lib/Qwiratry/QueryCursor.rakumod
    has Context $.context is required;
    has Mu $.plan;
    # Walk-local Navigator (not the shared registry instance); caches OK
    has Mu $.navigator;   # does Tree::Navigator::Base

    method step(--> Mu) { ... }   # often fetch-relative(+1) on $.default-axis
    # Optional Walkable → Streamable-Pull bridge (not required of all iterators)
    method iterator(--> QueryIterator) { ... }
}

role QueryIterator does Iterator {
    has Context $.context is required;
    # No required $.cursor — Pull backends often have none.
    method pull-one(--> Mu) { ... }   # match | IterationEnd
}
```

Walker Plan:

```raku
role Qwiratry::Walker::Plan {
    method cursor(--> QueryCursor) { ... }     # Walkable backends
    method iterator(--> QueryIterator) { ... } # Pull; must not require a Cursor
    # query / describe / capabilities unchanged
}
```

### Suggested result vs visit streams

To avoid ambiguity, document clearly that `QueryCursor.iterator` returns a
**match-oriented** `QueryIterator` (today’s semantics). If a visit stream is
needed later, add an explicit API (`visits`, `visit-iterator`, or a capability)
rather than overloading `iterator`.

# Who Implements What

| Walker / model | Cursor responsibilities (illustrative) |
| -------------- | -------------------------------------- |
| Tree (default) | `$current` + `$origin`; walk-local multi-step Navigator (caches + TreeRewrite invalidate); `step` ≈ `fetch-relative(+1)`; walk owner uses Cursor; Strategy hooks get optional `:cursor` |
| Table / Relation / Postgres | **Later (TOP merge):** sequence Cursor on `Axis.preceding-following`; map `fetch-*` / `move-*` to row order / SQL `FETCH`/`MOVE` — not in this proposal’s implementation scope |
| Logic / search | Position + choice points; `clone-position`; sectors as needed for term structure |

TOP’s existing `Cursor::Storage::Postgres` remains a reference backend for a
future Relation/Table `QueryCursor`, not work required to land this proposal.

# Migration

1. Draft `lib/Cursor.rakumod` (exports `Cursor` / `Sector` / `Axis`) and
   `lib/Qwiratry/QueryCursor.rakumod` (`Qwiratry::QueryCursor does Cursor`);
   `fetch-*` / `move-*` with optional `:axis` / `:sector`; `Int`|`Range` fetch
   multis; `move-*` → `Int` count.
2. Extend Tree Navigators with multi-step sector APIs; mint **walk-local**
   Navigators for Cursors; wire `Tree::Replace` cache invalidation.
3. Implement `Plan.cursor` for Tree (default `Axis.preceding-following`);
   refactor Tree iterators / Evaluators to **use** the Cursor + Navigator APIs;
   keep `Plan.iterator` sugar; optional `Cursor :$cursor` on Strategy hooks.
4. Add `X::Qwiratry::Cursor::*` exceptions; document capabilities (`axes`,
   `sectors`, `absolute`; Axes always bidirectional).
5. Update Extending docs (Walkers, Navigators, Strategies); publish as Raku-wide
   contract candidate.
6. Later (out of scope here): Memory/Postgres backends; mold/`$_` from Cursor;
   core Raku if the contract proves out.

Do not break callers that only use `plan.iterator` / `pull-one`.

# Acceptance Criteria

- [x] Generic `WalkCursor` role in `lib/WalkCursor.rakumod` exporting
      `WalkCursor` / `Sector` / `Axis`, with `fetch-*` / `move-*` (Int + Range
      fetch multis; move → Int count) and `cursor-capabilities` (`axes`,
      `sectors`, `absolute`). (Bare `Cursor` blocked by `CORE::Cursor` = `Match`.)
- [x] `Qwiratry::QueryCursor` in `lib/Qwiratry/QueryCursor.rakumod`; `Plan.cursor`
      returns an independent instance with its own Context and walk-local
      Navigator.
- [x] Tree Navigators expose multi-step sector helpers; shared registry instances
      stay cache-free; walk-local caches invalidate on `Tree::Replace` success.
- [x] Tree Cursor moves along at least `following` / `preceding` via
      `Axis.preceding-following` and vertical one-step via
      `Axis.ancestor-descendant` (`fetch/move-relative(±1)` ≈ child/parent);
      preferably also sibling sectors. Supported Axes are bidirectional;
      one-way-only backends advertise Sectors only.
- [x] Contract documents Postgres-style `fetch-*` / `move-*` on
      `Axis.preceding-following` for later TOP/Memory/Postgres backends (not
      required to ship here).
- [x] Walk owners use the Cursor; `cursor.iterator` yields the same match
      sequence as today’s `plan.iterator` for Tree baselines (no extra Table
      work). Strategy hooks accept optional `WalkCursor :$cursor`.
- [x] Traversal position is queryable via `current` during iteration/hooks.
- [x] Context still carries strategy; it is not the sole owner of current node.
- [x] Two cursors from one Plan do not share position or walk-local Navigator
      cache state.
- [x] Docs: Walker vs Cursor vs Iterator vs Context vs Navigator; I/O `*Walkable`
      vs deferred metanoia Walkable; QueryCursor as specialization of WalkCursor.
- [x] `QueryIterator` does not require a Cursor; docs state Cursor = Walkable,
      QueryIterator = Streamable-Pull (optional bridge via `QueryCursor.iterator`).
- [x] `X::Qwiratry::Cursor::*` for conflicting direction, negative sector step,
      unsupported op, invalid Range; empty fetch → `IterationEnd`.
- [x] Optional: backtracking demo via `clone-position`.

# Decisions

Settled answers, grouped by theme and numbered **1–28 in document order**.

## Scope and faces

1. **Must `QueryIterator` require a `$.cursor`?**  
   **No.** Backends come in three kinds: Walkable, Streamable-Push, and
   Streamable-Pull. Cursors belong to **Walkable** only. `QueryIterator` is the
   **Streamable-Pull** face (`pull-one`). A `QueryCursor` may optionally bridge
   to a pull stream via `.iterator`; pull-only backends build a `QueryIterator`
   with no Cursor at all.

2. **When do we introduce Walkable-as-cursor-factory?**  
   **Not as part of this plan.** Design and prove `Cursor` / `QueryCursor`
   first; metanoia Walkable (“structure that mints Cursors”) stays deferred.

3. **Do tables — or streaming trees — need a Cursor?**  
   **Not for the Streamable-Pull face.** A table **Source**, or a **streaming
   tree** (e.g. streaming XML), may yield rows/nodes as a pull `Iterator` /
   `QueryIterator` without a Cursor. A **Walker Cursor** is for **Walkable**
   query walkabout (including a fully loaded tree or relation). They may share
   ordered-sequence ideas (`Axis.preceding-following`) but are different faces —
   do not force Source / streaming-tree pull through `QueryCursor`.

4. **First landing scope vs acceptance?**  
   **Tree proof only** — no more Table work than Qwiratry already has.
   Non-goals already exclude Memory/Postgres Cursor implementations this pass;
   acceptance criteria match that (contract docs for later backends, no ship
   requirement).

## Packaging

5. **Where does the generic Cursor contract live?**  
   **Tiny standalone module inside Qwiratry:** `lib/WalkCursor.rakumod` exporting
   `WalkCursor` / `Sector` / `Axis`. The conceptual name remains “Cursor” in
   docs/metanoia, but Raku already binds **`CORE::Cursor` → `Match`**, so a
   bare `Cursor` role/module cannot ship. `WalkCursor` is the short name until
   core frees or renames that symbol. Query specialization is
   `Qwiratry::QueryCursor` (Decision 7).

6. **Generic module packaging?**  
   **Single `WalkCursor` module** (`lib/WalkCursor.rakumod`) exporting
   `WalkCursor`, `Sector`, and `Axis`. META6 `provides` entry for `WalkCursor`.

7. **Where does `QueryCursor` live?**  
   **Option A:** `lib/Qwiratry/QueryCursor.rakumod` providing
   `Qwiratry::QueryCursor` (beside `QueryIterator` / `QueryMatch`).

## Movement API (`fetch-*` / `move-*`)

8. **If both `:axis` and `:sector` are passed?**  
   **Throw an error.** Use one or the other (or neither → `$.default-axis`).

9. **Do `child` / `parent` need their own Axis?**  
   **No.** Treat them as one-step moves on `Axis.ancestor-descendant`:
   `fetch-relative(+1)` / `move-relative(+1)` ≈ child (descendant at distance 1),
   `fetch-relative(-1)` / `move-relative(-1)` ≈ parent (ancestor at distance 1).
   Keep `Sector::child` / `Sector::parent` as sector names for navigation /
   `:sector` sugar if useful.

10. **Is `fetch-absolute` / `move-absolute` 0-based or 1-based?**  
    **Do what Raku does: 0-based.** When a Postgres adaptor is built later (not
    this plan), offset by 1 at that boundary for `FETCH ABSOLUTE` /
    `MOVE ABSOLUTE`.

11. **For `fetch-relative` / `move-relative` with `:sector(...)`, may `$n` be
    negative?**  
    **Require `$n >= 0`.** `$n == 0` means **self** (stay on / reaffirm current;
    same idea as `Sector::self`). Positive `$n` steps along that sector. To go
    the other way, pass the opposite sector (or use `:axis` with a negative
    relative on the Axis line).

12. **What does `:sector` mean on `*-absolute` / `*-first` / `*-last`?**  
    * **`fetch/move-absolute($n, :$sector)`** — treat as
      **`fetch/move-relative($n, :$sector)`** (same rules: `$n >= 0`, `0` = self).
    * **`fetch/move-first(:$sector)`** — the **next** item on that sector
      (`*-relative(1, :$sector)`), i.e. first step along the sector from current
      (not “global first of the whole document” unless that coincides).
    * **`fetch/move-last(:$sector)`** — the **last** item reachable on that
      sector from the current position (end of that half-line).

13. **Why both `fetch-*` and `move-*`?**  
    **Mirror PostgreSQL `FETCH` vs `MOVE`.** Same direction algebra; `fetch-*`
    returns the item at the new position (`Mu` / `IterationEnd`); `move-*`
    only repositions and returns an **`Int` count**. No unprefixed `next` /
    `relative` / etc. — the prefix always says which.

14. **How do count-taking `fetch-*` express Postgres `ALL`?**  
    **Multi-methods: `Int` and `Range`.**  
    `fetch-absolute` / `fetch-relative` / `fetch-forward` / `fetch-backward`
    each have an `Int` candidate (return `Mu` / `IterationEnd` at the final
    position) and a `Range` candidate (return a `Seq` over the span). Range
    endpoints may be `Int`, `Inf`, or `Whatever` (`*`); open / `*` / `Inf`
    means “until exhausted” — so `fetch-forward(1..*)` /
    `fetch-backward(1..*)` cover `FORWARD ALL` / `BACKWARD ALL`. Endpoint
    signs: **any `Int`** when using `:axis` (or default axis); **non-negative
    only** when using `:sector` (aligned with scalar `$n` rules). Ranges may
    **start at any allowed endpoint** (including `0..*`). **Both closed and open
    Ranges** are supported; Raku exclusivity markers (`^` on either end) are
    honored when interpreting the span.

15. **Do `move-*` take a `Range`?**  
    **No.** A Cursor position is a single place. `move-*` lands on one item
    (or before/after the sequence). A Range is a *span of results* — that is
    a **fetch** concern (`Seq`), not a destination. Postgres `MOVE FORWARD ALL`
    only means “advance to after the last row,” which we already express as
    `move-last` / `move-forward($n)` with a scalar count — not “move to a
    range.”

16. **How do `*-next` / `*-prior` / `*-forward` / `*-backward` reduce?**  
    On `:axis` / default axis (signed motion):  
    `*-next` ≡ `*-relative(+1)`; `*-prior` ≡ `*-relative(-1)`;  
    `*-forward($n)` ≡ `*-relative(+$n)`; `*-backward($n)` ≡ `*-relative(-$n)`;  
    `$n == 0` ≡ self. Positive = forward sector, negative = backward sector.
    (`:sector` still requires `$n >= 0`; use the opposite sector to go the other
    way.)

17. **What does `clone-position` return?**  
    **A new Cursor** with the same position-relevant attributes (and enough
    context to resume independently). Continue on the original; return to the
    clone later (backtracking). Do **not** share mutable position state between
    the two. (Not a soft bookmark into the same object; not a deep clone of the
    whole data model.)

18. **Empty / exhausted scroll steps?**  
    **`IterationEnd`** on `fetch-*` (already decided: no `exhausted` flag).
    That includes “past the end” on `*-absolute` / `*-first` / `*-last` when
    there is no such item — do not invent a separate exhaustion exception.

## Capabilities and errors

19. **Cursor exception types (bad args / unsupported)?**  
    New under `X::Qwiratry::Cursor` (reuse hierarchy style from
    `X::Qwiratry::Walker` / `Operator`):  
    * `X::Qwiratry::Cursor::ConflictingDirection` — both `:axis` and `:sector`  
    * `X::Qwiratry::Cursor::NegativeSectorStep` — `$n < 0` (or Range endpoint)
      with `:sector`  
    * `X::Qwiratry::Cursor::Unsupported` — Axis/Sector/scroll op not supported
      by this Cursor  
    * `X::Qwiratry::Cursor::InvalidRange` — Range endpoints not Int-ish /
      wrong signs for the mode  
    Closest *existing* types (`X::Qwiratry::Operator`, `UnknownQueryElement`)
    are query/walker-shaped; better not overload them for position API misuse.
    Exhaustion stays `IterationEnd`, not an `X::`.

20. **Shape of `cursor-capabilities` reporting?**  
    **Same pattern as Walker/Operator today:** `method cursor-capabilities(--> Associative)`
    returning a Hash. (I/O “capabilities” are also role composition via `~~`;
    Raku itself has no single stdlib “capabilities” protocol — roles + `~~` /
    optional methods returning structured data.)

21. **Which keys belong in `cursor-capabilities`?**  
    Advertise supported **`axes`** and **`sectors`**, plus whether **`absolute`**
    is available. **`first` / `last` are always supported** (no optional flag).  
    **Scroll vs sector:** an advertised **Axis is always scrollable** (both
    directions on that line: next/prior, forward/backward, and the usual signed
    relative). If a backend can only go one way, it does **not** advertise that
    Axis — it advertises the one-way **Sector** instead. Drop a separate
    `scrollable` boolean; Postgres `NO SCROLL` maps to “sectors only (forward),
    no preceding-following Axis.”

## Walk ownership, Strategy, molds

22. **Should Strategy hooks receive the Cursor explicitly?**  
    **Yes.** Add optional **`Cursor :$cursor`** at the **end** of each Strategy
    hook’s parameter list. Walkable walks pass it; Streamable-Pull walks omit
    it. Optional named arg is enough — no separate Cursor-free multi. Hooks may
    use `$cursor.current`, `fetch-relative` / `move-relative`, `clone-position`,
    etc.

23. **Who owns the walk when a Cursor exists?**  
    **Leave walk ownership where it is today.** Runtime/Evaluators (no Strategy)
    or Strategy iterator / Walker (with Strategy) still drive visitation and
    matching; they **use** a Cursor for position/movement instead of private
    stack fields. Cursor is not a second choreographer.

24. **Match filtering vs visitation?**  
    **Match-directed advance (B)** for producing matches efficiently: the
    plan/evaluator steers the Cursor toward candidates. Stratego-like Strategy
    hooks that must observe *intermediate* nodes (`before` / `should-follow`)
    are handled by the **existing Strategy walk owner** stepping the Cursor
    along the structure it already walks (Decision 23) — not by forcing every
    query into visit-then-filter. That split is enough; dual streams (C) stay
    deferred.

25. **Should molds/transformers bind `$_` from a Cursor’s `current`?**  
    **Stay with what we have for now.** Molds already get `$_` as the node the
    Walker/transformer passes in. Do not retarget topic binding to
    `$cursor.current` in this plan.

## Tree position and Navigators

26. **How does Tree Cursor movement work without snapshot or path?**  
    Hold **`$current` + `$origin`**. One-step and multi-step sector edges go
    through **walk-local Tree Navigators** (Decisions 27–28). No full node
    snapshot; no mandatory stored path.

27. **Should Navigators grow multi-step APIs?**  
    **Yes.** Move multi-step sector helpers onto Navigators (following /
    preceding / *n*th along a sector, descendant/ancestor walks as appropriate).
    Specialized Navigators may use cheap model-local ops; Base keeps
    recompute-from-origin as the generic fallback. Evaluators and Tree Cursors
    both call those Navigator APIs (migrate today’s Evaluator-only loops).

28. **Where do Tree navigation caches live?**  
    **On the Navigator, implementation-dependent** — but on a **walk-local**
    Navigator (or Navigator+session owned by the Cursor / walk owner), **not**
    on the shared registry instances from `tree-navigator-for` (those must stay
    reusable across walks). Caches may hold parent, sibling list/index, ancestor
    stack, etc., as each Navigator chooses.  

    **TreeRewrite:** Navigators must **respect** in-place mutation. When
    `Qwiratry::Tree::Replace.replace-node` succeeds, it (or a shared hook it
    calls) **invalidates** caches for that `$origin` / affected identities
    (`$old` replaced by `$new`, parent sibling lists, etc.). Specialized
    Navigators may invalidate narrowly; Base may drop all walk-local caches for
    that origin. Until Strategy-owned rewrite exists, this is the main mutation
    path caches must survive.

# Open Questions

None for the Tree first landing. Later (out of Migration scope here): Memory /
Postgres backends; mold/`$_` from Cursor; Walkable-as-cursor-factory metanoia.

# References

* Metanoia: [Walkable vs Streamable](https://wayland.github.io/table-oriented-programming/Metanoias/Walkable-vs-Streamable.xml)
* `docs/rakudoc/Extending/Adding-Walkers.rakudoc`
* `docs/rakudoc/Extending/Adding-Tree-Navigators.rakudoc` (if present)
* Raku TOP Postgres cursor: `Cursor::Storage::Postgres` in Raku-TOP
* Streaming I/O walkable/pull rename: [Streaming-Qwiratry-Proposal.md](Streaming-Qwiratry-Proposal.md)
