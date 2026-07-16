# Rebuilding Raku TOP on Qwiratry

Working plan for rewriting [Raku TOP](https://github.com/wayland/Raku-TOP) against Qwiratry. Reference tree for this plan: `~/src/TOP/Raku-TOP/main` (read-only; do not edit it from here).

This is a design note, not a commitment to package layout or API names. We will refine it as we implement.

**Prerequisites spec (normative for §4.1–4.2):** [Qwiratry-TOP-Prerequisites.md](Qwiratry-TOP-Prerequisites.md).

## 1. Why rebuild

TOP is Table-Oriented Programming: `Database`, `Table`/`Relation`, `Field`, `Tuple`, plus:

- **Parsers / Formatters** for tabular text (CSV, HalfHuman, WithBorders)
- **Storage backends** (Memory, CSV stub, Postgres via DBIish)
- **Field modes** (Automatic / Error / Overflow) that decide what happens when a row has columns not in the schema

Qwiratry already owns the broader DOP pipeline: Query AST, Walkers, Strategies, Transformers/Molds, Formats, Locations, and table navigation via `Qwiratry::Table::Catalog` / `Schema`. TOP should become the **relational object front-end and storage story** on that pipeline, not a parallel mini-framework.

Today’s Qwiratry `Table` catalog is about FK-aware navigation over row collections. TOP’s `Table` is a richer **mutable relation** with schema, storage actions, and format hooks. Both should coexist: Catalog for walking; TOP-style Table for owning rows and backends.

## 2. What TOP has today (inventory)

### 2.1 Core object model (`lib/raku/TOP.rakumod`)

| Concept     | Role                                                                |
| ----------- | ------------------------------------------------------------------- |
| `TOP::Core` | Dynamic `load-library` for Storage / FieldMode / Formatter / Parser |
| `Tuple`     | Ordered row (`Hash::Ordered`)                                       |
| `Field`     | Named column view over a Relation (Positional over rows)            |
| `Relation`  | Shared role for table-like sets                                     |
| `Table`     | Frontend: name, database, action; delegates storage ops             |
| `Database`  | Frontend: picks storage type, `useTable`                            |

Table **actions** (`create` / `alter` / `use` / `can-create` / `ensure`) control whether storage must exist, may alter schema, and whether fields are supplied. Keep these; they are one of TOP’s useful distinctions from “just open a file”.

### 2.2 Formats as Parse / Format (TOP naming)

| Module                           | Parse   | Format / Render   | Notes                                                                |
| -------------------------------- | ------- | ----------------- | -------------------------------------------------------------------- |
| `TOP::Parser::CSV`               | Yes     | (planned as Make) | Uses `Text::CSV`; fills a Table via header + `add-row`               |
| `TOP::Parser::HalfHuman`         | Yes     | Yes (formatter)   | Whitespace-separated Unix-ish tables                                 |
| `TOP::Formatter::HalfHuman`      | —       | Yes               | Column-width `sprintf`, optional headers                             |
| `TOP::Formatter::WithBorders`    | —       | Yes               | Unicode box drawing; loads `BoxDrawingCharacters.csv` as a TOP table |
| HTML / JSON / Spreadsheet / Pod6 | planned | planned           | Defer; JSON already exists as `Qwiratry-Format-JSON`                 |

In TOP, `Table::Storage.format` / `parse` load formatter/parser classes and drive them against the live table. In Qwiratry, that responsibility splits cleanly into **Format** plugins plus optional **Location** I/O.

### 2.3 Storage

| Backend                       | Status        | Behaviour                                                                                                |
| ----------------------------- | ------------- | -------------------------------------------------------------------------------------------------------- |
| `Database::Storage::Memory`   | Working       | In-memory tables; singleton unnamed DB; full Positional/Associative                                      |
| `Database::Storage::CSV`      | Stub / broken | Intent: directory of CSV files as a “database”; currently incomplete                                     |
| `Database::Storage::Postgres` | Working-ish   | DBIish `Pg`, `.pgpass`, cursor-based reads, schema introspection, insert/update; create/alter incomplete |

`Table::Storage` always installs a **FieldMode** and implements `makeTuple` / `add-field` / `format` / `parse`.

### 2.4 Field modes

| Mode        | Behaviour                                                   |
| ----------- | ----------------------------------------------------------- |
| `Automatic` | Unknown keys become new Fields (spreadsheet-like)           |
| `Error`     | Unknown keys / extra array cells die (RDBMS-like)           |
| `Overflow`  | Unknown keys packed into a named overflow Associative field |

Entry point: `vet-for-tuple` before constructing a `Tuple`.

## 3. Qwiratry mapping

### 3.1 Separation Qwiratry already got right

TOP blurred three concerns that Qwiratry should keep distinct:

1. **Representation** (CSV / HalfHuman / borders) → Qwiratry **Format** (`Parse` / `Render`)
2. **Where the data lives and how we talk to it** (file, HTTP, Memory, Postgres, …) → Qwiratry **Location**
3. **Relational front-end** (`Database`, `Table`, `Field`, `Tuple`, FieldMode) → TOP layer on top of Location + Format

Today’s Location contract is only whole-value text I/O (`read → Str`, `write(content)`). That is enough for simple File/HTTP blobs, but not for live tables or for Source/Destination on tables. The plan is to **upgrade Location** so the same backend family exposes blob and/or **row** pipeline I/O plus optional Relation handles — not a parallel Storage hierarchy. Streaming-shaped I/O comes first. See §4.1 and [Qwiratry-TOP-Prerequisites.md](Qwiratry-TOP-Prerequisites.md).

### 3.2 Proposed layers

```text
  Query slang / Walkers / Catalog navigation
                 ↑
         TOP relation surface
      (Database, Table, Field, Tuple, FieldMode)
                 ↑
     Location backends (upgraded; see §4.1)
   (Memory | CSV Location | Postgres | later SQLite, .ods, …)
                 ↑
        Formats (when serialising to/from text)
```

Adaptor pipelines stay (payload may be text **or** rows, depending on Location capability):

```text
Source ↗ → Parse? → (query / transform) → Render? → Destination ↘
```

Table-native work stays:

```text
$t = Table.new(...)  → Location (row-capable) ←→ Walker / Catalog / Feed operators
# or Database.useTable when a named multi-table store is wanted
```

### 3.3 Name mapping (TOP → Qwiratry)

| TOP                                                   | Qwiratry-shaped successor                                                                                       |
| ----------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `TOP::Parser::*`                                      | `Qwiratry::Format::<Name>::Parse`                                                                               |
| `TOP::Formatter::*`                                   | `Qwiratry::Format::<Name>::Render`                                                                              |
| `Database::Storage::*`                                | `Qwiratry::Location::*` (upgraded; see §4.1 / §6)                                                               |
| `TOP::FieldMode::*`                                   | Keep as TOP-facing types (or `Qwiratry::Table::FieldMode::*`)                                                   |
| `Table` / `Database` / `Field` / `Tuple` / `Relation` | Rebuild under a TOP package namespace that depends on Qwiratry                                                  |
| `Table.format` / `Table.parse`                        | Keep as TOP-style methods on Table; implementations must share Format/Location factories with pipelines (§10.2) |

Exact distribution follows packaging option **C**; see §9.

## 4. What changes Qwiratry needs

Changes to make in Qwiratry *before* (or as the foundation of) the TOP rebuild, so the architectural model is right. Items here are Qwiratry-core concerns; TOP formats and backends then plug into them.

### 4.1 Upgrade Location (absorb TOP Storage needs)

Normative detail: [Qwiratry-TOP-Prerequisites.md](Qwiratry-TOP-Prerequisites.md) (§4–6).

Today’s Location contract is whole-value text I/O (`read → Str`, `write(content)`). That is right for simple File/HTTP blobs. It is **not** enough for Memory / CSV-as-table / Postgres / `.ods`, and it is **not** enough for Source/Destination on tables.

**Decision: do not add a separate Storage surface.** Extend Location so a backend can advertise and implement:

- **Source / Destination** for pipeline I/O — including **tables** (row Iterators / row sinks), not only blobs (`Str` / later text chunks)
- **Relation** (`use-table`) for the TOP **object** face: live Table handle, actions, fields, FieldMode
- Same backend shares row read/write paths across Source/Destination and Relation

**Streaming-shaped Location I/O comes first** (prerequisites §5): without Iterator-based Source/Destination, “Source a table” collapses to dumping a table as a string. See [Streaming-Qwiratry-Proposal.rakudoc](Streaming-Qwiratry-Proposal.rakudoc); row streams are in scope for TOP Locations even if Format chunk streaming trails.

Same discovery factory (`Qwiratry::Location`), same URI schemes (`file://`, `postgres://`, later `memory://` or an in-process convention). File stays blob-oriented; Postgres / Memory / CSV Location grow row Source/Destination + Relation; a backend that only implements blob `read`/`write` simply lacks table capabilities and fails clearly when asked for them.

**Why this fits**

- One plugin story: “where does this live?” is always Location; Format stays “how is it encoded?” when the pipeline still deals with text.
- Source/Destination remain the pipeline operators; they work for files **and** tables (payload shape follows capability).
- Relation is the long-lived Table handle, not a second I/O hierarchy.
- Aligns with streaming: row streams and byte/chunk streams are the same extension style with different capabilities.

**Risks to watch**

- Location’s name gets broader than “bytes at a URI”; documentation must say backends are capability-typed.
- Adaptor operators must branch on blob vs row capabilities — never assume `Str`-only.
- Keep Format separate for HalfHuman / WithBorders / CSVdemo; CSV *tables* are Location::CSV.

Concrete sketch (names negotiable):

```raku
# Pipeline face — blob and/or rows (streaming-shaped; see prerequisites §5)
role Qwiratry::Location::Base::Source { ... }       # read / read-chunks / read-rows as capable
role Qwiratry::Location::Base::Destination { ... }  # write / open-sink / open-row-sink as capable

# Object face — live Table
role Qwiratry::Location::Base::Relation {
    method use-table(...) {...}   # actions, fields, field-mode
}
```

### 4.2 Anonymous, swappable Tables as first-class values

Normative detail: [Qwiratry-TOP-Prerequisites.md](Qwiratry-TOP-Prerequisites.md) §7.

Support tables that live in ordinary variables with no Database and no name required:

```raku
my $t = Table.new;                    # lightweight Memory Location by default
# ... later, ideally only the declaration (or a location/storage argument) changes:
my $t = Table.new(:location('postgres://...'), ...);
```

Walkers, Catalog discovery, and Format render must accept a lone Table / Relation as an origin, not only a Catalog of named tables. Verify and close gaps in `Table::Schema.discover` / table Walker so anonymous tables are first-class.

Capability gaps across locations are expected (Postgres ≠ `.ods`). Prefer a **capability** check so unsupported features fail clearly when the location is swapped, rather than silently degrading.

### 4.3 Soft prerequisites (nice before heavy backends)

- **Location row streaming + Source/Destination on tables** — **required before** treating Relation/Table as done; see prerequisites §5. Format chunk streaming can trail.
- **`Qwiratry::Location::CSV` sibling package** (option C): relation-capable CSV Location for table files/directories. Do **not** “graduate” core `CSVdemo` into a production Format — leave the demo alone; real CSV table support lives in the Location module (§5.3, §6.3). WithBorders will depend on this package (§5.2).

### 4.4 Explicitly not required as Qwiratry rewrites

- Format / Location discovery factories — keep; extend Location’s *contracts*, not the factory model.
- Tree Navigators / Match / RakuAST — unrelated to TOP table surface.
- Query slang syntax for in-memory table walking — already the right shape; richer Location backends and (later) SQL pushdown extend it rather than replace it.
- Multi-dialect SQL encoding (Red-style) — deferred; see §12. Short term is Postgres only.

## 5. Formats to rebuild

Follow `docs/rakudoc/Extending/Adding-Formats.rakudoc`: modules under `Qwiratry::Format::*` with `::Parse` / `::Render`, discovered by `Qwiratry::Format`.

### 5.1 HalfHuman (core)

- **Parse**: whitespace-split lines → ordered field values; when used with a typed Table, `add-row` / FieldMode decides naming (`Automatic` → `A`, `B`, … or existing headers if we add a header line convention).
- **Render**: port `TOP::Formatter::HalfHuman` (`prepare-table` width scan → header/row `sprintf`). Options: `:show-headers`.
- Portability note: HalfHuman is TOP’s “Unix command output” dialect; good core citizen, few deps.

### 5.2 WithBorders (sibling Format; depends on Location::CSV)

- **Render only** (no parser in TOP today). Lives outside core under option C if it would pull CSV into core otherwise.
- Options: `:show-headers`, `:outer-line-type`, `:inner-line-type` (`Light` / `Double` / `Heavy`).
- Box-drawing character table: today TOP loads `BoxDrawingCharacters.csv` via CSV parse into a Table. On Qwiratry, use the **same mechanism**: open that resource through **`Qwiratry::Location::CSV`** (sibling package) as a relation Location / Table, then look up characters. **No static hash** and no special-case bypass — WithBorders may depend on the CSV Location module.

### 5.3 CSV is a Location module (not a graduated CSVdemo)

- **Do not graduate `CSVdemo`.** Keep `Qwiratry::Format::CSVdemo` as the small built-in demo Format for adaptor experiments.
- Production CSV table support is a **separate Location package** (e.g. `Qwiratry-Location-CSV` → `Qwiratry::Location::CSV`): files/directories as relation-capable Locations (§6.3), discovered like other Location backends.
- That package owns reading/writing CSV tables (quoting, headers, field order). Adaptor pipelines that only need Str↔rows can keep using CSVdemo; real TOP-style CSV tables go through Location::CSV.
- Prefer streamable row access; materialise when necessary (§10.3).

### 5.4 Later formats (accept / make)

From TOP’s matrix: HTML, Spreadsheet, Pod6, richer JSON. JSON already lives in `raku-Qwiratry-Format-JSON`; TOP rebuild should **consume** that package rather than reimplement. Tree-shaped formats use existing Navigator extension point.

### 5.5 Formatter protocol differences

TOP formatters are **stateful multi-phase**: `prepare-table`, `output-header`, `output-row`, `output-footer`, accumulate `$.output`.

Qwiratry renderers are **one-shot**: `render($data, :%options --> Str)`.

Port strategy:

1. First implementation: whole-table render matching current Format base (simple, matches CSVdemo/JSON).
2. Optionally keep an internal phased helper for WithBorders/HalfHuman (scan widths, emit borders) *inside* `render`.
3. When streaming lands (`Streaming-Qwiratry-Proposal.rakudoc`), expose row iterators for large tables without changing the discovery model.

## 6. Locations that replace TOP Storage: Memory, CSV, Postgres

TOP’s `Database::Storage::*` backends become upgraded `Qwiratry::Location::*` backends (§4.1). Formats stay for representations that are not themselves Locations (HalfHuman, WithBorders Render, demo CSVdemo). CSV tables are a Location package (§6.3), not a graduated Format.

### 6.1 What Location must gain

`Adding-Sources-Destinations` already treats databases as locations. TOP Storage also needed:

- create / open / alter tables
- Positional rows, Associative fields
- FieldMode-aware `makeTuple`
- Postgres cursor / potential key-based pagination
- type mapping (Raku ↔ SQL)

Those become **Location capabilities**, not a second plugin tree. **Source/Destination** are the pipeline face (blob *and* row streams). **Relation** is the live Table object face. Both share row I/O on table-capable backends (prerequisites §4–6).

Short term: implement **Memory** and **Postgres** as relation-capable locations; **CSV** as its own sibling Location package (§6.3). Other DBIish backends (SQLite, MySQL) are Accept/later — see §12 for multi-dialect SQL.

### 6.2 Memory

Port `Database::Storage::Memory` / `Table::Storage::Memory` first, as an in-process Location (URI convention TBD, e.g. `memory://` or a non-URI constructor used by `Table.new`).

- **Anonymous tables in variables are the default happy path.** A table need not be named or attached to a Database; you throw together a lightweight Memory location, then increase weight later (name it, attach a Database, or point `:location` at Postgres) ideally by changing only the table declaration.
- Named Databases remain useful for multi-table stores and URI-style locations; they are not required for every Table.
- Avoid depending on TOP’s old unnamed Memory **singleton** unless we find a strong reason; per-variable tables scale the mental model better.
- Full in-memory rows; no I/O.
- Primary target for tests and FieldMode behaviour.
- Should work with `Table::Schema` / Catalog *and* as a lone Walker origin (see §4.2).

### 6.3 CSV Location module

CSV tables are a **dedicated Location backend** (sibling package under option C), not “File + graduated Format::CSV” and not a promotion of `CSVdemo`:

- Package: e.g. `Qwiratry-Location-CSV` providing `Qwiratry::Location::CSV`
- Database ≈ directory (or explicit file list)
- Table ≈ one CSV file
- Actions: `use` / `ensure` / `create` map to file existence and header writing
- Reads: prefer **streamable** row iteration; **materialise** into memory when necessary (§10.3)
- Writes: stream or buffered write + atomic replace as the backend requires
- WithBorders depends on this module to load `BoxDrawingCharacters.csv` the same way TOP did (§5.2)

Current `Database::Storage::CSV` is a stub; rewrite in the new Location package rather than salvage.

### 6.4 Postgres (short-term SQL backend)

Port `Database::Storage::Postgres` behind `Qwiratry::Location::Postgres`. **Short term we only support Postgres** as a SQL location; do not block on multi-dialect encoding (§12).

| Concern                                     | Where it lives                                                      |
| ------------------------------------------- | ------------------------------------------------------------------- |
| Connection (`DBIish.connect`, `.pgpass`)    | Location::Postgres                                                  |
| Schema introspection (`information_schema`) | Location relation setup                                             |
| Cursor / key / sort+key read modes          | Location (TOP already sketched Cursor vs Key vs NumKey)             |
| Row mutation                                | Location; prefer parameterized queries over string escape over time |
| Pushdown filters / SQL generation           | Short term: Postgres-specific SQL as needed; multi-dialect → §12    |

Location URI sketch:

- `postgres://…` or `pg://…` → `Qwiratry::Location::Postgres`
- Later: `sqlite://…`, `mysql://…` (Accept / future)

Streaming proposal aligns with cursors and key pagination: Locations should eventually yield row Iterators instead of always buffering.

### 6.5 Capability matrix (target)

| Capability                         | Memory | CSV Location      | Postgres                  | SQLite (later) |
| ---------------------------------- | ------ | ----------------- | ------------------------- | -------------- |
| create / ensure / use              | Yes    | Yes               | Yes (finish create/alter) | Yes            |
| FieldMode Automatic                | Yes    | Yes               | Optional / limited        | Optional       |
| FieldMode Error                    | Yes    | Yes               | Default-ish               | Default-ish    |
| FieldMode Overflow                 | Yes    | Yes               | Yes (JSONB column)        | Later (JSON)   |
| Random Positional access           | Yes    | After load / yes  | Via cursor/key            | Via SQL        |
| Live write-through                 | Yes    | Flush policy      | Yes                       | Yes            |
| Query Walker without materialising | Yes    | Streamable first  | Cursor / SQL              | SQL            |

## 7. Field modes and similar objects

Keep FieldMode as first-class plugins:

- Load via the same discovery style as Format/Location (`Qwiratry::Table::FieldMode::*` or `TOP::FieldMode::*`).
- Install on relation-capable Locations / Tables at construction (`:field-mode`, `:overflow-field-name`).
- Call from `makeTuple` only; parsers/formatters should not reimplement column invention.

Objects we expect to keep in a similar shape:

| Object                                       | Notes                                                                                   |
| -------------------------------------------- | --------------------------------------------------------------------------------------- |
| `Database`                                   | Owns / groups Locations; `useTable`                                                     |
| `Table` / `Relation`                         | Frontend API; TOP-style methods including parse/format (§10.2)                          |
| `Field`                                      | Column metadata + positional column view                                                |
| `Tuple`                                      | Ordered row (`Hash::Ordered` lean; see §10.7); Postgres may keep write-through subclass |
| `FieldMode` (+ Automatic / Error / Overflow) | Unchanged semantics; SQL Overflow → JSONB (§10.4)                                       |
| Format Parse/Render                          | Replaces Parser/Formatter modules                                                       |
| Location backends (relation-capable)         | Replaces `Database::Storage` / `Table::Storage`                                         |
| Optional `Cursor`                            | Postgres (and streaming Memory/CSV)                                                     |
| `Catalog` / `Schema` / `ForeignKey`          | Existing Qwiratry; wire TOP Databases into them                                         |

Deferred TOP concepts (still from README object model): View, TupleSet, Section, Lot, DataDictionary — design hooks only until Table + upgraded Location solidify.

## 8. Integration with query, walkers, streaming

- Memory / loaded CSV tables should be excellent `Walker::Implementation::Table` citizens: rows as Associatives, Catalog for multi-table roots.
- Postgres Location: short-term expose cursors as Iterators matching the streaming proposal; multi-dialect predicate pushdown is §12.
- Adaptor path remains valid: `file://data.csv` → CSV Parse → query → HalfHuman Render → stdout Location.
- Keep the TOP object/method API (`Table`, `Field`, `Database`, including `parse` / `format`) as a first-class interface across backends; pipelines are complementary, not a replacement. Method implementations must call the same Format/Location factories operators use so the two paths cannot diverge (§10.2).

## 9. Packaging and migration

**Decision: option C** (hybrid). Core gets table + FieldMode + HalfHuman; heavier pieces (`Qwiratry-Location-CSV`, WithBorders Format depending on that CSV Location, Postgres Location, later SQLite) live as sibling packages in the same style as `Qwiratry-Format-JSON` / `Qwiratry-Location-HTTP`. Leave core `CSVdemo` as a demo Format — do not graduate it.

Suggested sequencing (editable):

1. **Design freeze** of this plan with you.
2. Land Qwiratry prerequisites in §4 (upgraded Location contracts, anonymous Table as Walker origin, capability checks; leave room for relation iterators).
3. **FieldMode + Memory Location + Table/Database/Field/Tuple** (smallest useful TOP; anonymous tables first).
4. **Formats**: HalfHuman (Parse+Render) in core.
5. **`Qwiratry-Location-CSV`** sibling; streamable-first (§10.3).
6. **WithBorders** Format sibling that depends on Location::CSV for box-drawing resource loading (§5.2).
7. **Postgres Location** (+ schemes); Postgres-specific SQL only for now.
8. Migrate TOP tests / demos; retire or thin-wrap old Raku-TOP.
9. Later: SQLite / multi-dialect (§12).

Compatibility: no need for drop-in `Database::Storage::*` names unless we want a shim. Prefer clean Qwiratry-era namespaces with a short migration note.

## 10. Decisions

1. **Anonymous tables.** Allow tables that just live in variables (lightweight Memory Location by default). Naming, attaching a Database, or moving to Postgres should ideally change only the table declaration / `:location`. Do not require a Database for every Table; do not revive TOP’s unnamed Memory singleton as the main model. Locations will not all share the same capabilities (Postgres ≠ `.ods`); support as much of the common surface as practical, and use capability checks when swapping (§4.2, §6.2).

2. **TOP object/method API stays.** Pipelines are good for adaptor-style work, but we absolutely keep using `Table`, `Field`, and `Database` as in TOP — method calls are the Raku way, and that interface should stay consistent across backends where possible (`parse`, `format`, row/field access, `useTable`, etc.). Pipelines and objects are complementary. Object methods must delegate to the same Format/Location implementations the operators use so behaviour cannot fork (§2.1–2.2, §5.5, §8). Format options (`:show-headers`, border line types, …) should work through those methods the same way they do via `Render` `%options`.

3. **CSV Location: streamable preferred.** Prefer streamable row access for `Qwiratry::Location::CSV`; materialise into memory when necessary (random access, small resources such as WithBorders’ box-drawing table, operations that need the full table). See §5.3 / §6.3.

4. **FieldMode Overflow on SQL → JSONB.** Support Automatic, Error, and Overflow on SQL locations as far as each backend allows. For Overflow on Postgres, store extra keys in a **JSONB** column named by `:overflow-field-name` (queryable, typed). Do not silently degrade Overflow to Error when swapping Memory → Postgres; if a location cannot provide Overflow, capability checks should fail clearly (§4.2). Later SQLite can use its JSON affinity/functions analogously.

5. **SQL dialects (near term).** Postgres only. Multi-dialect / Red-style encoding is **Future plans** (§12), not a prerequisite for the first Postgres Location.

6. **Package split.** Option **C** (hybrid). See §9.

7. **Tuple / column order — reading note.** There is no “insertion-ordered Hash” in the Raku language today. Ordinary hashes deliberately do **not** preserve order; since Rakudo 2018.05, iteration order is randomised per invocation. Read:

   - [Hashes and maps](https://docs.raku.org/language/hashmap) — documents that key/value order cannot be relied on.
   - [class Hash](https://docs.raku.org/type/Hash) — same guarantee of randomised order.
   - [`Hash::Ordered`](https://raku.land/zef:lizmat/Hash::Ordered) (what TOP already uses for `Tuple`) — ordered Associative; also discussed for core as `is Hash::Ordered` in [rakudo#5779](https://github.com/rakudo/rakudo/pull/5779).

   So the earlier “rely on insertion-ordered Raku hashes” alternative was a misstatement of the language. Practical choices are still `Hash::Ordered` (or equivalent) and/or explicit field order on the Table. **Default lean: keep `Hash::Ordered` for Tuple** unless we later adopt a core ordered-hash form. Exact choice can stay soft until Tuple is implemented; the reading list above is the answer to “where do I read about this?”

8. **Location absorbs TOP Storage; Source/Destination work on tables.** No separate Storage plugin tree. Pipeline Source/Destination yield/sink rows for table locations (streaming-shaped I/O first); Relation is the live Table object face on the same backends (§4.1; prerequisites).

9. **CSV is a Location package; do not graduate CSVdemo.** Production CSV tables live in `Qwiratry-Location-CSV`. Core `CSVdemo` stays a demo Format only. WithBorders depends on Location::CSV and loads box-drawing characters via that Location (same mechanism as TOP) — no static hash (§5.2, §5.3, §6.3).

## 11. Immediate next steps (when we start coding)

1. Land [Qwiratry-TOP-Prerequisites.md](Qwiratry-TOP-Prerequisites.md): **streaming-shaped Location I/O first** (Source/Destination on tables via row Iterators), then Relation + anonymous Table, sharing row paths.
2. Skeleton: FieldMode + Memory Location + minimal Table (anonymous-first) / optional Database.
3. Port a few Memory + FieldMode tests from Raku-TOP.
4. Add HalfHuman Format; wire one end-to-end File → Parse → Table → Render example.
5. Keep streamable-first / materialise-when-necessary for CSV and Postgres (§10.3).
6. `Qwiratry-Location-CSV` sibling; then WithBorders Format depending on it for box-drawing load.
7. Postgres Location with Postgres-specific SQL only; defer Red-style multi-dialect (§12).

## 12. Future plans

Ideas that should not block the first TOP-on-Qwiratry slice (Memory + HalfHuman + Postgres-only SQL).

### 12.1 Red-style multi-dialect SQL encoding

When we support more than Postgres (SQLite, MySQL, …), follow [Red ORM’s architecture](https://fco.github.io/Red/tutorials/architecture.html): keep a driver-neutral AST of the query intent; each DB Location/driver **translates** that AST to its dialect and runs it (Red: `ResultSeq` → `Red::AST` → `Red::Driver.translate`).

Qwiratry hook (likely Walker / Plan for table+SQL origins): in-memory Walkers execute the Query AST directly; SQL Location drivers translate. Shared SQL encoding can stay near core; dialect quirks stay in Location packages. Until then, Postgres may emit Postgres SQL directly.

### 12.2 Other later items (already noted elsewhere)

- Additional DBIish Locations (SQLite, MySQL) — Accept / when someone needs them.
- Spreadsheet / `.ods`, HTML, richer tree formats — TOP matrix “Make/Accept”.
- Full streaming adoption per `Streaming-Qwiratry-Proposal.rakudoc`.
- Predicate pushdown once multi-dialect translate exists.

---

*Source trees consulted: `Raku-TOP/main` (TOP, FieldMode, Formatter, Parser, Database::Storage::{Memory,CSV,Postgres}); Qwiratry core (Format, Location, Table/Schema, Operator::IO, Streaming proposal, Developing TODO).*
