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

# Test 2: Text output format
my $text-output = qx{raku $script --spec-file={$spec-file} --specs-dir={$specs-dir} 2>&1};
my $text-exit = $?;
is $text-exit, 1, "Script exits with code 1 (uncovered sections found)";
ok $text-output.contains("Coverage Report"), "Text output contains 'Coverage Report'";
ok $text-output.contains("Coverage:"), "Text output contains coverage percentage";

# Test 3: JSON output format
my $json-output = qx{raku $script --json --spec-file={$spec-file} --specs-dir={$specs-dir} 2>&1};
my $json-exit = $?;
is $json-exit, 1, "JSON mode exits with code 1";

# Test 4: Parse JSON output
my %json;
try {
    %json = from-json($json-output);
    CATCH {
        flunk "JSON output is not valid JSON: {.message}";
        exit 1;
    }
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

