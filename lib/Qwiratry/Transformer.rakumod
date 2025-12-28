=begin pod

Transformer declarator and Transformer class for declarative data transformations

This module provides the custom `transformer` declarator and the Transformer class
that enables pattern-matching transformations on various data structures using
templates. Transformers integrate with the Walker and Strategy systems for
flexible data transformation workflows.

=end pod

use Qwiratry::Template;
use Qwiratry::TemplateSlang;  # For get-collected-templates() and clear-collected-templates()
use Qwiratry::X;  # For X::Qwiratry::TemplateOrderingConflict
use Qwiratry::WalkerFactory;  # For Walker selection
use Qwiratry::Copy;  # For copy() and deepcopy() service functions (exported by default)
# Note: Template slang activation is handled by main Qwiratry.rakumod
# Users should `use Qwiratry` to get slang activation automatically

=begin pod

Package-level registry for templates collected during transformer compilation.
Keyed by transformer type identity (WHICH) for runtime access.

=end pod
our %TRANSFORMER-TEMPLATES;

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
    
    # Whether transformer has :streaming trait
    has Bool $.streaming = False;
    
    # Whether transformer can mutate input (from does TreeRewrite)
    has Bool $.mutates-input = False;
    
    # Transformation mode
    has Str $.mode = 'output-only';
    
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
            # Check if template matches this node
            if $template.matches($node) {
                # First match wins - execute template and return result
                # Pass self as transformer for self reference
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
        # Placeholder for WP03 - will be implemented when HOW class can access body AST
        # For now, return empty array
        # TODO: Implement AST traversal to find template declarations
        # TODO: Extract template components (name, signature, traits, when/do blocks)
        # TODO: Create Template objects and return them
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
        # Note: Method creation will be handled by HOW class during compilation
        # For WP03, we just store the template
        # TODO: Create callable method when HOW class is implemented
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
        # Note: This will be handled by HOW class during compilation
        # For WP03, we just store the templates
        # TODO: Create callable methods when HOW class is implemented
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
        # Return cached result if available
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
        my %specificity-cache;
        for @!templates -> $template {
            if !$template.specificity.defined {
                %specificity-cache{$template.WHICH} = self!calculate-specificity($template);
            }
        }
        
        # T014/T016/T017: Sort templates by priority → specificity → tie-breaker
        # Priority and tie-breaker are already stored in template attributes
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

    Calls ORDER-TEMPLATES to prepare templates, obtains Walker via factory,
    iterates over data nodes, and applies templates to each node.

    @param $data - Root data structure to transform
    @param Iterator :$iterator - Optional iterator (if not provided, uses default or Walker-provided)
    @returns Iterator|Mu|List|Nil - Transformation results

    =end pod
    method TRANSFORM($data, Iterator :$iterator --> Mu) {
        # T029: Main transformation orchestration
        # Call ORDER-TEMPLATES to prepare templates (cache result)
        my @ordered = self.ORDER-TEMPLATES;
        
        # T028: Obtain Walker via factory
        my $walker = WalkerFactory.instance.get-walker($data);
        
        # T030: Create iterator - use provided iterator or default
        my $iter = $iterator;
        if !$iter.defined {
            # Create default iterator (depth-first, top-down)
            # For MVP, use a simple iterator that yields nodes
            # Future: Use Walker-provided iterator if available
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
        if $.streaming {
            # Return lazy iterator
            return @results.iterator;
        } else {
            # Return List (always return List for consistency, even if single element)
            # This makes the return type predictable
            return @results.List;
        }
    }
    
    =begin pod

    Create default iterator for data traversal.

    Provides a simple depth-first, top-down iterator for basic data structures.
    For more complex cases, Walker-provided iterators should be used.

    @param $data - Root data structure
    @param Walker? $walker - Optional Walker (not used in MVP, for future enhancement)
    @returns Iterator - Iterator that yields nodes

    =end pod
    method !create-default-iterator($data, $walker --> Iterator) {
        # T030: Create default iterator (depth-first, top-down)
        # For MVP, provide simple iterator for basic structures
        # Future: Use Walker-provided iterator if available
        
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
        
        # Delegate to appropriate method based on mode
        given $actual-mode {
            when 'pre' {
                # Pre-transformation: prepare data before traversal
                # TODO: Implement prepare() method in future work package
                return self.TRANSFORM($input);
            }
            when 'inline' {
                # Inline transformation: apply to single element
                # TODO: Implement apply() method in future work package
                return self.APPLY($input);
            }
            when 'post' {
                # Post-transformation: transform QueryIterator
                # TODO: Implement _transform_iterator() method in future work package
                return self.TRANSFORM($input);
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

    Delegates to Qwiratry::Copy::copy() service function.
    Provides convenient access: $transformer.copy($node)

    @param $node - Node to copy
    @returns Mu - Shallow copy of node

    =end pod
    # T043: Attach copy() method to Transformer
    method copy($node --> Mu) {
        # Delegate to Qwiratry::Copy::copy() service function
        # copy() is imported from Qwiratry::Copy
        copy($node);
    }
    
    =begin pod

    Deep copy a node.

    Delegates to Qwiratry::Copy::deepcopy() service function.
    Provides convenient access: $transformer.deepcopy($node)

    @param $node - Node to deep copy
    @returns Mu - Deep copy of node

    =end pod
    # T043: Attach deepcopy() method to Transformer
    method deepcopy($node --> Mu) {
        # Delegate to Qwiratry::Copy::deepcopy() service function
        # deepcopy() is imported from Qwiratry::Copy
        deepcopy($node);
    }
}

=begin pod

Trait to ensure transformer classes inherit from Transformer base class
This will be applied automatically by the HOW class in a future work package
For WP02, transformers should manually inherit: `transformer MyX is Transformer { }`

=end pod

