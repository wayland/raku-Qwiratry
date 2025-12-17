#!/usr/bin/env raku

use Test;
use JSON::Fast;

plan 15;

# T038 & T039: Integration test for coverage script execution and JSON contract validation

# Create test fixtures
my $test-dir = "t/coverage-test".IO;
$test-dir.mkdir unless $test-dir.d;

my $spec-file = $test-dir.child("Specification.md");
$spec-file.spurt(q:to/SPEC/);
# 1. Introduction

## 1.1 Purpose

## 1.2 Principles

# 2. Architecture

## 2.1 Overview

## 2.2 Details
SPEC

my $specs-dir = $test-dir.child("kitty-specs");
$specs-dir.mkdir unless $specs-dir.d;

my $feature1-dir = $specs-dir.child("001-covered-feature");
$feature1-dir.mkdir unless $feature1-dir.d;

my $meta1-file = $feature1-dir.child("meta.json");
$meta1-file.spurt(q:to/META/);
{
  "feature_number": "001",
  "slug": "001-covered-feature",
  "friendly_name": "Covered Feature",
  "spec_sections": ["1.1", "2.1"],
  "dependencies": []
}
META

# Create a feature with missing directory (for broken link test)
my $feature2-dir = $specs-dir.child("002-missing-feature");
# Don't create the directory - this simulates a broken link

END {
    $meta1-file.unlink if $meta1-file.e;
    $feature1-dir.rmdir if $feature1-dir.d;
    $specs-dir.rmdir if $specs-dir.d;
    $spec-file.unlink if $spec-file.e;
    $test-dir.rmdir if $test-dir.d;
}

# Test 1: Script runs coverage check
my $script = "scripts/verify-spec-coverage.raku";
ok $script.IO.e, "Script exists";

# Helper: Run script and return proc and output
# For JSON mode, JSON is on stdout, errors on stderr
sub run-script(*@args) {
    my $proc = run("raku", $script, |@args, :out, :err);
    my $stdout = $proc.out.slurp;
    my $stderr = $proc.err.slurp;
    # For JSON mode, return stdout (JSON), otherwise merge both
    my $output = @args.grep(* eq "--json").elems > 0 ?? $stdout !! $stdout ~ $stderr;
    return ($proc, $output);
}

# Helper function to try parsing JSON
sub try-parse-json(Str $text) {
    my $result;
    try {
        $result = from-json($text);
        CATCH {
            return Nil;
        }
    }
    return $result;
}

# Test 2: Text output format
my ($text-proc, $text-output) = run-script("--spec-file={$spec-file}", "--specs-dir={$specs-dir}");
is $text-proc.exitcode, 1, "Script exits with code 1 (uncovered sections found)";
ok $text-output.contains("Coverage Report"), "Text output contains 'Coverage Report'";
ok $text-output.contains("Coverage:"), "Text output contains coverage percentage";

# Test 3: JSON output format
my ($json-proc, $json-output) = run-script("--json", "--spec-file={$spec-file}", "--specs-dir={$specs-dir}");
is $json-proc.exitcode, 1, "JSON mode exits with code 1";

# Test 4: Parse JSON output
# JSON is on stdout, may be multi-line

my %json;
# Try parsing the entire output as JSON first
my $json-result = try-parse-json($json-output);
if $json-result {
    %json = $json-result;
} else {
    # If that fails, try to extract JSON from lines containing { or [
    my $json-lines = $json-output.lines.grep({$_ ~~ /[\{]/ || $_ ~~ /[\[]/});
    if $json-lines.elems > 0 {
        my $json-text = $json-lines.join("\n");
        $json-result = try-parse-json($json-text);
        if $json-result {
            %json = $json-result;
        }
    }
}

unless %json {
    flunk "JSON output is not valid JSON. Output: {$json-output.head(200)}";
    exit 1;
}

# Test 5: JSON structure matches contract (T039)
ok %json<status>:exists, "JSON has 'status' field";
ok %json<coverage_percent>:exists, "JSON has 'coverage_percent' field";
ok %json<total_sections>:exists, "JSON has 'total_sections' field";
ok %json<covered_sections>:exists, "JSON has 'covered_sections' field";
ok %json<uncovered_sections>:exists, "JSON has 'uncovered_sections' field";
ok %json<broken_links>:exists, "JSON has 'broken_links' field";
ok %json<dependency_graph>:exists, "JSON has 'dependency_graph' field";

# Test 6: JSON field types match contract
ok %json<coverage_percent> ~~ Real, "coverage_percent is a number";
ok %json<total_sections> ~~ Int, "total_sections is an integer";
ok %json<uncovered_sections> ~~ Array, "uncovered_sections is an array";
ok %json<broken_links> ~~ Array, "broken_links is an array";
ok %json<dependency_graph> ~~ Hash, "dependency_graph is an object";

# Test 7: Dependency graph structure
my %graph = %json<dependency_graph>;
ok %graph<valid>:exists, "dependency_graph has 'valid' field";
ok %graph<circular_dependencies>:exists, "dependency_graph has 'circular_dependencies' field";

# Test 8: Uncovered sections structure
if %json<uncovered_sections>.elems > 0 {
    my %first-uncovered = %json<uncovered_sections>[0];
    ok %first-uncovered<section>:exists, "Uncovered section has 'section' field";
    ok %first-uncovered<title>:exists, "Uncovered section has 'title' field";
    ok %first-uncovered<level>:exists, "Uncovered section has 'level' field";
}

done-testing;

