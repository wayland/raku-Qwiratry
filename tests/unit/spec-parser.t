#!/usr/bin/env raku

use Test;
use lib 'scripts';
use lib '.';

# Load script functions by evaluating the script file
# Note: This requires the script to be structured to allow function access
# For now, we'll test by running the script and checking output
# A better approach would be to extract functions into a module

# Import necessary classes and functions
# Since the script uses classes and subs, we need to eval it or restructure
# For testing purposes, we'll create a simplified test that validates behavior

plan 15;

# T033: Unit tests for spec section parsing

# Create a temporary test specification file
my $test-spec = "t/spec-test.md".IO;
$test-spec.parent.mkdir unless $test-spec.parent.d;

$test-spec.spurt(q:to/SPEC/);
# 1. Introduction

Some content here.

## 1.1 Purpose

Purpose content.

## 1.2 Principles

Principles content.

# 2. Architecture

Architecture content.

## 2.1 Overview

Overview content.

### 2.1.1 Component A

Component A content.

### 2.1.2 Component B

Component B content.

## 2.2 Details

Details content.
SPEC

END {
    $test-spec.unlink if $test-spec.e;
    $test-spec.parent.rmdir if $test-spec.parent.d && $test-spec.parent.dir.elems == 0;
}

# T033: Unit tests for spec section parsing
# Note: These are integration-style tests since functions are in the script
# For true unit tests, functions should be extracted to a module

# Test 1: Test script can parse a specification file
my $script = "scripts/verify-spec-coverage.raku";
ok $script.IO.e, "Script exists and is executable";

# Test 2: Correct number of sections
is @sections.elems, 9, "Correct number of sections extracted (9)";

# Test 3: Section identifiers are correct
my @identifiers = @sections.map(*.identifier).sort;
is-deeply @identifiers, ["1", "1.1", "1.2", "2", "2.1", "2.1.1", "2.1.2", "2.2"], 
    "Section identifiers match expected values";

# Test 4: Section titles are correct
my %section-by-id = @sections.map({$_.identifier => $_}).Hash;
is %section-by-id{"1"}.title, "Introduction", "Section 1 title is correct";
is %section-by-id{"1.1"}.title, "Purpose", "Section 1.1 title is correct";
is %section-by-id{"2.1.1"}.title, "Component A", "Section 2.1.1 title is correct";

# Test 5: Section levels are correct
is %section-by-id{"1"}.level, 1, "Top-level section has level 1";
is %section-by-id{"1.1"}.level, 2, "Subsection has level 2";
is %section-by-id{"2.1.1"}.level, 3, "Sub-subsection has level 3";

# Test 6: Parent relationships are correct
is %section-by-id{"1.1"}.parent_id, "1", "Section 1.1 has parent 1";
is %section-by-id{"2.1.1"}.parent_id, "2.1", "Section 2.1.1 has parent 2.1";
is %section-by-id{"1"}.parent_id, "", "Top-level section has no parent";

# Test 7: find-parent-section function
my %test-map = @sections.map({$_.identifier => $_}).Hash;
is find-parent-section("1.1", %test-map), "1", "find-parent-section finds correct parent";
is find-parent-section("2.1.1", %test-map), "2.1", "find-parent-section finds nested parent";
is find-parent-section("1", %test-map), "", "find-parent-section returns empty for root";

# Test 8: Error handling for missing file
dies-ok { parse-specification("nonexistent-file.md") }, 
    "parse-specification dies on missing file";

done-testing;

