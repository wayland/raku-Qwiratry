=begin pod

=head1 Overview

Master walker for composite walker handovers.

C<Qwiratry::Walker::Master> coordinates planning when a query may need a
domain-specific walker. It discovers or accepts candidate walkers, checks domain
metadata from C<is providing>, asks walkers whether they support the query
subtree, delegates planning to the selected walker, and wraps the delegated plan
in a composite plan.

Execution remains pull-driven. A master plan produces a master iterator that
pulls from delegated subplan iterators in execution order.

=head1 Responsibilities

=item Discover candidate walkers through introspection or accept explicit
 registration from the caller.

=item Detect handover requirements using domain metadata, walker capability
 checks, AST pattern hooks, and last-resort heuristics.

=item Delegate planning to the selected domain-specific walker and embed the
 resulting subplan in a composite plan.

=item Coordinate composite execution by pulling from delegated subplan iterators.

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

=head1 Plan

C<Qwiratry::Walker::Master::Plan> implements L<Qwiratry::Walker::Plan> and
stores the original query plus delegated subplans.

=head2 Example

=begin code
my $plan = Qwiratry::Walker::Master::Plan.new(
    query-ast => $query,
    subplans => [$subplan1, $subplan2],
)
=end code

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

=head1 Iterator

C<Qwiratry::Walker::Master::Iterator> coordinates execution of multiple subplan
iterators.

It pulls incrementally from the first subplan until it is exhausted, then moves
to the next planned subplan. That preserves lazy behavior while keeping the
current composition model simple.

=head2 Example

=begin code
my $iter = Qwiratry::Walker::Master::Iterator.new(
    context => $ctx,
    plan => $composite-plan,
);
my $result = $iter.pull-one;
=end code

=end pod
class Qwiratry::Walker::Master::Iterator does QueryIterator {
	has Qwiratry::Walker::Master::Plan $.plan is required;
	has @!order;
	has @!subplan-iters;
	has Int $!order-index = 0;

	submethod BUILD(:$!context, :$!plan) {
		@!order = $!plan.execution-order;
		@!order.elems or @!order = (0..^$!plan.subplans.elems).Array;
		@!subplan-iters = @!order.map({ $!plan.subplans[$_].iterator });
	}

	method pull-one(--> Mu) {
		while $!order-index < @!subplan-iters.elems {
			my $iter = @!subplan-iters[$!order-index];
			my $result = $iter.pull-one;
			$result ~~ IterationEnd or return $result;
			$!order-index++;
		}
		IterationEnd
	}
}

=begin pod

=head1 Class

C<Qwiratry::Walker::Master> implements L<Qwiratry::Walker> for composite
handovers.

Pass C<:@candidate-walkers> to make selection explicit. Without candidates, the
master asks L<Qwiratry::Walker::Factory> to discover available walker types and
instantiates them.

=head2 Constructor Parameters

=item C<:@candidate-walkers>: optional walker instances that override discovery.

=head2 Example

=begin code
my $master = Qwiratry::Walker::Master.new;
my $master-with-walkers = Qwiratry::Walker::Master.new(
    :candidate-walkers[@sql-walker, @json-walker],
);
=end code

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

	=head1 Methods

	=head2 C<discover-walkers(:@paths, Bool :$refresh)>

	=begin code
	method discover-walkers(:@paths = ['lib'], Bool :$refresh = False --> Array)
	=end code

	=head3 Parameters

	=item C<@paths>

	 Directories to search when discovering walker implementations.

	=item C<$refresh>

	 Whether discovery should ignore cached results and rescan.


	Discovers candidate walker instances through L<Qwiratry::Walker::Factory>.

	Results are cached per master instance unless C<:$refresh> is true. The
	master walker itself is filtered out so delegation cannot recurse into another
	master plan by accident.

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

	=head2 C<check-ast-pattern(Mu $subtree)>

	=begin code
	method check-ast-pattern(Mu $subtree)
	=end code

	=head3 Parameters

	=item C<$subtree>

	 The query subtree being checked for handover or delegated planning.


	Optional extension point for AST-pattern walker selection.

	The current implementation returns C<Nil>, leaving selection to domain
	metadata and capability checks. Keeping the method explicit documents where
	pattern-based delegation should be added.

	=end pod
	method check-ast-pattern(Mu $subtree) {
		# For MVP, this is optional and not implemented
		# Can be enhanced later to recognize specific AST patterns
		# (e.g., SQL SELECT patterns, JSON path expressions, etc.)
		return Nil;
	}
    
	=begin pod

	=head2 C<check-heuristic(Mu $subtree)>

	=begin code
	method check-heuristic(Mu $subtree)
	=end code

	=head3 Parameters

	=item C<$subtree>

	 The query subtree being checked for handover or delegated planning.


	Optional last-resort extension point for heuristic walker selection.

	The current implementation returns C<Nil>. Production selection should prefer
	explicit domain metadata or walker capability responses because they produce
	clearer diagnostics.

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

	=head2 C<detect-handover(Mu $subtree, $root)>

	=begin code
	method detect-handover(Mu $subtree, $root is raw)
	=end code

	=head3 Parameters

	=item C<$subtree>

	 The query subtree being checked for handover or delegated planning.

	=item C<$root>

	 The traversal root that provides the data context for the plan.


	Selects a walker for C<$subtree> using the handover priority order.

	Domain metadata is checked first. If none is available, candidate walkers are
	asked through C<supports>. Pattern and heuristic hooks are tried last. Failure
	to find a walker is reported as L<X::Qwiratry::UnknownQueryElement> with the
	walkers tried and their failure reasons.

	=head3 Priority Order

	=item Domain metadata declared by the root data.

	=item Candidate walker capability checks via C<supports>.

	=item AST pattern suitability through C<check-ast-pattern>.

	=item Last-resort heuristic probing through C<check-heuristic>.

	=head3 Edge Cases Handled

	=item Declared domains with no matching walker fail early with the declared
	 domains and available candidate walkers.

	=item Multiple capable walkers are resolved by selecting the first matching
	 candidate in discovery or registration order.

	=item No suitable walker after all checks raises
	 L<X::Qwiratry::UnknownQueryElement> with the walkers tried and their failure
	 reasons.

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

	=head2 C<delegate-planning(Qwiratry::Walker $walker, Mu $subtree, Mu $root)>

	=begin code
	method delegate-planning(Qwiratry::Walker $walker, Mu $subtree, Mu $root --> Qwiratry::Walker::Plan)
	=end code

	=head3 Parameters

	=item C<$walker>

	 The candidate walker selected for delegated planning.

	=item C<$subtree>

	 The query subtree being checked for handover or delegated planning.

	=item C<$root>

	 The traversal root that provides the data context for the delegated plan.


	Delegates planning to a selected domain-specific walker.

	If a walker accepted the query through C<supports> but then rejects it during
	C<plan>, the exception is wrapped with the selected walker name and subtree so
	the caller can see which handover failed.

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

	=head2 C<plan(Mu $query, $root)>

	=begin code
	method plan(Mu $query, $root is raw --> Qwiratry::Walker::Plan)
	=end code

	=head3 Parameters

	=item C<$query>

	 The query AST or operator node being planned or tested.

	=item C<$root>

	 The traversal root that provides the data context for the delegated plan.


	Creates a composite execution plan from C<$query> and C<$root>.

	The master detects the delegated walker, extracts the delegated subtree, asks
	that walker to plan, and embeds the subplan under the original query AST.

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

	=head2 C<iterator(Qwiratry::Walker::Plan $plan)>

	=begin code
	method iterator(Qwiratry::Walker::Plan $plan --> QueryIterator)
	=end code

	=head3 Parameters

	=item C<$plan>

	 The execution plan to turn into a fresh query iterator.


	Produces a query iterator from a master plan.

	The plan is responsible for constructing the composite iterator because it
	knows its subplans and execution order.

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

