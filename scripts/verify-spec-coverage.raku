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

# WP03: Traceability Map Generation Functions

# T010: Build section-to-feature mapping data structure
sub build-section-to-feature-mapping(
    SpecificationSection @sections,
    FeatureTicket @features,
    %section-map
) {
    # Map: section_id -> [feature_slug1, feature_slug2, ...]
    my Array[Str] %section-to-features;
    
    # Initialize all sections with empty arrays
    for @sections -> $section {
        %section-to-features{$section.identifier} = Array[Str].new;
    }
    
    # First pass: Direct coverage from spec_sections arrays
    for @features -> $feature {
        for $feature.spec_sections -> $section-id {
            if %section-to-features{$section-id}:exists {
                %section-to-features{$section-id}.push($feature.slug);
            }
        }
    }
    
    # Second pass: Apply subsection inheritance
    # If a section is covered, all its subsections inherit the coverage
    for @sections -> $section {
        if $section.parent_id {
            # Check if parent is covered
            my $parent-id = $section.parent_id;
            if %section-to-features{$parent-id}.elems > 0 {
                # Inherit all features from parent
                for %section-to-features{$parent-id} -> $feature-slug {
                    unless %section-to-features{$section.identifier}.grep(* eq $feature-slug) {
                        %section-to-features{$section.identifier}.push($feature-slug);
                    }
                }
            }
        }
    }
    
    return %section-to-features;
}

# T014 & T011: Generate markdown document header with timestamp
sub generate-markdown-header(DateTime $timestamp) {
    my $iso-timestamp = $timestamp.Str;
    return qq:to/HEADER/;
# Specification Traceability Map

**Generated**: {$iso-timestamp}

This document maps all sections of `Specification.md` to feature tickets, providing a comprehensive view of specification coverage. Each section is linked to the feature(s) that implement it, or marked as "not yet assigned" if no feature covers it.

---

HEADER
}

# T012: Generate section mappings with feature links
sub generate-section-mappings(
    SpecificationSection @sections,
    Array[Str] %section-to-features,
    Str $specs-dir
) {
    my Str @lines;
    
    @lines.push("## Section Mappings\n");
    
    # Group sections by top-level section (e.g., "1", "2", "3")
    my Array[SpecificationSection] %sections-by-top-level;
    for @sections -> $section {
        my $top-level = $section.identifier.split('.')[0];
        unless %sections-by-top-level{$top-level}:exists {
            %sections-by-top-level{$top-level} = Array[SpecificationSection].new;
        }
        %sections-by-top-level{$top-level}.push($section);
    }
    
    # Generate mappings in order
    for %sections-by-top-level.keys.sort({$_.Int}) -> $top-level {
        my Array[SpecificationSection] $top-sections-array = %sections-by-top-level{$top-level};
        my SpecificationSection @top-sections = $top-sections-array.list;
        
        # Find the main section (level 1 or 2)
        my $main-section = @top-sections.first({$_.level <= 2});
        if $main-section {
            @lines.push("### Section {$main-section.identifier}: {$main-section.title}\n");
        } else {
            @lines.push("### Section {$top-level}\n");
        }
        
        # Generate mappings for all sections in this top-level group
        for @top-sections.sort({$_.identifier}) -> $section {
            my Array[Str] $slugs-array = %section-to-features{$section.identifier} // Array[Str].new;
            my Str @feature-slugs = $slugs-array.grep(*.chars > 0).Array;
            
            if @feature-slugs.elems > 0 {
                # Generate comma-separated links
                my Str @links;
                for @feature-slugs -> $slug {
                    # Relative path from docs/ to kitty-specs/
                    my $relative-path = "../{$specs-dir}/{$slug}/";
                    @links.push("[{$slug}]({$relative-path})");
                }
                @lines.push("- **Section {$section.identifier}** ({$section.title}): " ~ @links.join(", ") ~ "\n");
            } else {
                # T013: Mark uncovered sections
                @lines.push("- **Section {$section.identifier}** ({$section.title}): ⚠️ **not yet assigned**\n");
            }
        }
        
        @lines.push("\n");
    }
    
    return @lines.join("");
}

# T013: Generate summary of uncovered sections
sub generate-uncovered-summary(
    SpecificationSection @sections,
    Array[Str] %section-to-features
) {
    my SpecificationSection @uncovered;
    
    for @sections -> $section {
        if %section-to-features{$section.identifier}.elems == 0 {
            @uncovered.push($section);
        }
    }
    
    if @uncovered.elems == 0 {
        return "## Coverage Summary\n\n✅ **All sections are covered by at least one feature.**\n\n";
    }
    
    my Str @lines;
    @lines.push("## Coverage Summary\n\n");
    @lines.push("⚠️ **{@uncovered.elems} section(s) not yet assigned to any feature:**\n\n");
    
    for @uncovered.sort({$_.identifier}) -> $section {
        @lines.push("- Section {$section.identifier}: {$section.title}\n");
    }
    
    @lines.push("\n");
    return @lines.join("");
}

# T011: Generate complete traceability map document
sub generate-traceability-map(
    SpecificationSection @sections,
    FeatureTicket @features,
    Array[Str] %section-to-features,
    Str $specs-dir,
    Str $output-file
) {
    my DateTime $now = DateTime.now;
    
    # T014: Generate header with timestamp
    my $header = generate-markdown-header($now);
    
    # T013: Generate uncovered summary
    my $summary = generate-uncovered-summary(@sections, %section-to-features);
    
    # T012: Generate section mappings
    my $mappings = generate-section-mappings(@sections, %section-to-features, $specs-dir);
    
    # WP04: Generate dependency graph
    my Array[Str] %graph = build-dependency-graph(@features);
    my Array[Str] @validation-errors = validate-dependency-graph(%graph, @features);
    my Array[Str] @cycles = detect-circular-dependencies(%graph);
    my $dependency-graph = generate-dependency-graph-section(@features, %graph, @cycles, @validation-errors);
    
    # Combine all parts: header, summary, dependency graph, then mappings
    my $markdown = $header ~ $summary ~ $dependency-graph ~ $mappings;
    
    # Ensure output directory exists
    my $output-dir = $output-file.IO.dirname;
    unless $output-dir.IO.d {
        $output-dir.IO.mkdir;
    }
    
    # Write to file
    $output-file.IO.spurt($markdown);
    
    return $markdown;
}

# WP04: Dependency Graph Generation Functions

# T015: Build dependency graph from feature metadata
sub build-dependency-graph(FeatureTicket @features) {
    # Graph structure: from_feature -> [to_feature1, to_feature2, ...]
    # Feature A --> Feature B means "A blocks B"
    my Array[Str] %graph;
    
    # Build graph from dependencies arrays
    for @features -> $feature {
        # Initialize empty array for features with no dependencies
        unless %graph{$feature.slug}:exists {
            %graph{$feature.slug} = Array[Str].new;
        }
        
        # Add edges: if feature depends on X, then X blocks feature
        # So: X --> feature (X blocks feature)
        for $feature.dependencies -> $dep-slug {
            unless %graph{$dep-slug}:exists {
                %graph{$dep-slug} = Array[Str].new;
            }
            # Add edge: dep-slug blocks feature
            %graph{$dep-slug}.push($feature.slug);
        }
    }
    
    return %graph;
}

# T019: Validate graph structure (no self-deps, valid refs)
sub validate-dependency-graph(
    Array[Str] %graph,
    FeatureTicket @features
) {
    my Str @errors;
    my SetHash $feature-slugs = SetHash.new(@features.map(*.slug));
    
    # Check for self-dependencies and validate references
    for @features -> $feature {
        # Check self-dependencies
        if $feature.dependencies.grep(* eq $feature.slug).elems > 0 {
            @errors.push("ERROR: Feature {$feature.slug} depends on itself (self-dependency)");
        }
        
        # Validate all dependency targets exist
        for $feature.dependencies -> $dep-slug {
            unless $feature-slugs{$dep-slug}:exists {
                @errors.push("ERROR: Feature {$feature.slug} depends on non-existent feature: {$dep-slug}");
            }
        }
    }
    
    return @errors;
}

# T016: Detect circular dependencies using DFS
sub detect-circular-dependencies(Array[Str] %graph) {
    my Str @cycles;
    my SetHash $visited = SetHash.new;
    my SetHash $rec-stack = SetHash.new;
    
    sub dfs-visit(Str $node, Str @path) {
        if $rec-stack{$node}:exists {
            # Found a cycle! Extract the cycle from the path
            my Int $cycle-start = @path.first-index(* eq $node);
            if $cycle-start.defined {
                my @cycle = @path[$cycle-start..*];
                @cycle.push($node);  # Close the cycle
                @cycles.push(@cycle.join(" --> "));
            }
            return;
        }
        
        if $visited{$node}:exists {
            return;  # Already processed this node
        }
        
        $visited{$node} = True;
        $rec-stack{$node} = True;
        @path.push($node);
        
        # Visit all neighbors
        if %graph{$node}:exists {
            for %graph{$node}.list -> $neighbor {
                dfs-visit($neighbor, @path);
            }
        }
        
        $rec-stack{$node}:delete;
        @path.pop;
    }
    
    # Run DFS from each unvisited node
    for %graph.keys -> $node {
        unless $visited{$node}:exists {
            my Str @path;
            dfs-visit($node, @path);
        }
    }
    
    return @cycles;
}

# T017: Generate Mermaid flowchart syntax from dependency graph
sub generate-mermaid-diagram(Array[Str] %graph, FeatureTicket @features) {
    my Str @lines;
    @lines.push("```mermaid");
    @lines.push("graph TD");
    
    # Create a mapping of slug to friendly name for node labels
    my Str %slug-to-name = @features.map({$_.slug => $_.friendly_name}).Hash;
    
    # Generate edges: from --> to (from blocks to)
    for %graph.kv -> $from, $to-list {
        my $from-label = %slug-to-name{$from} // $from;
        for $to-list.list -> $to {
            my $to-label = %slug-to-name{$to} // $to;
            # Use feature slug as node ID, friendly name as label
            # Escape brackets in labels for Mermaid
            my $from-id = $from.subst(/<[\[\]]>/, {$_ eq '[' ?? '\\[' !! '\\]'}, :g);
            my $to-id = $to.subst(/<[\[\]]>/, {$_ eq '[' ?? '\\[' !! '\\]'}, :g);
            my $from-label-escaped = $from-label.subst(/<[\[\]]>/, {$_ eq '[' ?? '\\[' !! '\\]'}, :g);
            my $to-label-escaped = $to-label.subst(/<[\[\]]>/, {$_ eq '[' ?? '\\[' !! '\\]'}, :g);
            
            @lines.push("    {$from-id}[\"{$from-label-escaped}\"] --> {$to-id}[\"{$to-label-escaped}\"]");
        }
    }
    
    @lines.push("```");
    
    return @lines.join("\n");
}

# T018: Generate dependency graph section for traceability map
sub generate-dependency-graph-section(
    FeatureTicket @features,
    Array[Str] %graph,
    Array[Str] @cycles,
    Array[Str] @validation-errors
) {
    my Str @lines;
    @lines.push("## Dependency Graph\n");
    
    if @validation-errors.elems > 0 {
        @lines.push("⚠️ **Graph validation errors:**\n\n");
        for @validation-errors -> $error {
            @lines.push("- {$error}\n");
        }
        @lines.push("\n");
    }
    
    if @cycles.elems > 0 {
        @lines.push("❌ **Circular dependencies detected:**\n\n");
        for @cycles -> $cycle {
            @lines.push("- {$cycle}\n");
        }
        @lines.push("\n");
        @lines.push("⚠️ **Warning:** Circular dependencies prevent correct implementation ordering.\n\n");
    }
    
    # Generate Mermaid diagram
    if %graph.keys.elems > 0 {
        my $mermaid = generate-mermaid-diagram(%graph, @features);
        @lines.push("{$mermaid}\n\n");
        @lines.push("**Note:** Arrows indicate blocking relationships. Feature A --> Feature B means \"A blocks B\" (B depends on A).\n\n");
    } else {
        @lines.push("No dependencies defined between features.\n\n");
    }
    
    return @lines.join("");
}

# MAIN sub for CLI argument parsing
multi sub MAIN(
    Bool :$json = False,           # --json flag
    Bool :$verbose = False,        # --verbose flag
    Bool :$generate-map = False,   # --generate-map flag
    Str :$spec-file = "Specification.md",  # --spec-file=path
    Str :$specs-dir = "kitty-specs",       # --specs-dir=path
    Str :$output-dir = "docs",             # --output-dir=path
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
    
    # WP03: Generate traceability map if requested
    if $generate-map {
        if $verbose {
            note "INFO: Generating traceability map...";
        }
        
        # T010: Build section-to-feature mapping
        my Array[Str] %section-to-features = build-section-to-feature-mapping(
            @sections,
            @features,
            %section-map
        );
        
        if $verbose {
            note "INFO: Built mapping for {@sections.elems} sections";
            my $covered-count = %section-to-features.keys.grep({%section-to-features{$_}.elems > 0}).elems;
            note "INFO: {$covered-count} sections covered, {@sections.elems - $covered-count} uncovered";
        }
        
        # Generate output file path
        my $output-file = $output-dir.IO.child("spec-traceability-map.md").absolute;
        
        # T011-T014: Generate markdown document
        try {
            generate-traceability-map(
                @sections,
                @features,
                %section-to-features,
                $specs-dir,
                $output-file
            );
            
            say "SUCCESS: Traceability map generated at: $output-file";
            exit 0;
            CATCH {
                note "ERROR: Failed to generate traceability map: {.message}";
                exit 1;
            }
        }
    } else {
        # WP05: Coverage verification (not yet implemented)
        note "INFO: Coverage verification (WP05 - not yet implemented)";
        # TODO: Implement in WP05
    }
    
    # Verbose output for debugging
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
        raku scripts/verify-spec-coverage.raku [OPTIONS]

    Options:
        --json              Output results as JSON instead of human-readable text
        --verbose           Include detailed logging output
        --generate-map      Generate/update traceability map document
        --spec-file=path    Path to Specification.md (default: Specification.md)
        --specs-dir=path    Path to kitty-specs directory (default: kitty-specs)
        --output-dir=path   Directory for generated traceability map (default: docs)
        --help              Show this help message

    Exit Codes:
        0   Success (coverage check passed or map generated successfully)
        1   Error (uncovered sections found, broken links, or script error)
        2   Invalid arguments or missing files

    Examples:
        # Check coverage
        raku scripts/verify-spec-coverage.raku

        # Generate traceability map
        raku scripts/verify-spec-coverage.raku --generate-map

        # JSON output for CI/CD
        raku scripts/verify-spec-coverage.raku --json
    HELP
}

