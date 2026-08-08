# Qwiratry TOP Basics

Normative sketch for the **TOP layer** on Qwiratry: Relation, Memory, Postgres,
Tables (and related front-end objects). These are **not** Qwiratry core
prerequisites.

Depends on: [Qwiratry-TOP-Prerequisites.md](Qwiratry-TOP-Prerequisites.md)
(streaming Location I/O, `TypedIterator`, WalkCursor tree contract).  
Parent plan: [Qwiratry-TOP-Plan.md](Qwiratry-TOP-Plan.md) (§4.1–4.2 and following).

**Status:** Not started as product work. Prerequisites: streaming + `TypedIterator`
text path + WalkCursor tree; planned `QueryIterator does TypedIterator`. Do not
implement Relation/Table while table Sources would still dump to `Str`.  
**Scope:** Location **Relation** face; Memory / CSV / Postgres Locations; anonymous
swappable Tables; sharing row I/O with Source/Destination; WalkCursor backends;
**Destination row sinks** and **Parse skip** for structured `.of`; choosing row
`.of` type when table Locations land.

---

## 1. Goals

1. **Relation / `use-table`** as the TOP **object** face on Location backends:
   live Table handle, actions, fields, FieldMode, mutation — sharing row
   read/write with Source/Destination.
2. **Memory Location** as the default lightweight backend for anonymous Tables.
3. **Postgres Location** (sibling package) with row Source/Destination + Relation;
   map SQL cursors onto `WalkCursor` where useful.
4. **Anonymous, swappable Tables** (`Table.new` without Database; later
   `:location` swap with capability checks).
5. **Capability-typed backends** so blob-only Locations do not pretend to be
   tables (and vice versa), with clear failures on location swap.
6. **No `Qwiratry::Storage::*`** — Storage responsibilities move into upgraded
   Location + thin TOP Table front-end.

## 2. Non-goals

- Replacing the TOP object/method API with pipelines only (pipelines remain
  complementary; plan §10.2).
- Multi-dialect / Red-style SQL encoding (plan §12) — near term Postgres only.
- Graduating `CSVdemo` into a production Format (CSV **tables** are
  `Qwiratry::Location::CSV`).
- Re-implementing WalkCursor tree proof (done in prerequisites / Cursor proposal).
- Full Format `Supply` push adaptors (deferred; not required to start Basics).
- Changing `SourceOperator` to return a pull Iterator (rejected in prerequisites;
  walkable evaluate stays).

---

## 3. Two faces of the same Location

### 3.1 Pipeline face — Source / Destination

Defined for Qwiratry adaptors in the prerequisites. **`SourceOperator.evaluate`
stays walkable-only** (does not return an Iterator); table Locations expose rows
via `read-pull` → `TypedIterator` (and Relation handles), composed into pipelines
as Basics defines.

| Capability | Source / Location yields | Destination accepts |
| ---------- | ------------------------ | ------------------- |
| Table / relation (Memory, CSV Location, Postgres, …) | `TypedIterator` with `.of` = row type (or `Mu` + per-element) | Row stream / insert-replace-append per backend policy |

**Source on a table location must not mean “serialize the whole table as one
string.”** It means start a pull of rows (Location `read-pull` / Relation scan).

Parse/Render apply when the pipeline still deals with encoded text. When the
upstream stream’s `.of` is structured (row-like), **Parse must be skipped** (or
fail clearly if a text Parse was requested). Destination on a table-capable
Location uses a **row sink**; on a blob-only Location, structured `.of` is an
error (already the text-adaptor rule in core — do not `.Str`-dump rows).

### 3.1.1 Structured `.of` / row sinks (Basics work)

Moved here from prerequisites (not needed until table Locations exist):

- [ ] Choose row stream `.of` type when implementing Memory (`Associative` interim
      vs dedicated `Row` / `Tuple` once those types exist).
- [ ] Destination row sink API on table-capable Locations (write-row / close or
      equivalent); wire `DestinationOperator` when `.of` / elements are rows.
- [ ] ParseOperator: if `.of` is structured, do not `parse-pull` / join as text.
- [ ] End-to-end: Memory Source pull → query → Memory Destination row sink
      without Format dump.

### 3.2 Object face — Relation / `use-table`

`Qwiratry::Location::Base::Relation` (name negotiable) binds a **live Table** for
the TOP object/method API:

- table actions (`create` / `alter` / `use` / `can-create` / `ensure`)
- fields, FieldMode, `makeTuple`-level shaping
- long-lived handle for `$table.add-row`, field access, Walker origin, etc.

Relation is **not** a replacement for Source/Destination and **not** “the only
way to talk to tables.” It is the object-handle face. The same backend module
SHOULD back both faces and **share** the underlying row iterator / write path
(`TypedIterator`, prerequisites §5.3).

```text
Source ↗  →  (query / transform)  →  Destination ↘   # pipeline; files AND tables
$table = Table.new(:location<…>)                     # object face; same Location backend
```

### 3.3 What “Source with a table” means (normative)

| Situation | Required behaviour |
| --------- | ------------------ |
| Source + blob location | Blob read (`read-walkable` or text `TypedIterator` via pull composition with Parse). |
| Source + table-capable location | Location `read-pull` (or Relation scan) yields row `TypedIterator` / Seq. |
| Source + location with neither usable blob nor table Source | Clear capability / not-found error. |
| Destination + table-capable location | Consume rows via row sink into the table location. |
| Destination + blob location + structured `.of` | Clear error — not a text dump. |
| `Table.new` / `use-table` | Relation face; does not go through SourceOperator, but shares row I/O with Location pull where applicable. |
| `QueryCursor.iterator` / `Plan.iterator` | Returns `QueryIterator`, which **does** `TypedIterator` (prerequisite; default `.of = Mu`). Match stream, not Location I/O. |

---

## 4. Relation / upgrade Location

### 4.1 Design rule

**Do not add `Qwiratry::Storage::*`.** Extend Location so a backend may implement
any subset of:

- **Source** / **Destination** (blob and/or structured pull via `TypedIterator`)
- **Relation** for live Table handles

Format remains “how is it encoded?” for HalfHuman, WithBorders, demo CSVdemo,
etc. CSV *tables* are `Qwiratry::Location::CSV` (sibling package).

### 4.2 Discovery and naming

- Keep `Qwiratry::Location` as the sole Location discovery/dispatch factory.
- URI scheme → backend mapping unchanged in spirit (`file://`, `postgres://`,
  later CSV / `memory://` or in-process constructor).
- Backend module `Qwiratry::Location::<Name>` may provide `::Source`,
  `::Destination`, `::Relation` (and pull capabilities on those classes).
- Factory asks for an operation type; missing capability → clear error.
- Walkable bases for `Source` / `Destination` stay as today; Relation is an
  additional discoverable type or capability.

### 4.3 Relation capability contract

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
| Rows | Prefer Iterator scans; Positional MAY materialise or use `WalkCursor` / keys |
| Shared I/O | Row scan/write SHOULD reuse Source/Destination pull/sink paths (`TypedIterator`) |
| Mutation | Optional; if advertised, consistent add/update/delete |
| Actions | TOP table actions with existence/conformance checks |
| Walk position | When Walkable query walkabout is supported, expose a `WalkCursor` specialization (Tree `QueryCursor` is the reference) |

### 4.4 Capability advertising

Suggested keys (illustrative):

| Capability | Meaning |
| ---------- | ------- |
| `blob-source` / `blob-destination` | Walkable and/or pull text I/O |
| `row-source` / `row-destination` | Structured (row) pull/sink; element kind also on `TypedIterator.of` |
| `relation` | `use-table` / live Table handle |
| `field-mode-automatic` / `error` / `overflow` | Supported FieldModes |
| `positional-rows` | Random Positional access |
| `streaming-rows` | Iterator scan without full materialise |
| `walk-cursor` | `WalkCursor`-capable ordered walk (Tree done in core; Memory/SQL here) |
| `mutable` | Live write-through |
| `table-actions` | Which of create/alter/ensure/… are supported |

Location swap (Memory → Postgres, etc.) MUST fail explicitly if a required
capability is missing — no silent FieldMode degradation.

### 4.5 Built-in expectations (first slices)

| Backend | Blob Source/Dest | Row Source/Dest | Relation | Notes |
| ------- | ---------------- | --------------- | -------- | ----- |
| File | Yes (walkable + pull/sink) | No | No | Text I/O (core) |
| HTTP | Yes (walkable) | No | No | Sibling package |
| Memory | Optional | Yes | Yes | Default anonymous Tables |
| CSV Location | Optional | Yes | Yes | Sibling package; streamable first |
| Postgres | Optional | Yes | Yes | Sibling package |

### 4.6 Documentation updates

- `Adding-Sources-Destinations` — Source/Destination on tables; row vs blob; Relation; capabilities.
- Location base pod — Walkable, Pull/sink, Relation.
- Cross-link Streaming proposal and prerequisites `TypedIterator`.
- WalkCursor Extending notes already cover the tree landing; Relation docs should
  point Memory/SQL cursors at the same contract.

### 4.7 Acceptance criteria (Relation)

- [ ] Relation discoverable without a Storage namespace.
- [ ] Memory `use-table` supports at least `use` / `can-create` / `ensure`.
- [ ] Row Iterator from Relation handle matches structured Source pull for the same backend (shared path; same `.of`).
- [ ] File as Relation fails clearly; Memory as blob-only Source may be absent.
- [ ] Extending docs updated.
- [ ] Memory (and later Postgres) Walkable scan uses `WalkCursor` on `Axis.preceding-following` where random/relative row motion is advertised.

---

## 5. Anonymous, swappable Tables

### 5.1 Design rule

```raku
my $t = Table.new;   # lightweight Memory Location by default; name/Database optional
# later, preferably only the declaration changes:
my $t = Table.new(:location('postgres://...'), :name<countries>, ...);
```

- Database optional for single-table / anonymous use.
- Named Database for multi-table stores / URI grouping.
- No TOP unnamed Memory singleton as the primary model.

Namespace follows packaging option C in the plan; this spec requires behaviour.

### 5.2 Front-end responsibilities

- Optional name / Database metadata.
- Delegates storage to Relation handle (§4); row I/O consistent with
  Source/Destination on that location (§3).
- TOP-like methods across backends (`add-row`, fields, `parse` / `format`, …
  per plan §10.2), sharing Format/Location factories with operators.
- Location swap preserves API; capability mismatches fail per §4.4.

### 5.3 First-class query / walk / schema origin

| Consumer | Requirement |
| -------- | ----------- |
| Table Walker | Walk rows of an anonymous Table |
| `Schema.discover` | Recognise lone Table / relation handle → one-table Catalog or equivalent |
| Format Render / `Table.format` | No Catalog required |
| FK Catalog | Still for multi-table; anonymous Table not forced through a fake multi-table root |

### 5.4 Acceptance criteria (anonymous Tables)

- [ ] Anonymous Memory `Table.new` without Database/name.
- [ ] TOP-style row/field access; FieldMode Automatic on Memory.
- [ ] Usable as Walker/query origin without Catalog wrap.
- [ ] `Schema.discover` (or adapter) accepts it.
- [ ] `:location` to relation-capable backend works; blob-only location fails clearly.
- [ ] Documented sketch: anonymous Memory → redeclare with Postgres location.

---

## 6. WalkCursor backends (TOP)

Tree contract is done in core ([Cursor-Proposal.md](Cursor-Proposal.md),
prerequisites §5.6). Still open here:

- [ ] Memory / loaded-table `WalkCursor` on `Axis.preceding-following` (ordered row sequence).
- [ ] Postgres (or SQL) Location cursor mapping `FETCH` / `MOVE` onto `fetch-*` / `move-*`.
- [ ] Metanoia Walkable-as-cursor-factory (deferred in Cursor proposal).
- [ ] Whether Relation handles mint `WalkCursor` directly or only via Walker / `Plan.cursor`.
- [ ] Mapping TOP’s `Cursor::Storage::Postgres` onto `WalkCursor` (0-based Raku vs 1-based SQL adaptors).

---

## 7. Implementation order

After prerequisites (streaming, `TypedIterator` text path, WalkCursor tree,
`QueryIterator does TypedIterator`):

1. **Relation base + Memory Relation** sharing row I/O with structured pull;
   pick row `.of`; Memory `WalkCursor` on `Axis.preceding-following` when needed.
2. **Destination row sink + Parse skip** for structured `.of` (§3.1.1).
3. **Minimal Table front-end** anonymous-first (§5).
4. Walker / `Schema.discover` hooks for lone Table.
5. Tests: File≠Relation; Memory pull yields rows; Destination writes rows;
   capability failures; no Str dump.
6. Plan sequencing: HalfHuman, CSV Location, Postgres + SQL `WalkCursor`; more
   Format pull backends. Full `Supply` push remains deferred.

Do **not** ship Relation + Table while table Sources would still be forced through
walkable-`Str`-only dumps.

---

## 8. Open points

- Final name for Relation vs `Table`.
- How URI encodes table identity (`postgres://db#table` vs path vs params).
- Destination write policy: append vs replace vs upsert (per backend capability).
- Memory URI vs constructor-only.
- Database as Location grouping vs front-end object vs both.
- Exact exception types for capability failures / structured-on-blob Destination.
- FieldMode plugin loading site.
- Which type object row streams advertise in `.of` before Tuple lands
  (`Associative` vs dedicated `Row`) — decide when Memory Location is implemented.
- How far Format pull must go before CSV Location (structured pull is enough to
  start CSV Location).
- Whether Tree/Table `QueryIterator`s override `.of` beyond default `Mu`.

---

## 9. References

- [Qwiratry-TOP-Plan.md](Qwiratry-TOP-Plan.md) — especially §3–4, §6–8, §10
- [Qwiratry-TOP-Prerequisites.md](Qwiratry-TOP-Prerequisites.md)
- [Cursor-Proposal.md](Cursor-Proposal.md)
- `lib/TypedIterator.rakumod`, `lib/Qwiratry/QueryIterator.rakumod` (QueryIterator → TypedIterator in prerequisites)
- [Streaming-Qwiratry-Proposal.md](Streaming-Qwiratry-Proposal.md)
- [Adding-Sources-Destinations](../Extending/Adding-Sources-Destinations.rakudoc)
- `lib/Qwiratry/Table/Schema.rakumod`, `Table.rakumod` (existing Catalog — not the TOP Table front-end)
- Raku TOP reference tree: `~/src/TOP/Raku-TOP/main` (read-only)
