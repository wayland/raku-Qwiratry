#| Transformer declarator and Transformer class for declarative data transformations
#|
#| This module provides the custom `transformer` declarator and the Transformer class
#| that enables pattern-matching transformations on various data structures using
#| templates. Transformers integrate with the Walker and Strategy systems for
#| flexible data transformation workflows.
unit module Qwiratry::Transformer;

use Qwiratry::Template;

#| Export transformer declarator via EXPORTHOW::DECLARE
#| For WP02, we use Metamodel::ClassHOW directly
#| Custom behavior will be added via TWEAK and method addition in the transformer class
#| In later work packages, we'll create a proper custom HOW class to process templates
package EXPORTHOW {
    package DECLARE {
        # Use ClassHOW directly - transformers will inherit from Transformer class
        # which provides the necessary structure and CALL-ME method
        constant transformer = Metamodel::ClassHOW;
    }
}

#| Base Transformer class
#| Transformers declared with the `transformer` declarator should inherit from this
#| Full implementation will be added in later work packages
class Transformer {
    #| Templates defined in transformer body (populated in WP03)
    has @.templates is rw;
    
    #| Wrappers defined in transformer body (will be populated in WP08)
    has @.wrappers;
    
    #| Whether transformer has :streaming trait
    has Bool $.streaming = False;
    
    #| Whether transformer can mutate input (from does TreeRewrite)
    has Bool $.mutates-input = False;
    
    #| Transformation mode
    has Str $.mode = 'output-only';
    
    #| Make Transformer callable: MyTransform($data) syntax
    #| This will call TRANSFORM when it's implemented in WP06
    #| For WP02, this is a stub that returns self
    method CALL-ME(*@args, *%named) {
        # TRANSFORM will be implemented in WP06
        # For now, just return self to verify callable works
        self;
    }
    
    #| Process transformer body AST to collect templates.
    #|
    #| This method will be called by the HOW class during transformer compilation
    #| to parse template declarations from the transformer body.
    #|
    #| For WP03, this is a placeholder that will be enhanced when the custom HOW class
    #| is implemented (currently blocked by serialization issues with extending ClassHOW).
    #|
    #| @param $body-ast - The RakuAST body of the transformer (not yet accessible)
    #| @returns Array[Template] - Array of collected Template objects
    method !collect-templates-from-body($body-ast --> Array[Template]) {
        # Placeholder for WP03 - will be implemented when HOW class can access body AST
        # For now, return empty array
        # TODO: Implement AST traversal to find template declarations
        # TODO: Extract template components (name, signature, traits, when/do blocks)
        # TODO: Create Template objects and return them
        Array[Template].new
    }
    
    #| Add a template to this transformer's template collection.
    #|
    #| This is a helper method for testing and manual template registration.
    #| In the final implementation, templates will be collected automatically
    #| during compilation by the HOW class.
    #|
    #| @param Template $template - The template to add
    method add-template(Template $template) {
        @!templates.push($template);
        
        # If template has a name, create a callable method on this transformer
        # Note: Method creation will be handled by HOW class during compilation
        # For WP03, we just store the template
        # TODO: Create callable method when HOW class is implemented
    }
    
    #| Process templates from body AST and store them.
    #|
    #| This method will be called by the HOW class during compilation.
    #| For WP03, this is a placeholder that can be enhanced later.
    #|
    #| @param $body-ast - The RakuAST body of the transformer
    method !process-templates($body-ast) {
        my @collected = self!collect-templates-from-body($body-ast);
        @!templates = @collected;
        
        # Create callable methods for named templates
        # Note: This will be handled by HOW class during compilation
        # For WP03, we just store the templates
        # TODO: Create callable methods when HOW class is implemented
    }
}

#| Trait to ensure transformer classes inherit from Transformer base class
#| This will be applied automatically by the HOW class in a future work package
#| For WP02, transformers should manually inherit: `transformer MyX is Transformer { }`

