# Qwiratry: A Raku Architecture for Queries  

# 1. Introduction

## 1.1 Purpose

Qwiratry defines a **Raku architecture for declarative queries and flexible data walking**, suitable for trees, tables, relational structures, logic-programming environments, and anything reasonably structured and traversable.

It separates:
- **what** to query (`Query`)
- **how** to walk the data (`Walker`)
- **how results are produced incrementally** (`QueryIterator`)
- and optionally **how output is transformed** (Transformers + Templates)

This provides a general-purpose query execution pipeline that works across different data models without forcing a single semantic interpretation of a query.

## 1.2 High-Level Principles

1. **Separation of concerns**  
   A `Query` describe intent; a `Walker` interprets and executes; a `QueryIterator` yields results.

2. **Reusability and composability**  
   Walkers can produce multiple iterators; queries can be reused and optimised; traversal strategies can be composed.

3. **Optimisation planning**  
   Walkers may analyse or rewrite queries before executing them.

4. **Backtracking and multi-phase execution**  
   Walkers may execute in one or more passes, support backtracking, or build fixed-point computations.

## 1.3 Relevant Domains

Subclasses can specialise for:

- Tree walking (ASTs, XML, JSON, Match trees, document structures)  
- Table querying (database/spreadsheet rows, CSVs, table-like or positional structures)  
- Logic programming (goals, unification, backtracking)  
- Hybrid or pipeline-based systems where traversal and semantics diverge

Streaming-based architectures should also be workable.  

Note that, as far as new syntax goes, only Transformers are provided at this level.  The other features (eg. the query operators) will be provided by the subclasses.  

# 2. Core Architecture

## 2.1. Overview: Roles and Architecture

Qwiratry is a Raku framework for declarative queries, flexible data walking, and structured transformation.  

It separates:
* `Query`: what to query
* The **Walker** Group: How to walk the data.  Defines traversal strategies and execution plans.  
* The **Per-traversal** group: A walker might do multiple traversals.  This includes how results are produced incrementally.  This is roles instantiated per traversal to manage mutable state and incremental results.
* The **Strategy** Group: provides element-level behaviour and reusable processing logic
* The **Transformer** Group: declarative specification of data transformations using templates.  

The architecture is divided into five main groups of roles:

### 2.1.1 Query Group

The **Query Group** encapsulates all roles that define *what the user wants to find or match* in the data. Queries are declarative, immutable, and introspectable, allowing multiple traversal strategies or transformers to interpret the same query safely and efficiently.  

**Current Roles:**

- **Query** – describes a search, pattern, or constraint.  
  - Composable and reusable across multiple walkers or iterators.  
  - Supports introspection, normalisation, and optimisation before execution.  

**Key Principles:**

- **Declarative Semantics:** Queries specify *what* to find, not *how* to find it.  
- **Reusability:** The same query object can be shared across different walkers, transformers, or execution plans.  
- **Extensibility:** New query roles can be added to support additional semantics, constraints, or domains.  

### 2.1.2. Walker Group

* **Walker** – Encapsulates *how* a query is executed over a data structure. Determines traversal strategy, ordering, caching, and backtracking behaviour. Produces `QueryIterator` instances.  
* **Walker::Plan** – Represents a precomputed execution strategy for a specific query and root data structure. Enables multiple iterators without re-planning, supports introspection, and allows optimisation or multi-phase execution.

**Purpose:** Separating the Walker from the Query and the Plan enables multiple data models to execute the same query differently and allows traversal strategies to be reused.

Concrete implementations include:  
`Tree::Walker::DFS`, `Table::Walker::IndexScan`, `Logic::Walker::Backward`, etc.

### 2.1.3. Strategy Group

* **Strategy** – Defines element-level behaviour during traversal. Handles match processing, pruning, rewrites, and multi-pass logic. Walker-agnostic and reusable across data models.  
* **ControlSignal** – Enumeration of signals (`NO_REWRITE`, `REWRITE_IMMEDIATE`, `REWRITE_DEFERRED`, `SKIP_ELEMENT`, `STOP_TRAVERSAL`, `FINAL_RESULT`) that communicate decisions from the Strategy to the Walker.

**Purpose:** Strategies provide pluggable, reusable behaviour for element processing, allowing Walkers to remain generic while supporting specialised logic.

### 2.1.4. Transformer Group

* **Transformer** – Declarative object for transforming input data (trees, tables, or other hierarchical structures). Separates traversal, selection, and action, leveraging Walkers for traversal and Queries for node selection. Supports streaming and multi-phase application.  
* **Template** – Match-and-action rules within a Transformer. Templates specify how nodes are selected (`when`) and how output is produced (`do`). Templates can include traits like `:streaming` and can be prioritised and ordered for deterministic behaviour.

**Purpose:** Transformers allow structured manipulation and derivation of data. By combining Walkers, Queries, and Templates, they enable transformations similar in style to XSLT but operating over Raku data structures.

### 2.1.5. Per-Traversal Group

* **Context** – Mutable storage used during a traversal to hold counters, memoisation, queues, and intermediate state. Shared between the Walker and Strategy.  
* **QueryIterator** – Incremental, pull-based stream of query results. Maintains traversal state, supports lazy evaluation and backtracking.

**Purpose:** These roles are instantiated fresh for each traversal or iterator. They maintain the mutable state necessary to produce results and coordinate complex traversal or transformation behaviours.

### 2.1.6. Comparison Table

| Group                | Whole Walk/Data Level | Per-traversal          | Node Level                               | Other                       |
|----------------------|-----------------------|------------------------|-----------------------------------------|-----------------------------|
| Query Group           | `Query`                |                        |                                         |                             |
| Walker Group          | `Walker`, `Walker::Plan` | `Context`, `QueryIterator` | `Strategy`                                 | `ControlSignal`               |
| Transformer Group     | `Transformer`          |                        | `Template`                                 | `Wrapper`    |

---

# 3. Role Specifications

## 3.1 The **Query** Group

### 3.1.1. Role `Query`

#### Purpose

`Query` encapsulates *what the user wants* —patterns, constraints, filters — without specifying how they are executed. Queries must be **immutable**, **composable**, and **introspectable**.  This ensures they can safely be shared between multiple plans, walkers, or iterators without accidental mutation.  

#### Rationale

- Decouples intent from execution.  
- Enables reuse across walkers.  
- Allows optimisation, simplification, or normalisation prior to execution.

#### Definition

````raku
role Query {
    method matches(Mu:D $candidate --> Bool:D) { ... }
    method descriptor(--> Query::Descriptor)     { ... }
    method compose(&op, Query $other --> Query)  { ... }
}
````

#### Composability and Introspection

TODO

## 3.2. The **Walker** Group

Multiple classes participate in query execution:

* `Walker`: responsible for how to traverse the data structure. Calls hooks on Strategy at appropriate points.  Operates at the whole-database-structure level (`database`, `document`, etc), though this is quickly limited to the subset of the "database" defined in the query.  

* `Strategy`: responsible for what happens when elements are visited/matched/traversed. Controls rewrites, pruning, and multi-pass logic.

- `QueryMatch`: Represents a successful result of a `Query` against an element. Contains information needed for rewrites or analysis.

- `Context`: Mutable per-traversal storage for Strategy. Stores queues, counters, memoisation, accumulated results, or rewrite state. Persistent across all hooks.

- `ControlSignal`: Enum controlling traversal or rewrites: `NO_REWRITE`, `REWRITE_IMMEDIATE`, `REWRITE_DEFERRED`, `SKIP_ELEMENT`, `STOP_TRAVERSAL`. Lets Strategy communicate its decisions to the Walker.

- `Walker::Plan`: captures the *precomputed traversal strategy* for a given query and data shape. It can hold optimised visit orders, cached joins or path expansions, and any metadata that avoids recalculating traversal logic on each run. This lets a walker execute complex queries efficiently and consistently, even across different data sets or backends.

### 3.2.1 The `Walker` Role

#### Purpose

`Walker` encapsulates *how* a query is executed, including traversal strategy, ordering, backtracking, and optimisation planning. Walkers take a `Query` and produce a `QueryIterator`.

#### Capabilities

* **Single-pass** or **composite** traversal  
* **Multi-phase execution** (plan → rewrite → execute)  
* **Stateful caching** for repeated queries  
* **Reusable** to produce multiple iterators  
* **Backtracking** or lazy evaluation

#### Errors

If a Walker cannot interpret a Query, it throws `UnknownQueryElementException`.

#### Definition

````raku
role Walker does Iterable {
	##### Callable Methods

	# Plan an execution strategy based on the query (and optionally the data root)
	method plan(Query $query, Mu $root --> Walker::Plan) { ... }

	# Produce a QueryIterator for incremental results
	method iterator(Query $q) returns QueryIterator { ... }

	# Convenience method that calls .plan, and .iterator
	method start(Query $query, Mu:D $root --> QueryIterator) { ... }
	
	##### Hook Methods
	# Optional: hooks for extending Walker behaviour itself
	# (Strategy hooks cover element-level logic)
	method PRE-PASS(Context $ctx) { ... }
	method POST-PASS(Context $ctx) { ... }
}
````

#### Methods

TODO

### 3.2.2 The `Walker::Plan` Role

`Walker::Plan` encapsulates an optimised execution strategy derived from a `Walker` and a `Query`. It allows multiple incremental result streams to be produced without re-planning, supports introspection, and enables multi-phase execution.

#### Purpose

* Encapsulate an execution strategy for a specific `Query` (and optionally a root data structure).  
* Support introspection, debugging, and caching.  
* Produce multiple `QueryIterator` instances from the same plan.  
* Enable optimisation or adjustments without modifying the original `Walker`.

#### Definition

````raku
role Walker::Plan {

    # Produce a QueryIterator for this plan.
    method iterator(--> QueryIterator) { ... }

    # Return the Query that this plan represents.
    method query(--> Query) { ... }

    # Describe the execution strategy in human-readable form.
    method describe(--> Str) { ... }

    # Optional: allow tweaking or optimisation of the plan.
    method optimise(&modification) { ... }

    # Optional: return sub-plans if this is a composite/multi-phase plan.
    method subplans(--> @Walker::Plan) { ... }

    # Indicate whether the plan supports lazy execution or backtracking.
    method capabilities(--> Associative) { ... }
}
````

##### Rationale for Methods

* **iterator** – produce incremental results without re-planning.  
* **query** – introspection or reuse for other roots.  
* **describe** – debugging, profiling, or visualisation of the plan.  
* **optimise** – tweak the plan for performance or special cases.  `optimise` should return a new plan unless the modification is guaranteed safe to apply in-place. Walkers may choose their own mutability discipline.
* **subplans** – enable composite or multi-phase walkers.  
* **capabilities** – indicate capabilities to consumers, such as laziness or backtracking.  

#### Example Usage

````raku
my $walker = Tree::Walker::DFS.new;
my $plan   = $walker.plan($query, $root);   # returns Walker::Plan
my $iter1  = $plan.iterator;                # first result stream
my $iter2  = $plan.iterator;                # independent second result stream
say $plan.describe;
````

### 3.2.3 Role `Context`

The `Context` role provides **mutable, per-traversal state** for Walkers and Strategies.  
It is the shared workspace through which traversal hooks communicate, store intermediate results, manage queues or stacks, and coordinate rewrites or multi-phase logic. Unlike `Query` or `Walker`, which are immutable or reusable, a `Context` instance is created fresh for each traversal or plan execution.


#### Purpose

`Context` exists to:

- Hold **stateful information** during a traversal (e.g., counters, memo tables, visited sets).  
- Provide a **shared channel** between the Walker and the Strategy.  
- Maintain data needed across phases of a multi-pass traversal.  
- Support **backtracking**, **lazy evaluation**, and **rewrite scheduling**.  
- Accumulate results or diagnostics produced by Strategy hooks.

It is not intended to store the root or the query (those belong to the `Walker::Plan`), but rather the *evolving state* of an execution.

#### Lifecycle

- A Walker creates a `Context` instance at the start of a traversal pass.  
- The Walker and Strategy both receive the same `Context` in all hook calls (`before`, `on-match`, `after`, `finish`).  
- A new `Context` may be created for each pass in a multi-phase Walker, or the same one may be reused if the design requires fixed-point computation.

Contexts are **not** shared across separate traversals or separate result iterators unless explicitly designed by the Walker.

#### Role Definition

```raku
role Context {
    # Generic ancestor for all Context roles
}
```

### 3.2.4 Role `QueryIterator`

#### Purpose  

`QueryIterator` exposes a pull-based stream of results. It bridges the high-level Walker and the actual result production, maintaining execution state: stacks, queues, backtracking frames, cursor positions, and suspended computations for lazy execution.

### Definition

````raku
role QueryIterator does Iterator {
	# Return the next matching result, or Nil if exhausted
	method next(--> Mu) { ... }
}
````

### 3.2.5. The `Strategy` Role

The `Strategy` controls what happens when we visit a data element (node, table row, etc).  

#### Hooks

All hooks are optional: the walker will treat undefined returns as default behaviour.

Hooks are walker-agnostic: the same before, on-match, after, etc., work for trees, graphs, tables, documents, lists, and IR.

#### Definition

```
role Strategy {
	#------------------------------------------------------------------
	# Called before visiting an element (pre-visit)
	# Return a ControlSignal or Nil
	#------------------------------------------------------------------
	method before($element, Context $ctx --> ControlSignal|Nil) {...}
	
	#------------------------------------------------------------------
	# Called when a query matches an element
	# Can return a ControlSignal, a RewriteSpec, or Nil
	#------------------------------------------------------------------
	method on-match($element, Match $match, Context $ctx --> ControlSignal|RewriteSpec|Nil) { Nil }
	
	#------------------------------------------------------------------
	# Decide whether to follow a relation
	# Returns Bool
	#------------------------------------------------------------------
	method should-follow($origin, Relation $relation, Element $target, Context $ctx --> Bool) { True }
	
	#------------------------------------------------------------------
	# Called after visiting all relations of an element (post-visit)
	# Can return a ControlSignal, a RewriteSpec, or Nil
	#------------------------------------------------------------------
	method after($element, Context $ctx --> ControlSignal|RewriteSpec|Nil) { Nil }
	
	#------------------------------------------------------------------
	# Called after completing a full traversal
	# Returns a FinishResult object
	#------------------------------------------------------------------
	method finish($root, Context $ctx --> FinishResult) { FinishResult.new(type => 'final-result', value => Nil) }
	
	#------------------------------------------------------------------
	# Optional: decide whether to continue a fixed-point pass
	#------------------------------------------------------------------
	method should-continue(Element $root, Context $ctx --> Bool) { False }
}

```

### 3.2.6 The `ControlSignal` Enum 

````raku
enum ControlSignal <
    NO_REWRITE REWRITE_IMMEDIATE REWRITE_DEFERRED
    SKIP_ELEMENT STOP_TRAVERSAL FINAL_RESULT
>;
````

* `NO_REWRITE` — traversal continues, no changes
* `REWRITE_IMMEDIATE` — action performed inline in the template / hook
* `REWRITE_DEFERRED` — schedule this rewrite to be applied after the current traversal pass, not immediately during the visit
* `SKIP_ELEMENT` — skip this element and its relations
* `STOP_TRAVERSAL` — halt traversal immediately
* `FINAL_RESULT` — used in finish hook to signal end of traversal

## 3.3 The `Transformer` Group

### 3.3.1. Purpose

The purpose of a Raku **Transformer** is to walk the data passed in (a tree by default) and output different data (eg. another tree), in much the fashion that XSLT does, but we'll be walking Raku data instead.  This could be the Match tree returned by a grammar, or some XML data, or some JSON data, or whatever.

The Transformer is a structured object. The Transformer separates **traversal**, **selection**, and **action**, leveraging **Walkers** for traversal and **Queries** for node selection.

Data that we could walk includes:
* Tree-like structures:
	* The Match tree returned by a grammar  
	* XML, JSON, or table-like structures  
	* A AST (Abstract Syntax Tree) returned by Raku
	* Any nested object hierarchy
* Table-like and Array-like structures:
	* A Table
	* Anything that does Positional

The Transformer can be called at various points in the Qwiratry dataflow:

| Type                  | Notes | Processing Point | Call | Description |
| --------------------- | ----- | ---------------- | ---- | ----------- |
| Pre-Transformation   |       | Plan Phase       | .prepare($data, :$ctx)  | Transformers participate in the Walker::Plan, affecting elements before or during execution planning. |
| Inline Transformation | Optional | During Traversal | `.apply($element, :$ctx)` | Called by `Walker` or `Strategy` to request immediate transformation as part of traversal. |
| Post-Transformation   | Default behaviour | After traversal and query evaluation | `.transform($iter)` | Transformers consume the output of `QueryIterator` and produce a derived structure or stream. The Transformer may acting as a `QueryIterator` itself, in which case it can be composed in pipelines |

### 3.3.2 Transformer Declarator

There will be a custom declarator for a “transformer”.  The syntactic purpose of the transformer is to contain things, mostly templates.  

A Template is a structured specification that generates output (tree, table, or other structure) based on matched nodes. Templates may use interpolated values, computed fragments, or nested queries.

Transformers are declared using the `transformer` custom declarator.  For example:

````raku
transformer transform-the-tree {
	template TOP do {
		return Node.new();
	}
	template section() when {
		.name eq 'section'
	} do {

	}
}

transformer TransformerName is OtherTransformer :streaming {
	template TOP do { ... }
	template when { ... } do { ... }
}
````

#### Declarator Components

| Item       | Example       | Purpose |
| ---------- | ------------- | ------ |
| Declarator | `transformer` | Declares the start of a Transformer block |
| Name       | `transform-the-tree` | identifies the Transformer  |
| Roles/Traits | `is OtherTransformer`, `:streaming` | Switches the TRANSFORM method to one with a different application methodology |
| **Body**   | | contains:
| Templates  | | Match and Action rules |
| Wrappers   | | Wraps various parts of the Template |
| Methods | Can be used for a variety of purposes, including Stratego strategies |

* The `:streaming` trait can be applied at the Transformer or template level to enable `gather/take` streaming behavior (ie. the Transformer acts as an Iterator).  
* The `returns` trait can enforce the type of output returned by templates or the Transformer.
* The `does TreeRewrite` role overrides the APPLY method with one that does rewriting instead of outputting.  If this is done, then note that `make` will immediately replace the current node.  

#### Internals

* Declaring a Transformer automatically creates a sub/method with the Transformer name.  
* Calling it (e.g., `TransformerName($tree)`) invokes the underlying `TRANSFORM` method on the Transformer object.  

#### Traits

TODO (:streaming, returns, does TreeRewrite)

### 3.3.3. Methods on the Transformer class

The following methods are declared on the base Transformer class.  Those in capitals are designed to be overridden.  

```
class Transformer {
	# metadata
	has Bool $.streaming;
	has Bool $.mutates-input;   # if true, apply may mutate in-place
	has Str  $.mode;           # 'output-only'|'rewrite-optional'|'rewrite-mandatory'

	method transform($input, :$context = $*CONTEXT, :$streaming = Nil, :$mode = 'default' --> Iterator|Mu|List|Nil) {...}
}
```

#### `proto method TRANSFORM($data, Iterator :$iterator)`

This is the method that is called when the Transformer itself is called.  

The base `TRANSFORM` method:

* Prepares the templates by calling `ORDER-TEMPLATES`
* Walks the input data using **Iterators**  
* Applies templates by using the `APPLY` method
* Acts as a pull source, like `gather/take`

The default iterator is a depth-first, top-down iterator.  

**Walking process:**

1. The input iterator is invoked, producing a sequence of nodes (lazily).  
2. Each node is matched against template `when` clauses in order.  
3. If a template matches, its `do` clause is invoked and the output collected.  
4. Nextmatching templates can be invoked using `nextsame` or similar helpers.

Direct calls to template names bypass walk ordering.

#### ORDER-TEMPLATES and @.ordered-templates

This takes the templates that are part of the Transformer, and puts them in the right order in `@.ordered-templates`.

Ordering:

1. Templates can have a `:priority` trait (default 0). Highest numbers first, lowest numbers last.  Numbers can be negative.  
2. Templates with equal priority are sorted by specificity score.  So if there's only one template with a given priority, its specificity doesn't need to be calculated.  
3. Specificity is calculated based on the `when` clause:
   * Multilevel axis (ancestor/descendant/preceding/following) → -100  
   * Wildcards (`*`) → -10  
   * Each explicit path element → +5  
   * Each attribute axis → +5  
   * If there's a Union or the like, then we calculate each branch, and take the max, which becomes the specificity for this branch.  
4. Templates have a `:tie-breaker` trait (default 0) which you are required to set if two templates have the same specificity, and could match the same node.  
5. If there are two which rank equally, and could match the same object, an error is thrown asking you to select a tie-breaker

`when` clauses are placed into an array (on the Transformer object) so that they can easily be iterated over.  

Here's a list of orderings we didn't choose, and why:
* C3MRO is for inheritance resolution, so not applicable
* Raku's Multiple Dispatch system is dependent on arity and types, which aren't applicable either
* XSLT allows explicit priorities (which we've copied), and then specificity (which we've also copied), but finally uses document ordering.  We're going to try the `:tie-breaker` mechanism, and see how it works.  

#### APPLY method

The purpose of the APPLY method is to take the node given it, and apply the templates.  It can be overridden.  It is responsible for selecting and invoking the appropriate template(s) for a given node, **without handling traversal or iteration**, which is already done by `TRANSFORM`

The rest of this section covers the default version that appears in `Transformer.APPLY`.  

##### Purpose

- Apply templates to a single node according to `@.ordered-templates`.
- Return the output of the **first matching template**.
- Maintain deterministic behavior consistent with XSLT: **no fallback to other templates if a match fails**.
- Produce a sequence of output nodes (can be empty if no templates match).

##### Default Algorithm

1. Receive a single node `$node`.
2. iterate through the Transformer’s **ordered template list**  (already sorted by priority and specificity).  For the **first template whose `when` clause matches** `$node`:
	- Invoke its `do` block.
	- Return the result (sequence of nodes or transformed data).
	- **Stop processing further templates for this node**.
3. If no templates match, return an empty sequence.

When exiting the routine for any reason, pop the top iterator off the stack (use the relevant phaser for this).  

### 3.3.4. `copy` and `deepcopy` Methods

This section specifies the required behaviour of shallow and deep copying for all transformable node types within the Transformer framework. These methods MUST be attached to the Transformer object.

##### `copy()` — Shallow Copy

The `copy()` method MUST implement a shallow clone of the node.

###### Required Behaviour

1. Create a new instance of the same node type.  
	1. First check if the node has a `.copy()` method -- if so, call that to get the copy
2. Copy all immediate attributes, fields, or metadata values into the new instance.  
3. **Do not recursively copy children.**  
   - All child references MUST be shared with the original node.  
4. The operation MUST be O(1) with respect to the number of descendants.  
5. Node classes MAY implement their own `.copy()` to customise shallow-copy behaviour, but MUST adhere to the above constraints.

##### `deepcopy()` — Deep Copy

The `deepcopy()` method MUST implement a full recursive clone of the entire data or DAG rooted at the node.

###### Required Behaviour

1. Recursively clone the node and all of its children.  
2. Maintain structural sharing:  
	* If multiple parents reference the same child (DAG structure), the resulting deep copy MUST reference a single cloned child, not duplicate subtrees.  
	* This requires maintaining a "visited" hash keyed by object identity.  
3. Detect and correctly handle cycles:  
	* When encountering a node already present in the "visited" hash, reuse the existing clone rather than descending further.  
4. For primitive, immutable leaf types (e.g., Str, Numeric, Bool), simply return the value as-is.  
5. Produce a fully independent object graph, identical in content but disjoint in identity.

#### `transform` method

```
method transform(
	$input, 
	:$context = $*CONTEXT, 
	:$streaming = Nil, 
	:$mode = 'default' 
	--> Iterator|Mu|List|Nil
) {...}
```

`transform` is the transformation entrypoint.  It needs to determine when/how it's called, and act appropriately:

* Pre-Transformation: operates on a whole data structure
* Inline Transformation: operates on a single element
* Post-Transformation: operates on a QueryIterator.  This situation should be easy to identify as $input will be a QueryIterator.  

Possible values for `$mode` include:

| `$mode` Value           | Purpose / Behaviour |
|-------------------------|------------------|
| `default`               | Standard behaviour: `.transform` decides internally whether this is pre-, inline-, or post-transformation based on the type of input. No rewriting is enforced. |
| `pre`                   | **Pre-Transformation** stage: calls `prepare($data, :$ctx)` and produces a potentially modified or annotated structure **before traversal or query execution**. |
| `inline`                | **Inline Transformation**: calls `apply($element, :$ctx, :$mode)` on each element as it is visited by the Walker/Strategy. Allows in-place mutation if `$.mutates-input` is true. |
| `post`                  | **Post-Transformation** stage: consumes a `QueryIterator` and produces a derived output, optionally streaming. This is the default behaviour for normal `.transform($iter)` calls. |
| `rewrite-optional`      | Transformations may optionally mutate or replace nodes during inline application. Walker/Strategy may continue traversal after applying. |
| `rewrite-mandatory`     | Forces a rewrite of the node if possible; traversal may depend on the rewritten structure. Useful for fixed-point or normalization passes. |

**Notes:**

* `$mode` informs the Transformer **how to interpret the input** and which internal method (`prepare`, `apply`, `_transform_iterator`) to use.  
* `rewrite-optional` and `rewrite-mandatory` are particularly relevant for **tree or AST transformers**, where in-place or replacement mutations may be requested by strategies.  
* For post-transformation pipelines, `post` and `default` typically behave the same.

### 3.3.2. Templates

Templates define **match-and-action rules** within a Transformer. Each template consists of:

| Item       | Example       | Purpose |
| ---------- | ------------- | ------ |
| Optional `proto` or `multi` declarator | | See [proto](https://docs.raku.org/language/functions#Multi-dispatch) |
| Declarator | `template` | Declares the start of a Template block |
| Optional name/signature | `section()` | Makes a template directly callable, as a method |
| Optional traits | `:streaming` | Modifies the template behaviour |
| Matcher | `when {...}` | This is a code block.  It's expected to contain a query such as those involving by the Tree Operators.  It can be used for matching nodes (like the `select` clause on an XSLT template) |
| Action  | `do {...}` | This code block produces output nodes.  If the template is turned into a method, this is the body of the method |

**Matching with Iterators and Operators:**

* `when` clauses can use **composed iterators** (which are both callable and iterable) for path specifications:

````raku
template section() when { $_ ⪪⪪ <div> } do { <action on div> }
````

* Axis operators (like `⪪`, `⪫`, `⥷`) can be used directly within templates to select nodes.  
* Predicates and combinators (like `∪`, `∩`) can refine node selection in `when` clauses.  

#### Structure

TODO (template, optional name/signature, when matcher, do action)

#### Iterators, Axis Operators, and Predicates

TODO (see material above)

#### Return Values

* If the `do` block calls `make`, its results are added to the output stream.  
* Otherwise, the return value of `do` is used as output.  
* Returning `$*CONTEXT` or `$_` effectively copies the current node.  
* If no `do` block is provided, the `when` clause’s value is returned.
* It should be possible to call `NextTemplate.throw` in the body of an action, and, instead of the result of the action being put into the tree, we instead continue with the next matching template.  
* If no templates match a node, it does nothing

### 3.3.3. Wrappers

Wrappers allow custom pre- or post-processing of template matches or the entire Transformer output.  They consist of:

* `wrapper` declarator  
* Name and signature  
* Code block body

The following wrappers will be recognised and used by the base Transformer object:

* **TRANSFORMER** – wraps the entire Transformer output  
* **TEMPLATE_MATCHER** – wraps template match evaluation  
* **TEMPLATE_ACTION** – wraps template action execution

#### Internals

Under the hood, each wrapper is:
* Defined as a submethod called eg. `WRAP_TRANSFORMER`
* Called up the Transformer hierarchy *a la* `TWEAK`.  

### 3.3.4. Magic Variables

There should be three magic variables that are updated when walking the data.  These are:
* `$*CONTEXT` and `$_`: Both set to the current input context node (ie. the current item in the data being walked)
* `$*CAPTURE` and `$/`: Both set to the capture of the template signature parameters.  These can then be returned, if desired, or accessed via `$/<parameter1>`.  
* `self`: Reference to the current Transformer object

# 4. Query Execution Flow

1. **Query Construction**  
   Constructed via a Slang or directly in code, representing the desired search, filter, or pattern.

2. **Walker Planning**  
   The `Walker` receives the query, analyses it, and builds an execution plan. Optimisations, index selection, and multi-phase strategies occur here.

3. **QueryIterator Production**  
   `Walker.iterator($query)` produces a `QueryIterator` exposing results incrementally. Multiple iterators may be produced from the same Walker/query combination.

4. **Result Consumption**  
   The consumer calls `next()` or iterates over the iterator. Lazy evaluation, backtracking, or streaming behaviours are managed internally.

# 5. Composite and Multi-phase Walkers

* **Composite Walkers** can chain multiple traversal strategies: e.g., first use an index, then traverse children, then filter.  
* **Multi-phase Walkers** separate planning, rewriting, and execution. Each phase can be optimised independently.  
* **Reusability**: A single Walker can produce multiple iterators for different consumers or queries.  
* **Backtracking**: Walkers may internally maintain state to explore alternative paths lazily.

# 6. Slang for Query Expressions

A Raku Slang can be provided to:

* Parse tree or table operators and produce a `Query` object  
* Compose multiple queries with logical operators (`and`, `or`, `not`)  
* Annotate queries for optimisation hints or execution preferences  
* Optionally, allow inline predicates as code blocks


Any operator may take a trailing block, and that block becomes a Query object.

Examples desugar to:

````raku
Query::Op.new(
    :operator<descendant>,
    :arg(Any),
    :predicate(Query::BlockPredicate.new(
        block => -> $x { $x.value > 10 }
    ))
)
````

Slang requirements:

1. Extend grammar for operator-term with trailing block.  
2. In actions, produce AST nodes for Query objects.  
3. At BEGIN-time, compile these into Query subclasses.

# 7. Examples

## 7.1 Tree Walker (DFS)

````raku
class Tree::Walker::DFS does Walker {
    method start(Query $q, $node --> QueryIterator) {
        gather {
            sub dfs($n) {
                take $n if $q.matches($n);
                for $n.children -> $c { dfs($c) }
            }
            dfs($node);
        }
    }
}
````

## 7.2 Table Walker

````raku
class Table::Walker::Scan does Walker {
    has @!rows;

    method start(Query $q, @rows --> QueryIterator) {
        gather for @rows -> $r {
            take $r if $q.matches($r);
        }
    }
}
````

## 7.3 Logic Walker

````raku
class Logic::Walker::Backward does Walker {
    method start(Query $goal, $kb --> QueryIterator) {
        Logic::Iterator::Backward.new(:$kb, :$goal);
    }
}
````

# 8. Applicability Across Domains

- Trees: structural predicates, path queries  
- Tables: predicate pushdown, index selection, joins  
- Logic: goal evaluation and backtracking  

All are unified by the Query–Walker–Iterator architecture.

# Appendices

# Appendix A: Why Qwiratry?

It's an acronym of sorts:
* **Q**: *Q*uery
* **W**: *W*alker
* **I**: Query*I*terator.  Technically doesn't start with an I, but that's OK
* **Ra**: *Ra*ku.  Also, with Ra being the Egyptian sun god, it will hopefully remind us that it will shine a bright light onto your data.  
* **Tr**: *Tr*ansformer
* **Y**: *Y*are.  A nautical term meaning "Easily manageable and responsive to the helm".  It's also a river in the Norfolk Broads (where the books *Coot Club* and *The Big Six* took place).  It also sounds like someone saying "yeah", and positivity is appropriate here.  

It sounds like *Quira Tree*, which is a name for the Panama Redwood.  Which will be amusing when processing Tree data.  

It sounds like it's a word formed from **Quirat-ery*, but contracted.  And in case you're wondering, `Quirat` can be either:
* an historical currency unit in Spanish/Moroccan contexts
* a maritime property share in old French usage
* The Catalan word for *carat*

These three are all from Arabic قِيرَاط (qīrāṭ, “husk”), from Ancient Greek κεράτιον (kerátion, “carob seed”), diminutive form of κέρας (kéras, “horn”). 

From Ancient Greek carob seeds to Arabic units of weight and Catalan carats, the etymology mirrors the idea of measuring, traversing, and transforming data.


# TODO

* Feed it in again, and ask whether the document could be better structured.  Am working on this.  Current status:
	* This v1 document needs to be kept, for the TODO list, and to ensure that nothing gets left out
	* When done with this, look through the document for TODO sections
* Feed it back in one more time, and tell it that we want this to be a specification for an AI to create the project, and ask what needs changing.  
* Once this one is done, either install Spec Kitty and do it, or rewrite the Tree-Oriented Programming spec to rely on this one
	* When redoing the Tree one, make a note that, when we want article ideas, we should ask ChatGPT "what domains does this apply to"?  
* Ask ChatGPT to compare this model with the Raku compilation and execution model, so I know which bits I can reuse, and which I can't