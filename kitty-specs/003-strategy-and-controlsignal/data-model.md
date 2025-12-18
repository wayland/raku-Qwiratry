# Data Model: Strategy and ControlSignal

**Feature**: 003-strategy-and-controlsignal
**Date**: 2024-12-19

## Entities

### ControlSignal (Enum)

Enumeration of signals that communicate Strategy decisions to Walker.

| Value | Numeric | Semantics |
|-------|---------|-----------|
| `NO_REWRITE` | 0 | Continue traversal, no changes |
| `REWRITE_IMMEDIATE` | 1 | Rewrite performed inline in hook |
| `REWRITE_DEFERRED` | 2 | Schedule rewrite for after current pass |
| `SKIP_ELEMENT` | 3 | Skip this element and its relations |
| `STOP_TRAVERSAL` | 4 | Halt traversal immediately |
| `FINAL_RESULT` | 5 | Signal end of traversal (used in finish) |

**Constraints**:
- Values are mutually exclusive (only one can be returned per hook call)
- Precedence: STOP_TRAVERSAL > SKIP_ELEMENT > REWRITE_* > NO_REWRITE

### Strategy (Role)

Role defining element-level traversal behaviour through hooks.

**Attributes**: None (stateless role; state lives in Context)

**Methods** (all optional):

| Method | Signature | Return Type | Default |
|--------|-----------|-------------|---------|
| `before` | `($element, Context $ctx)` | `ControlSignal\|Nil` | `Nil` |
| `on-match` | `($element, Match $match, Context $ctx)` | `ControlSignal\|RewriteSpec\|Nil` | `Nil` |
| `should-follow` | `($origin, $relation, $target, Context $ctx)` | `Bool` | `True` |
| `after` | `($element, Context $ctx)` | `ControlSignal\|RewriteSpec\|Nil` | `Nil` |
| `finish` | `($root, Context $ctx)` | `FinishResult` | `FinishResult.new(type => 'final-result', value => Nil)` |
| `should-continue` | `($root, Context $ctx)` | `Bool` | `False` |

**Relationships**:
- Used by: Walker (via constructor injection)
- Accesses: Context (for state management)
- Returns: ControlSignal, RewriteSpec, FinishResult

### RewriteSpec (Role)

Stub role for rewrite specifications. To be expanded in future feature.

**Attributes**: None defined (stub)

**Methods**: None defined (stub)

**Purpose**: Type marker for rewrite return values from `on-match` and `after` hooks.

### FinishResult (Class)

Result object returned from Strategy.finish() hook.

**Attributes**:

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `type` | `Str` | Yes | Result type identifier (e.g., 'final-result', 'aggregated', 'error') |
| `value` | `Mu` | No | The result value (can be any type) |

**Methods**:

| Method | Signature | Return Type | Description |
|--------|-----------|-------------|-------------|
| `new` | `(:$type!, :$value)` | `FinishResult` | Constructor |
| `gist` | `()` | `Str` | Human-readable representation |

### Context (Role - Extended)

Extension to existing Context role from feature 002.

**New Attributes**:

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `strategy` | `Strategy` | No | The Strategy instance for this traversal |

**Existing**: Remains as generic ancestor for all Context roles.

### Walker (Role - Extended)

Extension to existing Walker role from feature 002.

**New Attributes**:

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `strategy` | `Strategy` | No | Default Strategy for this Walker |

**Modified Behaviour**:
- `plan()`: May consult Strategy for planning decisions
- `iterator()`: Creates Context with Strategy, calls hooks during traversal
- `PRE-PASS`: Calls Strategy setup if needed
- `POST-PASS`: Calls `should-continue` to decide on additional passes

## Entity Relationships

```
┌─────────────┐     injects      ┌──────────┐
│   Walker    │─────────────────>│ Strategy │
└─────────────┘                  └──────────┘
       │                               │
       │ creates                       │ accessed via
       ▼                               ▼
┌─────────────┐     stores      ┌──────────┐
│   Context   │<────────────────│ Strategy │
└─────────────┘                 └──────────┘
       │
       │ used by
       ▼
┌─────────────┐
│QueryIterator│
└─────────────┘
```

```
Strategy hooks return:
┌──────────────────┐
│  ControlSignal   │◄── before, on-match, after
└──────────────────┘
┌──────────────────┐
│   RewriteSpec    │◄── on-match, after (alternative)
└──────────────────┘
┌──────────────────┐
│  FinishResult    │◄── finish
└──────────────────┘
┌──────────────────┐
│      Bool        │◄── should-follow, should-continue
└──────────────────┘
```

## State Transitions

### Traversal State Machine

```
                    ┌─────────────────────────────────────────────┐
                    │                                             │
                    ▼                                             │
┌─────────┐   ┌─────────────┐   ┌─────────────┐   ┌──────────┐   │
│  START  │──>│   before()  │──>│  on-match() │──>│  after() │───┤
└─────────┘   └─────────────┘   └─────────────┘   └──────────┘   │
                    │                  │                │         │
                    │ SKIP_ELEMENT     │ SKIP_ELEMENT   │         │
                    ▼                  ▼                │         │
              ┌─────────────────────────────────┐      │         │
              │        Skip to next element     │──────┘         │
              └─────────────────────────────────┘                │
                                                                 │
                    │ STOP_TRAVERSAL   │ STOP_TRAVERSAL          │
                    ▼                  ▼                         │
              ┌─────────────────────────────────┐                │
              │           finish()              │<───────────────┘
              └─────────────────────────────────┘     (all elements done)
                              │
                              ▼
                         ┌─────────┐
                         │   END   │
                         └─────────┘
```

### Fixed-Point Iteration

```
┌─────────────────────────────────────────────────────┐
│                    Traversal Pass                    │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
              ┌─────────────────────┐
              │  should-continue()  │
              └─────────────────────┘
                    │         │
              True  │         │ False
                    ▼         ▼
         ┌──────────────┐  ┌─────────┐
         │ Another pass │  │ finish()│
         └──────────────┘  └─────────┘
```

## Validation Rules

### ControlSignal

- Must be one of the 6 defined values
- Cannot combine signals (one per hook return)

### Strategy Hooks

- All hooks are optional (not calling a hook = default behaviour)
- Hook return types must match signature
- Nil return is always valid (treated as default)

### FinishResult

- `type` is required (non-empty string)
- `value` can be any type including Nil

### Context.strategy

- Can be Nil (no strategy attached)
- If set, must be an object that does Strategy role

