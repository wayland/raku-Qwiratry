# Test Suite for Specification Traceability Map

## Running Tests

### Individual Test Files

Run a single test file directly with Raku:

```bash
raku -I. tests/unit/spec-parser.t
raku -I. tests/unit/feature-metadata.t
raku -I. tests/integration/traceability-map-gen.t
```

### All Unit Tests

Run all unit tests:

```bash
for test in tests/unit/*.t; do raku -I. "$test"; done
```

### All Integration Tests

Run all integration tests:

```bash
for test in tests/integration/*.t; do raku -I. "$test"; done
```

### Using prove6 (if available)

If `prove6` is installed, you can use it to run all tests:

```bash
prove6 -v tests/
```

## Test Structure

- **Unit Tests** (`tests/unit/`): Test individual functions and modules in isolation
  - `spec-parser.t`: Tests for Specification.md parsing
  - `feature-metadata.t`: Tests for meta.json reading
  - `dependency-graph.t`: Tests for dependency graph generation
  - `coverage-calc.t`: Tests for coverage calculation

- **Integration Tests** (`tests/integration/`): Test end-to-end workflows
  - `traceability-map-gen.t`: End-to-end traceability map generation
  - `coverage-script.t`: End-to-end coverage script execution

## Test Framework

Tests use Raku's built-in `Test` module. Each test file should:

1. Import the Test module: `use Test;`
2. Declare test plan: `plan N;` (where N is the number of tests)
3. Use test functions: `ok()`, `is()`, `is-deeply()`, `dies-ok()`, etc.

## Writing Tests

See the Raku Test module documentation: https://docs.raku.org/language/testing

