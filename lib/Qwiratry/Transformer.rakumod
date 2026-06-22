=begin pod

=head1 Overview

Transformer declarator and runtime class for declarative data transformations.

A C<transformer> class is composed by C<MetamodelX::TransformerHOW>. During
composition, molds and wrappers collected by L<Qwiratry::Mold::Slang> are moved
onto the transformer type, named molds become callable methods, and class traits
such as C<is streaming>, C<returns>, and C<does TreeRewrite> are recorded for
runtime use.

At runtime, a transformer orders its molds, chooses a walker for the input data,
iterates the selected nodes, and applies the first matching mold to each node.
Wrappers and return-type checks are applied at the appropriate mold or whole
transformer boundary.

=end pod

use Qwiratry::Mold;
use Qwiratry::Mold::Slang;  # For get-collected-molds(), clear-collected-molds(), get-collected-wrappers(), clear-collected-wrappers()
use X::Qwiratry;  # For X::Qwiratry::MoldOrderingConflict
use Qwiratry::Walker::Factory;  # For Qwiratry::Walker selection
use Qwiratry::Operator::Navigation;
use Qwiratry::Query::Specificity;
use Qwiratry::QueryIterator;
use Qwiratry::Transformer::Copy;

my constant copy-service = Qwiratry::Transformer::Copy.instance;
use Qwiratry::Tree::Replace;
# Note: Mold slang activation requires `use Qwiratry::Mold::Slang` in the caller compunit.

=begin pod

Package-level registry for molds collected during transformer compilation.
Keyed by transformer type identity (WHICH) for runtime access.

=end pod
our %TRANSFORMER-MOLDS;

=begin pod

Package-level registry for trait metadata collected during transformer compilation.
Keyed by transformer type identity (WHICH) for runtime access.
Stores streaming, returns-type, and tree-rewrite flags.

=end pod
our %TRANSFORMER-TRAITS;

=begin pod

Custom HOW class for transformer declarator is defined after the Transformer class.

=end pod

=begin pod

Export transformer declarator via EXPORTHOW::DECLARE (defined after Transformer class).

=end pod

=begin pod

=head1 Class

C<Transformer> is the base class installed behind the C<transformer> declarator.

User-declared transformer classes inherit its mold ordering, traversal,
copy/deepcopy helpers, wrapper dispatch, return checking, and callable entry
point.

=end pod
class Transformer does Callable is export {
	=begin pod

	Molds attached to this transformer type.

	The custom HOW stores compiled molds in a class-level registry keyed by type
	identity. Instances copy that list during C<TWEAK> so traversal can order and
	apply molds without consulting compile-time slang state.

	=end pod
	has @.molds is rw;
    
	=begin pod

	Initialize molds from class-level registry when instance is created.

	=end pod
	submethod TWEAK() {
		# Get molds from class-level registry
		# Use the type object's WHICH for lookup
		my $type-identity = self.WHAT.WHICH;
		if %TRANSFORMER-MOLDS{$type-identity}:exists {
			@!molds = %TRANSFORMER-MOLDS{$type-identity}.List;
		}
        
		# T052, T053, T054: Get trait metadata from class-level registry
		# Set instance attributes based on traits detected during compose
		if %TRANSFORMER-TRAITS{$type-identity}:exists {
			my %traits = %TRANSFORMER-TRAITS{$type-identity};
			$!streaming = %traits<streaming> // False;
			$!returns-type = %traits<returns-type> // Nil;
			$!mutates-input = %traits<tree-rewrite> // False;
		}
	}
    
	=begin pod

	Cached mold execution order.

	C<ORDER-MOLDS> populates this array by sorting priority, specificity, and
	tie-breaker descending. The cache avoids recalculating ordering for every node
	during a transform pass.

	=end pod
	has @.ordered-molds is rw;
    
	# Cache flag to avoid recalculating ordering
	has Bool $!ordering-cached = False;
    
	# Wrapper declarations are installed as generated methods during composition.
	has @.wrappers;
    
	# T052: Whether transformer has :streaming trait
	has Bool $.streaming is rw = False;
    
	# T053: Output type constraint (from returns(Type) trait)
	has Mu $.returns-type is rw;
    
	# T054: Whether transformer can mutate input (from does TreeRewrite)
	has Bool $.mutates-input is rw = False;

	# Optional Strategy for Walker traversal hooks during TRANSFORM
	has $.strategy is rw;
    
	# Transformation mode (pre, inline, post, default, rewrite-optional, rewrite-mandatory)
	has Str $.mode = 'default';
    
	=begin pod

	=head1 Methods

	=head2 C<CALL-ME(*@args, *%named)>

	=begin code
	method CALL-ME(*@args, *%named)
	=end code

	=head3 Parameters

	=item C<@args>

	 Positional input supplied when the transformer is called; the first non-pair value becomes the transform input.

	=item C<%named>

	 Named input and options supplied when the transformer is called; C<context>, C<streaming>, and C<mode> are routed as transform options.


	Makes transformer types and instances callable.

	Positional input becomes the transform data. Named C<context>, C<streaming>,
	and C<mode> options are routed to C<transform>; remaining named arguments are
	treated as data when no positional input is supplied.

	=end pod
	method CALL-ME(*@args, *%named) {
		# T031: Call transform() method when transformer is called
		# MyTransform($data) syntax
		my %options;
		for <context streaming mode> -> $option {
			if %named{$option}:exists {
				%options{$option} = %named{$option}:delete;
			}
		}
		my $data = @args
			?? @args.all ~~ Pair
				?? %(|@args, |%named)
				!! @args[0]
			!! %named
				?? %named
				!! $*CONTEXT;
		my $transformer = self.DEFINITE ?? self !! self.new;
		return $transformer.transform($data, |%options);
	}
    
	=begin pod

	=head2 C<APPLY($node)>

	=begin code
	method APPLY($node --> Mu)
	=end code

	=head3 Parameters

	=item C<$node>

	 The current node or element being matched, transformed, copied, or replaced.


	Applies ordered molds to a single node.

	The first mold whose matcher succeeds is executed. C<NextMold.throw> skips
	that action and resumes with the next matching mold. Mold matcher/action
	wrappers and transformer return-type checks are applied around the selected
	mold result.

	=end pod
	method APPLY($node --> Mu) {
		my $*TRANSFORM-NODE := $node;
		my $*TRANSFORM-REWRITE := $.mutates-input;

		# T027: Apply molds to a single node
		# Get ordered molds (call ORDER-MOLDS if not already ordered)
		my @ordered = self.ORDER-MOLDS;
        
		# Iterate through ordered molds
		for @ordered -> $mold {
			# T049: Check if mold matches this node (with WRAP_MOLD_MATCHER wrapper)
			my $match-result;
			my $wrap-method = self.^find_method('WRAP_MOLD_MATCHER', :no_fallback);
			if $wrap-method.defined {
				# Call wrapper submethod - it will traverse hierarchy and execute all wrappers
				# Wrapper receives node and match result, can modify match result
				my $raw-match = $mold.matches($node);
				$match-result = self.WRAP_MOLD_MATCHER($node, $raw-match);
			} else {
				# No wrapper - just check match directly
				$match-result = $mold.matches($node);
			}
            
			# Check if mold matches this node
			if $match-result {
				my $result;
				try {
					$result = $mold.execute($node, :transformer(self));
					CATCH {
						when X::Qwiratry::NextMold { next }
						default { .throw }
					}
				}
				if self.^find_method('WRAP_MOLD_ACTION', :no_fallback) {
					$result = self.WRAP_MOLD_ACTION($node, $result);
				}
				if $!returns-type.WHICH ne Mu.WHICH && $result.defined {
					unless $result ~~ $.returns-type {
						X::Qwiratry::TypeCheck.new(
							expected => $.returns-type,
							got => $result.WHAT,
							message => "Transformer '{self.^name}' has returns({$.returns-type.^name}) trait but result is of type {$result.WHAT.^name}. Ensure molds return values conforming to the specified type."
						).throw;
					}
				}
				return $result;
			}
		}
        
		# No molds matched - return Nil (empty sequence)
		# Explicitly return Nil to avoid returning Any (type object)
		return Nil;
	}
    
	=begin pod

	=head2 C<!collect-molds-from-body($body-ast)>

	=begin code
	method !collect-molds-from-body($body-ast --> Array[Mold])
	=end code

	=head3 Parameters

	=item C<$body-ast>

	 The transformer body AST to scan for collected molds.


	Compatibility hook for older body-AST collection experiments.

	Current mold collection happens through L<Qwiratry::Mold::Registry> during HOW
	composition, so this helper returns an empty typed array.

	=end pod
	method !collect-molds-from-body($body-ast --> Array[Mold]) {
		# Molds are now collected automatically by the HOW class during compose()
		# via the slang system. This method is kept for compatibility.
		Array[Mold].new
	}
    
	=begin pod

	=head2 C<add-mold(Mold $mold)>

	=begin code
	method add-mold(Mold $mold)
	=end code

	=head3 Parameters

	=item C<$mold>

	 The C<Mold> instance being registered, ordered, inspected, or copied.


	Adds a mold to this transformer instance.

	This is primarily a testing and manual-registration helper. Declarative
	transformers normally receive molds from the HOW at class composition time.

	=end pod
	method add-mold(Mold $mold) {
		@!molds.push($mold);
        
		# If mold has a name, create a callable method on this transformer
		# Method creation is handled by HOW class during compilation via !create-mold-method()
	}
    
	=begin pod

	=head2 C<!process-molds($body-ast)>

	=begin code
	method !process-molds($body-ast)
	=end code

	=head3 Parameters

	=item C<$body-ast>

	 The transformer body AST to scan for collected molds.


	Compatibility helper that stores molds returned by C<!collect-molds-from-body>.

	The active slang/HOW path bypasses this method, but keeping it documented
	makes the older AST collection boundary explicit.

	=end pod
	method !process-molds($body-ast) {
		my @collected = self!collect-molds-from-body($body-ast);
		@!molds = @collected;
        
		# Create callable methods for named molds
		# Method creation is handled by HOW class during compilation via !create-mold-method()
	}
    
	=begin pod

	=head2 C<ORDER-MOLDS()>

	=begin code
	method ORDER-MOLDS(--> Array)
	=end code

	Returns molds in execution order and caches the result.

	The ordering algorithm is:

	=begin item :numbered
	Sort by priority, highest first.
	=end item

	=begin item :numbered
	For equal priority, sort by query specificity, highest first.
	=end item

	=begin item :numbered
	For equal priority and specificity, sort by tie-breaker, highest first.
	=end item

	=begin item :numbered
	Detect and report conflicts when molds have equal priority, specificity, and
	tie-breaker values.
	=end item

	Specificity comes from the extracted C<when-query> when available; plain
	predicate molds receive a small default score. Equal ordering values are
	reported as L<X::Qwiratry::MoldOrderingConflict> because the transformer
	cannot choose a deterministic winner.

	=end pod
	method ORDER-MOLDS(--> Array) {
		# Performance: O(n log n) sorting with caching to avoid recalculation
		# Returns cached result if available (O(1) after first call)
		if $!ordering-cached && @!ordered-molds.elems > 0 {
			return @!ordered-molds;
		}
        
		# T014: Priority is already stored in mold's $.priority attribute
		# (extracted during mold creation in MoldSlang)
		# No additional extraction needed - molds already have priority set
        
		# T015/T016: Calculate specificity for each mold
		# For now, we'll use a simple approach: calculate basic specificity
		# Complex queries will be deferred to runtime evaluation
		# Note: Specificity is read-only, so we calculate it but can't store it
		# For molds without specificity, we'll use the calculated value in sorting
		# Performance: O(n) specificity calculation
		my %specificity-cache;
		for @!molds -> $mold {
			if !$mold.specificity.defined {
				%specificity-cache{$mold.WHICH} = self!calculate-specificity($mold);
			}
		}
        
		# T014/T016/T017: Sort molds by priority → specificity → tie-breaker
		# Priority and tie-breaker are already stored in mold attributes
		# Performance: O(n log n) - Raku's sort uses efficient algorithm
		my @sorted = @!molds.sort({
			# Primary sort: priority (descending - highest first)
			-$^a.priority <=> -$^b.priority
			||
			# Secondary sort: specificity (descending - highest first)
			# Use cached value if mold doesn't have specificity set
			-($^a.specificity // %specificity-cache{$^a.WHICH} // 0) <=> -($^b.specificity // %specificity-cache{$^b.WHICH} // 0)
			||
			# Tertiary sort: tie-breaker (descending - highest first)
			-$^a.tie-breaker <=> -$^b.tie-breaker
		});
        
		# T018: Detect conflicts (pass specificity cache for conflict checking)
		self!detect-conflicts(@sorted, %specificity-cache);
        
		# T019: Store ordered molds and mark as cached
		@!ordered-molds = @sorted;
		$!ordering-cached = True;
        
		return @!ordered-molds;
	}
    
	=begin pod

	=head2 C<TRANSFORM($data, :$iterator)>

	=begin code
	method TRANSFORM($data, Iterator :$iterator --> Mu)
	=end code

	=head3 Parameters

	=item C<$data>

	 The input data, root value, or rendered value handled by this operation.

	=item C<$iterator>

	 The iterator that supplies traversal elements.


	Transforms a root data structure by walking its nodes and applying molds.

	The method selects a walker through L<Qwiratry::Walker::Factory> unless the
	caller supplies an iterator, installs C<$*TRANSFORM-ROOT>, applies molds to
	each traversed node, optionally performs tree replacement, and finally applies
	whole-transformer wrappers. Streaming transformers return an iterator over
	results; non-streaming transformers return a list.

	=end pod
	method TRANSFORM($data, Iterator :$iterator --> Mu) {
		# T029: Main transformation orchestration
		# Call ORDER-MOLDS to prepare molds (cache result)
		my @ordered = self.ORDER-MOLDS;
        
		# T028: Obtain Qwiratry::Walker via factory
		my $walker = Qwiratry::Walker::Factory.instance.get-walker($data);
		if $.strategy.defined && $walker.defined {
			my $walker-type = $walker.WHAT;
			$walker = $walker-type.new(:strategy($.strategy));
		}
        
		# T030: Create iterator - use provided iterator or default
		my $iter = $iterator;
		if !$iter.defined {
			$iter = self!create-default-iterator($data, $walker);
		}
        
		# T029: Iterate over data nodes and apply molds
		my @results;
		my $*TRANSFORM-ROOT := $data;
		self!each-traversal-node($iter, $walker, -> $node {
			my $result = self.APPLY($node);
			if $.mutates-input && $result.defined && $result !~~ Iterator {
				unless $result === $node {
					Qwiratry::Tree::Replace.instance.replace-node($node, $result, $data);
				}
			}
			if $result.defined {
				if $!returns-type.WHICH ne Mu.WHICH {
					my @values = $result ~~ Positional ?? $result.list !! ($result,);
					for @values -> $item {
						unless $item ~~ $.returns-type {
							X::Qwiratry::TypeCheck.new(
								expected => $.returns-type,
								got => $item.WHAT,
								message => "Transformer '{self.^name}' has returns({$.returns-type.^name}) trait but result is of type {$item.WHAT.^name}. Ensure molds return values conforming to the specified type."
							).throw;
						}
					}
				}
				# Handle result - could be Iterator, List, or single value
				if $result ~~ Iterator {
					# If streaming, collect from iterator
					for $result -> $item {
						@results.push($item);
					}
				} elsif $result ~~ List || $result ~~ Array {
					@results.append($result.list);
				} else {
					# Single value
					@results.push($result);
				}
			}
		});
        
		# T029: Return results based on streaming trait
		my $result;
		if $.streaming {
			# Return lazy iterator
			$result = @results.iterator;
		} else {
			# Return List (always return List for consistency, even if single element)
			# This makes the return type predictable
			$result = @results.List;
		}
        
		# T048: Execute WRAP_TRANSFORMER wrapper around entire transformation output
		# The wrapper receives the transformation result and can modify it or perform side effects
		# Wrappers are called as submethods, which automatically traverse the hierarchy via MRO
		if self.^find_method('WRAP_TRANSFORMER', :no_fallback) {
			# Call wrapper submethod - it will traverse hierarchy and execute all wrappers
			$result = self.WRAP_TRANSFORMER($result);
		}
        
		# T053: Check returns(Type) trait if present
		if $!returns-type.WHICH ne Mu.WHICH {
			my @values = $result ~~ Positional ?? $result.list !! ($result,);
			for @values -> $item {
				unless $item ~~ $.returns-type {
					X::Qwiratry::TypeCheck.new(
						expected => $.returns-type,
						got => $item.WHAT,
						message => "Transformer '{self.^name}' has returns({$.returns-type.^name}) trait but result is of type {$item.WHAT.^name}. Ensure molds return values conforming to the specified type."
					).throw;
				}
			}
		}
        
		return $result;
	}
    
	=begin pod

	=head2 C<!default-traversal-query(Mu $data)>

	=begin code
	method !default-traversal-query(Mu $data --> Mu)
	=end code

	=head3 Parameters

	=item C<$data>

	 The input data, root value, or rendered value handled by this operation.


	Builds the query used for default traversal.

	Collection-like inputs are traversed with a descendant wildcard query; scalar
	inputs are wrapped in a root query. The selected walker then decides how that
	query maps to concrete nodes.

	=end pod
	method !default-traversal-query(Mu $data --> Mu) {
		if $data ~~ Positional || $data ~~ Associative {
			return DescendantOperator.new(:subject($data), :selector('*'));
		}
		return RootOperator.new(:subject($data));
	}

	method !walker-traversal-seq(Mu $data, $walker --> Iterable) {
		my $query = self!default-traversal-query($data);
		my $plan = $walker.plan($query, $data);
		my $qiter = $walker.iterator($plan);
		my $ctx = $qiter.context;
		gather {
			$walker.PRE-PASS($ctx);
			while (my $node = $qiter.pull-one) !~~ IterationEnd {
				take $node;
			}
			$walker.POST-PASS($ctx);
		}
	}

	method !each-traversal-node($iter, $walker, &code) {
		if $iter ~~ QueryIterator {
			my $ctx = $iter.context;
			$walker.PRE-PASS($ctx) if $walker.defined;
			while (my $node = $iter.pull-one) !~~ IterationEnd {
				code($node);
			}
			$walker.POST-PASS($ctx) if $walker.defined;
			return;
		}

		for $iter -> $node {
			code($node);
		}
	}

	method !create-default-iterator($data, $walker --> Mu) {
		if $walker.defined {
			my $query = self!default-traversal-query($data);
			if $walker.supports($query) {
				my $plan = $walker.plan($query, $data);
				return $walker.iterator($plan);
			}
		}

		# Fallback: simple root + direct children iterator
		my @nodes = gather {
			take $data;

			if $data ~~ Positional {
				for $data -> $item {
					take $item;
				}
			}

			if $data ~~ Associative {
				for $data.values -> $value {
					take $value;
				}
			}
		};
		return slip @nodes;
	}
    
	=begin pod

	=head2 C<transform($input, :$context, :$streaming, :$mode)>

	=begin code
	method transform($input, :$context, :$streaming, :$mode --> Mu)
	=end code

	=head3 Parameters

	=item C<$input>

	 The value supplied to the transformer entry point.

	=item C<$context>

	 Optional caller-provided traversal context.

	=item C<$streaming>

	 Optional flag selecting streaming results instead of eager materialization.

	=item C<$mode>

	 Optional transform mode override for inline, post, or default traversal behavior.


	Public transformation entry point.

	C<:mode> can force pre, inline, post, rewrite-optional, or rewrite-mandatory
	behavior. Without an explicit mode, iterators use post mode, single elements
	use inline mode, and larger structures use normal traversal. C<:streaming>
	overrides the transformer's streaming trait for this call.

	=end pod
	method transform($input, :$context, :$streaming, :$mode --> Mu) {
		# T031: Transformation entrypoint with mode detection
        
		# Determine mode: if :mode provided, use it; otherwise auto-detect
		my $actual-mode = $mode;
		if !$actual-mode.defined || $actual-mode eq 'default' {
			# Auto-detect based on input type
			# If $input is QueryIterator, use 'post' mode
			# If single element (heuristic), use 'inline' mode
			# Otherwise, use 'default' mode
			if $input ~~ Iterator {
				$actual-mode = 'post';
			} elsif self._is-single-element($input) {
				$actual-mode = 'inline';
			} else {
				# Simple heuristic: if it's a small structure, might be inline
				# For MVP, default to 'default' mode
				$actual-mode = 'default';
			}
		}
        
		# Handle streaming override
		my $use-streaming = $streaming.defined ?? $streaming !! $.streaming;
        
		# T057: Delegate to appropriate method based on mode
		given $actual-mode {
			when 'pre' {
				# T055: Pre-transformation: prepare data before traversal
				return self.prepare($input, :$context);
			}
			when 'inline' {
				# T056: Inline transformation: apply to single element
				my $result = self.apply($input, :$context, :mode($actual-mode));
				if self.^find_method('WRAP_TRANSFORMER', :no_fallback) {
					$result = self.WRAP_TRANSFORMER($result);
				}
				return $result;
			}
			when 'post' {
				# Post-transformation: transform QueryIterator
				# For post mode, consume the iterator and transform each element
				if $input ~~ Iterator {
					return self._transform_iterator($input, :$context, :$use-streaming);
				} else {
					# Not an iterator, fall back to TRANSFORM
					return self.TRANSFORM($input);
				}
			}
			when 'rewrite-optional' | 'rewrite-mandatory' {
				# T058: Rewrite modes - allow optional or mandatory mutation
				return self.apply($input, :$context, :mode($actual-mode));
			}
			default {
				# Default mode: call TRANSFORM directly
				return self.TRANSFORM($input);
			}
		}
	}
    
	=begin pod

	=head2 C<!calculate-specificity(Mold $mold)>

	=begin code
	method !calculate-specificity(Mold $mold --> Int)
	=end code

	=head3 Parameters

	=item C<$mold>

	 The C<Mold> instance being registered, ordered, inspected, or copied.


	Calculates an ordering specificity score for C<$mold>.

	Extracted navigation queries are scored by L<Qwiratry::Query::Specificity>.
	Plain predicate molds receive a small default score, and molds without a
	matcher receive zero. Higher scores are tried earlier when priority ties.

	=head3 Future Enhancement

	The navigation-query part of the original future work has been implemented:
	C<when-query> ASTs are delegated to L<Qwiratry::Query::Specificity>, which
	scores multilevel axes, wildcards, explicit path elements, attribute axes, and
	union-like branches.

	Predicate-only molds still use the default score. Future work may analyze
	dynamic C<when> predicates, mixed query/predicate clauses, or other AST shapes
	that cannot yet be reduced to a C<when-query>.

	=end pod
	method !calculate-specificity(Mold $mold --> Int) {
		if $mold.when-query.defined {
			return Qwiratry::Query::Specificity.instance.score($mold.when-query);
		}

		if !$mold.when-block.defined {
			return 0;
		}

		return 1;
	}
    
	=begin pod

	=head2 C<!detect-conflicts(@sorted, %specificity-cache)>

	=begin code
	method !detect-conflicts(@sorted, %specificity-cache)
	=end code

	=head3 Parameters

	=item C<@sorted>

	 The molds sorted by priority and specificity for conflict detection.

	=item C<%specificity-cache>

	 Cached specificity scores keyed by mold identity.


	Reports mold ordering conflicts after sorting.

	Two molds with equal priority, specificity, and tie-breaker are treated as
	ambiguous because they could both match the same node. The error names both
	molds and suggests using explicit tie-breakers.

	=end pod
	method !detect-conflicts(@sorted, %specificity-cache) {
		# Check for molds with equal priority, specificity, and tie-breaker
		for 0..^@sorted.elems -> $i {
			for ($i+1)..^@sorted.elems -> $j {
				my $t1 = @sorted[$i];
				my $t2 = @sorted[$j];
                
				# Get specificity values (use cached if not set)
				my $spec1 = $t1.specificity // %specificity-cache{$t1.WHICH} // 0;
				my $spec2 = $t2.specificity // %specificity-cache{$t2.WHICH} // 0;
                
				# Check if molds have equal ordering values
				if $t1.priority == $t2.priority &&
				$spec1 == $spec2 &&
				$t1.tie-breaker == $t2.tie-breaker {
                    
					# Conservative approach: if uncertain, report conflict
					# Molds with equal values could potentially match the same node
					my $t1-name = $t1.name // "<unnamed mold>";
					my $t2-name = $t2.name // "<unnamed mold>";
                    
					X::Qwiratry::MoldOrderingConflict.new(
						message => "Mold ordering conflict: molds '$t1-name' and '$t2-name' have equal priority ($t1.priority), specificity ($spec1), and tie-breaker ($t1.tie-breaker). Set explicit :tie-breaker values to resolve.",
						walker-type => 'Transformer',
						mold-names => [$t1-name, $t2-name],
						conflict-details => "priority=$t1.priority, specificity=$spec1, tie-breaker=$t1.tie-breaker"
					).throw;
				}
			}
		}
	}
    
	=begin pod

	=head2 C<copy($node)>

	=begin code
	method copy($node --> Mu)
	=end code

	=head3 Parameters

	=item C<$node>

	 The current node or element being matched, transformed, copied, or replaced.


	Shallow-copies a node by delegating to L<Qwiratry::Transformer::Copy>.

	=end pod
	method copy($node --> Mu) {
		copy-service.copy($node);
	}
    
	=begin pod

	=head2 C<deepcopy($node)>

	=begin code
	method deepcopy($node --> Mu)
	=end code

	=head3 Parameters

	=item C<$node>

	 The current node or element being matched, transformed, copied, or replaced.


	Deep-copies a node by delegating to L<Qwiratry::Transformer::Copy>.

	=end pod
	method deepcopy($node --> Mu) {
		copy-service.deepcopy($node);
	}
    
	=begin pod

	=head2 C<prepare($data, :$context)>

	=begin code
	method prepare($data, :$context --> Mu)
	=end code

	=head3 Parameters

	=item C<$data>

	 The input data, root value, or rendered value handled by this operation.

	=item C<$context>

	 Optional caller-provided traversal context.


	Pre-transformation hook for C<:mode<pre>>.

	The default implementation returns the data unchanged. Subclasses can
	override it to validate, annotate, or normalize the whole root before normal
	traversal.
    
	=end pod
	method prepare($data, :$context --> Mu) {
		# T055: Pre-transformation stage
		# For MVP, just return the data unchanged
		# Future: Can add preprocessing logic here (validation, annotation, etc.)
		# After preparation, typically call TRANSFORM on the prepared data
		my $prepared = $data;
        
		# If context is provided, can use it for preparation
		# For now, just return the data
		return $prepared;
	}
    
	=begin pod

	=head2 C<apply($element, :$context, :$mode)>

	=begin code
	method apply($element, :$context, :$mode --> Mu)
	=end code

	=head3 Parameters

	=item C<$element>

	 The element being transformed or passed through strategy hooks.

	=item C<$context>

	 Optional caller-provided traversal context.

	=item C<$mode>

	 Optional transform mode override for inline, post, or default traversal behavior.


	Inline transformation hook for a single element.

	The default implementation runs C<APPLY>. Rewrite modes return the mold result
	when mutation is enabled, and C<rewrite-mandatory> reports an error if no mold
	produces a replacement.
    
	=end pod
	method apply($element, :$context, :$mode --> Mu) {
		# T056: Inline transformation stage
		# For inline mode, apply molds to the element
		my $result = self.APPLY($element);
        
		# T058: Handle rewrite modes
		if $mode eq 'rewrite-optional' || $mode eq 'rewrite-mandatory' {
			# In rewrite modes, if mutation is allowed and result is defined, use it
			if $.mutates-input && $result.defined {
				# For rewrite modes, the result replaces the element
				# This is handled by the caller (Qwiratry::Walker or transformation logic)
				return $result;
			} elsif $mode eq 'rewrite-mandatory' && !$result.defined {
				# Mandatory rewrite requires a result
				die X::Qwiratry::Walker.new(
					message => "Transformer '{self.^name}' in rewrite-mandatory mode requires a transformation result, but no mold matched the element. Add a mold that matches this element or use rewrite-optional mode instead.",
					walker-type => self.^name
				).throw;
			}
		}
        
		# If no result, return element unchanged (or Nil if appropriate)
		my $value = $result // $element;
		return $value;
	}
    
	=begin pod

	=head2 C<_transform_iterator(Iterator $iterator, :$context, :$streaming)>

	=begin code
	method _transform_iterator(Iterator $iterator, :$context, :$streaming = False --> Mu)
	=end code

	=head3 Parameters

	=item C<$iterator>

	 The iterator that supplies traversal elements.

	=item C<$context>

	 Optional caller-provided traversal context.

	=item C<$streaming>

	 Optional flag selecting streaming results instead of eager materialization.


	Transforms each item pulled from an iterator in post mode.

	Streaming mode returns an iterator over collected results; otherwise the
	results are returned as a list.
    
	=end pod
	method _transform_iterator(Iterator $iterator, :$context, :$streaming = False --> Mu) {
		# Post mode: transform each element from iterator
		my @results;
		for $iterator -> $element {
			my $result = self.APPLY($element);
			if $result.defined {
				@results.push($result);
			}
		}
        
		# Return based on streaming flag
		if $streaming {
			return @results.iterator;
		} else {
			return @results.List;
		}
	}
    
	=begin pod

	=head2 C<_is-single-element($input)>

	=begin code
	method _is-single-element($input --> Bool)
	=end code

	=head3 Parameters

	=item C<$input>

	 The value supplied to the transformer entry point.


	Returns true when C<$input> should be treated as a single element for mode
	auto-detection.
    
	=end pod
	method _is-single-element($input --> Bool) {
		return False if $input ~~ Iterator;
		return False if $input ~~ Positional;
		return !($input<children> ~~ Positional) if $input ~~ Associative;
		return True;
	}
}

class MetamodelX::TransformerHOW is Metamodel::ClassHOW {
	method compose(Mu \type) {
		unless type ~~ Transformer {
			self.add_parent(type, Transformer);
		}
		callsame;

		my Bool $has-streaming = False;
		my Mu $returns-type = Nil;
		my Bool $has-tree-rewrite = False;

		try {
			my @traits = type.^traits;
			for @traits -> $trait {
				if $trait.^name eq 'streaming' || $trait.Str eq ':streaming' {
					$has-streaming = True;
				}
				elsif $trait.^name eq 'returns' {
					try {
						my @args = $trait.arguments;
						if @args.elems > 0 {
							$returns-type = @args[0];
						}
					}
				}
			}
		}

		try {
			my @roles = type.^roles;
			for @roles -> $role {
				if $role.^name eq 'TreeRewrite' {
					$has-tree-rewrite = True;
					last;
				}
			}
		}

		%TRANSFORMER-TRAITS{type.WHICH} = {
			streaming => $has-streaming,
			returns-type => $returns-type,
			tree-rewrite => $has-tree-rewrite
		};

		my @collected-molds = get-collected-molds();
		if @collected-molds.elems > 0 {
			%TRANSFORMER-MOLDS{type.WHICH} = @collected-molds;
			for @collected-molds -> $mold {
				if $mold.name.defined {
					self!create-mold-method(type, $mold);
				}
			}
		}

		my @collected-wrappers = get-collected-wrappers();
		if @collected-wrappers.elems > 0 {
			for @collected-wrappers -> %wrapper {
				my $wrapper-type = %wrapper<type>;
				my $wrapper-block = %wrapper<block>;
				if $wrapper-type eq 'TRANSFORMER' {
					self!create-wrapper-submethod(type, 'WRAP_TRANSFORMER', $wrapper-block);
				} elsif $wrapper-type eq 'MOLD_MATCHER' {
					self!create-wrapper-submethod(type, 'WRAP_MOLD_MATCHER', $wrapper-block);
				} elsif $wrapper-type eq 'MOLD_ACTION' {
					self!create-wrapper-submethod(type, 'WRAP_MOLD_ACTION', $wrapper-block);
				}
			}
		}

		return type;
	}

	method !create-mold-method(Mu \type, $mold) {
		if $mold.name.defined {
			my $mold-copy = $mold;
			my $type-identity = type.WHICH;
			my $method = method (|c) {
				my @molds = %TRANSFORMER-MOLDS{$type-identity} // [];
				my $found-mold = @molds.first(*.name eq $mold-copy.name);
				if $found-mold {
					$found-mold.execute(c[0] // $*CONTEXT // $_, :transformer(type));
				} else {
					die "Mold '{$mold-copy.name}' not found";
				}
			};
			self.add_method(type, $mold.name, $method);
		}
	}

	method !create-wrapper-submethod(Mu \type, Str $submethod-name, $wrapper-block) {
		return unless $wrapper-block.defined;
		my $block = $wrapper-block;
		my $submethod = submethod (|c) {
			$block(|c);
		};
		self.add_method(type, $submethod-name, $submethod);
	}
}

my package EXPORTHOW {
	package DECLARE {
		constant transformer = MetamodelX::TransformerHOW;
	}
}

=begin pod

=head1 Declarator Export

C<EXPORTHOW::DECLARE> exports the C<transformer> declarator. The custom HOW
ensures declared transformer classes inherit from C<Transformer>, collects molds
and wrappers from the slang registry, and installs generated methods during
class composition.

=end pod

