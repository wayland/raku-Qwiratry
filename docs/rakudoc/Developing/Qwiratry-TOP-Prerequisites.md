# Qwiratry TOP Prerequisites

Specification for **Qwiratry core** changes required before rebuilding TOP on
Qwiratry. This document is **not** the TOP product surface.

Parent plan: [Qwiratry-TOP-Plan.md](Qwiratry-TOP-Plan.md).  
TOP layer (Relation, Memory, Postgres, Tables, anonymous Table front-end):
[Qwiratry-TOP-Basics.md](Qwiratry-TOP-Basics.md).

**Status:** Prerequisites substantially complete (post-**0.0.9** / toward
**0.10.0**). Landed: text-chunk walkable/pull; sector vocabulary; WalkCursor /
QueryCursor tree; Topic slang; `TypedIterator` (File `.of = Str`); text-adaptor
checks; **`QueryIterator does TypedIterator`**. Remaining doc polish may trail
in Extending; row sinks / table Locations → [Basics](Qwiratry-TOP-Basics.md).  
**Scope (prerequisites only):** Streaming-shaped Location I/O; `TypedIterator`
as the common element-kind face (I/O pull **and** query match streams);
WalkCursor tree contract; no `Qwiratry::Storage::*`.

---

## 1. Goals

1. **Streaming-shaped Location I/O** (walkable + optional pull/sink) so adaptors
   can carry Iterators without always materialising a giant `Str`.
2. **`TypedIterator`** so pull streams advertise element kind (Location chunks
   today; query matches via `QueryIterator`; later rows in Basics) without
   parallel `read-rows` APIs.
3. **WalkCursor** tree contract as the movement API TOP/SQL cursors will reuse.
   (`WalkCursor` itself does not return an Iterator; `QueryCursor.iterator` is
   the optional match-stream bridge.)
4. **No parallel Storage hierarchy** — when TOP lands, table backends extend
   Location (see Basics); Qwiratry core must not ship a competing Storage tree.
5. **Adaptor operators** that do not assume every pull stream is text (no blind
   `.Str` coerce).
6. **`SourceOperator` stays walkable-shaped** — it does not return an Iterator;
   Location pull is composed by Parse (or, later, by Basics when a table Source
   is used in a pipeline that needs rows). Dirs/globs keep current return shapes.

## 2. Non-goals (TOP work — see Basics)

These are **out of scope** for prerequisites. Spec and acceptance live in
[Qwiratry-TOP-Basics.md](Qwiratry-TOP-Basics.md):

- **Relation** / `use-table` / live Table handles
- **Memory** Location (and anonymous default storage)
- **Postgres** (and other SQL) Location
- **Tables** / Database / Field / Tuple front-end, FieldMode plugins as TOP API
- CSV Location, HalfHuman, WithBorders (plan sequencing)
- Multi-dialect / Red-style SQL encoding (plan §12)
- Graduating `CSVdemo` into a production Format
- Full Format push (`Supply`) edges — **not needed** for TOP Basics; destination
  text sinks suffice for blob streaming today (see Streaming proposal v2 later)
- Interim row `.of` type and Destination **row sinks** — Basics (table Locations
  not in prerequisites)
- Making bare `SourceOperator` return a pull `Iterator` — **rejected** for now;
  walkable evaluate is intentional

## 3. Current baseline (after 0.0.9 → Unreleased / 0.10.0)

| Piece | Behaviour |
| ----- | --------- |
| `Qwiratry::Location::Base::SourceWalkable` | `read-walkable(Str $location --> Mu)` — whole payload |
| `Qwiratry::Location::Base::DestinationWalkable` | `write-walkable(Str $location, Mu $content --> Mu)` |
| `Qwiratry::Location::Base::SourcePull` | Optional `read-pull(--> Iterator)`; prefer `TypedIterator` |
| `Qwiratry::Location::Base::DestinationPush` | Optional `open-sink-push` → sink with `write-chunk` / `close` |
| `Qwiratry::Format::Base::ParseWalkable` / `RenderWalkable` | `parse-walkable` / `render-walkable` |
| `Qwiratry::Format::Base::ParsePull` / `RenderPull` | Optional `parse-pull` / `render-pull` |
| `SourceOperator` | Always whole-value `read-walkable` (dirs/globs/return shapes). Does **not** return an Iterator. Pull composition is chosen by `ParseOperator` when both source and parser support pull. |
| `DestinationOperator` | Prefer `open-sink-push` when upstream is a text-chunk `Iterator`; else join and `write-walkable`. Rejects non-text `.of` / non-`Str` untyped elements. |
| `ParseOperator` / `RenderOperator` | Prefer pull when format (and source, for parse) advertise it; else walkable fallback. Same text-kind checks as Destination. |
| File | Walkable + `SourcePull` + `DestinationPush`; `read-pull` → `TypedIterator` with `.of = Str` |
| HTTP | Walkable only (sibling package) |
| NDJSONdemo | Walkable + `ParsePull` / `RenderPull` |
| `Qwiratry::Location` factory | Discovers `::Source` / `::Destination`; validates against Walkable bases |
| `Qwiratry::Table::Catalog` / `Schema` | Existing FK-aware navigation over named collections / row lists (not TOP Table front-end) |
| Navigation vocabulary | Former “axis” naming → **sector** |
| `WalkCursor` / `Sector` / `Axis` | Generic position/`fetch-*`/`move-*` (`lib/WalkCursor.rakumod`) — **not** an Iterator factory |
| `Qwiratry::QueryCursor` | Tree specialization; `Plan.cursor`; optional Strategy `:cursor`; `.iterator` → `QueryIterator` (match bridge) |
| `Qwiratry::QueryIterator` | Query match pull stream (+ Context); **does** `TypedIterator` (default `.of = Mu`) |
| Tree Navigator | Multi-step sector helpers; walk-local caches |
| `Qwiratry::Query::Slang` + `::Ops` + `::Topic` | Topic slang after Slang for `given` / bare nav / universe ops |
| `TypedIterator` | Top-level role + `TypedIterator::Wrapper`; `.of` default `Mu` |

**Still missing for TOP to plug in cleanly:** Basics Locations (Memory, …) that
yield row `TypedIterator`s, plus Destination row sinks / Parse skip for
structured `.of` — specified in Basics, not here.

---

## 4. Pipeline face (prerequisite concern)

`SourceOperator` and `DestinationOperator` remain the adaptor pipeline operators:

- **Source** = pull data from a location **into** the pipeline.
- **Destination** = push pipeline data **out** to a location.

| Location capability | Source yields (via Location APIs) | Destination accepts |
| ------------------- | --------------------------------- | ------------------- |
| Blob (File, HTTP, …) | `read-walkable`, or `read-pull` → `TypedIterator` with `.of = Str` (used when Parse composes pull) | `write-walkable`, or text-chunk sink |
| Structured / table-capable (TOP Locations) | Same `read-pull` surface with row `.of` — **Basics** | Row sink when elements are rows — **Basics** |

**`SourceOperator.evaluate` always uses `read-walkable`.** It does not return an
Iterator. That keeps directory/glob shapes stable. Pull is an optional Location
capability consumed by `ParseOperator` today (and by Basics pipelines that call
`read-pull` / structured adaptors later).

Parse/Render stay on Format when the pipeline deals with encoded text. When a
pipeline already has structured values, Parse may be skipped (**Basics**).

The **object face** (Relation / `Table.new`) is TOP Basics, not a prerequisite
module. Both faces SHOULD eventually share row I/O on the same backend — that
sharing rule is specified in Basics.

Adaptor operators MUST NOT assume every Location is `Str`-only.

---

## 5. Prerequisite A0 — Streaming-shaped Location I/O

### 5.1 Why first

TOP table Sources are only honest if the Location and operator stack can carry
**Iterators** (chunks or later rows) without forcing full materialisation. Text
walkable/pull **has landed**. `QueryIterator does TypedIterator` and Extending
`.of` docs are landed. Row sinks / table Locations are Basics.

Align names with [Streaming-Qwiratry-Proposal.md](Streaming-Qwiratry-Proposal.md).

### 5.2 Landed contracts (text / blob)

```raku
class Qwiratry::Location::Base::SourceWalkable {
    method read-walkable(Str $location --> Mu) { ... }
}
class Qwiratry::Location::Base::DestinationWalkable {
    method write-walkable(Str $location, Mu $content --> Mu) { ... }
}
role Qwiratry::Location::Base::SourcePull {
    method read-pull(Str:D $location --> Iterator:D) { ... }
}
role Qwiratry::Location::Base::DestinationPush {
    method open-sink-push(Str:D $location --> Mu) { ... }  # write-chunk / close
}

class Qwiratry::Format::Base::ParseWalkable {
    method parse-walkable(Str $input-string --> Mu) { ... }
}
class Qwiratry::Format::Base::RenderWalkable {
    method render-walkable(Mu $data, Associative :%options --> Str) { ... }
}
role Qwiratry::Format::Base::ParsePull {
    method parse-pull(Iterator:D $chunks, *%options --> Mu) { ... }
}
role Qwiratry::Format::Base::RenderPull {
    method render-pull(Mu $data, Associative :%options --> Iterator:D) { ... }
}
```

Operators choose pull when both sides advertise it; otherwise walkable fallback.
Full `Supply` push roles are deferred.

### 5.3 TypedIterator (element kind on pull streams)

**Decision:** one Location pull/sink surface (`SourcePull` / `DestinationPush`),
not parallel `read-rows` APIs. Advertise element kind with **`TypedIterator`**.

Same role is the element-kind face for **query match** streams:

```raku
# lib/TypedIterator.rakumod
role TypedIterator does Iterator {
    method of(--> Mu:U) { Mu }   # default = untyped / per-element
}
# TypedIterator::Wrapper — wrap a foreign Iterator with an explicit :of

role QueryIterator does TypedIterator { ... }  # match streams + Context
# QueryCursor.iterator / Plan.iterator → QueryIterator ⇒ also TypedIterator
# Default .of = Mu (heterogeneous matches); walkers may override later
```

`.of` means “element kind of this pull stream,” whether the producer is Location
I/O (chunks/rows) or a query match bridge — not I/O-only.

| `.of` | Behaviour |
| ----- | --------- |
| `Str` | Text-chunk path: Parse may consume; Destination may `write-chunk` (**landed**) |
| Row / `Associative` / Tuple | Structured path: skip text Parse; Destination row sink — **Basics** (no interim row type until table Locations) |
| `Mu` or plain `Iterator` | Per-element; text adaptors require `Str` or error (no blind `.Str`) (**landed** for text) |

**Landed:** File `.of = Str`; text adaptors raise `X::Qwiratry::IO::ElementType`;
`QueryIterator does TypedIterator`.  
**Basics:** row `.of`, row sinks, Parse skip for structured streams.

Do **not** invent a second Storage tree; do **not** require a Format round-trip
as the only way to get rows out of a future table Location.

### 5.4 Operator requirements (settled for prerequisites)

- `SourceOperator` **does not** return an Iterator (walkable evaluate only).
- Location `read-pull` SHOULD return a `TypedIterator` whose `.of` matches the
  payload (File: `Str`).
- Text Parse/Destination MUST NOT treat every `Iterator` as text chunks (landed).
- Blob Destination + non-text `.of` → clear error (landed via ElementType);
  structured sinks are Basics.
- They SHOULD NOT force a lazy Seq into a full `List` unless required downstream.

### 5.5 Acceptance criteria

**Text-chunk / walkable-pull (done):**

- [x] Walkable + optional pull/sink roles on Format and Location bases.
- [x] File implements `read-pull` and `open-sink-push`.
- [x] Parse / Render / Destination compose pull without forcing full materialisation where both sides support it.
- [x] NDJSONdemo reference format with walkable + pull.
- [x] Documented rename map / Extending docs for walkable method names.
- [x] Unit coverage in `t/unit/streaming-io.rakutest`.

**TypedIterator readiness:**

- [x] `TypedIterator` with `.of(--> Mu:U)` (default `Mu`); plain `Iterator` = untyped.
- [x] File pull returns `TypedIterator` with `.of = Str`.
- [x] Destination / Parse text path: non-text `.of` → error; `.of = Mu` → per-element `Str` or error.
- [x] `SourceOperator` remains walkable-only (does not return Iterator) — settled.
- [x] `QueryIterator does TypedIterator` (default `.of = Mu`); `QueryCursor.iterator` / `Plan.iterator` are then TypedIterators.
- [x] Extending docs describe `.of` for Location pull and for query match streams.
- [x] Pull vs walkable discovery: `~~ SourcePull` / `~~ DestinationPush` (document in Extending); element kind lives on the Iterator via `.of`.

Row sink / Parse skip when `.of` is structured → [Basics](Qwiratry-TOP-Basics.md).

### 5.6 Soft foundation — WalkCursor / QueryCursor (tree done)

Normative design: [Cursor-Proposal.md](Cursor-Proposal.md). Tree first landing
shipped. Memory/Postgres/Relation cursor backends are **TOP Basics**.

**Done (Tree proof):**

- [x] Generic `WalkCursor` + `Sector` / `Axis` in `lib/WalkCursor.rakumod`.
- [x] `Qwiratry::QueryCursor`; `Plan.cursor`; walk-local Navigator.
- [x] Strategy optional `WalkCursor :$cursor`; Navigation Evaluator delegation.
- [x] `QueryCursor.iterator` match bridge → `QueryIterator` (not a visit-every-node stream).
- [x] Extending docs; `t/unit/query-cursor.rakutest`.
- [x] Sector vocabulary; Cursor **Axis** = bidirectional sector pair.
- [x] Postgres-style `fetch-*` / `move-*` documented for later TOP backends.

**Settled:** `WalkCursor` has no Iterator factory. Optional pull from a cursor is
`QueryCursor.iterator` only. That bridge returns a `QueryIterator`, which
**does** `TypedIterator` (default `.of = Mu`; still typed as `QueryIterator` in
signatures).

Do not force Location Source Iterators through `QueryCursor`.

---

## 6. Implementation order (prerequisites)

1. ~~Text-chunk streaming~~ — landed (§5.2 / §5.5).
2. ~~WalkCursor tree landing~~ — landed (§5.6).
3. ~~Sector vocabulary + Topic slang~~ — landed.
4. ~~`TypedIterator` + File `.of = Str` + text-adaptor checks~~ — landed (§5.3).
5. ~~`SourceOperator` stays walkable-only~~ — settled (§5.4).
6. ~~`QueryIterator does TypedIterator` + Extending docs~~ — landed (§5.3 / §5.5).
7. **Then** [Qwiratry-TOP-Basics.md](Qwiratry-TOP-Basics.md): Relation, Memory,
   Tables, Postgres, row sinks, row `.of`, …

## 7. Open points (prerequisite)

- Whether specific Tree/Table `QueryIterator`s should override `.of` soon, or leave `Mu` until Basics (default **leave `Mu`**).

Moved to Basics / deferred: interim row `.of` type; Destination row sink + Parse
skip; full `Supply` push; bare Source returning Iterator.

---

## 8. References

- [Qwiratry-TOP-Plan.md](Qwiratry-TOP-Plan.md)
- [Qwiratry-TOP-Basics.md](Qwiratry-TOP-Basics.md) — Relation, Memory, Postgres, Tables
- [Cursor-Proposal.md](Cursor-Proposal.md)
- [Universe-Topic-Slang-Plan.md](Universe-Topic-Slang-Plan.md)
- [Streaming-Qwiratry-Proposal.md](Streaming-Qwiratry-Proposal.md) / [.rakudoc](Streaming-Qwiratry-Proposal.rakudoc)
- [Streaming-Qwiratry-Proposal-v2.md](Streaming-Qwiratry-Proposal-v2.md)
- [Adding-Sources-Destinations](../Extending/Adding-Sources-Destinations.rakudoc)
- `lib/Qwiratry/Location.rakumod`, `Location/Base.rakumod`, `Operator/IO.rakumod`
- `lib/TypedIterator.rakumod`, `lib/WalkCursor.rakumod`, `lib/Qwiratry/QueryCursor.rakumod`
- `t/unit/streaming-io.rakutest`, `t/unit/typed-iterator.rakutest`, `t/unit/query-cursor.rakutest`
- Raku TOP reference tree: `~/src/TOP/Raku-TOP/main` (read-only)
