# API Contract: Transformer Templates System

**Feature**: 005-transformer-templates-system
**Date**: 2025-01-27
**Version**: 1.0.0

## Transformer Declarator

```raku
# Basic transformer declaration
transformer MyTransformer {
    template TOP do {
        return Node.new();
    }
}

# Transformer with traits and roles
transformer StreamTransformer :streaming does TreeRewrite {
    template section() when { $_.name eq 'section' } do {
        make Node.new(name => $_.name);
    }
}

# Transformer with type constraint
transformer TableTransformer returns(Array) {
    template row() do {
        make Node.new(data => $_.data);
    }
}
```

### Declarator Syntax

```raku
transformer TransformerName [is RoleName] [:streaming] [returns(Type)] [does RoleName] {
    # Templates, wrappers, methods
}
```

### Semantics

- Creates a class named `TransformerName` that does `Transformer`
- Automatically creates callable sub/method with transformer name
- Calling `TransformerName($data)` invokes `TRANSFORM` method
- Traits and roles applied at compile-time
- Body contains templates, wrappers, and optional methods

## Transformer Class

```raku
#| Declarative object for transforming data structures using templates.
class Transformer {
    #| All templates defined in transformer body
    has Array[Template] @.templates;
    
    #| Templates sorted by priority → specificity → tie-breaker
    has Array[Template] @.ordered-templates;
    
    #| Whether transformer has :streaming trait
    has Bool $.streaming = False;
    
    #| Whether transformer can mutate input (from does TreeRewrite)
    has Bool $.mutates-input = False;
    
    #| Transformation mode
    has Str $.mode = 'output-only';
    
    #| Main transformation method - called when transformer is invoked
    proto method TRANSFORM($data, Iterator :$iterator --> Iterator|Mu|List|Nil) { * }
    
    #| Orders templates by priority → specificity → tie-breaker
    method ORDER-TEMPLATES(--> Array[Template]) { ... }
    
    #| Applies templates to a single node
    method APPLY($node --> Iterator|Mu|List|Nil) { ... }
    
    #| Transformation entrypoint - determines mode and delegates
    method transform(
        $input,
        :$context = $*CONTEXT,
        :$streaming = Nil,
        :$mode = 'default'
        --> Iterator|Mu|List|Nil
    ) { ... }
    
    #| Pre-transformation: modifies structure before traversal
    method prepare($data, :$ctx) { ... }
    
    #| Inline transformation: transforms element during traversal
    method apply($element, :$ctx, :$mode) { ... }
}
```

### Method Contracts

#### TRANSFORM

```raku
method TRANSFORM($data, Iterator :$iterator --> Iterator|Mu|List|Nil)
```

- **Purpose**: Main transformation method, called when transformer is invoked
- **Parameters**:
  - `$data`: Input data structure to transform
  - `:$iterator`: Optional iterator (default: depth-first, top-down)
- **Returns**: Iterator (if streaming), List, single value, or Nil
- **Behavior**:
  - Calls `ORDER-TEMPLATES` to prepare templates
  - Walks input data using iterator
  - Applies templates using `APPLY` method
  - Acts as pull source (like `gather/take`)

#### ORDER-TEMPLATES

```raku
method ORDER-TEMPLATES(--> Array[Template])
```

- **Purpose**: Orders templates by priority → specificity → tie-breaker
- **Returns**: Array of templates in execution order
- **Behavior**:
  - Sorts templates by priority (highest first)
  - For equal priority, sorts by specificity (highest first)
  - For equal priority and specificity, sorts by tie-breaker (highest first)
  - Reports error if two templates have equal values and could match same node
  - Caches result in `@.ordered-templates`

#### APPLY

```raku
method APPLY($node --> Iterator|Mu|List|Nil)
```

- **Purpose**: Applies templates to a single node
- **Parameters**:
  - `$node`: Node to transform
- **Returns**: Iterator, List, single value, or Nil (empty if no match)
- **Behavior**:
  - Iterates through `@.ordered-templates`
  - For first template whose `when` clause matches:
    - Sets magic variables (`$*CONTEXT`, `$*CAPTURE`)
    - Executes template's `do` block
    - Returns result
    - Stops processing (no fallback to other templates)
  - If no templates match, returns empty sequence

#### transform

```raku
method transform(
    $input,
    :$context = $*CONTEXT,
    :$streaming = Nil,
    :$mode = 'default'
    --> Iterator|Mu|List|Nil
)
```

- **Purpose**: Transformation entrypoint, determines mode and delegates
- **Parameters**:
  - `$input`: Input data (whole structure, element, or QueryIterator)
  - `:$context`: Context for traversal (default: `$*CONTEXT`)
  - `:$streaming`: Override streaming behavior (default: Nil, uses trait)
  - `:$mode`: Transformation mode (default: 'default', auto-detect)
- **Returns**: Iterator, List, single value, or Nil
- **Modes**:
  - `'default'`: Auto-detect based on input type
  - `'pre'`: Pre-transformation (calls `prepare`)
  - `'inline'`: Inline transformation (calls `apply`)
  - `'post'`: Post-transformation (consumes QueryIterator)
  - `'rewrite-optional'`: Optional in-place mutation
  - `'rewrite-mandatory'`: Mandatory in-place mutation

## Template Declarator

```raku
# Basic template
template TOP do {
    return Node.new();
}

# Template with when clause
template section() when { $_.name eq 'section' } do {
    make Node.new(name => $_.name);
}

# Template with priority and traits
template important :priority(10) :streaming when { $_.priority > 5 } do {
    take $_.transform;
}

# Template with signature and tie-breaker
template node($name) :tie-breaker(1) when { $_.name eq $name } do {
    make Node.new(name => $name);
}
```

### Declarator Syntax

```raku
template [Name] [($signature)] [:priority(Int)] [:tie-breaker(Int)] [:streaming] [returns(Type)] when { ... } do { ... }
```

### Semantics

- Defines match-and-action rule within transformer
- `when` block: code that returns Bool (True if template matches node)
- `do` block: code that produces output (via `make` or return)
- Named templates become callable methods on transformer
- Templates ordered by priority → specificity → tie-breaker

## Template Class

```raku
#| Match-and-action rule within a Transformer
class Template {
    #| Optional template name (makes template callable)
    has Str $.name;
    
    #| Optional template signature (for parameters)
    has Signature $.signature;
    
    #| Code block for matching nodes
    has Block $.when-block;
    
    #| Code block for producing output
    has Block $.do-block;
    
    #| Template priority (from :priority trait, default 0)
    has Int $.priority = 0;
    
    #| Calculated specificity score (cached)
    has Int $.specificity;
    
    #| Tie-breaker value (from :tie-breaker trait, default 0)
    has Int $.tie-breaker = 0;
    
    #| Whether template has :streaming trait
    has Bool $.streaming = False;
    
    #| Output type constraint (from returns(Type) trait)
    has Type $.returns-type;
    
    #| Evaluates when block against node
    method matches($node --> Bool) { ... }
    
    #| Executes do block with magic variables set
    method execute($node, :$context --> Iterator|Mu|List|Nil) { ... }
}
```

### Method Contracts

#### matches

```raku
method matches($node --> Bool)
```

- **Purpose**: Evaluates `when` block against node
- **Parameters**:
  - `$node`: Node to match
- **Returns**: True if template matches, False otherwise
- **Behavior**:
  - Sets `$*CONTEXT = $node` and `$_ = $node`
  - Executes `when` block
  - Returns result (must be Bool)

#### execute

```raku
method execute($node, :$context --> Iterator|Mu|List|Nil)
```

- **Purpose**: Executes `do` block with magic variables set
- **Parameters**:
  - `$node`: Node being processed
  - `:$context`: Context for traversal (optional)
- **Returns**: Iterator, List, single value, or Nil
- **Behavior**:
  - Sets `$*CONTEXT = $node`, `$_ = $node`
  - Sets `$*CAPTURE` if template has signature
  - Sets `self` to Transformer object
  - Executes `do` block
  - Returns result

## Magic Variables

```raku
# Available during template execution:

$*CONTEXT  # Current input context node (set to current item being processed)
$*CAPTURE  # Capture of template signature parameters (set to template parameters if any)
self       # Reference to current Transformer object (automatically available)
$_         # Same as $*CONTEXT (convenience alias)
$/         # Same as $*CAPTURE (convenience alias)
```

### Semantics

- Set automatically before template `do` block execution
- Scoped to template execution (not visible outside)
- `$*CONTEXT` and `$_` both refer to current node
- `$*CAPTURE` and `$/` both refer to template parameters (if template has signature)
- `self` refers to Transformer object (available in all methods/blocks)

## Wrapper System

```raku
# Wrapper declarations in transformer body
transformer MyTransformer {
    wrapper TRANSFORMER {
        # Wraps entire transformer output
    }
    
    wrapper TEMPLATE_MATCHER {
        # Wraps template match evaluation
    }
    
    wrapper TEMPLATE_ACTION {
        # Wraps template action execution
    }
}
```

### Wrapper Types

- **TRANSFORMER**: Wraps entire transformer output (called around `TRANSFORM` method)
- **TEMPLATE_MATCHER**: Wraps template match evaluation (called around `when` block)
- **TEMPLATE_ACTION**: Wraps template action execution (called around `do` block)

### Implementation

Wrappers are implemented as submethods:

```raku
submethod WRAP_TRANSFORMER(...) { ... }
submethod WRAP_TEMPLATE_MATCHER(...) { ... }
submethod WRAP_TEMPLATE_ACTION(...) { ... }
```

Called up transformer hierarchy (like `TWEAK`).

## Transformable Node Interface

```raku
#| Role/interface for nodes that can be transformed
role Transformable {
    #| Shallow copy: O(1) operation, children shared
    method copy(--> Transformable) { ... }
    
    #| Deep copy: recursive clone with cycle detection
    method deepcopy(--> Transformable) { ... }
}
```

### Method Contracts

#### copy

```raku
method copy(--> Transformable)
```

- **Purpose**: Creates shallow copy of node
- **Returns**: New node instance with same attributes, children shared
- **Complexity**: O(1) with respect to descendant count
- **Behavior**:
  - If node has custom `.copy()` method, call it
  - Otherwise, create shallow clone (attributes copied, children shared)

#### deepcopy

```raku
method deepcopy(--> Transformable)
```

- **Purpose**: Creates deep copy of node and all descendants
- **Returns**: Fully independent object graph
- **Behavior**:
  - Recursively clones node and all children
  - Maintains DAG structure (single clone per unique node)
  - Detects cycles (reuses existing clone)
  - For immutable primitives (Str, Numeric, Bool), returns as-is

## Walker Factory

```raku
#| Factory for selecting appropriate Walker instances
class WalkerFactory {
    #| Selects appropriate Walker for data type
    method get-walker($data --> Walker?) { ... }
    
    #| Registers Walker for specific data type/role
    method register-walker($type, Walker) { ... }
    
    #| Discovers available Walkers via introspection (optional)
    method discover-walkers(--> Array[Walker]) { ... }
}
```

### Method Contracts

#### get-walker

```raku
method get-walker($data --> Walker?)
```

- **Purpose**: Selects appropriate Walker for data type
- **Parameters**:
  - `$data`: Input data structure
- **Returns**: Walker instance or Nil (if none found)
- **Behavior**:
  - Checks registry for data type/role
  - Returns registered Walker or Nil
  - May use heuristics if no exact match

## Error Handling

### Template Ordering Conflicts

```raku
# Error thrown when two templates have equal priority/specificity/tie-breaker
# and could match the same node
X::Qwiratry::TemplateOrderingConflict.new(
    template1 => $template1,
    template2 => $template2,
    priority => $priority,
    specificity => $specificity,
    tie-breaker => $tie-breaker
)
```

### Missing Walker

```raku
# Error thrown when no suitable Walker found for data type
X::Qwiratry::NoWalkerFound.new(
    data-type => $data-type,
    available-walkers => @available-walkers
)
```

## Usage Examples

### Basic Transformer

```raku
transformer SimpleTransform {
    template TOP do {
        return Node.new();
    }
    
    template section() when { $_.name eq 'section' } do {
        make Node.new(name => $_.name);
    }
}

my $result = SimpleTransform($tree);
```

### Streaming Transformer

```raku
transformer StreamSections :streaming {
    template section() when { $_.name eq 'section' } do {
        take Node.new(name => $_.name);
    }
}

for StreamSections($tree) -> $node {
    say $node.name;
}
```

### Tree Rewriting

```raku
transformer RewriteTree does TreeRewrite {
    template leaf() when { $_.is_leaf } do {
        make $_.copy;
    }
}

RewriteTree($tree);  # Modifies tree in-place
```

