# Qwiratry TOP Prerequisites

Specification for Qwiratry core changes required before rebuilding TOP on Qwiratry.

Parent plan: [Qwiratry-TOP-Plan.md](Qwiratry-TOP-Plan.md) (§4.1–4.2). This document is normative for the prerequisites; the plan remains the broader design note.

**Status:** Partially implemented (post-**0.0.9** / toward **0.10.0**). Landed: text-chunk walkable/pull Location and Format I/O; navigation **sector** vocabulary; **WalkCursor** / **QueryCursor** tree first landing; Topic slang for `given`/bare nav and universe ops; **`TypedIterator`** with File `.of = Str` and text-adaptor checks. Still open: **row** Source/Destination (`.of` + sinks), Relation, anonymous Tables, and Memory/Postgres `WalkCursor` backends.  
**Scope:** Streaming-shaped Location I/O so Source/Destination work on tables; Relation for the TOP object face; anonymous, swappable Tables; cursor contract shared with future relation/SQL backends.

Terminology for I/O boundaries (see [Streaming-Qwiratry-Proposal.md](Streaming-Qwiratry-Proposal.md)):

| Style | Meaning | Landed for text blobs? |
| ----- | ------- | ---------------------- |
| **Walkable** | Whole-value transfer (`read-walkable` / `write-walkable` / `parse-walkable` / `render-walkable`) | Yes |
| **Pull** | Consumer-driven `Iterator` of `Str` chunks (`read-pull` / `parse-pull` / `render-pull`) | Yes (File + NDJSONdemo; operators compose when both sides pull) |
| **Push** | Producer-driven `Supply` edges | Not yet (destination **sinks** via `DestinationPush.open-sink-push` already accept pushed chunks) |

Factory `:type` labels remain `Parse` / `Render` / `Source` / `Destination`. Concrete classes stay `::Parse` etc.; they inherit the Walkable bases and may `does` Pull/sink roles.

---

## 1. Goals

1. **One Location plugin story** for “where data lives,” covering blob endpoints (File, HTTP) and table endpoints (Memory, CSV Location, Postgres, later `.ods`, SQLite, …). No parallel Storage hierarchy.
2. **Source and Destination work on tables**, not only blobs. Pipeline I/O must pull/push **rows** from/to relation-capable locations, without dumping a table to a giant `Str`.
3. **Streaming-shaped Location I/O** so table Source/Destination have an honest representation. Text-chunk walkable/pull is in place; **row** pull/sink contracts and operator paths are the remaining Location blocker. Align with [Streaming-Qwiratry-Proposal.md](Streaming-Qwiratry-Proposal.md) / [.rakudoc](Streaming-Qwiratry-Proposal.rakudoc).
4. **Relation / `use-table`** as the TOP **object** face on the same backends: live `Table` with actions, fields, FieldMode, mutation — sharing row read/write paths with Source/Destination, not forking them.
5. **Capability-typed backends** so blob-only Locations do not pretend to be tables (and vice versa where needed), with clear failures on location swap.
6. **Anonymous Tables** that live in ordinary variables (default Memory), then grow heavier by changing primarily the location declaration.

## 2. Non-goals

- Implementing full CSV Location, Postgres Location, HalfHuman, or WithBorders (later plan work) — but contracts must allow them.
- Multi-dialect / Red-style SQL encoding (plan §12).
- Graduating `CSVdemo` into a production Format (CSV tables are a Location package).
- Replacing the TOP object/method API with pipelines only (pipelines remain complementary; plan §10.2).
- Requiring complete Format push (`Supply`) edges before Relation — **Location structured pull (`TypedIterator`) and honest Source/Destination row paths are the blockers**; Format pull for text already exists and can trail further formats.
- Implementing full push (`ParsePush` / `SourcePush` / …) before TOP — deferred; destination text sinks are enough for blob streaming today.

## 3. Current baseline (after 0.0.9 → Unreleased / 0.10.0)

| Piece | Behaviour |
| ----- | --------- |
| `Qwiratry::Location::Base::SourceWalkable` | `read-walkable(Str $location --> Mu)` — whole payload |
| `Qwiratry::Location::Base::DestinationWalkable` | `write-walkable(Str $location, Mu $content --> Mu)` |
| `Qwiratry::Location::Base::SourcePull` | Optional `read-pull(--> Iterator)` of `Str` chunks |
| `Qwiratry::Location::Base::DestinationPush` | Optional `open-sink-push` → sink with `write-chunk` / `close` |
| `Qwiratry::Format::Base::ParseWalkable` / `RenderWalkable` | `parse-walkable` / `render-walkable` |
| `Qwiratry::Format::Base::ParsePull` / `RenderPull` | Optional `parse-pull` / `render-pull` |
| `SourceOperator` | Always whole-value `read-walkable` (dirs/globs/return shapes). Pull composition with a parser is chosen by `ParseOperator`. |
| `DestinationOperator` | Prefer `open-sink-push` when upstream is a text-chunk `Iterator`; else join and `write-walkable`. |
| `ParseOperator` / `RenderOperator` | Prefer pull when format (and source, for parse) advertise it; else walkable fallback. |
| File | Walkable + `SourcePull` + `DestinationPush` |
| HTTP | Walkable only (sibling package) |
| NDJSONdemo | Walkable + `ParsePull` / `RenderPull` |
| `Qwiratry::Location` factory | Discovers `::Source` / `::Destination`; validates against Walkable bases |
| `Qwiratry::Table::Catalog` / `Schema` | FK-aware navigation over named collections / row lists |
| Navigation vocabulary | Former “axis” naming → **sector** in query/nav docs and APIs |
| `WalkCursor` / `Sector` / `Axis` (`lib/WalkCursor.rakumod`) | Generic position/`fetch-*`/`move-*` contract (bare `Cursor` blocked by `CORE::Cursor` = `Match`) |
| `Qwiratry::QueryCursor` | Tree specialization; `Plan.cursor`; optional Strategy `WalkCursor :$cursor`; `.iterator` bridges to match stream |
| Tree Navigator | Multi-step sector helpers; walk-local caches (invalidated on TreeRewrite via `$*QWIRATRY-WALK-NAVIGATOR`) |
| `Qwiratry::Query::Slang` + `::Ops` + `::Topic` | Operators in Ops; Topic slang (load **after** Slang) injects lexical `$_` for universe ops and bare navigation under `given` |

**Still missing for TOP:** there is no way for Source to mean “rows from this table location” without either lying (`Str` dump) or adding **structured pull** (`TypedIterator` + operator branching, §5.3). That extension remains this prerequisite’s open work. Memory/Postgres **row** `WalkCursor` backends are likewise still open (the *contract* and tree proof are done — see §5.6).

TOP’s `Database::Storage` / `Table::Storage` responsibilities still move into **upgraded Location** (pipeline + object faces) plus a thin TOP Table front-end — not into a new Storage namespace.

---

## 4. Two faces of the same Location

### 4.1 Pipeline face — Source / Destination

`SourceOperator` and `DestinationOperator` remain the adaptor pipeline operators:

- **Source** = pull data from a location **into** the pipeline.
- **Destination** = push pipeline data **out** to a location.

Payload shape depends on Location capability (not on inventing parallel operators):

| Location capability | Source yields | Destination accepts |
| ------------------- | ------------- | ------------------- |
| Blob (File, HTTP, …) | Complete payload via `read-walkable`, or `TypedIterator` pull with `.of` = `Str` (composed with pull Parse today) | Complete payload via `write-walkable`, or text-chunk sink via `open-sink-push` |
| Table / relation (Memory, CSV Location, Postgres, …) | Same pull surface; `TypedIterator` with `.of` = row type (or `.of` = `Mu` + per-element typing) — **not yet** | Same sink surface; row write when elements are rows — **not yet** |

**Source on a table location must not mean “serialize the whole table as one string.”** It means start a pull of rows into the pipeline.

**Destination on a table location** means write pipeline data as rows (insert, replace, or append — backend documents which; capability-advertised).

Parse/Render stay on the Format side when the pipeline still deals with encoded text (classic `Source → Parse → … → Render → Destination`). When Source already yields rows, Parse may be skipped.

### 4.2 Object face — Relation / `use-table`

`Qwiratry::Location::Base::Relation` (name negotiable) binds a **live Table** for the TOP object/method API:

- table actions (`create` / `alter` / `use` / `can-create` / `ensure`)
- fields, FieldMode, `makeTuple`-level shaping
- long-lived handle for `$table.add-row`, field access, Walker origin, etc.

Relation is **not** a replacement for Source/Destination and **not** “the only way to talk to tables.” It is the object-handle face. The same backend module SHOULD back both faces and **share** the underlying row iterator / write path.

```text
Source ↗  →  (query / transform)  →  Destination ↘   # pipeline; works for files AND tables
$table = Table.new(:location<…>)                     # object face; same Location backend
```

### 4.3 What “Source with a table” means (normative)

Under this plan:

| Situation | Required behaviour |
| --------- | ------------------ |
| Source + blob location | Blob read (`read-walkable` or chunk `Iterator` via pull composition). |
| Source + table-capable location | Yield row Iterator/Seq (streamable preferred; materialise only if necessary). |
| Source + location with neither usable blob nor table Source | Clear capability / not-found error. |
| Destination + table-capable location | Consume rows (or data coercible to rows) into the table location. |
| `Table.new` / `use-table` | Relation face; does not go through SourceOperator, but shares row I/O with Source where applicable. |

Adaptor operators MUST NOT assume every Location is `Str`-only.

---

## 5. Prerequisite A0 — Streaming-shaped Location I/O

### 5.1 Why first

Source/Destination on tables are only honest if the Location and operator stack can carry **Iterators** (rows or chunks) without forcing full materialisation. Implementing Relation alone while Source remains walkable-`Str`-only for tables paints the wrong corner: every “Source a table” becomes a dump.

Text-chunk walkable/pull (Location + Format + adaptor composition) **has landed**. This section now tracks:

1. What is already done for blobs (acceptance closed).
2. What remains for **row** streams (still blocking TOP).

Align names with the walkable / pull / push rename in [Streaming-Qwiratry-Proposal.md](Streaming-Qwiratry-Proposal.md).

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

Operators choose pull when both sides of a boundary advertise it; otherwise they fall back to walkable (joining or materialising as needed). Full `Supply` push roles are deferred.

### 5.3 Required contracts still open (structured pull for TOP)

**Decision:** one pull/sink surface (reuse `SourcePull` / `DestinationPush`, or the same method names), not parallel `read-rows` / `open-row-sink` APIs. Distinguish stream element kind with a **`TypedIterator`**.

Core `Iterator` has no element-type API. Qwiratry adds:

```raku
# lib/TypedIterator.rakumod (top-level, like WalkCursor)
role TypedIterator does Iterator {
    # Homogeneous element type for this stream. Default Mu = unspecified /
    # heterogeneous: operators MUST inspect each pulled value and handle it
    # case-by-case (see below). Prefer a real type/role (Str, Associative,
    # future Row/Tuple, …), not a string label.
    method of(--> Mu:U) { Mu }
}
```

| `.of` | Operator behaviour |
| ----- | ------------------ |
| `Str` (or similar text chunk type) | Text-chunk path: Parse may consume; Destination may `write-chunk` |
| Row / `Associative` / Tuple (as defined when Table lands) | Structured path: do **not** Parse as text; Destination uses row/insert sink when the Location supports it |
| `Mu` (default) or plain `Iterator` without `TypedIterator` | **Per-element:** treat as untyped (same as `.of = Mu`); examine each pulled value’s type and dispatch case-by-case (chunk vs row vs error). Do not assume “everything is `Str`” and coerce with `.Str` |

**This pass (landed):** `TypedIterator` + File `.of = Str`; text adaptors error on non-text `.of` and on non-`Str` elements when untyped. Row `.of` / Memory Location deferred with TOP Table work.


Do **not** invent a second Storage tree; do **not** require a Format round-trip to get rows out of a table Location.

### 5.4 Operator requirements (remaining)

- `SourceOperator` / `DestinationOperator` MUST be able to pull/sink **structured** values (typically rows) when the Location is table-capable, via the same pull/sink methods as text, distinguished by `TypedIterator.of` (or per-element typing when `.of` is `Mu`).
- They MUST NOT normalise a structured/row stream into a single `Str`.
- They MUST NOT treat every `Iterator` as text chunks (today’s Destination `.Str` coerce is the anti-pattern to retire once `TypedIterator` lands).
- They SHOULD NOT force a lazy row Seq into a full `List` unless a downstream step requires it (same rule already applied for `RenderPull` vs walkable render).
- Capability detection: if the caller/pipeline needs rows and the backend only has blob Source, fail clearly (or require an explicit Format round-trip) — do not silently dump tables to text.
- Bare `SourceOperator` may keep returning walkable shapes for blob/dir/glob cases; when pull is used, prefer a `TypedIterator` whose `.of` matches the Location’s payload (text vs rows).

### 5.5 Acceptance criteria

**Text-chunk / walkable-pull (done in 0.10.0):**

- [x] Walkable + optional pull/sink roles on Format and Location bases.
- [x] File implements `read-pull` and `open-sink-push`.
- [x] `ParseOperator` / `RenderOperator` / `DestinationOperator` compose pull without forcing full materialisation where both sides support it.
- [x] NDJSONdemo reference format with walkable + pull.
- [x] Documented rename map and Extending docs updated for walkable method names.
- [x] Unit coverage in `t/unit/streaming-io.rakutest`.

**Structured pull / `TypedIterator` (partial — text path landed; rows defer to TOP):**

- [x] `TypedIterator` role with `.of(--> Mu:U)` (default `Mu`); plain `Iterator` treated as `.of = Mu`.
- [x] File (and other blob) pull returns `TypedIterator` with `.of` = `Str` (or equivalent).
- [x] `DestinationOperator` / `ParseOperator` text path: non-text `.of` → error; `.of = Mu` → per-element `Str` or error (no blind `.Str`).
- [ ] A Memory (or test double) Location can Source rows via the **same** pull surface with `.of` = row type, without building a giant `Str`.
- [ ] `SourceOperator` against that Location returns a lazy row sequence into the pipeline.
- [ ] `DestinationOperator` row sink when `.of` / elements are rows (TOP).
- [ ] Extending docs describe element kind via `.of`; terminology aligned with walkable/pull.
- [ ] Location capability query can still distinguish “pull available” vs walkable-only; element kind lives primarily on the Iterator.

### 5.6 Soft foundation — WalkCursor / QueryCursor (done)

Normative design: [Cursor-Proposal.md](Cursor-Proposal.md). Tree first landing shipped after 0.0.9; this is **not** a substitute for structured pull / `TypedIterator` (§5.3) or Relation (§6), but it is the movement contract Relation / Memory / Postgres cursors should implement later (plan §7 “Optional Cursor”, §8 Postgres).

**Done (Tree proof):**

- [x] Generic `WalkCursor` role + `Sector` / `Axis` in `lib/WalkCursor.rakumod` (`fetch-*` / `move-*`; capabilities `axes` / `sectors` / `absolute`).
- [x] `Qwiratry::QueryCursor`; `Plan.cursor` mints an independent Context + walk-local Navigator.
- [x] Tree Navigators: multi-step sector helpers; shared registry cache-free; walk-local cache invalidation on TreeRewrite.
- [x] Strategy hooks accept optional `WalkCursor :$cursor`; Navigation Evaluator delegates ancestor / descendant / sibling helpers to Navigator APIs.
- [x] `QueryCursor.iterator` bridges to the same match stream as `Plan.iterator` for Tree baselines.
- [x] Postgres-style `fetch-*` / `move-*` on `Axis.preceding-following` documented for later TOP/Memory/Postgres backends (not required to ship in the tree pass).
- [x] Extending docs (Walkers, Navigators, Strategies) and unit coverage (`t/unit/query-cursor.rakutest`).
- [x] Sector vocabulary rename completed (Cursor **Axis** = bidirectional sector pair — distinct from old nav “axis” naming).

**Still open (Relation / TOP backends — do not block the tree contract):**

- [ ] Memory / loaded-table `WalkCursor` on `Axis.preceding-following` (ordered row sequence).
- [ ] Postgres (or SQL) Location cursor mapping `FETCH` / `MOVE` onto `fetch-*` / `move-*`.
- [ ] Metanoia Walkable-as-cursor-factory (deferred in Cursor proposal).

Pull-only structured Source (§5.3 `TypedIterator`) does **not** require a Cursor; Walkable query walkabout (including a fully loaded relation) does. Do not force Source Iterators through `QueryCursor`.

---

## 6. Prerequisite A — Relation / upgrade Location (plan §4.1)

### 6.1 Design rule

**Do not add `Qwiratry::Storage::*`.** Extend Location so a backend may implement any subset of:

- **Source** / **Destination** (blob walkable/pull and/or structured pull via `TypedIterator`, per §5)
- **Relation** for live Table handles

Format remains “how is it encoded?” for HalfHuman, WithBorders, demo CSVdemo, etc. CSV *tables* are `Qwiratry::Location::CSV` (sibling package).

### 6.2 Discovery and naming

- Keep `Qwiratry::Location` as the sole Location discovery/dispatch factory.
- URI scheme → backend mapping unchanged in spirit (`file://`, `postgres://`, later CSV / `memory://` or in-process constructor).
- Backend module `Qwiratry::Location::<Name>` may provide `::Source`, `::Destination`, `::Relation` (and pull/row roles as capabilities on those classes or siblings).
- Factory asks for an operation type; missing capability → clear error.
- Walkable base-class mapping for `Source` / `Destination` stays as today (`SourceWalkable` / `DestinationWalkable`); Relation is an additional discoverable type or capability.

### 6.3 Relation capability contract

```raku
role Qwiratry::Location::Base::Relation {
    method use-table(
        :$table,
        Str :$action = 'use',       # create | alter | use | can-create | ensure
        :%fields,
        Str :$field-mode = 'Automatic',
        Str :$overflow-field-name,
        *%params
        --> Mu                      # table handle
    ) { ... }

    method relation-capabilities(--> Associative) { ... }
}
```

Table handle MUST provide at minimum:

| Concern | Requirement |
| ------- | ----------- |
| Fields | Ordered field metadata; add-field / lookup by name |
| FieldMode | Honour `:field-mode` / `:overflow-field-name` when making tuples |
| Rows | Prefer Iterator scans; Positional MAY materialise or use `WalkCursor` / keys (§5.6) |
| Shared I/O | Row scan/write SHOULD reuse the same pull/sink paths as Source/Destination for that backend (`TypedIterator`, §5.3) |
| Mutation | Optional; if advertised, consistent add/update/delete |
| Actions | TOP table actions with existence/conformance checks |
| Walk position | When Walkable query walkabout is supported, expose a `WalkCursor` specialization (Memory/Postgres backends still open; Tree `QueryCursor` is the reference) |

### 6.4 Capability advertising

Suggested keys (illustrative):

| Capability | Meaning |
| ---------- | ------- |
| `blob-source` / `blob-destination` | Walkable and/or pull text I/O |
| `row-source` / `row-destination` | Can participate in structured (row) pull/sink; element kind also on `TypedIterator.of` (§5.3) |
| `relation` | `use-table` / live Table handle |
| `field-mode-automatic` / `error` / `overflow` | Supported FieldModes |
| `positional-rows` | Random Positional access |
| `streaming-rows` | Iterator scan without full materialise |
| `walk-cursor` | Advertises a `WalkCursor`-capable ordered walk (Tree done; Memory/SQL open) |
| `mutable` | Live write-through |
| `table-actions` | Which of create/alter/ensure/… are supported |

Location swap (Memory → Postgres, etc.) MUST fail explicitly if a required capability is missing — no silent FieldMode degradation.

### 6.5 Built-in expectations (first slices)

| Backend | Blob Source/Dest | Row Source/Dest | Relation | Notes |
| ------- | ---------------- | --------------- | -------- | ----- |
| File | Yes (walkable + pull/sink) | No | No | Text I/O |
| HTTP | Yes (walkable) | No | No | Sibling package |
| Memory | Optional | Yes | Yes | Default anonymous Tables |
| CSV Location | Optional | Yes | Yes | Sibling package; streamable first |
| Postgres | Optional | Yes | Yes | Sibling package |

### 6.6 Documentation updates

- `Adding-Sources-Destinations` — Source/Destination on tables; row vs blob; Relation; capabilities.
- Location base pod — Walkable, Pull/sink, Relation, row roles.
- Cross-link Streaming proposal: row streams are in scope for TOP Locations; text-chunk pull already shipped.
- WalkCursor Extending notes (Walkers / Navigators / Strategies) already updated for the tree landing (§5.6); Relation docs should point Memory/SQL cursors at the same contract.

### 6.7 Acceptance criteria (Relation)

- [ ] Relation discoverable without a Storage namespace.
- [ ] Memory `use-table` supports at least `use` / `can-create` / `ensure`.
- [ ] Row Iterator from Relation handle matches structured Source pull for the same backend (shared path or equivalent semantics; same `.of`).
- [ ] File as Relation fails clearly; Memory as blob-only Source may be absent.
- [ ] Extending docs updated.
- [ ] Memory (and later Postgres) Walkable scan uses `WalkCursor` on `Axis.preceding-following` where random/relative row motion is advertised (§5.6 open backends).

---

## 7. Prerequisite B — Anonymous, swappable Tables (plan §4.2)

### 7.1 Design rule

```raku
my $t = Table.new;   # lightweight Memory Location by default; name/Database optional
# later, preferably only the declaration changes:
my $t = Table.new(:location('postgres://...'), :name<countries>, ...);
```

- Database optional for single-table / anonymous use.
- Named Database for multi-table stores / URI grouping.
- No TOP unnamed Memory singleton as the primary model.

Namespace follows packaging option C in the plan; this spec requires behaviour.

### 7.2 Front-end responsibilities

- Optional name / Database metadata.
- Delegates storage to Relation handle (§6); row I/O consistent with Source/Destination on that location (§4–5).
- TOP-like methods across backends (`add-row`, fields, `parse` / `format`, … per plan §10.2), sharing Format/Location factories with operators.
- Location swap preserves API; capability mismatches fail per §6.4.

### 7.3 First-class query / walk / schema origin

| Consumer | Requirement |
| -------- | ----------- |
| Table Walker | Walk rows of an anonymous Table |
| `Schema.discover` | Recognise lone Table / relation handle → one-table Catalog or equivalent |
| Format Render / `Table.format` | No Catalog required |
| FK Catalog | Still for multi-table; anonymous Table not forced through a fake multi-table root |

### 7.4 Acceptance criteria (anonymous Tables)

- [ ] Anonymous Memory `Table.new` without Database/name.
- [ ] TOP-style row/field access; FieldMode Automatic on Memory.
- [ ] Usable as Walker/query origin without Catalog wrap.
- [ ] `Schema.discover` (or adapter) accepts it.
- [ ] `:location` to relation-capable backend works; blob-only location fails clearly.
- [ ] Documented sketch: anonymous Memory → redeclare with Postgres location.

---

## 8. Implementation order (normative preference)

1. ~~Spec freeze for text-chunk streaming~~ — landed as walkable/pull in 0.10.0 (§5.2 / §5.5).
2. ~~WalkCursor tree first landing~~ — landed (§5.6); Memory/Postgres cursor backends wait on Relation.
3. ~~Sector vocabulary + Topic slang for `given`/bare nav/universe ops~~ — landed (query face ready for table walkabout under topic).
4. **Structured pull (§5.3–5.5 open items):** `TypedIterator` + `.of`; SourceOperator/DestinationOperator branch on `.of` / per-element type; Memory (etc.) yield rows without `Str` dumps.
5. **Relation base + Memory Relation (§6)** sharing row I/O with structured pull; Memory `WalkCursor` on `Axis.preceding-following` when Walkable scan is needed.
6. **Minimal Table front-end** anonymous-first (§7).
7. Walker / `Schema.discover` hooks for lone Table.
8. Tests: File≠Relation; Source on Memory yields rows; Destination writes rows; capability failures.
9. Then plan sequencing (HalfHuman, CSV Location, Postgres + SQL `WalkCursor`; more Format pull backends; push `Supply` edges as needed).

Do **not** ship Relation + Table while Source for table locations is still walkable-`Str`-only.

## 9. Open points deferred to implementation

- Exact module/role name for `TypedIterator` (`Qwiratry::TypedIterator` vs top-level).
- Which type object row streams advertise in `.of` before Tuple lands (`Associative` vs dedicated `Row`).
- Per-element dispatch table when `.of` is `Mu` (which types map to chunk sink vs row sink vs error).
- Final name for Relation vs `Table`.
- How URI encodes table identity (`postgres://db#table` vs path vs params).
- Destination write policy: append vs replace vs upsert (per backend capability).
- Memory URI vs constructor-only.
- Database as Location grouping vs front-end object vs both.
- Exact exception types.
- FieldMode plugin loading site.
- Whether bare `SourceOperator` should ever return text-chunk Iterators directly (today pull starts at Parse); structured/row Source almost certainly should return from Source as `TypedIterator`.
- How far Format pull must go before CSV Location (structured pull is enough to start CSV Location).
- When to land full push (`Supply`) adaptors — after TOP row paths are honest is fine.
- Whether Relation handles mint `WalkCursor` directly or only via Walker/`Plan.cursor` (Tree already uses the latter).
- Mapping TOP’s `Cursor::Storage::Postgres` onto `WalkCursor` `fetch-*`/`move-*` (0-based Raku vs 1-based SQL adaptors).

---

## 10. References

- [Qwiratry-TOP-Plan.md](Qwiratry-TOP-Plan.md) — especially §3–4, §6–8, §10
- [Cursor-Proposal.md](Cursor-Proposal.md) — WalkCursor / QueryCursor (tree landed; Memory/SQL later)
- [Universe-Topic-Slang-Plan.md](Universe-Topic-Slang-Plan.md) — Topic slang load order (`Slang` then `Topic`)
- [Streaming-Qwiratry-Proposal.md](Streaming-Qwiratry-Proposal.md) / [Streaming-Qwiratry-Proposal.rakudoc](Streaming-Qwiratry-Proposal.rakudoc)
- [Streaming-Qwiratry-Proposal-v2.md](Streaming-Qwiratry-Proposal-v2.md) — later push / model notes
- [Adding-Sources-Destinations](../Extending/Adding-Sources-Destinations.rakudoc)
- `lib/Qwiratry/Location.rakumod`, `Location/Base.rakumod`, `Operator/IO.rakumod`
- `lib/Qwiratry/Format/Base.rakumod`, `Format/NDJSONdemo.rakumod`
- `lib/WalkCursor.rakumod`, `lib/TypedIterator.rakumod`, `lib/Qwiratry/QueryCursor.rakumod`
- `t/unit/streaming-io.rakutest`, `t/unit/typed-iterator.rakutest`, `t/unit/query-cursor.rakutest`
- `lib/Qwiratry/Table/Schema.rakumod`, `Table.rakumod` (Catalog)
- Raku TOP reference tree: `~/src/TOP/Raku-TOP/main` (read-only)
