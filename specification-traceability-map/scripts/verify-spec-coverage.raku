#!/usr/bin/env raku

# Coverage Verification Script for Specification Traceability Map
# Verifies that all sections of Specification.md are covered by feature tickets

use v6;
use JSON::Fast;

# Data model classes

class SpecificationSection {
    has Str $.identifier is required;
    has Str $.title is required;
    has Int $.level is required;
    has Str $.parent_id;
    has Str $.content;
    
    method gist() {
        "Section {$!identifier} (level {$!level}): {$!title}"
    }
}

class FeatureTicket {
    has Str $.feature_number is required;
    has Str $.slug is required;
    has Str $.friendly_name is required;
    has @.spec_sections = [];
    has @.dependencies = [];
    has Str $.directory_path is required;
    
    method gist() {
        "Feature {$!feature_number} ({$!slug}): {$!friendly_name}"
    }
}

# Parsing functions

# T005: Parse Specification.md and extract sections
sub parse-specification(Str $spec-file) {
    my SpecificationSection @sections;
    
    unless $spec-file.IO.e {
        die "ERROR: Specification file not found: $spec-file";
    }
    
    my $content = $spec-file.IO.slurp;
    my @lines = $content.lines;
    
    # Regex pattern for markdown headings with numeric section identifiers
    # Matches: # 1. Title, ## 1.1 Title, ### 2.1.1 Title, etc.
    my regex section-heading {
        ^ '#'+ \s+ 
        $<identifier> = [\d+ ['.' \d+]*]
        ['.' | ':']? \s*
        $<title> = .*
    }
    
    my SpecificationSection %section-map;
    
    for @lines.kv -> $line-num, $line {
        if $line ~~ /<section-heading>/ {
            my $identifier = ~$<section-heading><identifier>;
            my $title = ~$<section-heading><title>.trim;
            my $level = $line.match(/^ '#'+ /).Str.chars;
            
            # Skip headings at level 5 or deeper (these are typically list items, not sections)
            if $level > 4 {
                next;
            }
            
            # Find parent section
            my $parent-id = find-parent-section($identifier, %section-map);
            
            my $section = SpecificationSection.new(
                identifier => $identifier,
                title => $title,
                level => $level,
                parent_id => $parent-id
            );
            
            @sections.push($section);
            %section-map{$identifier} = $section;
        }
    }
    
    return @sections;
}

# T006: Find parent section for subsection inheritance
sub find-parent-section(Str $identifier, %section-map) {
    # Extract numeric parts (e.g., "3.2.1.1" -> [3, 2, 1, 1])
    my @parts = $identifier.split('.').map(*.Int);
    
    # Try progressively shorter prefixes to find parent
    for (@parts.elems - 1) ... 1 -> $len {
        my $parent-id = @parts[0..^$len].join('.');
        if %section-map{$parent-id}:exists {
            return $parent-id;
        }
    }
    
    return '';  # No parent found (root section)
}

# Get all ancestors of a section (for coverage inheritance)
sub get-ancestors(Str $section-id, %section-map) {
    my Str @ancestors;
    my $current-id = $section-id;
    
    while $current-id && %section-map{$current-id}:exists {
        my $section = %section-map{$current-id};
        if $section.parent_id {
            @ancestors.push($section.parent_id);
            $current-id = $section.parent_id;
        } else {
            last;
        }
    }
    
    return @ancestors;
}

# T007: Scan kitty-specs/ directories for features
sub scan-feature-directories(Str $specs-dir) {
    my Str @feature-dirs;
    
    unless $specs-dir.IO.d {
        note "WARN: Specs directory not found: $specs-dir";
        return @feature-dirs;
    }
    
    # Pattern: three digits followed by hyphen and slug (e.g., "001-feature-name")
    my regex feature-dir-name {
        ^ \d ** 3 '-' \w+ [ '-' \w+ ]* $
    }
    
    for $specs-dir.IO.dir -> $entry {
        if $entry.d && $entry.basename ~~ /<feature-dir-name>/ {
            @feature-dirs.push($entry.absolute);
        }
    }
    
    return @feature-dirs;
}

# T008 & T009: Parse meta.json files with error handling
sub parse-feature-metadata(Str $feature-dir) {
    my $meta-file = $feature-dir.IO.child('meta.json');
    
    # T009: Handle missing meta.json
    unless $meta-file.e {
        note "WARN: Missing meta.json in feature directory: $feature-dir";
        return Nil;
    }
    
    # T009: Handle malformed JSON
    my %meta;
    try {
        my $json-content = $meta-file.slurp;
        %meta = from-json($json-content);
        CATCH {
            note "ERROR: Invalid JSON in meta.json for feature: $feature-dir";
            note "  Error: {.message}";
            return Nil;
        }
    }
    
    # Extract required fields
    unless (%meta<feature_number>:exists) && (%meta<slug>:exists) && (%meta<friendly_name>:exists) {
        note "ERROR: Missing required fields in meta.json for feature: $feature-dir";
        return Nil;
    }
    
    # Extract optional fields with defaults
    my @spec-sections;
    if (%meta<spec_sections>:exists) {
        if %meta<spec_sections> ~~ Array {
            @spec-sections = %meta<spec_sections>.map(*.Str).Array;
        } else {
            note "WARN: spec_sections must be an array in meta.json for feature: $feature-dir";
        }
    }
    
    my @dependencies;
    if (%meta<dependencies>:exists) {
        if %meta<dependencies> ~~ Array {
            @dependencies = %meta<dependencies>.map(*.Str).Array;
        } else {
            note "WARN: dependencies must be an array in meta.json for feature: $feature-dir";
        }
    }
    
    # Extract feature slug from directory name if not in meta.json
    my $slug = %meta<slug> // $feature-dir.IO.basename;
    
    return FeatureTicket.new(
        feature_number => %meta<feature_number>.Str,
        slug => $slug,
        friendly_name => %meta<friendly_name>.Str,
        spec_sections => @spec-sections,
        dependencies => @dependencies,
        directory_path => $feature-dir
    );
}

# Load all feature tickets from kitty-specs/
sub load-all-features(Str $specs-dir) {
    my FeatureTicket @features;
    my @feature-dirs = scan-feature-directories($specs-dir);
    
    for @feature-dirs -> $feature-dir {
        my $ticket = parse-feature-metadata($feature-dir);
        if $ticket {
            @features.push($ticket);
        }
    }
    
    return @features;
}

# MAIN sub for CLI argument parsing
multi sub MAIN(
    Bool :$json = False,           # --json flag
    Bool :$verbose = False,        # --verbose flag
    Bool :$generate-map = False,   # --generate-map flag
    Str :$spec-file = "Specification.md",  # --spec-file=path
    Str :$specs-dir = "kitty-specs",       # --specs-dir=path
    Str :$output-dir = "specification-traceability-map/docs",             # --output-dir=path
    Bool :$help = False            # --help flag
) {
    if $help {
        show-help();
        exit 0;
    }

    # Validate file paths
    unless $spec-file.IO.e {
        note "ERROR: Specification file not found: $spec-file";
        exit 2;
    }
    
    unless $specs-dir.IO.d {
        note "ERROR: Specs directory not found: $specs-dir";
        exit 2;
    }
    
    # WP02: Parse specification and load features
    if $verbose {
        note "INFO: Parsing specification file: $spec-file";
    }
    
    my SpecificationSection @sections;
    try {
        @sections = parse-specification($spec-file);
        CATCH {
            note "ERROR: Failed to parse specification: {.message}";
            exit 1;
        }
    }
    
    if $verbose {
        note "INFO: Found {@sections.elems} sections in specification";
    }
    
    if $verbose {
        note "INFO: Loading feature metadata from: $specs-dir";
    }
    
    my FeatureTicket @features;
    try {
        @features = load-all-features($specs-dir);
        CATCH {
            note "ERROR: Failed to load features: {.message}";
            exit 1;
        }
    }
    
    if $verbose {
        note "INFO: Loaded {@features.elems} features";
    }
    
    # Build section map for inheritance lookups
    my %section-map;
    for @sections -> $section {
        %section-map{$section.identifier} = $section;
    }
    
    # TODO: Implement coverage calculation and map generation in WP03-WP05
    if $generate-map {
        note "INFO: Generate map mode (WP03 - not yet implemented)";
        # TODO: Implement in WP03
    } else {
        note "INFO: Coverage verification (WP05 - not yet implemented)";
        # TODO: Implement in WP05
    }
    
    # For now, just report what we parsed (for testing WP02)
    if $verbose {
        note "\nParsed Sections:";
        for @sections -> $section {
            my $parent-info = $section.parent_id ?? " (parent: {$section.parent_id})" !! " (root)";
            note "  {$section.identifier}: {$section.title}{$parent-info}";
        }
        
        note "\nLoaded Features:";
        for @features -> $feature {
            my $sections-info = $feature.spec_sections.elems > 0 
                ?? " covers: {$feature.spec_sections.join(', ')}" 
                !! " (no spec_sections)";
            note "  {$feature.slug}: {$feature.friendly_name}{$sections-info}";
        }
    }
    
    exit 0;
}

# Help text
sub show-help() {
    say q:to/HELP/;
    Coverage Verification Script

    Usage:
        raku specification-traceability-map/scripts/verify-spec-coverage.raku [OPTIONS]

    Options:
        --json              Output results as JSON instead of human-readable text
        --verbose           Include detailed logging output
        --generate-map      Generate/update traceability map document
        --spec-file=path    Path to Specification.md (default: Specification.md)
        --specs-dir=path    Path to kitty-specs directory (default: kitty-specs)
        --output-dir=path   Directory for generated traceability map (default: specification-traceability-map/docs)
        --help              Show this help message

    Exit Codes:
        0   Success (coverage check passed or map generated successfully)
        1   Error (uncovered sections found, broken links, or script error)
        2   Invalid arguments or missing files

    Examples:
        # Check coverage
        raku specification-traceability-map/scripts/verify-spec-coverage.raku

        # Generate traceability map
        raku specification-traceability-map/scripts/verify-spec-coverage.raku --generate-map

        # JSON output for CI/CD
        raku specification-traceability-map/scripts/verify-spec-coverage.raku --json
    HELP
}

