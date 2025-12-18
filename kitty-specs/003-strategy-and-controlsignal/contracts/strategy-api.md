# API Contract: Strategy and ControlSignal

**Feature**: 003-strategy-and-controlsignal
**Date**: 2024-12-19
**Version**: 1.0.0

## ControlSignal Enum

```raku
enum ControlSignal is export <
    NO_REWRITE
    REWRITE_IMMEDIATE
    REWRITE_DEFERRED
    SKIP_ELEMENT
    STOP_TRAVERSAL
    FINAL_RESULT
>;
```

### Semantics

| Signal | Walker Behaviour |
|--------|-----------------|
| `NO_REWRITE` | Continue traversal normally |
| `REWRITE_IMMEDIATE` | Element was rewritten in-place; continue with modified element |
| `REWRITE_DEFERRED` | Schedule rewrite for after current pass; continue normally |
| `SKIP_ELEMENT` | Do not visit this element's relations; move to next sibling |
| `STOP_TRAVERSAL` | Halt traversal immediately; proceed to finish() |
| `FINAL_RESULT` | Used by finish() to signal traversal complete |

## RewriteSpec Role

```raku
#| Stub role for rewrite specifications.
#| To be expanded in future feature when rewrite functionality is implemented.
role RewriteSpec is export {
    # Marker role - no methods required
}
```

## FinishResult Class

```raku
#| Result object returned from Strategy.finish() hook.
class FinishResult is export {
    #| Result type identifier
    has Str $.type is required;
    
    #| The result value (can be any type)
    has $.value;
    
    #| Human-readable representation
    method gist(--> Str) {
        "FinishResult(type: $.type, value: {$.value.gist})"
    }
}
```

### Construction

```raku
# Minimal
FinishResult.new(type => 'final-result')

# With value
FinishResult.new(type => 'aggregated', value => @results)

# Error result
FinishResult.new(type => 'error', value => $exception)
```

## Strategy Role

```raku
#| Role defining element-level traversal behaviour through hooks.
#| All hooks are optional; undefined hooks use default behaviour.
role Strategy is export {
    
    #| Called before visiting an element (pre-visit).
    #| Return a ControlSignal to control traversal, or Nil for default.
    method before($element, Context $ctx --> ControlSignal) { ... }
    
    #| Called when a query matches an element.
    #| Can return ControlSignal, RewriteSpec, or Nil.
    method on-match($element, Match $match, Context $ctx --> ControlSignal) { ... }
    
    #| Decide whether to follow a relation to another element.
    #| Return False to prune this branch.
    method should-follow($origin, $relation, $target, Context $ctx --> Bool) { True }
    
    #| Called after visiting all relations of an element (post-visit).
    #| Can return ControlSignal, RewriteSpec, or Nil.
    method after($element, Context $ctx --> ControlSignal) { ... }
    
    #| Called after completing a full traversal.
    #| Return a FinishResult with traversal outcome.
    method finish($root, Context $ctx --> FinishResult) {
        FinishResult.new(type => 'final-result', value => Nil)
    }
    
    #| Decide whether to continue with another traversal pass.
    #| Return True to trigger fixed-point iteration.
    method should-continue($root, Context $ctx --> Bool) { False }
}
```

### Hook Call Order

```
for each element in traversal:
    1. before($element, $ctx)
       - If SKIP_ELEMENT: skip to next element
       - If STOP_TRAVERSAL: goto finish()
    
    2. if query matches element:
       on-match($element, $match, $ctx)
       - If SKIP_ELEMENT: skip to next element
       - If STOP_TRAVERSAL: goto finish()
    
    3. for each relation of element:
       if should-follow($element, $relation, $target, $ctx):
           recursively process $target
    
    4. after($element, $ctx)
       - If STOP_TRAVERSAL: goto finish()

when all elements processed (or STOP_TRAVERSAL):
    5. finish($root, $ctx)
    
    6. if should-continue($root, $ctx):
       start new traversal pass
```

## Context Extension

```raku
#| Extended Context role with Strategy accessor.
role Context {
    #| The Strategy instance for this traversal (may be undefined)
    has Strategy $.strategy;
}
```

## Walker Extension

```raku
#| Extended Walker role with Strategy support.
role Walker does Iterable {
    #| Default Strategy for this Walker (may be undefined)
    has Strategy $.strategy;
    
    #| Plan execution strategy (existing method - unchanged)
    method plan(RakuAST::Node $query, Mu $root --> Walker::Plan) { ... }
    
    #| Produce QueryIterator (existing method - now calls Strategy hooks)
    method iterator(Walker::Plan $plan --> QueryIterator) { ... }
    
    #| Convenience method (existing - unchanged)
    method start(RakuAST::Node $query, Mu:D $root --> QueryIterator) { ... }
}
```

### Walker Construction

```raku
# Without Strategy (backward compatible)
my $walker = SomeWalker.new;

# With Strategy
my $walker = SomeWalker.new(strategy => MyStrategy.new);

# Strategy stored in Context at traversal start
method iterator(Walker::Plan $plan --> QueryIterator) {
    my $ctx = Context.new(strategy => $.strategy);
    # ... traversal logic calls hooks via $ctx.strategy
}
```

## Error Handling Contract

### Default Behaviour

Exceptions from Strategy hooks propagate to caller (fail-fast).

### Fault-Tolerant Strategy Pattern

```raku
class FaultTolerantStrategy does Strategy {
    method before($element, Context $ctx --> ControlSignal) {
        CATCH {
            default {
                # Log error, continue traversal
                $ctx.log-error($_);
                return Nil;
            }
        }
        # ... actual logic
    }
}
```

### Walker-Level Error Capture (Optional)

```raku
class SafeWalker does Walker {
    has Bool $.capture-hook-errors = False;
    
    # In traversal logic:
    if $.capture-hook-errors {
        my $result = try { $ctx.strategy.before($element, $ctx) };
        $ctx.log-error($!) if $!;
    } else {
        $ctx.strategy.before($element, $ctx);
    }
}
```

## Backward Compatibility

- Walker without Strategy works as before (all hooks skipped)
- Context without Strategy works as before ($.strategy is undefined)
- Existing Walker implementations need no changes unless they want Strategy support

