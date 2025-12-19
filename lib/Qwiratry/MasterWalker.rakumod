#| Master Walker for composite walker handovers
#|
#| This module implements the Master Walker class that detects when handovers
#| are required between domain-specific walkers and delegates planning and
#| execution to appropriate walkers. The Master Walker coordinates composite
#| execution for multi-domain queries.
#|
#| The Master Walker:
#| - Discovers candidate walkers via introspection (default) or accepts explicit registration
#| - Detects handover requirements using domain metadata and capability checks
#| - Delegates planning to domain-specific walkers and embeds resulting plans as subplans
#| - Coordinates composite execution of multi-domain queries
unit module Qwiratry::MasterWalker;

use Qwiratry::Walker;
use Qwiratry::Provides;
use Qwiratry::X;
use Qwiratry::QueryIterator;

#| Composite Plan that implements Walker::Plan role with embedded subplans.
#|
#| Represents a composite execution plan containing subplans from multiple
#| domain-specific walkers. The composite plan maintains the original query AST
#| and embeds subplans as an array.
#|
#| Example:
#|   my $plan = CompositePlan.new(
#|       query-ast => $query,
#|       subplans => [$subplan1, $subplan2]
#|   );
class CompositePlan does Walker::Plan {
    #| Original query AST (composite query, not modified)
    has RakuAST::Node $.query-ast is required;
    
    #| Embedded subplans from delegated walkers
    has @.subplans;
    
    #| Execution order for subplans (optional, for future use)
    has @.execution-order;
    
    #| Constructor
    submethod BUILD(:$!query-ast, :@subplans, :@execution-order) {
        @!subplans = @subplans // Array.new;
        @!execution-order = @execution-order // Array.new;
    }
    
    #| Return array of embedded subplans
    method subplans(--> Array) {
        return @!subplans;
    }
    
    #| Return original query AST (not modified)
    method query(--> RakuAST::Node) {
        return $!query-ast;
    }
    
    #| Describe the composite plan
    method describe(--> Str) {
        my $subplan-count = @!subplans.elems;
        return "CompositePlan with $subplan-count subplan(s)";
    }
    
    #| Produce QueryIterator for this composite plan
    #| This will be fully implemented in WP06
    method iterator(--> QueryIterator) {
        # TODO: Implement composite iterator in WP06
        die "CompositePlan.iterator() not yet implemented (WP06)";
    }
}

#| Master Walker class that implements Walker role for composite handovers.
#|
#| Responsible for detecting when handovers are required and delegating
#| planning and execution to appropriate domain-specific Walkers.
#|
#| Constructor parameters:
#|   :@candidate-walkers - Optional array of Walker instances (overrides discovery)
#|
#| Example:
#|   my $master = MasterWalker.new;
#|   my $master-with-walkers = MasterWalker.new(:candidate-walkers[@sql-walker, @json-walker]);
class MasterWalker does Walker {
    #| Explicitly provided candidate walkers (overrides discovery if provided)
    has @.candidate-walkers;
    
    #| Cached discovered walkers (lazy initialization)
    has @!discovered-walkers;
    
    #| Flag indicating if discovery has been performed
    has Bool $!discovery-performed = False;
    
    #| Constructor accepts optional candidate walkers
    #| If provided, discovery is skipped and explicit list is used
    submethod BUILD(:@candidate-walkers) {
        if @candidate-walkers {
            @!candidate-walkers = @candidate-walkers;
        }
    }
    
    #| Get candidate walkers (explicit list or discovered)
    #| Returns explicit list if provided, otherwise discovers walkers
    method candidate-walkers(--> Array) {
        if @!candidate-walkers {
            return @!candidate-walkers;
        }
        return self.discover-walkers();
    }
    
    #| Discover candidate walkers via introspection.
    #| Scans loaded classes/types for those implementing Walker role.
    #| Cached per instance to avoid repeated introspection.
    method discover-walkers(--> Array) {
        # Return cached result if discovery already performed
        if $!discovery-performed {
            return @!discovered-walkers;
        }
        
        # Perform discovery
        my @found = Array[Walker].new;
        
        # Scan through all loaded classes/types using Metamodel
        # Check each class to see if it does Walker role
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
            # We check if a class does Walker by using .^does(Walker)
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
    
    #| Check provides trait on root object, return domain names or Nil.
    #| Uses provides-domains() from Qwiratry::Provides to extract domain metadata.
    method check-domain-metadata(Mu $root --> Array) {
        my @domains = provides-domains($root);
        return @domains if @domains;
        return Nil;
    }
    
    #| Query walker about capability via supports() method.
    #| Returns True if walker supports the subtree, False otherwise.
    method check-capability(RakuAST::Node $subtree, Walker $walker --> Bool) {
        # Check if walker has supports() method and call it
        if $walker.^can('supports') {
            return $walker.supports($subtree);
        }
        # Default: walker doesn't support if no supports() method
        return False;
    }
    
    #| Find walker supporting at least one of the declared domains.
    #| This is the fast path using domain metadata.
    #| For MVP, we use a heuristic: check if walker type name contains domain name.
    #| This can be enhanced later with explicit domain support methods.
    method find-walker-by-domain(Array $domains --> Walker) {
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
    
    #| Detect handover requirement using domain metadata (fast path) and capability checks (fallback).
    #| Follows priority order: domain metadata → capability checks.
    #| Returns Walker if handover is needed, Nil if not.
    method detect-handover(RakuAST::Node $subtree, Mu $root) {
        # Step 1: Check domain metadata (fast path)
        my @domains = self.check-domain-metadata($root);
        if @domains {
            my $walker = self.find-walker-by-domain(@domains);
            if $walker {
                return $walker;
            }
            # Early failure: domains declared but no suitable walker found
            X::Qwiratry::UnknownQueryElement.new(
                message => "No walker found for declared domains: {@domains.join(', ')}",
                walker-type => 'MasterWalker',
                query-ast => $subtree
            ).throw;
        }
        
        # Step 2: Capability checks (fallback)
        my @candidates = self.candidate-walkers();
        for @candidates -> $walker {
            if self.check-capability($subtree, $walker) {
                return $walker;
            }
        }
        
        # No walker found
        return Nil;
    }
    
    #| Extract AST subtree from query for delegation.
    #| For MVP, delegates entire query. Subtree extraction can be enhanced later.
    method extract-subtree(RakuAST::Node $query --> RakuAST::Node) {
        # For MVP, return entire query as subtree
        # This can be enhanced later to extract specific subtrees
        return $query;
    }
    
    #| Delegate planning to domain-specific walker.
    #| Calls walker's plan() method and handles exceptions.
    method delegate-planning(Walker $walker, RakuAST::Node $subtree, Mu $root --> Walker::Plan) {
        try {
            return $walker.plan($subtree, $root);
        } catch X::Qwiratry::UnknownQueryElement {
            # Re-throw with context
            .rethrow;
        } catch {
            # Wrap other exceptions
            X::Qwiratry::UnknownQueryElement.new(
                message => "Walker {$walker.^name} failed to plan: {.message}",
                walker-type => $walker.^name,
                query-ast => $subtree
            ).throw;
        }
    }
    
    #| Required: Create execution plan from query and root.
    #| Detects handovers, delegates planning, and embeds subplans in CompositePlan.
    method plan(RakuAST::Node $query, Mu $root --> Walker::Plan) {
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
    
    #| Required: Produce QueryIterator from plan.
    #| Coordinates composite execution for multi-domain queries.
    method iterator(Walker::Plan $plan --> QueryIterator) {
        # TODO: Implement iterator method
        # This will be implemented in WP05-WP06
        die "Not yet implemented"
    }
}

