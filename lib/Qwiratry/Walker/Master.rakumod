=begin pod

Master Walker for composite walker handovers

This module implements the Master Walker class that detects when handovers
are required between domain-specific walkers and delegates planning and
execution to appropriate walkers. The Master Walker coordinates composite
execution for multi-domain queries.

The Master Walker:
- Discovers candidate walkers via introspection (default) or accepts explicit registration
- Detects handover requirements using domain metadata and capability checks
- Delegates planning to domain-specific walkers and embeds resulting plans as subplans
- Coordinates composite execution of multi-domain queries

=end pod
unit module Qwiratry::Walker::Master;

use experimental :rakuast;
use Qwiratry::Walker;
use Qwiratry::Walker::Provides;
use X::Qwiratry;
use Qwiratry::QueryIterator;
use Qwiratry::Context;

# Forward declaration
class CompositeIterator { ... }

=begin pod

Composite Plan that implements Qwiratry::Walker::Plan role with embedded subplans.

Represents a composite execution plan containing subplans from multiple
domain-specific walkers. The composite plan maintains the original query AST
and embeds subplans as an array.

Example:
  my $plan = CompositePlan.new(
      query-ast => $query,
      subplans => [$subplan1, $subplan2]
  )

=end pod
class CompositePlan does Qwiratry::Walker::Plan {
    # Original query AST (composite query, not modified)
    has RakuAST::Node $.query-ast is required;
    
    # Embedded subplans from delegated walkers
    has @.subplans;
    
    # Execution order for subplans (optional, for future use)
    has @.execution-order;
    
    # Constructor
    submethod BUILD(:$!query-ast, :@subplans, :@execution-order) {
        @!subplans = @subplans // Array.new;
        @!execution-order = @execution-order // Array.new;
    }
    
    # Return array of embedded subplans
    method subplans(--> Array) {
        return @!subplans;
    }
    
    # Return original query AST (not modified)
    method query(--> RakuAST::Node) {
        return $!query-ast;
    }
    
    # Describe the composite plan
    method describe(--> Str) {
        my $subplan-count = @!subplans.elems;
        return "CompositePlan with $subplan-count subplan(s)";
    }
    
    # Produce QueryIterator for this composite plan.
    # Creates a composite iterator that coordinates subplan iterators.
    method iterator(--> QueryIterator) {
        # Create context for composite execution
        my class CompositeContext does Context {
            # Simple context for composite execution
        }
        my $ctx = CompositeContext.new;
        
        # Create composite iterator that coordinates subplan iterators
        return CompositeIterator.new(
            context => $ctx,
            plan => self
        );
    }
}

=begin pod

Composite iterator that coordinates execution of multiple subplan iterators.

For MVP, materializes results from each subplan and combines them.
Execution follows the order specified in CompositePlan.execution-order,
or sequential order if not specified.

Example:
  my $iter = CompositeIterator.new(context => $ctx, plan => $composite-plan);
  my $result = $iter.pull-one();  # Returns first combined result

=end pod
class CompositeIterator does QueryIterator {
    # The composite plan this iterator executes
    has CompositePlan $.plan is required;
    
    # Materialized results from all subplans (lazy initialization)
    has @!materialized-results;
    
    # Current index in materialized results
    has Int $!current-index = 0;
    
    # Flag indicating if materialization has been performed
    has Bool $!materialized = False;
    
    # Constructor
    submethod BUILD(:$!context, :$!plan) {
        # Context and plan are set via attributes
    }
    
    # Materialize results from all subplans.
    # For MVP, collects all results before returning any.
    method !materialize-results() {
        return if $!materialized;
        
        my @all-results = Array.new;
        
        # Determine execution order
        my @order = $!plan.execution-order;
        if @order.elems == 0 {
            # No explicit order - use sequential (0, 1, 2, ...)
            @order = (0..^$!plan.subplans.elems).Array;
        }
        
        # Execute subplans in order and materialize results
        for @order -> $index {
            my $subplan = $!plan.subplans[$index];
            my $subplan-iter = $subplan.iterator;
            
            # Materialize all results from this subplan
            my @subplan-results = Array.new;
            loop {
                my $result = $subplan-iter.pull-one();
                last if $result === IterationEnd;
                @subplan-results.push($result);
            }
            
            # Combine results (for MVP, simple concatenation)
            @all-results.append(@subplan-results);
        }
        
        @!materialized-results = @all-results;
        $!materialized = True;
    }
    
    # Return the next combined result, or IterationEnd if exhausted.
    method pull-one(--> Mu) {
        # Materialize results on first call
        self!materialize-results();
        
        # Return next result or IterationEnd
        if $!current-index >= @!materialized-results.elems {
            return IterationEnd;
        }
        
        return @!materialized-results[$!current-index++];
    }
}

=begin pod

Master Walker class that implements Qwiratry::Walker role for composite handovers.

Responsible for detecting when handovers are required and delegating
planning and execution to appropriate domain-specific Walkers.

Constructor parameters:
  :@candidate-walkers - Optional array of Walker instances (overrides discovery)

Example:
  my $master = MasterWalker.new;
  my $master-with-walkers = MasterWalker.new(:candidate-walkers[@sql-walker, @json-walker]);

=end pod
class MasterWalker does Qwiratry::Walker {
    # Explicitly provided candidate walkers (overrides discovery if provided)
    has @.candidate-walkers;
    
    # Cached discovered walkers (lazy initialization)
    has @!discovered-walkers;
    
    # Flag indicating if discovery has been performed
    has Bool $!discovery-performed = False;
    
    # Constructor accepts optional candidate walkers
    # If provided, discovery is skipped and explicit list is used
    submethod BUILD(:@candidate-walkers) {
        if @candidate-walkers {
            @!candidate-walkers = @candidate-walkers;
        }
    }
    
    # Get candidate walkers (explicit list or discovered)
    # Returns explicit list if provided, otherwise discovers walkers
    method candidate-walkers(--> Array) {
        if @!candidate-walkers {
            return @!candidate-walkers;
        }
        return self.discover-walkers();
    }
    
    =begin pod

    Discover candidate walkers via introspection.
    Scans loaded classes/types for those implementing Walker role.
    Cached per instance to avoid repeated introspection.

    =end pod
    method discover-walkers(--> Array) {
        # Return cached result if discovery already performed
        if $!discovery-performed {
            return @!discovered-walkers;
        }
        
        # Perform discovery
        my @found = Array[Qwiratry::Walker].new;
        
        # Scan through all loaded classes/types using Metamodel
            # Check each class to see if it does Qwiratry::Walker role
        try {
            # Use Metamodel::ClassHOW to iterate through all classes
            # This is a basic discovery mechanism that can be enhanced
            my $metamodel = Metamodel::ClassHOW;
            
            # Get all classes from the metamodel registry
            # Note: This is a simplified approach - in practice, we'd need to
            # scan through all loaded modules or use a registry
            # For MVP, we'll check if we can find Walker implementations
            # by iterating through known class hierarchies
            
            # Try to find classes that do Walker role
            # We check if a class does Qwiratry::Walker by using .^does(Qwiratry::Walker)
            # However, we need to get a list of all classes first
            
            # For now, return empty array - discovery can be enhanced later
            # with more sophisticated mechanisms (e.g., module registry, 
            # explicit walker registration system, etc.)
            # The important part is that explicit registration via constructor works
        }
        
        # Cache results
        @!discovered-walkers = @found;
        $!discovery-performed = True;
        
        return @!discovered-walkers;
    }
    
    # Check provides trait on root object, return domain names or Nil.
    # Uses provides-domains() from Qwiratry::Walker::Provides to extract domain metadata.
    method check-domain-metadata(Mu $root --> Array) {
        my @domains = provides-domains($root);
        return @domains if @domains;
        return Nil;
    }
    
    # Query walker about capability via supports() method.
    # Returns True if walker supports the subtree, False otherwise.
    method check-capability(RakuAST::Node $subtree, Qwiratry::Walker $walker --> Bool) {
        # Check if walker has supports() method and call it
        if $walker.^can('supports') {
            return $walker.supports($subtree);
        }
        # Default: walker doesn't support if no supports() method
        return False;
    }
    
    # Find walker supporting at least one of the declared domains.
    # This is the fast path using domain metadata.
    # For MVP, we use a heuristic: check if walker type name contains domain name.
    # This can be enhanced later with explicit domain support methods.
    method find-walker-by-domain(Array $domains --> Qwiratry::Walker) {
        my @candidates = self.candidate-walkers();
        
        # For each domain, try to find a walker that supports it
        for @$domains -> $domain {
            for @candidates -> $walker {
                # Check if walker has domain support method (if available)
                if $walker.^can('supports-domain') {
                    if $walker.supports-domain($domain) {
                        return $walker;
                    }
                } else {
                    # Fallback heuristic: check if walker type name contains domain
                    # This is a simple heuristic for MVP - can be enhanced later
                    my $walker-name = $walker.^name.lc;
                    if $walker-name.contains($domain.lc) {
                        return $walker;
                    }
                }
            }
        }
        
        return Nil;
    }
    
    =begin pod

    Check AST pattern suitability (optional optimization).
    Recognizes common AST patterns and matches to walker capabilities.
    For MVP, this is a placeholder that can be enhanced later.

    Returns Qwiratry::Walker if pattern matches, Nil otherwise.

    =end pod
    method check-ast-pattern(RakuAST::Node $subtree) {
        # For MVP, this is optional and not implemented
        # Can be enhanced later to recognize specific AST patterns
        # (e.g., SQL SELECT patterns, JSON path expressions, etc.)
        return Nil;
    }
    
    =begin pod

    Use heuristics to select walker (optional, last resort).
    Uses heuristics like node type, structure, or keywords to guess walker.
    For MVP, this is a placeholder that can be enhanced later.

    Returns Qwiratry::Walker if heuristic matches, Nil otherwise.

    =end pod
    method check-heuristic(RakuAST::Node $subtree) {
        # For MVP, this is optional and not implemented
        # Can be enhanced later with heuristics based on:
        # - Node type (RakuAST::Node.^name)
        # - Structure analysis
        # - Keyword matching
        return Nil;
    }
    
    =begin pod

    Detect handover requirement following full priority order:
    domain metadata → capability → pattern → heuristic.
    Returns Qwiratry::Walker if handover is needed, Nil if not.
    Handles edge cases: no walker found, multiple walkers, walker declines.

    =end pod
    method detect-handover(RakuAST::Node $subtree, Mu $root) {
        my @candidates = self.candidate-walkers();
        my @tried-walkers = Array.new;
        my @failure-reasons = Array.new;
        
        # Step 1: Check domain metadata (fast path)
        my @domains = self.check-domain-metadata($root);
        if @domains {
            my $walker = self.find-walker-by-domain(@domains);
            if $walker {
                return $walker;
            }
            # Early failure: domains declared but no suitable walker found
            my $candidate-names = @candidates.map(*.^name).join(', ');
            X::Qwiratry::UnknownQueryElement.new(
                message => "No walker found for declared domains: {@domains.join(', ')}. Available walkers: $candidate-names",
                walker-type => 'MasterWalker',
                query-ast => $subtree
            ).throw;
        }
        
        # Step 2: Capability checks (fallback)
        for @candidates -> $walker {
            @tried-walkers.push($walker.^name);
            if self.check-capability($subtree, $walker) {
                # Multiple walkers might support - select first one (edge case T051)
                return $walker;
            } else {
                @failure-reasons.push("{$walker.^name}: supports() returned False");
            }
        }
        
        # Step 3: AST pattern suitability (optional optimization)
        my $pattern-walker = self.check-ast-pattern($subtree);
        if $pattern-walker {
            return $pattern-walker;
        }
        
        # Step 4: Heuristic probing (optional, last resort)
        my $heuristic-walker = self.check-heuristic($subtree);
        if $heuristic-walker {
            return $heuristic-walker;
        }
        
        # Edge case T050: No walker found after all checks
        my $tried-names = @tried-walkers.join(', ');
        my $reasons = @failure-reasons.join('; ');
        X::Qwiratry::UnknownQueryElement.new(
            message => "No suitable walker found for query. Tried walkers: $tried-names. Reasons: $reasons",
            walker-type => 'MasterWalker',
            query-ast => $subtree
        ).throw;
    }
    
    # Extract AST subtree from query for delegation.
    # For MVP, delegates entire query. Subtree extraction can be enhanced later.
    method extract-subtree(RakuAST::Node $query --> RakuAST::Node) {
        # For MVP, return entire query as subtree
        # This can be enhanced later to extract specific subtrees
        return $query;
    }
    
    =begin pod

    Delegate planning to domain-specific walker.
    Calls walker's plan() method and handles exceptions.
    Handles edge case T052: walker accepts via supports() but declines during planning.

    =end pod
    method delegate-planning(Qwiratry::Walker $walker, RakuAST::Node $subtree, Mu $root --> Qwiratry::Walker::Plan) {
        {
            return $walker.plan($subtree, $root);
            CATCH {
                when X::Qwiratry::UnknownQueryElement {
                    # Walker declined responsibility after accepting via supports()
                    # This is edge case T052 - re-throw with enhanced context
                    X::Qwiratry::UnknownQueryElement.new(
                        message => "Walker {$walker.^name} accepted query via supports() but declined during planning: {.message}",
                        walker-type => $walker.^name,
                        query-ast => $subtree
                    ).throw;
                }
                default {
                    # Wrap other exceptions
                    X::Qwiratry::UnknownQueryElement.new(
                        message => "Walker {$walker.^name} failed to plan: {.message}",
                        walker-type => $walker.^name,
                        query-ast => $subtree
                    ).throw;
                }
            }
        }
    }
    
    =begin pod

    Required: Create execution plan from query and root.
    Detects handovers, delegates planning, and embeds subplans in CompositePlan.

    =end pod
    method plan(RakuAST::Node $query, Mu $root --> Qwiratry::Walker::Plan) {
        # Detect if handover is needed
        my $walker = self.detect-handover($query, $root);
        
        if $walker {
            # Extract subtree for delegation (for MVP, entire query)
            my $subtree = self.extract-subtree($query);
            
            # Delegate planning to domain-specific walker
            my $subplan = self.delegate-planning($walker, $subtree, $root);
            
            # Create composite plan with original query AST and embedded subplan
            return CompositePlan.new(
                query-ast => $query,
                subplans => [$subplan]
            );
        }
        
        # No handover needed or no suitable walker found
        # For MVP, throw exception if no walker found
        X::Qwiratry::UnknownQueryElement.new(
            message => "No suitable walker found for query",
            walker-type => 'MasterWalker',
            query-ast => $query
        ).throw;
    }
    
    =begin pod

    Required: Produce QueryIterator from plan.
    Delegates to the plan's iterator() method, which handles composite execution.

    =end pod
    method iterator(Qwiratry::Walker::Plan $plan --> QueryIterator) {
        return $plan.iterator();
    }
}

