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

use experimental :rakuast;
use Qwiratry::Walker;
use Qwiratry::Walker::Factory;
use Qwiratry::Walker::Providing;
use X::Qwiratry;
use Qwiratry::Walker::Capabilities;
use Qwiratry::QueryIterator;
use Qwiratry::Context;

# Forward declaration
class Qwiratry::Walker::Master::Iterator { ... }

=begin pod

Composite Plan that implements Qwiratry::Walker::Plan role with embedded subplans.

Represents a composite execution plan containing subplans from multiple
domain-specific walkers. The composite plan maintains the original query AST
and embeds subplans as an array.

Example:
  my $plan = Qwiratry::Walker::Master::Plan.new(
      query-ast => $query,
      subplans => [$subplan1, $subplan2]
  )

=end pod
class Qwiratry::Walker::Master::Plan does Qwiratry::Walker::Plan {
	# Original query AST (composite query, not modified)
	has Mu $.query-ast is required;
    
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
	method query(--> Mu) {
		return $!query-ast;
	}
    
	# Describe the composite plan
	method describe(--> Str) {
		my $subplan-count = @!subplans.elems;
		return "Qwiratry::Walker::Master::Plan with $subplan-count subplan(s)";
	}

	method capabilities(--> Associative) {
		my @subcaps = @!subplans.map(*.capabilities);
		Qwiratry::Walker::Capabilities.instance.merge(
			Qwiratry::Walker::Capabilities.instance.lazy(:enabled(True), :type('incremental')),
			|@subcaps,
		)
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
		return Qwiratry::Walker::Master::Iterator.new(
			context => $ctx,
			plan => self
		);
	}
}

=begin pod

Composite iterator that coordinates execution of multiple subplan iterators.

For composite execution, pulls incrementally from each subplan iterator in order.

Example:
  my $iter = Iterator.new(context => $ctx, plan => $composite-plan);
  my $result = $iter.pull-one();  # Returns first combined result

=end pod
class Qwiratry::Walker::Master::Iterator does QueryIterator {
	has Qwiratry::Walker::Master::Plan $.plan is required;
	has @!order;
	has @!subplan-iters;
	has Int $!order-index = 0;

	submethod BUILD(:$!context, :$!plan) {
		@!order = $!plan.execution-order;
		@!order = (0..^$!plan.subplans.elems).Array unless @!order.elems;
		@!subplan-iters = @!order.map({ $!plan.subplans[$_].iterator });
	}

	method pull-one(--> Mu) {
		while $!order-index < @!subplan-iters.elems {
			my $iter = @!subplan-iters[$!order-index];
			my $result = $iter.pull-one;
			return $result unless $result ~~ IterationEnd;
			$!order-index++;
		}
		IterationEnd
	}
}

=begin pod

Master Walker class that implements Qwiratry::Walker role for composite handovers.

Responsible for detecting when handovers are required and delegating
planning and execution to appropriate domain-specific Walkers.

Constructor parameters:
  :@candidate-walkers - Optional array of Walker instances (overrides discovery)

Example:
  my $master = Qwiratry::Walker::Master.new;
  my $master-with-walkers = Qwiratry::Walker::Master.new(:candidate-walkers[@sql-walker, @json-walker]);

=end pod
class Qwiratry::Walker::Master does Qwiratry::Walker {
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
	method discover-walkers(:@paths = ['lib'], Bool :$refresh = False --> Array) {
		if $!discovery-performed && !$refresh {
			return @!discovered-walkers;
		}

		my @types = Qwiratry::Walker::Factory.instance.discover-walkers(:@paths, :$refresh);
		my @instances = gather {
			for @types -> $type {
				next if $type === Qwiratry::Walker::Master;
				take $type.new;
			}
		};
		@!discovered-walkers = @instances;
		$!discovery-performed = True;
		return @!discovered-walkers;
	}
    
	# Check "providing" trait on root object, return domain names or Nil.
	# Uses providing-domains() from Qwiratry::Walker::Providing to extract domain metadata.
	method check-domain-metadata($root is raw --> Array) {
		Qwiratry::Walker::Providing.instance.cached-domains($root);
	}
    
	# Query walker about capability via supports() method.
	# Returns True if walker supports the subtree, False otherwise.
	method check-capability(Mu $subtree, Qwiratry::Walker $walker --> Bool) {
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
			my $domain-name = ~$domain;
			next unless $domain-name.chars;
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
					if $walker-name.contains($domain-name.lc) {
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
	method check-ast-pattern(Mu $subtree) {
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
	method check-heuristic(Mu $subtree) {
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
	method detect-handover(Mu $subtree, $root is raw) {
		my @candidates = self.candidate-walkers();
		my @tried-walkers = Array.new;
		my @failure-reasons = Array.new;
        
		# Step 1: Check domain metadata (fast path)
		my $domains = self.check-domain-metadata($root);
		if $domains.defined {
			my @domains = $domains;
			my $walker = self.find-walker-by-domain(@domains);
			if $walker {
				return $walker;
			}
			# Early failure: domains declared but no suitable walker found
			my $candidate-names = @candidates.map(*.^name).join(', ');
			X::Qwiratry::UnknownQueryElement.new(
				message => "No walker found for declared domains: {@domains.join(', ')}. Available walkers: $candidate-names",
				walker-type => 'Qwiratry::Walker::Master',
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
				walker-type => 'Qwiratry::Walker::Master',
			query-ast => $subtree
		).throw;
	}
    
	# Extract AST subtree from query for delegation.
	# For MVP, delegates entire query. Subtree extraction can be enhanced later.
	method extract-subtree(Mu $query --> Mu) {
		# For MVP, return entire query as subtree
		# This can be enhanced later to extract specific subtrees
		return $query;
	}
    
	=begin pod

	Delegate planning to domain-specific walker.
	Calls walker's plan() method and handles exceptions.
	Handles edge case T052: walker accepts via supports() but declines during planning.

	=end pod
	method delegate-planning(Qwiratry::Walker $walker, Mu $subtree, Mu $root --> Qwiratry::Walker::Plan) {
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
	Detects handovers, delegates planning, and embeds subplans in Qwiratry::Walker::Master::Plan.

	=end pod
	method plan(Mu $query, $root is raw --> Qwiratry::Walker::Plan) {
		# Detect if handover is needed
		my $walker = self.detect-handover($query, $root);
        
		if $walker {
			# Extract subtree for delegation (for MVP, entire query)
			my $subtree = self.extract-subtree($query);
            
			# Delegate planning to domain-specific walker
			my $subplan = self.delegate-planning($walker, $subtree, $root);
            
			# Create composite plan with original query AST and embedded subplan
			return Qwiratry::Walker::Master::Plan.new(
				query-ast => $query,
				subplans => [$subplan]
			);
		}
        
		# No handover needed or no suitable walker found
		# For MVP, throw exception if no walker found
		X::Qwiratry::UnknownQueryElement.new(
			message => "No suitable walker found for query",
				walker-type => 'Qwiratry::Walker::Master',
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

	method capabilities(--> Associative) {
		Qwiratry::Walker::Capabilities.instance.merge(
			Qwiratry::Walker::Capabilities.instance.lazy(:enabled(True), :type('incremental')),
			Qwiratry::Walker::Capabilities.instance.navigation(:enabled(True), 'composite'),
		)
	}
}

