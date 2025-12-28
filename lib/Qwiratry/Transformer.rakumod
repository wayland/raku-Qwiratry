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
                    # This will be fully implemented in WP05 (template execution)
                    # For now, this is a basic implementation
                    $found-template.execute(c[0] // $*CONTEXT // $_);
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
        # TRANSFORM will be implemented in WP06
        # For now, just return self to verify callable works
        self;
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

    Calculate specificity score for a template based on its when clause.
    Implements basic specificity calculation for static patterns.

    Scoring rules:
    - Multilevel axis: -100
    - Wildcards: -10
    - Explicit path elements: +5
    - Attribute axes: +5

    For complex queries, this may return a default value and defer
    to runtime evaluation.

    @param Template $template - Template to calculate specificity for
    @returns Int - Specificity score (higher is more specific)

    =end pod
    method !calculate-specificity(Template $template --> Int) {
        # For WP04, we implement basic specificity calculation
        # Complex queries will need runtime evaluation (deferred to later)
        
        # If template has no when block, default specificity is 0
        if !$template.when-block.defined {
            return 0;
        }
        
        # Basic approach: analyze the when block's AST if possible
        # For now, we'll use a simple heuristic based on the block's structure
        # More sophisticated analysis can be added later
        
        # Default specificity for templates with when blocks
        # This is a placeholder - full AST analysis will be implemented
        # when query operators are available
        my Int $specificity = 0;
        
        # Try to analyze the when block
        # For MVP, we'll use a simple approach: templates with when blocks
        # get a base specificity, which can be refined later
        if $template.when-block.defined {
            # Base specificity for templates with when clauses
            $specificity = 1;
            
            # TODO: Analyze when-block AST for:
            # - Axis operators (multilevel: -100, single-level: 0)
            # - Wildcards (-10)
            # - Explicit path elements (+5)
            # - Attribute axes (+5)
            # This will require access to query AST structure
        }
        
        return $specificity;
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
}

=begin pod

Trait to ensure transformer classes inherit from Transformer base class
This will be applied automatically by the HOW class in a future work package
For WP02, transformers should manually inherit: `transformer MyX is Transformer { }`

=end pod

