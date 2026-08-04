# Streaming Qwiratry Proposal - v2

*Follow-on design notes: walkable / push / pull, Raku mappings, and push streaming.*

Continues from [Streaming-Qwiratry-Proposal.md](Streaming-Qwiratry-Proposal.md)
(which covers the original pull streaming proposal and the Streaming Rename map).

# Streaming Thoughts

We should have two language models (stream/walk), and three APIs (walkable/push/pull).

## Transformers

Transformers should support attributes; these can fulfil the role that accumulators fill in XSLT. They probably already do, but we should check. Transformers should support multicontext; see below.

## Molds

Molds should support the following characteristics:

* Context node ($_ or $/ or something)
* Sibling Limit: This is how far it's permitted to look at previous/next siblings before throwing an error. This is to help control memory consumption (for streaming behaviour). These are preceding-limit and following-limit.

  * Default: Inf. This is Walkable.
  * 0: This is like Streaming mode in XSLT
  * 1: This allows the immediately preceding/following sibling to be accessed, but no further (following-limit)
  * n: Any other number can be put here; I haven't seen a use for it, but someone might have one someday.
  * Note that nodes can always access ancestors, descendants, and attributes -- the above restrictions are for siblings.
* Multicontext:

  * Molds can be marked as multi-input or multi-output. This is to facilitate the processing of multiple streams in parallel.
  * If a mold/transformer marks itself multi-input, then we need to handle this as multiple contexts somehow; not sure how we do this; probably with extra parameters to the mold. .
* Questions

  * How do we integrate molds (or maybe mold protos) with the walkable/push/pull capabilities/APIs

The smart thing to do as a developer is to have a mold that's in streaming mode, and then it calls out to other molds (with different names) that are not in streaming mode.

## Operators

We should be looking at having the walkable/push/pull APIs being capabilities, rather than roles; we should probably have the base one just throw exceptions, and then work from there. Also, there should be a fourth capability, "streaming", which is true if push or pull is true.

## Future thoughts

* Consider allowing markers on loops, etc, to indicate that the loop items should be processed in order (cf. xsl:iterate vs. xsl:for-each) * Possibly also worthwhile being able to mark that things can be done in parallel in groups

# Raku Push, Pull, and Walkable

A map of existing Raku features onto the three sectors used elsewhere in this document. Empty cells mean that feature is not really that model.

* **Push** — producer drives (Supply / SAX-ish).
* **Pull** — consumer drives (`pull-one` / StAX-ish).
* **Walkable** — whole value in hand, then navigate (DOM-ish).

Grammars are split into input vs output rows below (walkable input; push-like actions / walkable `Match`).

**Keep for now:** Queues, Grammars (input), Grammars (output). Other rows are still under discussion.


| Thing                          | Push                                                                     | Pull                                                                                            | Walkable                                                                              | Comments                                                                                                                              |
| -------------------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Equivalent XML model           | SAX                                                                      | StAX                                                                                            | DOM                                                                                   |                                                                                                                                       |
| Queues                         | `Channel.send`                                                           | `Channel.receive`                                                                               |                                                                                       | Converts Push to Pull                                                                                                                 |
| Grammars (input)               | *Would like to have somethng here for eg. network protocols*             |                                                                                                 | Input is a whole`Str`                                                                 |                                                                                                                                       |
| Grammars (output)              | Action methods (Grammar calls actions)                                   |                                                                                                 | Result is a`Match` tree                                                               |                                                                                                                                       |
| Multi-value streams            | `Supplier.emit`, `Supply` + `tap` / `react`/`whenever`                   | `Iterator.pull-one`, `Seq`, `gather`/`take`                                                     | `List` / `Array` after `.list` / `.eager`                                             | Dual protocols for a stream of many values: push emits, pull asks. Bridges (pump / Channel) convert between them.                     |
| Sequences                      |                                                                          | `Seq`, `Iterator`, `gather`/`take`                                                              | `List`, `Array` (eager / `.list`)                                                     | Overlaps Multi-value streams (pull/walkable); may fold into that row later.                                                           |
| Reactive streams               | `Supply`, `Supplier`, `tap`, `react`/`whenever`                          | (via bridges, e.g. Channel / draining)                                                          |                                                                                       | Overlaps Multi-value streams (push); may fold into that row later.                                                                    |
| Single async value             | `Promise.then` (callback)                                                | `await`                                                                                         | kept/broken result value                                                              | One-shot, not a multi-value stream. Under discussion.                                                                                 |
| Text I/O                       | e.g.`Supply` from async/react I/O                                        | `.lines`, `.get`, read-ish iterators                                                            | `.slurp`, whole-buffer reads                                                          | Under discussion.                                                                                                                     |
| Associatives / positionals     |                                                                          | iterating`.iterator` / `.kv` etc.                                                               | `Hash`, `Map`, `Array` as complete structures                                         | Under discussion.                                                                                                                     |
| Feed operators                 |                                                                          |                                                                                                 | `==>` (forward feed), `<==` (backward feed)                                           | Pipeline composition: chains whole-value stages left-to-right (or right-to-left). Each stage materializes before the next starts.     |
| Qwiratry I/O (input)           |                                                                          | Operators receive upstream chunk streams as`Iterator` input to `parse-pull` / `render-pull` | Operators receive whole values via`read-walkable` / `parse-walkable` / `render-walkable` / `write-walkable`               | This row is about what each I/O operator accepts from the previous stage.                                                             |
| Qwiratry I/O (output)          | Destination operators push chunks into a sink via`write-chunk` / `close` | Source / parse / render operators pass chunk streams onward as`Iterator`                        | Source / parse / render / destination operators pass whole values onward              | This row is about what each I/O operator hands to the next stage.                                                                     |
| Qwiratry query (input)         |                                                                          | Query operators receive upstream data as`QueryIterator` / lazy `Seq`                            | Query entry points may receive already-materialized origins                           | Query operators themselves are fundamentally pull/lazy on input.                                                                      |
| Qwiratry query (output)        |                                                                          | Query operators pass lazy results onward as`QueryIterator` / `select-seq`                       | Pipeline boundaries use`seq-to-pipeline-value` to hand callers a `List` / whole value | Internal chaining stays pull; only the boundary to ordinary callers becomes walkable.                                                 |
| Qwiratry transformers (input)  |                                                                          | Transformers can consume lazy query results / iterators one item at a time                      | Transformers can consume already-built trees / tables / hashes                        | Needs checking against current implementation, but conceptually transformers should be able to accept either pull or walkable inputs. |
| Qwiratry transformers (output) |                                                                          | Transformers can yield lazy transformed items onward                                            | Transformers can return a fully transformed value / structure                         | Likely analogous to query output: internal chaining can stay lazy, while ordinary callers may prefer a whole transformed result.      |
| Hyper / race                   |                                                                          |                                                                                                 | Parallel over a complete (or sliced) input; not a stream protocol                     | Under discussion.                                                                                                                     |

## Model converters

How to convert from one model (source / column) into another (destination / row).
Cells name what **Raku already provides**.


| Destination\\ Source | Push →        | Pull →                                   | Walkable →          |
| ---------------------- | ---------------- | ------------------------------------------- | ---------------------- |
| → Push              | *(same model)* | Channel +`Channel.Supply` / Supplier pump | `Supply.from-list`   |
| → Pull              | Channel        | *(same model)*                            | `.iterator` / `.Seq` |
| → Walkable          | `Supply.list`  | `.list` / `.eager`                        | *(same model)*       |

**Qwiratry should make** (helpers / typed bridges beyond bare Raku):

* A reusable **Pull → Push** pump that turns an `Iterator` (especially text-chunk iterators) into a `Supply` via `Supplier`, with clear `done` / error behaviour.
* A reusable **Push → Pull** adapter that exposes a `Supply` as an `Iterator` (likely `Channel`-backed), so existing pull parse/render paths can consume push sources without rewriting the query core.
* Thin result roles or types that mark **text-chunk streams** vs **record/value streams**, so destination/parse do not confuse a `Seq` of hashes with an `Iterator` of `Str` chunks.
* Operator-level conversion policy: when adjacent I/O stages disagree (push vs pull vs walkable), choose a named converter instead of ad-hoc `~~ Iterator` checks.
* Optional **Push → Walkable** / **Walkable → Push** helpers aimed at adaptor boundaries (whole document ↔ `Supply`), so format authors are not inventing accumulation each time.

# Push Streaming for Qwiratry

This section sketches a possible push-capable extension for Qwiratry. The
current `0.10.0` implementation is fundamentally walkable + pull, with one
push-ish edge already present in destination sinks.

The obvious Raku building blocks are `Supply` and `Supplier`:

* `Supply` is the push stream observed by consumers.
* `Supplier` is the producer handle that emits values into a `Supply`.

That suggests the following rough shape for a future push API family:


| Capability      | Possible Qwiratry surface                                                                          | Raku basis                                             |
| ----------------- | ---------------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| ParsePush       | `parse-push(Supply:D $chunks, *%options --> Supply:D)`                                             | `Supply` in, `Supply` out                              |
| RenderPush      | `render-push(Mu $data, Associative :%options --> Supply:D)`                                        | often built by draining a pull source into a`Supplier` |
| SourcePush      | `read-push(Str:D $location --> Supply:D)`                                                          | async / callback / socket input wrapped as a`Supply`   |
| DestinationPush | `open-sink-push(Str:D $location --> Mu)` or `write-push(Str:D $location, Supply:D $chunks --> Mu)` | sink object or`Supply` consumer                        |

Some observations:

* `DestinationPush` is the least speculative piece, because current sinks
  already accept pushed chunks via `write-chunk`.
* `SourcePush` is the natural fit for sockets, callbacks, HTTP bodies, and
  protocol handlers that already arrive as events.
* `ParsePush` and `RenderPush` would probably work best as `Supply`-to-`Supply`
  adaptors, though internally they might still bridge through pull logic in a
  first implementation.

Bridging is likely to matter more than purity:

* **Push -> Pull:** buffer with `Channel`, or expose a pull `Iterator` view over
  arriving push events.
* **Pull -> Push:** pump `pull-one` results into a `Supplier.emit` loop.
* **Push -> Walkable:** accumulate all pushed values, then hand over one
  materialized structure.
* **Walkable -> Push:** emit one value, or emit a sequence derived from the
  whole value.

This means Qwiratry does not necessarily need a fully separate push-only query
engine. A practical first step could be:

1. keep the current pull query core;
2. add push-capable source / destination / maybe parse / render surfaces;
3. bridge push into pull at the edge using `Supply`/`Supplier` plus a queue or
   pump;
4. only later decide whether native push query execution is worthwhile.

Open question: whether push should be expressed primarily as `Supply`, as
`Supplier`-backed sinks/sources, or as both. My current guess is:

* expose **`Supply`** at public stream boundaries;
* use **`Supplier`** internally when Qwiratry itself is the producer;
* keep sink objects where explicit lifecycle (`write-chunk`, `close`) matters.

# Data Models

Two Raku stream shapes that matter for push vs pull:

```
Supplier  ────emit────▶  Supply  ─────tap────▶ Consumer
Iterable  ──iterator──▶ Iterator ──pull-one──▶ Consumer
```
