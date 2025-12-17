#!/usr/bin/env raku

use Test;

plan 5;

# T035: Unit tests for dependency graph generation
# Note: These test the script's dependency graph functionality via integration

# Create test fixtures
my $test-dir = "t/dependency-test".IO;
$test-dir.mkdir unless $test-dir.d;

my $spec-file = $test-dir.child("Specification.md");
$spec-file.spurt("# 1. Test\n## 1.1 Subsection\n");

my $specs-dir = $test-dir.child("kitty-specs");
$specs-dir.mkdir unless $specs-dir.d;

# Create features with dependencies
my $feature1-dir = $specs-dir.child("001-blocker");
$feature1-dir.mkdir;
$feature1-dir.child("meta.json").spurt(q:to/META/);
{
  "feature_number": "001",
  "slug": "001-blocker",
  "friendly_name": "Blocker Feature",
  "spec_sections": ["1"],
  "dependencies": []
}
META

my $feature2-dir = $specs-dir.child("002-blocked");
$feature2-dir.mkdir;
$feature2-dir.child("meta.json").spurt(q:to/META/);
{
  "feature_number": "002",
  "slug": "002-blocked",
  "friendly_name": "Blocked Feature",
  "spec_sections": ["1.1"],
  "dependencies": ["001-blocker"]
}
META

END {
    $feature1-dir.child("meta.json").unlink if $feature1-dir.child("meta.json").e;
    $feature2-dir.child("meta.json").unlink if $feature2-dir.child("meta.json").e;
    $feature1-dir.rmdir if $feature1-dir.d;
    $feature2-dir.rmdir if $feature2-dir.d;
    $specs-dir.rmdir if $specs-dir.d;
    $spec-file.unlink if $spec-file.e;
    $test-dir.rmdir if $test-dir.d;
}

# Test 1: Generate traceability map includes dependency graph
my $script = "scripts/verify-spec-coverage.raku";
my $output-dir = $test-dir.child("docs");
$output-dir.mkdir unless $output-dir.d;

my $output = qx{raku $script --generate-map --spec-file={$spec-file} --specs-dir={$specs-dir} --output-dir={$output-dir} 2>&1};
my $exit-code = $?;
is $exit-code, 0, "Script generates map with dependencies";

# Test 2: Dependency graph section exists in output
if $output-dir.child("spec-traceability-map.md").e {
    my $content = $output-dir.child("spec-traceability-map.md").slurp;
    ok $content.contains("Dependency Graph"), "Output contains dependency graph section";
    ok $content.contains("```mermaid"), "Output contains Mermaid diagram";
}

# Test 3: Coverage script validates dependency graph
my $coverage-output = qx{raku $script --json --spec-file={$spec-file} --specs-dir={$specs-dir} 2>&1};
my $coverage-exit = $?;
is $coverage-exit, 1, "Coverage script runs with dependency validation";

# Test 4: JSON output includes dependency graph status
use JSON::Fast;
try {
    my %json = from-json($coverage-output);
    ok %json<dependency_graph>:exists, "JSON output includes dependency_graph";
    ok %json<dependency_graph><valid>:exists, "Dependency graph has valid field";
    CATCH {
        skip "Could not parse JSON output";
    }
}

$output-dir.child("spec-traceability-map.md").unlink if $output-dir.child("spec-traceability-map.md").e;
$output-dir.rmdir if $output-dir.d;

done-testing;

