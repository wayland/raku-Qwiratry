---
work_package_id: "WP06"
subtasks:
  - "T049"
  - "T050"
  - "T051"
  - "T052"
  - "T053"
  - "T054"
  - "T055"
  - "T056"
  - "T057"
  - "T058"
title: "Integration Tests and Examples"
phase: "Phase 3 - Polish"
lane: "doing"
assignee: "claude"
agent: "claude"
shell_pid: "28095"
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2024-12-19T09:45:00Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
---

# Work Package Prompt: WP06 - Integration Tests and Examples

## Objectives & Success Criteria

- All 6 user stories from spec have passing integration tests
- Edge cases from spec are tested
- Example Strategy implementations demonstrate common patterns
- quickstart.md examples compile and run correctly

## Context & Constraints

**Reference Documents**:
- `kitty-specs/003-strategy-and-controlsignal/spec.md` - User stories and acceptance scenarios
- `kitty-specs/003-strategy-and-controlsignal/quickstart.md` - Usage patterns and examples

**User Stories to Test**:
1. Basic Traversal Control (STOP_TRAVERSAL)
2. Element Skipping and Pruning (SKIP_ELEMENT, should-follow)
3. Match Processing (on-match collecting results)
4. Pre/Post Visit Processing (before/after depth tracking)
5. Traversal Completion (finish hook aggregation)
6. Fixed-Point Iteration (should-continue multi-pass)

**Edge Cases** (from spec.md):
- Hook returns Nil (continue normally)
- before returns SKIP_ELEMENT but on-match would have matched
- Signal precedence: STOP_TRAVERSAL > SKIP_ELEMENT > others
- should-follow not implemented (default True)
- finish called after early STOP_TRAVERSAL

## Subtasks & Detailed Guidance

### Subtask T049 - Integration test: Basic traversal control [P]
- **Purpose**: Test User Story 1 - STOP_TRAVERSAL
- **File**: `tests/integration/walker-strategy.rakutest`
- **Test Scenario**:
```raku
subtest 'User Story 1 - Basic Traversal Control', {
    # Create a simple tree structure
    my $tree = { name => 'root', children => [
        { name => 'a', children => [] },
        { name => 'target', children => [] },
        { name => 'b', children => [] },
    ]};
    
    # Strategy that stops when 'target' is found
    my class FindFirstStrategy does Strategy {
        has $.found;
        method on-match($element, $match, $ctx) {
            $!found = $element;
            STOP_TRAVERSAL
        }
    }
    
    my $strategy = FindFirstStrategy.new;
    # ... run walker, verify 'b' was never visited
    ok $strategy.found<name> eq 'target', 'Found target element';
    # Verify traversal stopped
}
```
- **Acceptance Criteria**:
  1. STOP_TRAVERSAL halts traversal immediately
  2. Elements after target are not visited

### Subtask T050 - Integration test: Element skipping and pruning [P]
- **Purpose**: Test User Story 2 - SKIP_ELEMENT, should-follow
- **File**: `tests/integration/walker-strategy.rakutest`
- **Test Scenario**:
```raku
subtest 'User Story 2 - Element Skipping', {
    my @visited;
    
    my class SkipMetadataStrategy does Strategy {
        method should-follow($origin, $relation, $target, $ctx --> Bool) {
            return False if $target<name> eq 'metadata';
            True
        }
        method before($element, $ctx) {
            @visited.push: $element<name>;
            Nil
        }
    }
    
    # Tree with metadata branch that should be skipped
    my $tree = { name => 'root', children => [
        { name => 'content', children => [] },
        { name => 'metadata', children => [
            { name => 'should-not-visit', children => [] }
        ]},
    ]};
    
    # ... run walker
    ok 'should-not-visit' !~~ @visited, 'Metadata branch was pruned';
}
```

### Subtask T051 - Integration test: Match processing [P]
- **Purpose**: Test User Story 3 - on-match collecting results
- **File**: `tests/integration/walker-strategy.rakutest`
- **Test Scenario**:
```raku
subtest 'User Story 3 - Match Processing', {
    my class CollectMatchesStrategy does Strategy {
        has @.matches;
        method on-match($element, $match, $ctx) {
            @!matches.push: $element;
            NO_REWRITE
        }
    }
    
    # ... run walker with query that matches certain elements
    # Verify all matches were collected
}
```

### Subtask T052 - Integration test: Pre/post visit processing [P]
- **Purpose**: Test User Story 4 - before/after hooks
- **File**: `tests/integration/walker-strategy.rakutest`
- **Test Scenario**:
```raku
subtest 'User Story 4 - Depth Tracking', {
    my class DepthTrackingStrategy does Strategy {
        has Int $.max-depth = 0;
        has Int $!current-depth = 0;
        
        method before($element, $ctx) {
            $!current-depth++;
            $!max-depth max= $!current-depth;
            Nil
        }
        method after($element, $ctx) {
            $!current-depth--;
            Nil
        }
    }
    
    # Tree with known depth
    # Verify max-depth matches expected
}
```

### Subtask T053 - Integration test: Traversal completion [P]
- **Purpose**: Test User Story 5 - finish hook
- **File**: `tests/integration/walker-strategy.rakutest`
- **Test Scenario**:
```raku
subtest 'User Story 5 - Traversal Completion', {
    my class CountingStrategy does Strategy {
        has Int $.count = 0;
        
        method before($element, $ctx) {
            $!count++;
            Nil
        }
        method finish($root, $ctx --> FinishResult) {
            FinishResult.new(type => 'counted', value => $.count)
        }
    }
    
    # ... run walker
    # Verify finish result contains correct count
}
```

### Subtask T054 - Integration test: Fixed-point iteration [P]
- **Purpose**: Test User Story 6 - should-continue
- **File**: `tests/integration/walker-strategy.rakutest`
- **Test Scenario**:
```raku
subtest 'User Story 6 - Fixed-Point Iteration', {
    my class MultiPassStrategy does Strategy {
        has Int $.pass-count = 0;
        has Int $.max-passes = 3;
        
        method before($element, $ctx) {
            # Track we're visiting elements
            Nil
        }
        method should-continue($root, $ctx --> Bool) {
            $!pass-count++;
            $!pass-count < $!max-passes
        }
    }
    
    # ... run walker
    # Verify multiple passes occurred
}
```

### Subtask T055 - Integration test: Edge cases
- **Purpose**: Test edge cases from spec
- **File**: `tests/integration/walker-strategy.rakutest`
- **Test Cases**:
  1. Nil return treated as default
  2. SKIP_ELEMENT prevents on-match
  3. Signal precedence (STOP > SKIP)
  4. finish called after STOP_TRAVERSAL

### Subtask T056 - Create example Strategy implementations
- **Purpose**: Demonstrate common patterns
- **File**: `tests/examples/strategy-examples.rakutest`
- **Examples**:
  1. FindFirstStrategy - early termination
  2. CollectAllStrategy - gather all matches
  3. PruningStrategy - skip branches
  4. DepthLimitStrategy - limit traversal depth
  5. TransformingStrategy - (stub) shows rewrite pattern

### Subtask T057 - Validate quickstart.md examples
- **Purpose**: Ensure documentation examples work
- **Steps**:
  1. Extract code examples from quickstart.md
  2. Create test file that runs each example
  3. Verify all examples compile and produce expected output

### Subtask T058 - Final test suite verification
- **Purpose**: Complete test pass
- **Steps**:
  1. Run full test suite: `prove6 -l tests/`
  2. Verify no failures
  3. Check test coverage if available
  4. Document any known limitations

## Parallel Opportunities

- T049-T054 can all proceed in parallel (independent user stories)
- T055-T057 can run after user story tests
- T058 runs last

## Risks & Mitigations

- **Complex test setup**: Create shared fixtures for tree structures
- **Mock data requirements**: Use simple nested hashes
- **Walker implementation differences**: Tests may need adjustment based on WP05 implementation

## Definition of Done Checklist

- [ ] User Story 1 test passes (T049)
- [ ] User Story 2 test passes (T050)
- [ ] User Story 3 test passes (T051)
- [ ] User Story 4 test passes (T052)
- [ ] User Story 5 test passes (T053)
- [ ] User Story 6 test passes (T054)
- [ ] Edge case tests pass (T055)
- [ ] Example strategies created (T056)
- [ ] quickstart.md examples validated (T057)
- [ ] Full test suite passes (T058)
- [ ] `tasks.md` updated with status change

## Review Guidance

- Each user story test should be self-contained
- Examples should be copy-pasteable
- Edge cases should cover spec.md scenarios

## Activity Log

- 2024-12-19T09:45:00Z - system - lane=planned - Prompt created.
- 2024-12-19T12:25:00Z - claude - shell_pid=28095 - lane=doing - Started implementation
- 2024-12-19T12:45:00Z - claude - shell_pid=28095 - lane=doing - Completed all user story tests (T049-T054)
- 2024-12-19T12:45:00Z - claude - shell_pid=28095 - lane=doing - Completed edge case tests (T055)
- 2024-12-19T12:45:00Z - claude - shell_pid=28095 - lane=doing - Created example Strategy implementations (T056)
- 2024-12-19T12:45:00Z - claude - shell_pid=28095 - lane=doing - Validated quickstart.md examples (T057)
- 2024-12-19T12:45:00Z - claude - shell_pid=28095 - lane=doing - Verified full test suite passes (T058)

