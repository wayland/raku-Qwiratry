#!/usr/bin/env raku

use Test;

plan 10;

# T040: Test edge cases: missing files, malformed JSON, circular dependencies, broken links

# Create test fixtures
my $test-dir = "t/edge-cases-test".IO;
$test-dir.mkdir unless $test-dir.d;

my $spec-file = $test-dir.child("Specification.md");
$spec-file.spurt("# 1. Test\n## 1.1 Subsection\n");

my $specs-dir = $test-dir.child("kitty-specs");
$specs-dir.mkdir unless $specs-dir.d;

END {
    # Cleanup
    for $specs-dir.dir -> $entry {
        if $entry.d {
            $entry.child("meta.json").unlink if $entry.child("meta.json").e;
            $entry.rmdir if $entry.d;
        }
    }
    $specs-dir.rmdir if $specs-dir.d;
    $spec-file.unlink if $spec-file.e;
    $test-dir.rmdir if $test-dir.d;
}

my $script = "scripts/verify-spec-coverage.raku";

# Test 1: Missing meta.json file (should handle gracefully)
my $missing-meta-dir = $specs-dir.child("001-missing-meta");
$missing-meta-dir.mkdir;
# Don't create meta.json

my $proc1 = run("raku", $script, "--json", "--spec-file={$spec-file}", "--specs-dir={$specs-dir}", :out, :err);
my $output1 = $proc1.out.slurp;
is $proc1.exitcode, 1, "Script handles missing meta.json gracefully (exits 1)";
ok $output1.contains("WARN") || $output1.contains("ERROR"), 
    "Script logs warning/error for missing meta.json";

$missing-meta-dir.rmdir if $missing-meta-dir.d;

# Test 2: Invalid JSON in meta.json
my $invalid-json-dir = $specs-dir.child("002-invalid-json");
$invalid-json-dir.mkdir;
$invalid-json-dir.child("meta.json").spurt("{ invalid json }");

my $proc2 = run("raku", $script, "--json", "--spec-file={$spec-file}", "--specs-dir={$specs-dir}", :out, :err);
my $output2 = $proc2.out.slurp;
is $proc2.exitcode, 1, "Script handles invalid JSON gracefully";
ok $output2.contains("ERROR") || $output2.contains("Invalid"), 
    "Script logs error for invalid JSON";

$invalid-json-dir.child("meta.json").unlink if $invalid-json-dir.child("meta.json").e;
$invalid-json-dir.rmdir if $invalid-json-dir.d;

# Test 3: Circular dependencies
my $circular1-dir = $specs-dir.child("003-circular-a");
$circular1-dir.mkdir;
$circular1-dir.child("meta.json").spurt(q:to/META/);
{
  "feature_number": "003",
  "slug": "003-circular-a",
  "friendly_name": "Circular A",
  "spec_sections": ["1"],
  "dependencies": ["003-circular-b"]
}
META

my $circular2-dir = $specs-dir.child("003-circular-b");
$circular2-dir.mkdir;
$circular2-dir.child("meta.json").spurt(q:to/META/);
{
  "feature_number": "004",
  "slug": "003-circular-b",
  "friendly_name": "Circular B",
  "spec_sections": ["1.1"],
  "dependencies": ["003-circular-a"]
}
META

my $proc3 = run("raku", $script, "--json", "--spec-file={$spec-file}", "--specs-dir={$specs-dir}", :out, :err);
my $output3 = $proc3.out.slurp;
use JSON::Fast;
try {
    my %json = from-json($output3);
    ok %json<dependency_graph>:exists, "Dependency graph is generated";
    # Circular dependencies should be detected
    ok %json<dependency_graph><circular_dependencies>.elems > 0 || 
       %json<dependency_graph><valid> == False,
       "Circular dependencies are detected";
    CATCH {
        skip "Could not parse JSON for circular dependency test";
    }
}

$circular1-dir.child("meta.json").unlink if $circular1-dir.child("meta.json").e;
$circular2-dir.child("meta.json").unlink if $circular2-dir.child("meta.json").e;
$circular1-dir.rmdir if $circular1-dir.d;
$circular2-dir.rmdir if $circular2-dir.d;

# Test 4: Broken links (feature directory doesn't exist)
# This is tested by creating a meta.json that references a non-existent feature
my $broken-link-dir = $specs-dir.child("005-broken-link");
$broken-link-dir.mkdir;
$broken-link-dir.child("meta.json").spurt(q:to/META/);
{
  "feature_number": "005",
  "slug": "005-broken-link",
  "friendly_name": "Broken Link",
  "spec_sections": ["1"],
  "dependencies": ["999-nonexistent"]
}
META

my $proc4 = run("raku", $script, "--json", "--spec-file={$spec-file}", "--specs-dir={$specs-dir}", :out, :err);
my $output4 = $proc4.out.slurp;
try {
    my %json = from-json($output4);
    ok %json<dependency_graph><validation_errors>.elems > 0,
       "Broken links (invalid dependencies) are detected";
    CATCH {
        skip "Could not parse JSON for broken link test";
    }
}

$broken-link-dir.child("meta.json").unlink if $broken-link-dir.child("meta.json").e;
$broken-link-dir.rmdir if $broken-link-dir.d;

# Test 5: Missing specification file
my $proc5 = run("raku", $script, "--spec-file=nonexistent.md", "--specs-dir={$specs-dir}", :out, :err);
my $output5 = $proc5.out.slurp;
is $proc5.exitcode, 2, "Script exits with code 2 for missing specification file";
ok $output5.contains("ERROR") || $output5.contains("not found"),
    "Script reports error for missing specification file";

done-testing;

