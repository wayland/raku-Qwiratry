#!/usr/bin/env raku

use Test;

plan 8;

# T037: Integration test for traceability map generation

# Create test fixtures
my $test-dir = "t/integration-test".IO;
$test-dir.mkdir unless $test-dir.d;

my $spec-file = $test-dir.child("Specification.md");
$spec-file.spurt(q:to/SPEC/);
# 1. Introduction

## 1.1 Purpose

## 1.2 Principles

# 2. Architecture

## 2.1 Overview
SPEC

my $specs-dir = $test-dir.child("kitty-specs");
$specs-dir.mkdir unless $specs-dir.d;

my $feature-dir = $specs-dir.child("001-test-feature");
$feature-dir.mkdir unless $feature-dir.d;

my $meta-file = $feature-dir.child("meta.json");
$meta-file.spurt(q:to/META/);
{
  "feature_number": "001",
  "slug": "001-test-feature",
  "friendly_name": "Test Feature",
  "spec_sections": ["1.1", "2.1"],
  "dependencies": []
}
META

my $output-dir = $test-dir.child("docs");
$output-dir.mkdir unless $output-dir.d;

END {
    $meta-file.unlink if $meta-file.e;
    $feature-dir.rmdir if $feature-dir.d;
    $specs-dir.rmdir if $specs-dir.d;
    $output-dir.child("spec-traceability-map.md").unlink if $output-dir.child("spec-traceability-map.md").e;
    $output-dir.rmdir if $output-dir.d;
    $spec-file.unlink if $spec-file.e;
    $test-dir.rmdir if $test-dir.d;
}

# Test 1: Script runs without errors
my $script = "scripts/verify-spec-coverage.raku";
ok $script.IO.e, "Script exists";

# Test 2: Generate traceability map
my $output = qx{raku $script --generate-map --spec-file={$spec-file} --specs-dir={$specs-dir} --output-dir={$output-dir} 2>&1};
my $exit-code = $?;
is $exit-code, 0, "Script exits successfully with --generate-map";

# Test 3: Output file is created
my $output-file = $output-dir.child("spec-traceability-map.md");
ok $output-file.e, "Traceability map file is created";

# Test 4: Output file contains expected content
if $output-file.e {
    my $content = $output-file.slurp;
    ok $content.contains("Specification Traceability Map"), "Output contains title";
    ok $content.contains("Section Mappings"), "Output contains section mappings";
    ok $content.contains("001-test-feature"), "Output contains feature reference";
    ok $content.contains("Dependency Graph"), "Output contains dependency graph section";
}

# Test 5: Generated timestamp is present
if $output-file.e {
    my $content = $output-file.slurp;
    ok $content ~~ /Generated.*\d{4}-\d{2}-\d{2}/, "Output contains generation timestamp";
}

done-testing;

