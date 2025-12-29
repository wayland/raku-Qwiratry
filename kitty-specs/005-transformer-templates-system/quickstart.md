# Quickstart: Transformer Templates System

**Feature**: 005-transformer-templates-system

## Overview

Transformers provide declarative data transformation using pattern-matching templates. They enable XSLT-like transformations over Raku data structures (trees, tables, etc.) without writing manual traversal code.

## Basic Usage

### 1. Import the modules

```raku
use Qwiratry::Transformer;
```

### 2. Create a simple transformer

```raku
transformer SimpleTransform {
    template TOP do {
        return Node.new();
    }
    
    template section() when { $_.name eq 'section' } do {
        make Node.new(name => $_.name);
    }
}
```

### 3. Use the transformer

```raku
my $tree = ...;  # Your data structure
my $result = SimpleTransform($tree);
```

## Common Patterns

### Basic Template Matching

```raku
transformer BasicTransform {
    # Match root node
    template TOP do {
        return Node.new();
    }
    
    # Match nodes by name
    template div() when { $_.name eq 'div' } do {
        make Node.new(name => 'div', children => $_.children);
    }
    
    # Match nodes by attribute
    template highlighted() when { $_.attributes<highlight>:exists } do {
        make Node.new(
            name => $_.name,
            style => 'highlighted',
            children => $_.children
        );
    }
}
```

### Template Priority

```raku
transformer PriorityTransform {
    # Higher priority template (executes first)
    template important :priority(10) when { $_.priority > 5 } do {
        make Node.new(name => 'important', data => $_.data);
    }
    
    # Lower priority template (executes if first doesn't match)
    template normal :priority(0) when { True } do {
        make Node.new(name => 'normal', data => $_.data);
    }
}
```

### Template with Parameters

```raku
transformer ParamTransform {
    # Template with signature parameters
    template node($name) when { $_.name eq $name } do {
        # Access parameter via $*CAPTURE or $/
        make Node.new(name => $*CAPTURE<name>);
    }
}
```

### Streaming Transformations

```raku
transformer StreamSections :streaming {
    template section() when { $_.name eq 'section' } do {
        take Node.new(name => $_.name);  # Use 'take' for streaming
    }
}

# Consume results lazily
for StreamSections($tree) -> $node {
    say $node.name;
}
```

### Tree Rewriting

```raku
transformer RewriteTree does TreeRewrite {
    template leaf() when { $_.is_leaf } do {
        make $_.copy;  # Modifies tree in-place
    }
    
    template node() when { True } do {
        make $_.copy;  # All nodes rewritten
    }
}

RewriteTree($tree);  # Modifies $tree in-place
```

### Using Magic Variables

```raku
transformer MagicVars {
    template node() when { True } do {
        # $*CONTEXT or $_ = current node
        say "Processing: {$*CONTEXT.name}";
        
        # self = Transformer object
        say "Transformer: {self.^name}";
        
        # $*CAPTURE or $/ = template parameters (if template has signature)
        make Node.new(name => $*CONTEXT.name);
    }
}
```

### Template Tie-Breaker

```raku
transformer TieBreakerTransform {
    # Two templates with same priority and specificity
    template specific() :priority(5) :tie-breaker(1) when { $_.name eq 'specific' } do {
        make Node.new(name => 'specific');
    }
    
    template general() :priority(5) :tie-breaker(2) when { $_.name eq 'specific' } do {
        # This won't execute for 'specific' nodes (tie-breaker 1 wins)
        make Node.new(name => 'general');
    }
}
```

### Wrapper System

```raku
transformer WrappedTransform {
    # Wrap entire transformer output
    wrapper TRANSFORMER {
        my $result = callwith();  # Call original transformation
        # Post-process result
        return $result.map: { $_.transform };
    }
    
    # Wrap template matching
    wrapper TEMPLATE_MATCHER {
        my $matched = callwith();  # Call original match
        # Log matching
        say "Template matched: {self.^name}";
        return $matched;
    }
    
    # Wrap template action
    wrapper TEMPLATE_ACTION {
        my $result = callwith();  # Call original action
        # Post-process action result
        return $result.map: { $_.validate };
    }
    
    template node() when { True } do {
        make Node.new(name => $_.name);
    }
}
```

### Type Constraints

```raku
transformer TypedTransform returns(Array) {
    template row() do {
        make Node.new(data => $_.data);
    }
}

# Output is guaranteed to be Array type
my Array $result = TypedTransform($table);
```

### Multiple Transformation Modes

```raku
transformer MultiMode {
    template node() when { True } do {
        make Node.new(name => $_.name);
    }
}

# Pre-transformation (before traversal)
my $prepared = MultiMode.transform($data, :mode<pre>);

# Inline transformation (during traversal)
MultiMode.transform($element, :mode<inline>);

# Post-transformation (after query evaluation)
my $iter = $walker.iterator($plan);
my $transformed = MultiMode.transform($iter, :mode<post>);
```

### Copy Operations

```raku
# Shallow copy (children shared)
my $shallow = $node.copy;

# Deep copy (all descendants cloned)
my $deep = $node.deepcopy;

# Use in templates
transformer CopyTransform {
    template node() when { True } do {
        # Non-destructive transformation
        make $*CONTEXT.deepcopy;
    }
}
```

## Integration with Walker System

```raku
# Transformer automatically uses appropriate Walker
transformer AutoWalker {
    template node() when { True } do {
        make Node.new(name => $_.name);
    }
}

# Walker selected automatically based on data type
my $result = AutoWalker($tree);      # Uses tree walker
my $result = AutoWalker($table);     # Uses table walker

# Explicit Walker override
my $custom-walker = CustomWalker.new;
my $transformer = MyTransformer.new(:$custom-walker);
```

## Error Handling

### Template Ordering Conflicts

```raku
# If two templates have equal priority/specificity/tie-breaker:
# Error: X::Qwiratry::TemplateOrderingConflict
# Solution: Set explicit :tie-breaker values

transformer ConflictTransform {
    template a() :priority(5) :tie-breaker(1) when { $_.name eq 'a' } do { ... }
    template b() :priority(5) :tie-breaker(2) when { $_.name eq 'a' } do { ... }
}
```

### Missing Walker

```raku
# If no suitable Walker found:
# Error: X::Qwiratry::NoWalkerFound
# Solution: Register Walker or provide explicit Walker

WalkerFactory.register-walker(MyDataType, MyWalker.new);
```

## Best Practices

1. **Use TOP template**: Always define a TOP template for root node handling
2. **Set priorities explicitly**: Use `:priority` for important templates
3. **Use tie-breakers**: Set `:tie-breaker` when templates could conflict
4. **Stream for large data**: Use `:streaming` trait for memory efficiency
5. **Type constraints**: Use `returns(Type)` for type safety
6. **Non-destructive**: Use `copy()` or `deepcopy()` when not using `TreeRewrite`
7. **Magic variables**: Use `$*CONTEXT` for current node, `$*CAPTURE` for parameters
8. **Template names**: Name templates for direct method calls when needed

## Advanced Examples

### Complex Query Matching

```raku
transformer ComplexMatch {
    # Match using query operators (when query system available)
    template section() when { $_ ⪪⪪ <div> } do {
        make Node.new(name => 'section');
    }
}
```

### Nested Transformations

```raku
transformer OuterTransform {
    template container() when { $_.name eq 'container' } do {
        # Apply inner transformation to children
        my $inner = InnerTransform.new;
        make Node.new(
            name => 'container',
            children => $_.children.map: { $inner.transform($_) }
        );
    }
}
```

### Fixed-Point Transformation

```raku
transformer NormalizeTree does TreeRewrite {
    template node() when { $_.needs-normalization } do {
        make $_.normalize;
    }
}

# Apply until fixed point
my $changed = True;
while $changed {
    $changed = False;
    NormalizeTree($tree);  # Modifies in-place
}
```

