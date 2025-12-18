# Quickstart: Strategy and ControlSignal

**Feature**: 003-strategy-and-controlsignal

## Overview

Strategy provides pluggable, walker-agnostic behaviour for element processing during traversal. ControlSignal is an enumeration that communicates Strategy decisions to the Walker.

## Basic Usage

### 1. Import the modules

```raku
use Qwiratry::ControlSignal;
use Qwiratry::Strategy;
use Qwiratry::FinishResult;
use Qwiratry::Walker;
use Qwiratry::Context;
```

### 2. Create a simple Strategy

```raku
class CollectMatchesStrategy does Strategy {
    method on-match($element, Match $match, Context $ctx --> ControlSignal) {
        # Store matched elements in Context
        $ctx.matches.push: $element;
        NO_REWRITE;  # Continue traversal
    }
    
    method finish($root, Context $ctx --> FinishResult) {
        FinishResult.new(
            type => 'collected',
            value => $ctx.matches
        );
    }
}
```

### 3. Use Strategy with Walker

```raku
my $strategy = CollectMatchesStrategy.new;
my $walker = SomeWalker.new(strategy => $strategy);

my $plan = $walker.plan($query, $root);
my $iterator = $plan.iterator;

# Iterate results - Strategy hooks called automatically
for $iterator -> $result {
    say $result;
}
```

## Common Patterns

### Early Termination (Find First)

```raku
class FindFirstStrategy does Strategy {
    has $.found;
    
    method on-match($element, Match $match, Context $ctx --> ControlSignal) {
        $!found = $element;
        STOP_TRAVERSAL;  # Stop immediately
    }
    
    method finish($root, Context $ctx --> FinishResult) {
        FinishResult.new(type => 'found', value => $.found);
    }
}
```

### Branch Pruning

```raku
class SkipMetadataStrategy does Strategy {
    method should-follow($origin, $relation, $target, Context $ctx --> Bool) {
        # Don't traverse into metadata nodes
        return False if $target.name eq 'metadata';
        True;
    }
}
```

### Element Filtering

```raku
class SkipCommentsStrategy does Strategy {
    method before($element, Context $ctx --> ControlSignal) {
        return SKIP_ELEMENT if $element.type eq 'comment';
        Nil;  # Continue normally
    }
}
```

### Depth Tracking

```raku
class DepthTrackingStrategy does Strategy {
    method before($element, Context $ctx --> ControlSignal) {
        $ctx.depth++;
        Nil;
    }
    
    method after($element, Context $ctx --> ControlSignal) {
        $ctx.depth--;
        Nil;
    }
}
```

### Fixed-Point Iteration

```raku
class OptimizationStrategy does Strategy {
    method on-match($element, Match $match, Context $ctx --> ControlSignal) {
        if can-optimize($element) {
            $ctx.changes++;
            REWRITE_IMMEDIATE;
        } else {
            NO_REWRITE;
        }
    }
    
    method should-continue($root, Context $ctx --> Bool) {
        # Continue until no more optimizations possible
        my $had-changes = $ctx.changes > 0;
        $ctx.changes = 0;  # Reset for next pass
        $had-changes;
    }
}
```

### Fault-Tolerant Strategy

```raku
class SafeLoggingStrategy does Strategy {
    method before($element, Context $ctx --> ControlSignal) {
        CATCH {
            default {
                note "Warning: before hook failed for {$element.gist}: $_";
                return Nil;  # Continue despite error
            }
        }
        $ctx.log("Visiting: {$element.gist}");
        Nil;
    }
}
```

## ControlSignal Reference

| Signal | Use When |
|--------|----------|
| `NO_REWRITE` | Processing complete, continue normally |
| `REWRITE_IMMEDIATE` | You modified the element in-place |
| `REWRITE_DEFERRED` | Schedule modification for after pass |
| `SKIP_ELEMENT` | Skip this element and its children |
| `STOP_TRAVERSAL` | Found what you need, stop now |
| `FINAL_RESULT` | Used in finish() to signal completion |

## Hook Quick Reference

| Hook | Called | Returns | Default |
|------|--------|---------|---------|
| `before` | Before visiting element | ControlSignal/Nil | Nil (continue) |
| `on-match` | When query matches | ControlSignal/RewriteSpec/Nil | Nil |
| `should-follow` | Before following relation | Bool | True (follow) |
| `after` | After visiting relations | ControlSignal/RewriteSpec/Nil | Nil |
| `finish` | After traversal complete | FinishResult | final-result |
| `should-continue` | After each pass | Bool | False (stop) |

## Next Steps

- See `contracts/strategy-api.md` for full API documentation
- See `data-model.md` for entity relationships
- See `spec.md` for detailed requirements

