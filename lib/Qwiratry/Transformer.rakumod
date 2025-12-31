=begin pod

Transformer declarator and Transformer class for declarative data transformations

This module provides the custom `transformer` declarator and the Transformer class
that enables pattern-matching transformations on various data structures using
templates. Transformers integrate with the Qwiratry::Walker and Strategy systems for
flexible data transformation workflows.

=end pod

use Qwiratry::Template;
use Qwiratry::Template::Slang;  # For get-collected-templates(), clear-collected-templates(), get-collected-wrappers(), clear-collected-wrappers()
use X::Qwiratry;  # For X::Qwiratry::TemplateOrderingConflict
use Qwiratry::Walker::Factory;  # For Qwiratry::Walker selection
use Qwiratry::Transformer::Copy;  # For copy() and deepcopy() service functions (exported by default)
# Note: Template slang activation is handled by main Qwiratry.rakumod
# Users should `use Qwiratry` to get slang activation automatically

=begin pod

Package-level registry for templates collected during transformer compilation.
Keyed by transformer type identity (WHICH) for runtime access.

=end pod
our %TRANSFORMER-TEMPLATES;

=begin pod

Package-level registry for trait metadata collected during transformer compilation.
Keyed by transformer type identity (WHICH) for runtime access.
Stores streaming, returns-type, and tree-rewrite flags.

=end pod
our %TRANSFORMER-TRAITS;

=begin pod

Custom HOW class for transformer declarator.
Extends Metamodel::ClassHOW to process transformer body AST
and collect templates and wrappers during compilation.

=end pod
class MetamodelX::TransformerHOW is Metamodel::ClassHOW {
    =begin pod

    Override compose to process transformer body and collect templates/wrappers.
    This is called during class composition, allowing us to access the body AST.

    =end pod
    method compose(Mu \type) {
        # Call parent compose first to set up the class
        callsame;
        
        # T052: Detect traits on transformer declaration
        # Check for :streaming, returns(Type), and does TreeRewrite traits
        my Bool $has-streaming = False;
        my Mu $returns-type = Nil;
        my Bool $has-tree-rewrite = False;
        
        # Check for :streaming trait
        try {
            my @traits = type.^traits;
            for @traits -> $trait {
                # Check for :streaming trait (colon trait)
                if $trait.^name eq 'streaming' || $trait.Str eq ':streaming' {
                    $has-streaming = True;
                }
                # Check for returns(Type) trait
                elsif $trait.^name eq 'returns' {
                    # Extract type from trait arguments
                    try {
                        my @args = $trait.arguments;
                        if @args.elems > 0 {
                            $returns-type = @args[0];
                        }
                    }
                }
            }
        }
        
        # T054: Check for TreeRewrite role composition
        # Check if type does TreeRewrite role
        try {
            # Use string-based role check to avoid import issues during compose
            my @roles = type.^roles;
            for @roles -> $role {
                if $role.^name eq 'TreeRewrite' {
                    $has-tree-rewrite = True;
                    last;
                }
            }
        }
        
        # Store trait metadata in class-level registry for instance initialization
        %TRANSFORMER-TRAITS{type.WHICH} = {
            streaming => $has-streaming,
            returns-type => $returns-type,
            tree-rewrite => $has-tree-rewrite
        };
        
        # Collect templates that were parsed by the slang during compilation
        # The slang must be activated in the user's code (via `use Slangify`)
        # before declaring transformers. Templates are collected into @TEMPLATES
        # during compilation when the slang processes template declarations.
        my @collected-templates = get-collected-templates();
        
        # Store templates in the class-level registry keyed by type identity
        # This allows instances to access templates via the @.templates attribute
        if @collected-templates.elems > 0 {
            %TRANSFORMER-TEMPLATES{type.WHICH} = @collected-templates;
            
            # Create callable methods for named templates
            for @collected-templates -> $template {
                if $template.name.defined {
                    self!create-template-method(type, $template);
                }
            }
        }
        
        # T045: Collect wrappers that were parsed by the slang during compilation
        # Wrappers are collected into @WRAPPERS during compilation when the slang processes wrapper declarations.
        my @collected-wrappers = get-collected-wrappers();
        
        # T046: Create wrapper submethods for each wrapper type
        if @collected-wrappers.elems > 0 {
            for @collected-wrappers -> %wrapper {
                my $wrapper-type = %wrapper<type>;
                my $wrapper-block = %wrapper<block>;
                
                # Create corresponding submethod based on wrapper type
                if $wrapper-type eq 'TRANSFORMER' {
                    self!create-wrapper-submethod(type, 'WRAP_TRANSFORMER', $wrapper-block);
                } elsif $wrapper-type eq 'TEMPLATE_MATCHER' {
                    self!create-wrapper-submethod(type, 'WRAP_TEMPLATE_MATCHER', $wrapper-block);
                } elsif $wrapper-type eq 'TEMPLATE_ACTION' {
                    self!create-wrapper-submethod(type, 'WRAP_TEMPLATE_ACTION', $wrapper-block);
                }
            }
        }
        
        return type;
    }
    
    
    =begin pod

    Create a callable method for a named template on the transformer class.

    @param \type - The transformer class type
    @param $template - The Template object with a name

    =end pod
    method !create-template-method(Mu \type, $template) {
        # Create a method on the type that calls the template
        # The method should execute the template's do block when called
        
        if $template.name.defined {
            # Get the template from the registry (it's stored there)
            # We need to capture the template in the closure
            my $template-copy = $template;
            
            # Create a method that executes the template
            # The method signature should match the template's signature (if any)
            # For now, we create a method that accepts any arguments
            # We capture the type identity in the closure
            my $type-identity = type.WHICH;
            my $method = method (|c) {
                # Get templates from the registry for this type
                my @templates = %TRANSFORMER-TEMPLATES{$type-identity} // [];
                
                # Find the template by name
                my $found-template = @templates.first(*.name eq $template-copy.name);
                
                if $found-template {
                    # Execute template's do block with magic variables set
                    # Pass the transformer instance for self reference
                    $found-template.execute(c[0] // $*CONTEXT // $_, :transformer(type));
                } else {
                    die "Template '{$template-copy.name}' not found";
                }
            };
            
            # Add the method to the type using HOW's add_method
            self.add_method(type, $template.name, $method);
        }
    }
    
    =begin pod

    Create a submethod for a wrapper on the transformer class.
    T046: Creates submethods WRAP_TRANSFORMER, WRAP_TEMPLATE_MATCHER, or WRAP_TEMPLATE_ACTION.

    @param \type - The transformer class type
    @param $submethod-name - The submethod name (WRAP_TRANSFORMER, etc.)
    @param $wrapper-block - The wrapper code block

    =end pod
    method !create-wrapper-submethod(Mu \type, Str $submethod-name, $wrapper-block) {
        # T046: Create a submethod that executes the wrapper's code block
        # T047: Submethods enable hierarchy traversal via MRO
        # The wrapper block will be called with appropriate parameters
        
        if $wrapper-block.defined {
            # Create a submethod that calls the wrapper block
            # The submethod signature depends on the wrapper type:
            # - WRAP_TRANSFORMER: receives transformation result
            # - WRAP_TEMPLATE_MATCHER: receives node and match result
            # - WRAP_TEMPLATE_ACTION: receives node and action result
            
            # T047: Create a submethod that accepts any arguments and calls up hierarchy
            # The submethod first calls the wrapper block, then calls next method in hierarchy
            my $submethod = submethod (|c) {
                # T047: Execute wrapper block first, then call next method in hierarchy
                # This allows wrappers to modify results or perform side effects
                # before/after calling parent wrappers
                my $result;
                if $wrapper-block.defined {
                    # Execute wrapper block with provided arguments
                    # The block receives the arguments passed to the submethod
                    # The block should return the (possibly modified) result
                    $result = $wrapper-block(|c);
                } else {
                    # No wrapper block - use first argument as result
                    $result = c[0] if c.elems > 0;
                }
                
                # T047: Call next method in hierarchy using callwith
                # This traverses the MRO to find the next wrapper submethod
                # If no next method exists, callwith returns the result unchanged
                {
                    # Try to call next method in hierarchy
                    # If no next method exists, this will throw, which we catch
                    my $next-result = callwith($result, |c[1..*]);
                    return $next-result;
                    CATCH {
                        # No next method in hierarchy - return the result from this wrapper
                        return $result;
                    }
                }
            };
            
            # Add the submethod to the type using HOW's add_method
            self.add_method(type, $submethod-name, $submethod);
        }
    }
}

=begin pod

Export transformer declarator via EXPORTHOW::DECLARE
Using global package (not lexical) so declarator is available globally

=end pod
package EXPORTHOW {
	package DECLARE {
		# Use custom TransformerHOW class to process transformer body
		constant transformer = MetamodelX::TransformerHOW;
	}
}

=begin pod

Base Transformer class
Transformers declared with the `transformer` declarator should inherit from this
Full implementation will be added in later work packages

=end pod
class Transformer is export {
    =begin pod

    Templates defined in transformer body (populated in WP03).
    Initialized from class-level registry when instance is created.

    =end pod
    has @.templates is rw;
    
    =begin pod

    Initialize templates from class-level registry when instance is created.

    =end pod
    submethod TWEAK() {
        # Get templates from class-level registry
        # Use the type object's WHICH for lookup
        my $type-identity = self.WHAT.WHICH;
        if %TRANSFORMER-TEMPLATES{$type-identity}:exists {
            @!templates = %TRANSFORMER-TEMPLATES{$type-identity}.List;
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

    Templates sorted by priority → specificity → tie-breaker (populated in WP04).
    This array is populated by ORDER-TEMPLATES method and cached to avoid recalculation.

    =end pod
    has @.ordered-templates is rw;
    
    # Cache flag to avoid recalculating ordering
    has Bool $!ordering-cached = False;
    
    # Wrappers defined in transformer body (will be populated in WP08)
    has @.wrappers;
    
    # T052: Whether transformer has :streaming trait
    has Bool $.streaming = False;
    
    # T053: Output type constraint (from returns(Type) trait)
    has Mu $.returns-type;
    
    # T054: Whether transformer can mutate input (from does TreeRewrite)
    has Bool $.mutates-input = False;
    
    # Transformation mode (pre, inline, post, default, rewrite-optional, rewrite-mandatory)
    has Str $.mode = 'default';
    
    =begin pod
    
    Make Transformer callable: MyTransform($data) syntax.
    This will call TRANSFORM when it's implemented in WP06.
    For WP02, this is a stub that returns self.
    
    =end pod
    method CALL-ME(*@args, *%named) {
        # T031: Call transform() method when transformer is called
        # MyTransform($data) syntax
        my $data = @args[0] // $*CONTEXT;
        return self.transform($data, |%named);
    }
    
    =begin pod

    Apply templates to a single node, return first matching template result.

    Iterates through ordered templates and returns the result of the first
    matching template. Stops after first match (no fallback to other templates).

    @param $node - Node to apply templates to
    @returns Iterator|Mu|List|Nil - Result from first matching template, or Nil if no match

    =end pod
    method APPLY($node --> Mu) {
        # T027: Apply templates to a single node
        # Get ordered templates (call ORDER-TEMPLATES if not already ordered)
        my @ordered = self.ORDER-TEMPLATES;
        
        # Iterate through ordered templates
        for @ordered -> $template {
            # T049: Check if template matches this node (with WRAP_TEMPLATE_MATCHER wrapper)
            my $match-result;
            if self.^find_method('WRAP_TEMPLATE_MATCHER', :no_fallback) {
                # Call wrapper submethod - it will traverse hierarchy and execute all wrappers
                # Wrapper receives node and match result, can modify match result
                my $raw-match = $template.matches($node);
                $match-result = self.WRAP_TEMPLATE_MATCHER($node, $raw-match);
            } else {
                # No wrapper - just check match directly
                $match-result = $template.matches($node);
            }
            
            # Check if template matches this node
            if $match-result {
                # First match wins - execute template and return result
                # Pass self as transformer for self reference
                # T050: WRAP_TEMPLATE_ACTION is called inside Template.execute()
                return $template.execute($node, :transformer(self));
            }
        }
        
        # No templates matched - return Nil (empty sequence)
        # Explicitly return Nil to avoid returning Any (type object)
        return Nil;
    }
    
    =begin pod

    Process transformer body AST to collect templates.

    This method will be called by the HOW class during transformer compilation
    to parse template declarations from the transformer body.

    For WP03, this is a placeholder that will be enhanced when the custom HOW class
    is implemented (currently blocked by serialization issues with extending ClassHOW).

    @param $body-ast - The RakuAST body of the transformer (not yet accessible)
    @returns Array[Template] - Array of collected Template objects

    =end pod
    method !collect-templates-from-body($body-ast --> Array[Template]) {
        # Templates are now collected automatically by the HOW class during compose()
        # via the slang system. This method is kept for compatibility.
        Array[Template].new
    }
    
    =begin pod

    Add a template to this transformer's template collection.

    This is a helper method for testing and manual template registration.
    In the final implementation, templates will be collected automatically
    during compilation by the HOW class.

    @param Template $template - The template to add

    =end pod
    method add-template(Template $template) {
        @!templates.push($template);
        
        # If template has a name, create a callable method on this transformer
        # Method creation is handled by HOW class during compilation via !create-template-method()
    }
    
    =begin pod

    Process templates from body AST and store them.

    This method will be called by the HOW class during compilation.
    For WP03, this is a placeholder that can be enhanced later.

    @param $body-ast - The RakuAST body of the transformer

    =end pod
    method !process-templates($body-ast) {
        my @collected = self!collect-templates-from-body($body-ast);
        @!templates = @collected;
        
        # Create callable methods for named templates
        # Method creation is handled by HOW class during compilation via !create-template-method()
    }
    
    =begin pod

    Orders templates by priority → specificity → tie-breaker.
    Populates @.ordered-templates array with sorted templates.
    Caches result to avoid recalculation.

    This method implements the template ordering algorithm:
    1. Sort by priority (highest first)
    2. For equal priority, sort by specificity (highest first)
    3. For equal priority and specificity, sort by tie-breaker (highest first)
    4. Detect and report conflicts when templates have equal values

    @returns Array[Template] - Array of templates in execution order

    =end pod
    method ORDER-TEMPLATES(--> Array) {
        # Performance: O(n log n) sorting with caching to avoid recalculation
        # Returns cached result if available (O(1) after first call)
        if $!ordering-cached && @!ordered-templates.elems > 0 {
            return @!ordered-templates;
        }
        
        # T014: Priority is already stored in template's $.priority attribute
        # (extracted during template creation in TemplateSlang)
        # No additional extraction needed - templates already have priority set
        
        # T015/T016: Calculate specificity for each template
        # For now, we'll use a simple approach: calculate basic specificity
        # Complex queries will be deferred to runtime evaluation
        # Note: Specificity is read-only, so we calculate it but can't store it
        # For templates without specificity, we'll use the calculated value in sorting
        # Performance: O(n) specificity calculation
        my %specificity-cache;
        for @!templates -> $template {
            if !$template.specificity.defined {
                %specificity-cache{$template.WHICH} = self!calculate-specificity($template);
            }
        }
        
        # T014/T016/T017: Sort templates by priority → specificity → tie-breaker
        # Priority and tie-breaker are already stored in template attributes
        # Performance: O(n log n) - Raku's sort uses efficient algorithm
        my @sorted = @!templates.sort({
            # Primary sort: priority (descending - highest first)
            -$^a.priority <=> -$^b.priority
            ||
            # Secondary sort: specificity (descending - highest first)
            # Use cached value if template doesn't have specificity set
            -($^a.specificity // %specificity-cache{$^a.WHICH} // 0) <=> -($^b.specificity // %specificity-cache{$^b.WHICH} // 0)
            ||
            # Tertiary sort: tie-breaker (descending - highest first)
            -$^a.tie-breaker <=> -$^b.tie-breaker
        });
        
        # T018: Detect conflicts (pass specificity cache for conflict checking)
        self!detect-conflicts(@sorted, %specificity-cache);
        
        # T019: Store ordered templates and mark as cached
        @!ordered-templates = @sorted;
        $!ordering-cached = True;
        
        return @!ordered-templates;
    }
    
    =begin pod

    Main transformation method that orchestrates full transformation.

    Calls ORDER-TEMPLATES to prepare templates, obtains Qwiratry::Walker via factory,
    iterates over data nodes, and applies templates to each node.

    @param $data - Root data structure to transform
    @param Iterator :$iterator - Optional iterator (if not provided, uses default or Qwiratry::Walker-provided)
    @returns Iterator|Mu|List|Nil - Transformation results

    =end pod
    method TRANSFORM($data, Iterator :$iterator --> Mu) {
        # T029: Main transformation orchestration
        # Call ORDER-TEMPLATES to prepare templates (cache result)
        my @ordered = self.ORDER-TEMPLATES;
        
        # T028: Obtain Qwiratry::Walker via factory
        my $walker = Qwiratry::Walker::Factory.instance.get-walker($data);
        
        # T030: Create iterator - use provided iterator or default
        my $iter = $iterator;
        if !$iter.defined {
            # Create default iterator (depth-first, top-down)
            # For MVP, use a simple iterator that yields nodes
            # Future: Use Qwiratry::Walker-provided iterator if available
            $iter = self!create-default-iterator($data, $walker);
        }
        
        # T029: Iterate over data nodes and apply templates
        my @results;
        for $iter -> $node {
            my $result = self.APPLY($node);
            if $result.defined {
                # Handle result - could be Iterator, List, or single value
                if $result ~~ Iterator {
                    # If streaming, collect from iterator
                    for $result -> $item {
                        @results.push($item);
                    }
                } elsif $result ~~ List {
                    # If List, append all items
                    @results.append($result);
                } else {
                    # Single value
                    @results.push($result);
                }
            }
        }
        
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
        if $.returns-type.defined {
            # Check if result conforms to the specified type
            unless $result ~~ $.returns-type {
                die X::Qwiratry::TypeCheck.new(
                    expected => $.returns-type,
                    got => $result.WHAT,
                    message => "Transformer '{self.^name}' has returns({$.returns-type.^name}) trait but result is of type {$result.WHAT.^name}. Ensure templates return values conforming to the specified type."
                );
            }
        }
        
        return $result;
    }
    
    =begin pod

    Create default iterator for data traversal.

    Provides a simple depth-first, top-down iterator for basic data structures.
    For more complex cases, Qwiratry::Walker-provided iterators should be used.

    @param $data - Root data structure
    @param Qwiratry::Walker? $walker - Optional Walker (not used in MVP, for future enhancement)
    @returns Iterator - Iterator that yields nodes

    =end pod
    method !create-default-iterator($data, $walker --> Iterator) {
        # T030: Create default iterator (depth-first, top-down)
        # For MVP, provide simple iterator for basic structures
        # Future: Use Qwiratry::Walker-provided iterator if available
        
        # Simple iterator that yields the root and its children (if applicable)
        return gather {
            # Yield root node
            take $data;
            
            # For Positional (arrays, lists), yield each element
            if $data ~~ Positional {
                for $data -> $item {
                    take $item;
                }
            }
            
            # For Associative (hashes, maps), yield each value
            if $data ~~ Associative {
                for $data.values -> $value {
                    take $value;
                }
            }
        }.iterator;
    }
    
    =begin pod

    Transformation entrypoint that determines mode and delegates.

    This is the public API entrypoint. Handles mode detection and delegation
    to appropriate methods (prepare, apply, _transform_iterator, TRANSFORM).

    @param $input - Input data to transform
    @param :$context - Optional context (defaults to $*CONTEXT)
    @param :$streaming - Optional streaming override (overrides trait setting)
    @param :$mode - Optional mode ('default', 'pre', 'inline', 'post', etc.)
    @returns Iterator|Mu|List|Nil - Transformation results

    =end pod
    method transform($input, :$context, :$streaming, :$mode --> Mu) {
        # T031: Transformation entrypoint with mode detection
        
        # Determine mode: if :mode provided, use it; otherwise auto-detect
        my $actual-mode = $mode;
        if !$actual-mode.defined {
            # Auto-detect based on input type
            # If $input is QueryIterator, use 'post' mode
            # If single element (heuristic), use 'inline' mode
            # Otherwise, use 'default' mode
            if $input ~~ Iterator {
                $actual-mode = 'post';
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
                return self.apply($input, :$context, :mode($actual-mode));
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

    Calculate specificity score for a template based on its when clause.
    Implements basic specificity calculation for static patterns.

    **MVP Implementation (WP04)**:
    This is a basic implementation that provides a default specificity value
    for templates with when blocks. Full AST analysis will be implemented when
    query operators are available.

    **Future Enhancement**:
    When query operators (⪪, ⪪⪪, etc.) are available, this method should analyze
    the when-block AST to calculate specificity based on:
    - Multilevel axis (⪪⪪): -100
    - Wildcards (*): -10
    - Explicit path elements: +5
    - Attribute axes: +5
    - Union queries: calculate each branch, take max

    For complex queries with dynamic predicates, specificity calculation may
    need to be deferred to runtime evaluation.

    @param Template $template - Template to calculate specificity for
    @returns Int - Specificity score (higher is more specific)

    =end pod
    method !calculate-specificity(Template $template --> Int) {
        # MVP Implementation (WP04): Basic specificity calculation
        # 
        # This provides a minimal implementation that:
        # 1. Returns 0 for templates without when blocks
        # 2. Returns 1 for templates with when blocks (base specificity)
        #
        # Full AST analysis will be implemented when query operators are available.
        # At that time, we'll analyze the when-block AST to detect:
        # - Axis operators (⪪, ⪪⪪, etc.) - multilevel axes reduce specificity
        # - Wildcards (*) - reduce specificity
        # - Explicit path elements - increase specificity
        # - Attribute axes - increase specificity
        #
        # For now, templates with when blocks get a base specificity of 1,
        # which allows ordering to work correctly when priority is equal.
        # Users can use explicit :tie-breaker values to fine-tune ordering
        # until full specificity calculation is available.
        
        # If template has no when block, default specificity is 0
        if !$template.when-block.defined {
            return 0;
        }
        
        # Base specificity for templates with when clauses
        # This ensures templates with when blocks are ordered correctly
        # when priority is equal, even without full AST analysis
        return 1;
    }
    
    =begin pod

    Detect template ordering conflicts.
    Reports error when two templates have equal priority, specificity, and tie-breaker
    and could match the same node.

    @param Array[Template] @sorted - Sorted array of templates
    @param Hash %specificity-cache - Cache of calculated specificity values

    =end pod
    method !detect-conflicts(@sorted, %specificity-cache) {
        # Check for templates with equal priority, specificity, and tie-breaker
        for 0..^@sorted.elems -> $i {
            for ($i+1)..^@sorted.elems -> $j {
                my $t1 = @sorted[$i];
                my $t2 = @sorted[$j];
                
                # Get specificity values (use cached if not set)
                my $spec1 = $t1.specificity // %specificity-cache{$t1.WHICH} // 0;
                my $spec2 = $t2.specificity // %specificity-cache{$t2.WHICH} // 0;
                
                # Check if templates have equal ordering values
                if $t1.priority == $t2.priority &&
                   $spec1 == $spec2 &&
                   $t1.tie-breaker == $t2.tie-breaker {
                    
                    # Conservative approach: if uncertain, report conflict
                    # Templates with equal values could potentially match the same node
                    my $t1-name = $t1.name // "<unnamed template>";
                    my $t2-name = $t2.name // "<unnamed template>";
                    
                    X::Qwiratry::TemplateOrderingConflict.new(
                        message => "Template ordering conflict: templates '$t1-name' and '$t2-name' have equal priority ($t1.priority), specificity ($spec1), and tie-breaker ($t1.tie-breaker). Set explicit :tie-breaker values to resolve.",
                        walker-type => 'Transformer',
                        template-names => [$t1-name, $t2-name],
                        conflict-details => "priority=$t1.priority, specificity=$spec1, tie-breaker=$t1.tie-breaker"
                    ).throw;
                }
            }
        }
    }
    
    =begin pod

    Shallow copy a node.

    Delegates to Qwiratry::Transformer::Copy::copy() service function.
    Provides convenient access: $transformer.copy($node)

    @param $node - Node to copy
    @returns Mu - Shallow copy of node

    =end pod
    # T043: Attach copy() method to Transformer
    method copy($node --> Mu) {
        # Delegate to Qwiratry::Transformer::Copy::copy() service function
        # copy() is imported from Qwiratry::Transformer::Copy
        copy($node);
    }
    
    =begin pod

    Deep copy a node.

    Delegates to Qwiratry::Transformer::Copy::deepcopy() service function.
    Provides convenient access: $transformer.deepcopy($node)

    @param $node - Node to deep copy
    @returns Mu - Deep copy of node

    =end pod
    # T043: Attach deepcopy() method to Transformer
    method deepcopy($node --> Mu) {
        # Delegate to Qwiratry::Transformer::Copy::deepcopy() service function
        # deepcopy() is imported from Qwiratry::Transformer::Copy
        deepcopy($node);
    }
    
    =begin pod
    
    T055: Pre-transformation stage (before traversal).
    
    Called when transform is called with :mode<pre>.
    Operates on whole data structure before traversal.
    Can modify or annotate structure.
    
    @param $data - Root data structure to prepare
    @param :$context - Optional context
    @returns Mu - Potentially modified structure
    
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
    
    T056: Inline transformation stage (during traversal).
    
    Called when transform is called with :mode<inline> or rewrite modes.
    Operates on each element during traversal.
    Can mutate in-place if $.mutates-input is true.
    
    @param $element - Element to transform
    @param :$context - Optional context
    @param :$mode - Transformation mode (inline, rewrite-optional, rewrite-mandatory)
    @returns Mu - Transformed element
    
    =end pod
    method apply($element, :$context, :$mode --> Mu) {
        # T056: Inline transformation stage
        # For inline mode, apply templates to the element
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
                    message => "Transformer '{self.^name}' in rewrite-mandatory mode requires a transformation result, but no template matched the element. Add a template that matches this element or use rewrite-optional mode instead.",
                    walker-type => self.^name
                );
            }
        }
        
        # If no result, return element unchanged (or Nil if appropriate)
        return $result // $element;
    }
    
    =begin pod
    
    Transform an iterator (post mode).
    
    Consumes a QueryIterator or Iterator and transforms each element.
    
    @param Iterator $iterator - Iterator to transform
    @param :$context - Optional context
    @param :$streaming - Whether to return streaming results
    @returns Iterator|List - Transformation results
    
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
    
    Heuristic to determine if input is a single element (not a collection).
    
    Used for mode auto-detection.
    
    @param $input - Input to check
    @returns Bool - True if appears to be single element
    
    =end pod
    method _is-single-element($input --> Bool) {
        # Heuristic: if it's not Positional, Associative, or Iterator, treat as single element
        # This is conservative - collections are Positional or Associative
        return !($input ~~ Positional || $input ~~ Associative || $input ~~ Iterator);
    }
}

=begin pod

Trait to ensure transformer classes inherit from Transformer base class
This will be applied automatically by the HOW class in a future work package
For WP02, transformers should manually inherit: `transformer MyX is Transformer { }`

=end pod

