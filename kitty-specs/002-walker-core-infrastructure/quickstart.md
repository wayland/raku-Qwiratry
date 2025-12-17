# Quickstart: Walker Core Infrastructure

**Feature**: Walker Core Infrastructure  
**Date**: 2025-12-17  
**Phase**: 1 - Design & Contracts

## Overview

This guide demonstrates how to use the Walker Core Infrastructure roles to create domain-specific walkers and execute queries.

## Basic Usage

### Creating a Simple Walker

```raku
use Qwiratry::Walker;
use Qwiratry::Walker::Plan;
use Qwiratry::Context;
use Qwiratry::QueryIterator;

# Example: Simple tree walker
class SimpleTreeWalker does Walker {
    has $.root;
    
    method plan(RakuAST::Node $query, Mu $root --> Walker::Plan) {
        # Store root for iterator convenience method
        $!root = $root;
        
        # Create a simple plan
        SimplePlan.new(:$query, :$root)
    }
    
    method iterator(RakuAST::Node $q --> QueryIterator) {
        # Convenience method: use stored root
        self.plan($q, $!root).iterator
    }
}

# Simple plan implementation
class SimplePlan does Walker::Plan {
    has RakuAST::Node $.query;
    has Mu $.root;
    
    method iterator(--> QueryIterator) {
        my $ctx = SimpleContext.new;
        SimpleIterator.new(:$ctx, :plan(self))
    }
    
    method query(--> RakuAST::Node) { $!query }
    method describe(--> Str) { "Simple tree traversal" }
}

# Simple context
class SimpleContext does Context {
    has @.visited;
    has Int $.count = 0;
}

# Simple iterator
class SimpleIterator does QueryIterator {
    has Context $.context;
    has Walker::Plan $.plan;
    has Int $.position = 0;
    
    method next(--> Mu) {
        # Simple implementation: return Nil when exhausted
        return Nil if $!position >= 10;
        $!position++;
        return "result-$!position";
    }
}
```

### Planning and Executing a Query

```raku
# Create walker
my $walker = SimpleTreeWalker.new;

# Create a query AST (simplified example)
# In practice, Query AST would come from Slang or be constructed programmatically
my $query = ...; # RakuAST::Node instance

# Option 1: Plan then iterate
my $plan = $walker.plan($query, $root);
my $iter1 = $plan.iterator;
my $iter2 = $plan.iterator; # Independent iterator

# Option 2: Convenience method (start)
my $iter3 = $walker.start($query, $root);

# Option 3: Iterator convenience (if root stored in walker)
my $iter4 = $walker.iterator($query);

# Consume results
for $iter1 -> $result {
    say "Result: $result";
    last if $result eq "result-5";
}

# Multiple iterators are independent
say $iter2.next; # Continues from beginning
```

### Error Handling

```raku
use Qwiratry::X;

try {
    my $plan = $walker.plan($uninterpretable-query, $root);
    CATCH {
        when X::Qwiratry::UnknownQueryElement {
            say "Cannot interpret query: {.message}";
            say "Query AST: {.query-ast.raku}";
            say "Walker type: {.walker-type}";
        }
    }
}
```

### Using Optional Hooks

```raku
class HookedWalker does Walker {
    method PRE-PASS(Context $ctx) {
        # Initialize traversal state
        $ctx.count = 0;
        $ctx.visited = [];
    }
    
    method POST-PASS(Context $ctx) {
        # Finalize and report
        say "Traversed {.count} nodes";
    }
    
    # ... other methods ...
}
```

### Capability Introspection

```raku
# Check walker capabilities
my %caps = $walker.capabilities;
say "Supports lazy: {%caps<lazy><enabled>}";
say "Lazy type: {%caps<lazy><type>}";

# Check if walker supports a query
if $walker.supports($query) {
    my $plan = $walker.plan($query, $root);
} else {
    say "Walker cannot handle this query type";
}
```

### Plan Optimization

```raku
# Optimize a plan
my $optimized-plan = $plan.optimise(-> Walker::Plan $p {
    # Modify plan (return new plan)
    OptimizedPlan.new(:query($p.query), :optimizations(...))
});

# Check plan capabilities
my %plan-caps = $plan.capabilities;
say "Plan supports backtracking: {%plan-caps<backtracking><enabled>}";
```

## Common Patterns

### Multiple Iterators from Same Plan

```raku
my $plan = $walker.plan($query, $root);

# Create multiple independent iterators
my @iterators = $plan.iterator xx 5;

# Each iterator maintains independent state
for @iterators -> $iter {
    say $iter.next; # Each produces results independently
}
```

### Context State Management

```raku
class StatefulWalker does Walker {
    method plan(RakuAST::Node $query, Mu $root --> Walker::Plan) {
        my $plan = MyPlan.new(:$query, :$root);
        
        # Create context for this traversal
        my $ctx = MyContext.new;
        $ctx.initialize($root);
        
        # Store context in plan (implementation-specific)
        $plan.context = $ctx;
        
        return $plan;
    }
}

# Context persists across hook calls
class MyContext does Context {
    has @.visited;
    has %.memo;
    
    method initialize(Mu $root) {
        @!visited = [];
        %!memo = {};
    }
}
```

## Next Steps

- See `data-model.md` for entity relationships
- See `contracts/walker-api.md` for complete API reference
- Implement concrete walkers (e.g., `Tree::Walker::DFS`, `Table::Walker::Scan`)

