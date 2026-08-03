# Streaming Qwiratry Proposal

*Proposed interfaces for streaming-capable parsers, renderers, sources, and destinations*

# Overview

This document proposes a streaming extension to Qwiratry's existing format and location interfaces.

The goal is to let parsers, renderers, sources, and destinations operate incrementally when that is useful, while preserving the current extension model and keeping existing implementations working unchanged.

The proposal is intentionally conservative:

* It keeps `Qwiratry::Format` and `Qwiratry::Location` as the discovery and dispatch points.
* It keeps `Parse`, `Render`, `Source`, and `Destination` as the primary implementation concepts.
* It treats streaming as an optional capability, not a replacement for the current whole-value interfaces.
* It follows Qwiratry's existing pull-based style, using `Iterator` rather than callback-driven or push-driven APIs.

# Status

Streaming support landed in Qwiratry `0.10.0`. This document remains the design rationale for the optional pull-based roles and operator fallback rules.

# Motivation

Qwiratry already has a strong incremental execution model in its query layer. Results are naturally exposed through pull-based iteration, especially via `QueryIterator`.

However, the current format and location boundaries are whole-value oriented:

* Parsers accept a complete `Str`.
* Renderers produce a complete `Str`.
* Sources return a complete `Str`.
* Destinations consume a complete value and return it for pass-through.

This is simple and useful, but it forces materialization at I/O boundaries even when the external representation or transport could be handled incrementally.

Streaming support would make Qwiratry a better fit for:

* Large files that should not be loaded fully into memory.
* Network responses whose bodies can be consumed incrementally.
* Row- or record-oriented formats such as CSV, NDJSON, and event streams.
* Pipelines where query evaluation, rendering, and output should begin before the whole input has been consumed.

# Design Goals

* Preserve the current discovery model and naming conventions.
* Preserve backward compatibility for existing format and location modules.
* Match Qwiratry's pull-based execution style.
* Avoid introducing a second parallel hierarchy of streaming-only factories or operator classes unless later experience shows that this is necessary.
* Allow partial adoption, so a backend can be streaming-capable on only one side of the pipeline.

# Non-Goals

* This proposal does not require all queries to become stream-safe.
* This proposal does not try to solve every whole-document format with a single streaming strategy.
* This proposal does not require `QueryIterator` itself to become the transport abstraction for raw bytes or text chunks.
* This proposal does not standardize binary streaming in the first step. The initial surface is text-oriented, matching the current `Str`-based interfaces.

# Current Surface

Today the format and location contracts are:

```raku
class Qwiratry::Format::Base::Parse {
    method parse(Str $input-string --> Mu) { ... }
}

class Qwiratry::Format::Base::Render {
    method render(Mu $data, Associative :%options --> Str) { ... }
}

class Qwiratry::Location::Base::Source {
    method read(Str $location --> Str) { ... }
}

class Qwiratry::Location::Base::Destination {
    method write(Str $location, Mu $content --> Mu) { ... }
}
```

The query layer is already pull-based, but adaptor operators currently materialize values at key points. In particular, rendering currently normalizes lazy sequences to a list before handing them to a renderer.

This means a streaming-capable renderer cannot be useful without a matching execution path through the operators.

# Recommended Interface Shape

The recommended design is to add *optional streaming capabilities* on top of the existing classes.

## Streaming Format Capabilities

```raku
role Qwiratry::Format::Base::StreamingParse {
    method parse-chunks(Iterator:D $chunks, *%options --> Mu) { ... }
}

role Qwiratry::Format::Base::StreamingRender {
    method render-chunks(
        Mu $data,
        Associative :%options
        --> Iterator:D
    ) { ... }
}
```

`parse-chunks` accepts a pull-based stream of text chunks and returns either:

* A single parsed value.
* A lazy `Seq` or `Iterator` of parsed top-level values.

`render-chunks` accepts normal Qwiratry data and returns a pull-based stream of text chunks.

## Streaming Location Capabilities

```raku
role Qwiratry::Location::Base::StreamingSource {
    method read-chunks(Str:D $location --> Iterator:D) { ... }
}

role Qwiratry::Location::Base::StreamingDestination {
    method open-sink(Str:D $location --> Mu) { ... }
}
```

`read-chunks` returns a pull-based stream of `Str` chunks from the given location.

`open-sink` returns an object representing an incremental destination. The sink should support operations such as:

```raku
class ExampleSink {
    method write-chunk(Str:D $chunk --> Nil) { ... }
    method close(--> Nil) { ... }
}
```

This sink-based shape is preferred over a single `write-chunks` method because it fits pass-through pipelines better and gives explicit control over resource lifecycle.

# Why This Shape Fits Qwiratry

## Reuses Existing Discovery

Qwiratry already resolves implementations through:

```raku
Qwiratry::Format.make(:type<Parse>, :format<JSONdemo>)
Qwiratry::Format.make(:type<Render>, :format<JSONdemo>)

Qwiratry::Location.make(:type<Source>, :location<input.csv>)
Qwiratry::Location.make(:type<Destination>, :location<output.csv>)
```

The proposed design does not change that. A format or location implementation is still discovered in the same way. Streaming is simply detected as an additional capability on the returned implementation object.

## Matches Pull-Based Execution

Qwiratry's natural incremental abstraction is a pull iterator. That makes `Iterator` the best fit for streaming transport:

* It is consistent with `QueryIterator`.
* It allows lazy composition.
* It keeps backpressure simple: the consumer pulls when ready.
* It avoids introducing callback or reactive machinery where the rest of Qwiratry does not currently use it.

## Preserves Backward Compatibility

Existing formats and backends can continue to implement only:

```raku
method parse(Str $input-string --> Mu)
method render(Mu $data, Associative :%options --> Str)
method read(Str $location --> Str)
method write(Str $location, Mu $content --> Mu)
```

Nothing in this proposal requires those implementations to change.

# Operator Behavior

The streaming interfaces are only useful if the adaptor operators preserve streaming when possible.

## Source Operator

When a source implementation does `StreamingSource`, and the downstream consumer can use streamed input, `SourceOperator` should use `read-chunks`. Otherwise it should fall back to `read`.

## Parse Operator

When its format implementation does `StreamingParse` and its input is chunked, `ParseOperator` should call `parse-chunks`. Otherwise it should call `parse`.

## Render Operator

When its format implementation does `StreamingRender`, `RenderOperator` should avoid forcing upstream lazy data into a list. Instead it should pass the upstream value through in its existing lazy form when safe to do so.

This is the most important operator change in the proposal. Without it, the renderer would remain a materialization boundary even if it supports streaming.

## Destination Operator

When its location implementation does `StreamingDestination`, and the upstream value is a text chunk iterator, `DestinationOperator` should stream those chunks through a sink object rather than first assembling them into one `Str`.

# Capability Detection and Fallback

Streaming should be optional and discovered dynamically.

At a high level:

```raku
my $source = Qwiratry::Location.make(:type<Source>, :location($loc));

if $source ~~ Qwiratry::Location::Base::StreamingSource {
    my $chunks = $source.read-chunks($loc);
    ...
}
else {
    my $text = $source.read($loc);
    ...
}
```

Equivalent capability checks should be used for parsers, renderers, and destinations.

Fallback rules should be simple:

* If both sides of a boundary support streaming, use the streaming path.
* If either side does not support streaming, adapt through the existing whole-value method.
* If an implementation exposes both whole-value and streaming methods, both must be semantically consistent for equivalent inputs.

# Expected Return Shapes

The following table summarizes the intended shapes:


| Component   | Existing method | Streaming method | Intended payload shape                     |
| ------------- | ----------------- | ------------------ | -------------------------------------------- |
| Source      | `read`          | `read-chunks`    | `Iterator` of `Str` chunks                 |
| Parser      | `parse`         | `parse-chunks`   | one value, or lazy stream of parsed values |
| Renderer    | `render`        | `render-chunks`  | `Iterator` of `Str` chunks                 |
| Destination | `write`         | `open-sink`      | sink object receiving`Str` chunks          |

# Example End-to-End Flow

For a row-oriented format, a streaming-capable pipeline could behave like this:

```raku
my $chunks   = $source.read-chunks('input.ndjson');
my $records  = $parser.parse-chunks($chunks);
my $filtered = execute($query, :origin($records));
my $output   = $renderer.render-chunks($filtered, :%options);
my $sink     = $destination.open-sink('output.ndjson');

for $output -> $chunk {
    $sink.write-chunk($chunk);
}
$sink.close;
```

This is intentionally schematic. The actual operator pipeline should hide most of these details from ordinary users.

# Relationship to `QueryIterator`

`QueryIterator` is the right abstraction for incremental query results, but it should not be forced to represent transport-layer chunk streams.

Reasons:

* Chunk streams do not need traversal `Context`.
* Text transport and query semantics are different layers.
* Plain `Iterator` is simpler for sources, renderers, and sinks.

The proposal therefore uses ordinary pull iterators for chunk transport and keeps `QueryIterator` for query result production.

# Destination Pass-Through Semantics

Current destinations return the content that was written, which makes destination operators observable at the end of a pipeline.

This becomes trickier with one-shot iterators:

* If the destination fully consumes an iterator, the original iterator may no longer be reusable.
* Returning the same iterator after consumption may be misleading.

The recommended behavior is:

* Prefer sink-driven streaming inside the operator implementation.
* Preserve the current pass-through idea where practical.
* If necessary, document that streamed destination pass-through is single-consumer unless explicitly buffered or teed.

This is an area where implementation experience may refine the exact contract.

# Scope Limits

This proposal is best suited to formats whose top-level structure can be handled incrementally, such as:

* CSV rows
* NDJSON records
* line-oriented logs
* chunked text protocols

It is less straightforward for formats or queries that require whole-document knowledge before any meaningful query can run, for example:

* cases where parent or sibling relationships are only knowable after full materialization
* formats whose grammar forces arbitrary lookahead before producing any top-level result
* queries that depend on whole-document ordering or root-level aggregation

In such cases, implementations should be free to support only the current whole-value interface or to expose a streaming parser that still buffers internally before producing a final value.

# Migration Strategy

A staged rollout is recommended:

* 1. Add the new streaming roles or capability methods to the base documentation and developer guidance.
* 2. Teach adaptor operators to preserve streamed values when both upstream and downstream support them.
* 3. Add one or two reference implementations, such as a file source that reads chunks and a line-oriented demonstration format.
* 4. Add tests covering streaming and fallback composition.
* 5. Consider binary-oriented extensions only after the text-oriented version has settled.

# Testing Recommendations

Tests for streaming support should prove:

* Discovery and loading still work through `Qwiratry::Format` and `Qwiratry::Location`.
* Whole-value implementations continue to behave exactly as before.
* A streaming source composes with a non-streaming parser through fallback.
* A non-streaming source composes with a streaming parser through fallback.
* A streaming renderer does not force a lazy upstream sequence into an eager list when the pipeline stays on the streaming path.
* Streamed destinations write the complete output in correct order.
* Error behavior remains attributable to the correct operator type and location or format.

# Alternatives Considered

## Separate Streaming Factory Types

One possible design would introduce separate types such as:

```raku
Qwiratry::Format.make(:type<ParseStream>, ...)
Qwiratry::Format.make(:type<RenderStream>, ...)
```

This was rejected as the primary proposal because it creates a parallel discovery vocabulary, duplicates concepts that already exist, and makes the extension model harder to learn.

## Callback-Based APIs

Another option would be to use callbacks rather than pull iterators.

This was rejected because it does not match Qwiratry's existing incremental style as well as ordinary `Iterator` does.

# Recommendation

Qwiratry should adopt optional pull-based streaming capabilities on top of the existing format and location classes.

The recommended public surface is:

```raku
role Qwiratry::Format::Base::StreamingParse {
    method parse-chunks(Iterator:D $chunks, *%options --> Mu) { ... }
}

role Qwiratry::Format::Base::StreamingRender {
    method render-chunks(Mu $data, Associative :%options --> Iterator:D) { ... }
}

role Qwiratry::Location::Base::StreamingSource {
    method read-chunks(Str:D $location --> Iterator:D) { ... }
}

role Qwiratry::Location::Base::StreamingDestination {
    method open-sink(Str:D $location --> Mu) { ... }
}
```

This design is small, consistent with the existing architecture, compatible with current extensions, and strong enough to support genuinely incremental I/O where the surrounding query semantics allow it.

# Streaming Rename

This rename has been applied. The table below remains as the historical
vocabulary map from the original `0.10.0` streaming surface to the
walkable / pull / push names now used in code.

The goal is a **three-way** I/O-boundary breakdown:

* **Walkable** — whole-value adaptors. The consumer works with a complete
  payload (for example a full `Str`, or a fully assembled structure). This is
  the original `parse` / `render` / `read` / `write` family (DOM-ish).
* **Pull** — consumer-driven chunk adaptors. The consumer pulls an `Iterator`
  of text chunks (StAX-ish). In `0.10.0` this is the `*-chunks` /
  `Streaming*` family.
* **Push** — producer-driven chunk adaptors. The producer emits into a
  `Supply` / sink-style API (SAX-ish). Not implemented in `0.10.0` yet except
  insofar as destination sinks already accept pushed chunks via `write-chunk`.

`Walkable` here is I/O-boundary terminology for whole-value transfer. It is not
the same thing as query-layer navigation over an already-loaded structure, even
though both can feel “incremental” to a caller.

**Umbrella:** “streaming” (as a capability flag) means push **or** pull is
available; walkable is the non-streaming whole-value path.


| Old name                                         | New name                                        | Notes                                                                   |
| -------------------------------------------------- | ------------------------------------------------- | ------------------------------------------------------------------------- |
| `Qwiratry::Format::Base::Parse`                  | `Qwiratry::Format::Base::ParseWalkable`         | Whole-value parse contract                                              |
| `Parse.parse`                                    | `ParseWalkable.parse-walkable`                  | Accepts a complete`Str`                                                 |
| `Qwiratry::Format::Base::StreamingParse`         | `Qwiratry::Format::Base::ParsePull`             | Optional pull-chunk parse capability                                    |
| `StreamingParse.parse-chunks`                    | `ParsePull.parse-pull`                          | Accepts`Iterator` of `Str` chunks                                       |
| *(none — planned)*                              | `Qwiratry::Format::Base::ParsePush`             | Optional push-chunk parse capability                                    |
| *(none — planned)*                              | `ParsePush.parse-push`                          | Accepts`Supply` (or equivalent) of `Str` chunks                         |
| `Qwiratry::Format::Base::Render`                 | `Qwiratry::Format::Base::RenderWalkable`        | Whole-value render contract                                             |
| `Render.render`                                  | `RenderWalkable.render-walkable`                | Produces a complete`Str`                                                |
| `Qwiratry::Format::Base::StreamingRender`        | `Qwiratry::Format::Base::RenderPull`            | Optional pull-chunk render capability                                   |
| `StreamingRender.render-chunks`                  | `RenderPull.render-pull`                        | Produces`Iterator` of `Str` chunks                                      |
| *(none — planned)*                              | `Qwiratry::Format::Base::RenderPush`            | Optional push-chunk render capability                                   |
| *(none — planned)*                              | `RenderPush.render-push`                        | Produces`Supply` of `Str` chunks                                        |
| `Qwiratry::Location::Base::Source`               | `Qwiratry::Location::Base::SourceWalkable`      | Whole-value source contract                                             |
| `Source.read`                                    | `SourceWalkable.read-walkable`                  | Returns a complete payload                                              |
| `Qwiratry::Location::Base::StreamingSource`      | `Qwiratry::Location::Base::SourcePull`          | Optional pull-chunk source capability                                   |
| `StreamingSource.read-chunks`                    | `SourcePull.read-pull`                          | Returns`Iterator` of `Str` chunks                                       |
| *(none — planned)*                              | `Qwiratry::Location::Base::SourcePush`          | Optional push-chunk source capability                                   |
| *(none — planned)*                              | `SourcePush.read-push`                          | Returns`Supply` of `Str` chunks                                         |
| `Qwiratry::Location::Base::Destination`          | `Qwiratry::Location::Base::DestinationWalkable` | Whole-value destination contract                                        |
| `Destination.write`                              | `DestinationWalkable.write-walkable`            | Consumes a complete payload                                             |
| *(none — planned)*                              | `Qwiratry::Location::Base::DestinationPull`     | Optional pull-chunk destination capability                              |
| *(none — planned)*                              | `DestinationPull.write-pull`                    | Consumes`Iterator` of `Str` chunks                                      |
| `Qwiratry::Location::Base::StreamingDestination` | `Qwiratry::Location::Base::DestinationPush`     | Optional push/sink destination capability                               |
| `StreamingDestination.open-sink`                 | `DestinationPush.open-sink-push`                | Returns a chunk sink (`write-chunk` / `close`); caller pushes chunks in |

Operator selection under the new names: when both sides of a boundary share
push or both share pull, prefer that streaming path; otherwise fall back
toward walkable (joining, materializing, or bridging as needed). Push↔pull
mismatches may use an edge pump or queue rather than forcing walkable.
