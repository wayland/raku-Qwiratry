#| Transformer declarator and Transformer class for declarative data transformations
#|
#| This module provides the custom `transformer` declarator and the Transformer class
#| that enables pattern-matching transformations on various data structures using
#| templates. Transformers integrate with the Walker and Strategy systems for
#| flexible data transformation workflows.
unit module Qwiratry::Transformer;

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
    #| Templates defined in transformer body (will be populated in WP03)
    has @.templates;
    
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
}

#| Trait to ensure transformer classes inherit from Transformer base class
#| This will be applied automatically by the HOW class in a future work package
#| For WP02, transformers should manually inherit: `transformer MyX is Transformer { }`

