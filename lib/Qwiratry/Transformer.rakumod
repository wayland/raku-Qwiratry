=begin pod

Transformer declarator and Transformer class for declarative data transformations

This module provides the custom `transformer` declarator and the Transformer class
that enables pattern-matching transformations on various data structures using
templates. Transformers integrate with the Walker and Strategy systems for
flexible data transformation workflows.

=end pod

use Qwiratry::Template;
use Qwiratry::TemplateSlang;  # For get-collected-templates() and clear-collected-templates()
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
}

=begin pod

Trait to ensure transformer classes inherit from Transformer base class
This will be applied automatically by the HOW class in a future work package
For WP02, transformers should manually inherit: `transformer MyX is Transformer { }`

=end pod

