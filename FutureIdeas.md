# Future Ideas

This file records architectural ideas that are potentially useful, but are not part
of the current implementation plan. Notes here are intentionally tentative.

## Semantic Pattern Extractors

Domain-specific pattern extractors could provide higher-level matching vocabulary
above ordinary tree navigation.

The navigator layer answers structural questions such as "what are this node's
children?", "what is its parent?", or "what attributes does it expose?". Pattern
extractors would answer semantic questions for a particular domain.

Possible examples:

- RakuAST: match a call by name, an infix operator by symbol, a literal by value,
  or a declaration by kind.
- XML: match an element by name, an attribute by name or value, a namespace, text
  nodes, or processing instructions.
- HTML/XHTML: match a tag, CSS class, ID, link target, form field, or heading
  level.
- JSON-like config data: match an object with a key, a key path, or a dependency
  declaration.

These should probably sit above navigators rather than inside them. A navigator
should expose structure consistently; a semantic extractor can then interpret that
structure for a domain.

Open questions:

- Whether extractors should be ordinary functions, query operators, mold helpers,
  or registered domain services.
- Whether extractors should produce query AST fragments or just predicates.
- Whether extractors belong with domains, formats, or transformer libraries.

## Stratego-Like Traversal Combinators

Stratego separates rewrite rules from traversal control. It provides primitive
one-step traversal operations such as applying a strategy to all, one, or some
children, and builds reusable traversal schemes such as top-down, bottom-up,
once-top-down, and innermost rewriting.

Qwiratry already has a Strategy layer with hooks for before, on-match,
should-follow, after, finish, and should-continue. It also has Walker plans and
iterators controlling traversal. If Stratego-like combinators are added, they
should probably build on that existing model rather than replace it.

Possible directions:

- Provide named traversal helpers for common schemes such as top-down,
  bottom-up, fixed-point, and first-match.
- Let transformer methods compose strategy behavior for a specific transform.
- Treat these combinators as convenience APIs over Walker/Strategy behavior, not
  as a separate traversal engine.

Open questions:

- How failure/backtracking should be represented in Raku.
- Whether combinators belong on Strategy, Transformer, Walker::Plan, or a new
  traversal utility module.
- How they should interact with existing ControlSignal values and rewrite modes.

## K Semantic Framework-Inspired Ideas

K uses configurations, labeled cells, local rewriting, contexts, and "anywhere"
rules to define executable semantics. These ideas may become useful if Qwiratry
grows from structural transformation into semantic transformation over larger
program states.

Possible directions:

- Model a transform target as labeled regions or cells, allowing rules to mention
  only the relevant part of a larger state.
- Support local rewrites that explicitly identify which parts of a structure are
  read, written, or ignored.
- Add "anywhere" style rules for cases where a rewrite should apply wherever a
  matching term appears.
- Explore context abstractions for evaluation-order or normalization tasks.

These ideas are deliberately deferred. They are probably too heavy for the current
tree navigation and format navigator work, but worth keeping in mind for future
semantic rewriting features.
