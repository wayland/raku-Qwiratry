# Qwiratry TOP Prerequisites

Specification for Qwiratry core changes required before rebuilding TOP on Qwiratry.

Parent plan: [Qwiratry-TOP-Plan.md](Qwiratry-TOP-Plan.md) (§4.1–4.2). This document is normative for the prerequisites; the plan remains the broader design note.

**Status:** Spec / not yet implemented.  
**Scope:** Streaming-shaped Location I/O so Source/Destination work on tables; Relation for the TOP object face; anonymous, swappable Tables.

---

## 1. Goals

1. **One Location plugin story** for “where data lives,” covering blob endpoints (File, HTTP) and table endpoints (Memory, CSV Location, Postgres, later `.ods`, SQLite, …). No parallel Storage hierarchy.
2. **Source and Destination work on tables**, not only blobs. Pipeline I/O must pull/push **rows** from/to relation-capable locations, without dumping a table to a giant `Str`.
3. **Streaming-shaped Location I/O first** (at least Iterator-based Source/Destination and operator paths that do not force full materialisation), so table Source/Destination have an honest representation. Align with [Streaming-Qwiratry-Proposal.rakudoc](Streaming-Qwiratry-Proposal.rakudoc).
4. **Relation / `use-table`** as the TOP **object** face on the same backends: live `Table` with actions, fields, FieldMode, mutation — sharing row read/write paths with Source/Destination, not forking them.
5. **Capability-typed backends** so blob-only Locations do not pretend to be tables (and vice versa where needed), with clear failures on location swap.
6. **Anonymous Tables** that live in ordinary variables (default Memory), then grow heavier by changing primarily the location declaration.

## 2. Non-goals

- Implementing full CSV Location, Postgres Location, HalfHuman, or WithBorders (later plan work) — but contracts must allow them.
- Multi-dialect / Red-style SQL encoding (plan §12).
- Graduating `CSVdemo` into a production Format (CSV tables are a Location package).
- Replacing the TOP object/method API with pipelines only (pipelines remain complementary; plan §10.2).
- Requiring complete Format chunk-streaming (`parse-chunks` / `render-chunks`) before Relation — **Location row streaming and Source/Destination Iterator support are the blockers**; Format chunk streaming can trail.

## 3. Current baseline

Today:

| Piece | Behaviour |
| ----- | --------- |
| `Qwiratry::Location::Base::Source` | `read(Str $location --> Str)` only |
| `Qwiratry::Location::Base::Destination` | `write(Str $location, Mu $content --> Mu)` only |
| `SourceOperator` / `DestinationOperator` | Always whole-value `read` / `write`; assume blob-ish payloads |
| `Qwiratry::Location` factory | Discovers `::Source` / `::Destination` by URI scheme / path |
| `Qwiratry::Table::Catalog` / `Schema` | FK-aware navigation over named collections / row lists |

There is no way for Source to mean “rows from this table location” without either lying (`Str` dump) or extending Location + operators. That extension is this prerequisite.

TOP’s `Database::Storage` / `Table::Storage` responsibilities move into **upgraded Location** (pipeline + object faces) plus a thin TOP Table front-end — not into a new Storage namespace.

---

## 4. Two faces of the same Location

### 4.1 Pipeline face — Source / Destination

`SourceOperator` and `DestinationOperator` remain the adaptor pipeline operators:

- **Source** = pull data from a location **into** the pipeline.
- **Destination** = push pipeline data **out** to a location.

Payload shape depends on Location capability (not on inventing parallel operators):

| Location capability | Source yields | Destination accepts |
| ------------------- | ------------- | ------------------- |
| Blob (File, HTTP, …) | `Str`, or chunk `Iterator` once streaming lands | `Str`, or chunk sink once streaming lands |
| Table / relation (Memory, CSV Location, Postgres, …) | row `Iterator` / `Seq` (Tuples or Associatives) | row stream or table-shaped data to insert/replace/append per backend policy |

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
| Source + blob location | Blob read (`Str` or chunk Iterator). |
| Source + table-capable location | Yield row Iterator/Seq (streamable preferred; materialise only if necessary). |
| Source + location with neither usable blob nor table Source | Clear capability / not-found error. |
| Destination + table-capable location | Consume rows (or data coercible to rows) into the table location. |
| `Table.new` / `use-table` | Relation face; does not go through SourceOperator, but shares row I/O with Source where applicable. |

Adaptor operators MUST NOT assume every Location is `Str`-only.

---

## 5. Prerequisite A0 — Streaming-shaped Location I/O (do this first)

### 5.1 Why first

Source/Destination on tables are only honest if the Location and operator stack can carry **Iterators** (rows or chunks) without forcing full materialisation. Implementing Relation alone while Source remains `read --> Str` paints the wrong corner: every “Source a table” becomes a dump.

This prerequisite therefore **starts with** (or as the first slice of) the Location/operator parts of [Streaming-Qwiratry-Proposal.rakudoc](Streaming-Qwiratry-Proposal.rakudoc), extended for **row** streams as well as text chunks.

### 5.2 Required contracts (minimal for TOP)

Names negotiable; behaviour is not. Prefer optional capability roles on top of existing Source/Destination classes (same discovery as today):

```raku
# Text / blob streaming (from Streaming proposal)
role Qwiratry::Location::Base::StreamingSource {
    method read-chunks(Str:D $location --> Iterator:D) { ... }
}
role Qwiratry::Location::Base::StreamingDestination {
    method open-sink(Str:D $location --> Mu) { ... }  # write-chunk / close
}

# Row streaming for table-capable locations
role Qwiratry::Location::Base::RowSource {
    method read-rows(Str:D $location, *%params --> Iterator:D) { ... }
}
role Qwiratry::Location::Base::RowDestination {
    method open-row-sink(Str:D $location, *%params --> Mu) { ... }  # write-row / close
}
```

Whole-value `read` / `write` remain for simple blob backends and as fallbacks. Operators choose streaming/row APIs when the implementation advertises them and the pipeline can stay lazy.

### 5.3 Operator requirements

- `SourceOperator` / `DestinationOperator` MUST be able to use row streaming when the Location is table-capable (and chunk streaming when blob-streaming is available).
- They MUST NOT normalise a row Source into a single `Str`.
- They SHOULD NOT force a lazy row Seq into a full `List` unless a downstream step requires it (same pathology the streaming proposal calls out for Render today).
- Capability detection: if the caller/pipeline needs rows and the backend only has blob Source, fail clearly (or require an explicit Format round-trip) — do not silently dump tables to text.

### 5.4 Acceptance criteria (streaming-shaped I/O)

- [ ] Location capability query distinguishes blob Source, streaming blob Source, row Source, Destination variants.
- [ ] A Memory (or test double) Location can Source rows as an Iterator without building a giant `Str`.
- [ ] SourceOperator against that Location returns a lazy row sequence into the pipeline.
- [ ] DestinationOperator can write a row Seq to a table-capable Location via a row sink (or equivalent).
- [ ] File Source/Destination still work for whole-value (and optionally chunks).
- [ ] Documented in Extending + aligned with Streaming proposal terminology.

---

## 6. Prerequisite A — Relation / upgrade Location (plan §4.1)

### 6.1 Design rule

**Do not add `Qwiratry::Storage::*`.** Extend Location so a backend may implement any subset of:

- **Source** / **Destination** (blob and/or row, per §5)
- **Relation** for live Table handles

Format remains “how is it encoded?” for HalfHuman, WithBorders, demo CSVdemo, etc. CSV *tables* are `Qwiratry::Location::CSV` (sibling package).

### 6.2 Discovery and naming

- Keep `Qwiratry::Location` as the sole Location discovery/dispatch factory.
- URI scheme → backend mapping unchanged in spirit (`file://`, `postgres://`, later CSV / `memory://` or in-process constructor).
- Backend module `Qwiratry::Location::<Name>` may provide `::Source`, `::Destination`, `::Relation` (and streaming/row roles as capabilities on those classes or siblings).
- Factory asks for an operation type; missing capability → clear error.

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
| Rows | Prefer Iterator scans; Positional MAY materialise or use cursors/keys |
| Shared I/O | Row scan/write SHOULD reuse the same paths as RowSource / RowDestination for that backend |
| Mutation | Optional; if advertised, consistent add/update/delete |
| Actions | TOP table actions with existence/conformance checks |

### 6.4 Capability advertising

Suggested keys (illustrative):

| Capability | Meaning |
| ---------- | ------- |
| `blob-source` / `blob-destination` | Whole-value or chunk text I/O |
| `row-source` / `row-destination` | Source/Destination row streams (§5) |
| `relation` | `use-table` / live Table handle |
| `field-mode-automatic` / `error` / `overflow` | Supported FieldModes |
| `positional-rows` | Random Positional access |
| `streaming-rows` | Iterator scan without full materialise |
| `mutable` | Live write-through |
| `table-actions` | Which of create/alter/ensure/… are supported |

Location swap (Memory → Postgres, etc.) MUST fail explicitly if a required capability is missing — no silent FieldMode degradation.

### 6.5 Built-in expectations (first slices)

| Backend | Blob Source/Dest | Row Source/Dest | Relation | Notes |
| ------- | ---------------- | --------------- | -------- | ----- |
| File | Yes | No | No | Text I/O |
| Memory | Optional | Yes | Yes | Default anonymous Tables |
| CSV Location | Optional | Yes | Yes | Sibling package; streamable first |
| Postgres | Optional | Yes | Yes | Sibling package |

### 6.6 Documentation updates

- `Adding-Sources-Destinations` — Source/Destination on tables; row vs blob; Relation; capabilities.
- Location base pod — Source, Destination, Relation, streaming/row roles.
- Cross-link Streaming proposal: row streams are in scope for TOP Locations.

### 6.7 Acceptance criteria (Relation)

- [ ] Relation discoverable without a Storage namespace.
- [ ] Memory `use-table` supports at least `use` / `can-create` / `ensure`.
- [ ] Row Iterator from Relation handle matches RowSource behaviour for the same backend (shared path or equivalent semantics).
- [ ] File as Relation fails clearly; Memory as blob-only Source may be absent.
- [ ] Extending docs updated.

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

1. Spec freeze for this document (names may still shift).
2. **Streaming-shaped Location I/O (§5):** capability detection; RowSource/RowDestination (and optionally chunk streaming); SourceOperator/DestinationOperator paths that can yield/sink rows without `Str` dumps.
3. **Relation base + Memory Relation (§6)** sharing row paths with RowSource/RowDestination.
4. **Minimal Table front-end** anonymous-first (§7).
5. Walker / `Schema.discover` hooks for lone Table.
6. Tests: File≠Relation; Source on Memory yields rows; Destination writes rows; capability failures.
7. Then plan sequencing (HalfHuman, CSV Location, Postgres, Format chunk streaming as needed).

Do **not** ship Relation + Table while Source is still whole-`Str`-only for table locations.

## 9. Open points deferred to implementation

- Final role names (`RowSource` vs methods on Source; `Relation` vs `Table`).
- How URI encodes table identity (`postgres://db#table` vs path vs params).
- Destination write policy: append vs replace vs upsert (per backend capability).
- Memory URI vs constructor-only.
- Database as Location grouping vs front-end object vs both.
- Exact exception types.
- FieldMode plugin loading site.
- How far Format chunk streaming must go before CSV Location (row streaming is enough to start CSV Location).

---

## 10. References

- [Qwiratry-TOP-Plan.md](Qwiratry-TOP-Plan.md) — especially §3–4, §6, §10
- [Streaming-Qwiratry-Proposal.rakudoc](Streaming-Qwiratry-Proposal.rakudoc)
- [Adding-Sources-Destinations](../Extending/Adding-Sources-Destinations.rakudoc)
- `lib/Qwiratry/Location.rakumod`, `Location/Base.rakumod`, `Operator/IO.rakumod`
- `lib/Qwiratry/Table/Schema.rakumod`, `Table.rakumod` (Catalog)
- Raku TOP reference tree: `~/src/TOP/Raku-TOP/main` (read-only)
