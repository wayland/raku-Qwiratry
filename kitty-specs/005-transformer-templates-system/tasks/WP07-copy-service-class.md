---
work_package_id: WP07
title: Copy Service Class
lane: done
history:
- timestamp: '2025-01-27T23:45:00Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
- timestamp: '2025-01-28T10:35:00Z'
  lane: doing
  agent: claude
  shell_pid: '64642'
  action: Started implementation
- timestamp: '2025-01-28T11:15:00Z'
  lane: for_review
  agent: claude
  shell_pid: '64642'
  action: 'WP07 implementation complete: All subtasks (T033-T044) implemented. Qwiratry::Copy service class with copy() and deepcopy() multi subs. Cycle detection and DAG preservation working. Custom method check implemented. Methods attached to Transformer. All unit tests passing (10/10).'
- timestamp: '2025-01-28T11:30:00Z'
  lane: done
  agent: claude
  shell_pid: '71544'
  action: 'Code review complete: All requirements met. Implementation follows spec section 3.3.6. All tests passing (10/10). Cycle detection and DAG preservation working correctly. Custom method check implemented for all types. Methods properly attached to Transformer. Approved without changes.'
agent: claude
assignee: ''
phase: Phase 2 - Core
review_status: approved without changes
reviewed_by: claude
shell_pid: '71544'
subtasks:
- T033
- T034
- T035
- T036
- T037
- T038
- T039
- T040
- T041
- T042
- T043
- T044
---
*Path: [templates/task-prompt-template.md](templates/task-prompt-template.md)*

## Review Feedback

**Status**: ✅ **Approved Without Changes**

**Review Summary**:
The implementation fully meets all requirements specified in the task prompt. All subtasks (T033-T044) have been completed successfully.

**What Was Done Well**:
- ✅ All multi subs correctly implemented for `copy()` and `deepcopy()` (Mu, Positional, Associative)
- ✅ Cycle detection properly implemented using visited hash with placeholder pattern (prevents infinite recursion)
- ✅ DAG preservation working correctly (single clone per unique node via visited hash)
- ✅ Custom method check implemented for all types (Mu, Positional, Associative) using `^find_method('copy', :no_fallback)`
- ✅ Methods properly attached to Transformer class with correct delegation to service functions
- ✅ Comprehensive unit tests (10/10 subtests passing) covering all scenarios
- ✅ Performance requirement met: `copy()` is O(1) via `clone`
- ✅ Code follows spec section 3.3.6 structure and requirements
- ✅ Proper use of proto subs to avoid conflicts with built-in `copy`
- ✅ Cycle detection test passes (no infinite loops)
- ✅ DAG preservation test passes (shared children cloned once)

**Implementation Details Verified**:
- `Qwiratry::Copy` module structure correct with proper exports
- `copy(Mu)` checks for custom method before returning identity
- `copy(Positional)` and `copy(Associative)` use `clone` for O(1) shallow copy
- `deepcopy(Positional)` and `deepcopy(Associative)` use visited hash pattern with placeholder storage before recursion
- Transformer methods correctly delegate: `method copy($node) { Qwiratry::Copy::copy($node) }`
- All edge cases handled: empty arrays/hashes, immutable primitives, complex nested structures

**Test Results**:
- All 10 subtests passing:
  1. ✅ copy() - shallow copy (7 assertions)
  2. ✅ deepcopy() - recursive deep copy (7 assertions)
  3. ✅ Cycle detection (2 assertions)
  4. ✅ DAG preservation (2 assertions)
  5. ✅ Custom .copy() method (2 assertions)
  6. ✅ Transformer copy() and deepcopy() methods (4 assertions)
  7. ✅ Performance - copy is O(1) (1 assertion)
  8. ✅ Edge cases (3 assertions)
  9. ✅ Immutable primitives (4 assertions)
  10. ✅ Complex structures (2 assertions)

**No Issues Found**:
- No bugs or regressions detected
- No missing tests identified
- No performance concerns
- Code quality is excellent

**Action Items**: None - ready to proceed to next work package.

# Work Package Prompt: WP07 – Copy Service Class

## Objectives & Success Criteria

- Implement `Qwiratry::Copy` service class with `copy()` and `deepcopy()` multi subs
- Provide default implementations for `Positional` and `Associative` types
- Implement cycle detection for `deepcopy`
- Implement DAG preservation (single clone per unique node)
- Attach methods to Transformer object for convenient access
- Check for custom `.copy()` method before using default

## Context & Constraints

- **Prerequisites**: WP02 (transformer declarator)
- **Related Documents**: 
  - `plan.md` - Architecture decision #5 (Copy service class approach)
  - `research.md` - RQ6 (Copy service class implementation)
  - `spec.md` - Section 3.3.6, FR-015, FR-016, FR-031-FR-034
  - `contracts/transformer-api.md` - Copy service class API
- **Architecture**: Service class with multi subs, methods attached to Transformer
- **Constraints**: Must follow spec section 3.3.6 exactly, must be O(1) for copy, must handle cycles/DAGs

## Subtasks & Detailed Guidance

### Subtask T033 – Create Copy module

- **Purpose**: Create `Qwiratry::Copy` module structure
- **Steps**:
  1. In `lib/Qwiratry/Copy.rakumod`, create unit module declaration
  2. Export `copy` and `deepcopy` multi subs
  3. Set up module structure for multi subs
- **Files**: `lib/Qwiratry/Copy.rakumod`
- **Parallel?**: No
- **Notes**: Follow spec section 3.3.6 structure exactly.

### Subtask T034 – copy(Mu) multi sub

- **Purpose**: Default identity case for copy
- **Steps**:
  1. Implement `multi sub copy(Mu $x --> Mu) { $x }`
  2. This is the default case (identity - returns as-is)
  3. More specific multi subs will override this for Positional/Associative
- **Files**: `lib/Qwiratry/Copy.rakumod`
- **Parallel?**: No
- **Notes**: Default case handles atoms, objects with identity.

### Subtask T035 – copy(Positional) multi sub

- **Purpose**: Shallow copy for Positional types
- **Steps**:
  1. Implement `multi sub copy(Positional $p --> Positional)`
  2. First check if `$p` has custom `.copy()` method, call it if available
  3. Otherwise, use `$p.clone` for shallow copy
  4. Ensure O(1) operation (children shared with original)
- **Files**: `lib/Qwiratry/Copy.rakumod`
- **Parallel?**: No (depends on T034)
- **Notes**: Check for custom method first, then use default. Must be O(1).

### Subtask T036 – copy(Associative) multi sub

- **Purpose**: Shallow copy for Associative types
- **Steps**:
  1. Implement `multi sub copy(Associative $a --> Associative)`
  2. First check if `$a` has custom `.copy()` method, call it if available
  3. Otherwise, use `$a.clone` for shallow copy
  4. Ensure O(1) operation (children shared with original)
- **Files**: `lib/Qwiratry/Copy.rakumod`
- **Parallel?**: No (depends on T034)
- **Notes**: Check for custom method first, then use default. Must be O(1).

### Subtask T037 – deepcopy(Mu) multi sub

- **Purpose**: Default identity case for deepcopy
- **Steps**:
  1. Implement `multi sub deepcopy(Mu $x --> Mu) { $x }`
  2. This is the default case (identity - returns as-is for atoms, objects with identity)
  3. More specific multi subs will override this for Positional/Associative
- **Files**: `lib/Qwiratry/Copy.rakumod`
- **Parallel?**: No
- **Notes**: Default case handles immutable primitives (Str, Numeric, Bool).

### Subtask T038 – deepcopy(Positional) multi sub

- **Purpose**: Recursive deep copy for Positional types
- **Steps**:
  1. Implement `multi sub deepcopy(Positional $p --> Positional)`
  2. Use `$p.map({ deepcopy($_) }).Array` for recursive deep copy
  3. This will recursively call `deepcopy` on each element
  4. Return new Array with deep-copied elements
- **Files**: `lib/Qwiratry/Copy.rakumod`
- **Parallel?**: No (depends on T037)
- **Notes**: Recursive map handles deep copying. Cycle detection will be added in T040.

### Subtask T039 – deepcopy(Associative) multi sub

- **Purpose**: Recursive deep copy for Associative types with cycle detection
- **Steps**:
  1. Implement `multi sub deepcopy(Associative $a --> Associative)`
  2. Use `$a.map({ .key => deepcopy(.value) }).Hash` for recursive deep copy
  3. This will recursively call `deepcopy` on each value
  4. Return new Hash with deep-copied values
  5. Cycle detection will be added in T040 (may need to refactor to support visited hash)
- **Files**: `lib/Qwiratry/Copy.rakumod`
- **Parallel?**: No (depends on T037)
- **Notes**: Recursive map handles deep copying. May need refactoring for cycle detection.

### Subtask T040 – Cycle detection

- **Purpose**: Detect cycles in deepcopy to prevent infinite recursion
- **Steps**:
  1. Add "visited" hash parameter to `deepcopy` multi subs (or use internal state)
  2. Key visited hash by object identity (`.WHICH` method)
  3. Before recursing, check if node is in visited hash
  4. If visited, return existing clone from visited hash (reuse)
  5. If not visited, add to visited hash before recursing
  6. Update Positional and Associative deepcopy to use visited hash
- **Files**: `lib/Qwiratry/Copy.rakumod`
- **Parallel?**: No (depends on T038, T039)
- **Notes**: Cycle detection prevents infinite recursion. Use object identity for keys.

### Subtask T041 – DAG preservation

- **Purpose**: Preserve DAG structure (single clone per unique node regardless of parent count)
- **Steps**:
  1. Ensure visited hash maintains single clone per unique node
  2. When multiple parents reference same child, all should reference same clone
  3. This is handled by visited hash: first encounter creates clone, subsequent encounters reuse
  4. Test with DAG structures to verify preservation
- **Files**: `lib/Qwiratry/Copy.rakumod`
- **Parallel?**: No (depends on T040)
- **Notes**: DAG preservation is automatic with visited hash approach. Test thoroughly.

### Subtask T042 – Custom method check

- **Purpose**: Check for custom `.copy()` method before using default implementation
- **Steps**:
  1. In `copy(Positional)` and `copy(Associative)` multi subs, check if node has `.copy()` method
  2. Use `.^find_method('copy')` or similar to check for method
  3. If custom method exists, call it: `$p.copy()`
  4. If no custom method, use default implementation (`clone`)
  5. Custom method must still adhere to O(1) constraint (document in comments)
- **Files**: `lib/Qwiratry/Copy.rakumod`
- **Parallel?**: No (depends on T035, T036)
- **Notes**: Check for custom method first. Custom methods should still be O(1).

### Subtask T043 – Attach methods to Transformer

- **Purpose**: Attach `copy()` and `deepcopy()` methods to Transformer object for convenient access
- **Steps**:
  1. In Transformer class, add methods: `method copy($node) { Qwiratry::Copy::copy($node) }`
  2. Add method: `method deepcopy($node) { Qwiratry::Copy::deepcopy($node) }`
  3. Methods delegate to service functions
  4. This enables convenient syntax: `$transformer.copy($node)`
- **Files**: `lib/Qwiratry/Transformer.rakumod`
- **Parallel?**: No (depends on T033-T041)
- **Notes**: Methods provide convenient access to service functions. Delegate pattern.

### Subtask T044 – Unit tests for Copy

- **Purpose**: Verify Copy service class works correctly
- **Steps**:
  1. Test `copy(Positional)`: shallow copy, children shared, O(1) operation
  2. Test `copy(Associative)`: shallow copy, children shared, O(1) operation
  3. Test `copy(Mu)`: identity for other types
  4. Test `deepcopy(Positional)`: recursive deep copy, all descendants cloned
  5. Test `deepcopy(Associative)`: recursive deep copy, all descendants cloned
  6. Test `deepcopy(Mu)`: identity for immutable primitives
  7. Test cycle detection: circular references handled correctly
  8. Test DAG preservation: shared children cloned once
  9. Test custom method: custom `.copy()` method is used if available
  10. Test method attachment: Transformer methods delegate correctly
- **Files**: `tests/unit/copy.rakutest`
- **Parallel?**: Yes
- **Notes**: Test all scenarios, edge cases, cycles, DAGs, custom methods.

## Test Strategy

- **Unit tests**: Test all multi subs, cycle detection, DAG preservation, custom methods
- **Test location**: `tests/unit/copy.rakutest`

## Risks & Mitigations

- **Cycle detection complexity**: Use standard visited hash pattern, test thoroughly
- **DAG preservation**: Visited hash automatically handles this, verify with tests
- **Performance**: Ensure copy is O(1), deepcopy is efficient

## Definition of Done Checklist

- [x] All multi subs implemented (copy and deepcopy for Mu, Positional, Associative)
- [x] Cycle detection implemented and tested
- [x] DAG preservation implemented and tested
- [x] Custom method check implemented
- [x] Methods attached to Transformer object
- [x] Unit tests pass
- [x] Performance requirements met (copy O(1))
- [x] `tasks.md` updated with status change

## Activity Log

- 2025-01-27T23:45:00Z – system – lane=planned – Prompt created.
- 2025-01-28T10:35:00Z – claude – shell_pid=64642 – lane=doing – Started implementation: Implementing Qwiratry::Copy service class with copy() and deepcopy() multi subs.
- 2025-01-28T11:00:00Z – claude – shell_pid=64642 – lane=doing – Completed T033-T043: Created Qwiratry::Copy module with all multi subs. Implemented copy() for Mu/Positional/Associative with custom method check. Implemented deepcopy() with cycle detection and DAG preservation using visited hash. Attached copy() and deepcopy() methods to Transformer. Fixed cycle detection by storing placeholder before recursing.
- 2025-01-28T11:15:00Z – claude – shell_pid=64642 – lane=doing – Completed T044: Added comprehensive unit tests for Copy service. All tests passing (10/10 subtests). Tests cover shallow copy, deep copy, cycle detection, DAG preservation, custom methods, Transformer methods, performance, edge cases, and complex structures. Ready for review.

