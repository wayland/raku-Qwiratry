# Upcoming Versions

## By 0.1.0

### Core System

Prefatory work:
* DONE Start out by getting it to write a plan for rebuilding TOP on Qwiratry,
  so that I can start work on that when I run out of credits
* DONE Fix the current problem, sort out what we currently have and do a commit

Rejigging:
* DONE Would it make sense to combine Walkers and Navigators?  Would there be 
  efficiency gains by doing that?  

Testing:
* DONE Ask it if we have (functional) tests based on the Specification
* DONE Make test suites for testing formats/locations that can be run against any new 
  format/Location 
* DONE Ensure it combines well with feed operators

New features:
* DONE Have it do at least a little testing to figure out why it's so slow
* DONE As a fallback, if there's no Format/Location, can we look up recommended 
  packages in zef, so that if a format is missing, it recommends to people that 
  they can install it
* DONE Use Matches as the tree as well as RakuAST
* DONE Make a qwiratry-setup script that asks which formats/locations you'd like to 
  install (after querying zef/ecosystem to find what's available); lets you 
  tick the ones you want, and then it'll install them

### Modules

*	Locations:
	*	DONE: Filesystem -- if someone uses file:/ or something with no : on a 
		directory, then assume that we're treating that as a root for 
		find/navigation; treat files and directories differently; test out 
	        regex/glob matching
*	Formats
	*	DONE: JSON
	*	DONE: YAML
	*	XML
	*	INI
	*	TOML
	*	XKB in conjunction with writing an article about it (cf. articles)


* Ensure that everything (including raku-Qwiratry-Test) is pushed to fez/github

### Tweak ideas

Maybe do these:
*	If parse op doesn't have a LHS, use STDIN
*	If attribute op doesn't have a LHS, use $_

## Streamable Trees

### Core System

Making things Streamable; cf. both:
* Streaming-Qwiratry-Proposal.rakudoc (in this directory)
* https://wayland.github.io/table-oriented-programming/Metanoias/Walkable-vs-Streamable.xml

## Table-Oriented Programming (this may be multiple versions)

* Rewrite my existing TOP code to use Qwiratry; include Human and Half-Human formats
  as part of core; will likely need CSV to implement Human format, so maybe only
  include Half-Human as part of core?  
* Break out some of the parts into modules; SQL encoding should probably remain
  in core though
* Could probably do ods files at this point

## Benchmarking

* Do some benchmarking, and do a comparison of a basic pipeline compared with
  normal code, and see if we can't do something to speed it along

## Stylesheets

### CSS

Do this at some point, because it really needs to be read in as transformers/molds

### XSLT

See if we can read this in as transformers/molds as well.  

# Ideas to Consider

This records architectural ideas that are potentially useful, but are not part
of the current implementation plan. Notes here are intentionally tentative.

## Declaraku

Some of these ideas might be better as part of Declarative Raku, but not 
Data-Oriented Programming.  

Revisit Declaraku ideas, including:
* Logic Programming Integration
* Queries being the inverse of functions
* Dependent Programming (cf. Puppet and Makefiles); everything runs simultaneously,
  except the stuff that's dependent on other stuff
* Read https://chatgpt.com/c/6a537baa-cd8c-83ec-87b6-407118618bc3 -- Picat has
  already done some of the hard work.  Skip the first Q&A, the answer to the second
  question is better, and it only gets better from there.  Also skip the explanation 
  of BFS and DFS
  * Possibly we want to have functions be able to declare "cache all results, and if
    I'm re-called with the same parameters, return the same value".  We don't want
    to do that for everything, but could sometimes be handy for eg. goal-seeking.  
  * The "Logic Variables" also sound cool and implementable.  Maybe not part of 
    Data-Oriented Programming though.  

### Semantic Pattern Extractors

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

### Stratego-Like Traversal Combinators

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

### K Semantic Framework-Inspired Ideas

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

# Postponed until Raku integration

* POSTPONED See if we can rejig things so that we only need one “use” statement; 
  can the Slangs be merged into the main Qwiratry module (and then load other 
  modules on demand)?  This would be trickyish -- might be best to wait until we 
  merge them into the language.  

