=begin pod

Template Slang for transformer template syntax

This module provides a Slang that extends Raku grammar to recognize
the `template` declarator syntax within transformer bodies. The slang
parses template declarations and converts them into Template objects
that are collected by the Transformer HOW class.

Template syntax:
  template [name] [signature] [traits] when { ... } do { ... }

Example:
  template TOP do { return Node.new(); }
  template section() when { .name eq 'section' } do { make Node.new(); }
  template :streaming when { $_.is_leaf } do { take $_; }

The grammar and actions roles are exported for use with Slangify.
The transformer HOW class will activate this slang when processing
transformer bodies.

=end pod
use	v6.e.PREVIEW;

unit module Qwiratry::Template::Slang;
use	MONKEY-SEE-NO-EVAL;

use Qwiratry::Template;

=begin pod

Package-level storage for templates collected during slang parsing.
This is accessed by the Transformer HOW class to retrieve templates
that were parsed from the transformer body.

=end pod
our @TEMPLATES;

=begin pod

Package-level storage for wrappers collected during slang parsing.
This is accessed by the Transformer HOW class to retrieve wrappers
that were parsed from the transformer body.

=end pod
our @WRAPPERS;

sub register-template(Template $template) is export {
    @TEMPLATES.push($template);
}

sub register-wrapper(Str $type, Block $block) is export {
    @WRAPPERS.push(%(type => $type, block => $block));
}

=begin pod

Get templates collected by the slang.
This function is called by the Transformer HOW class to retrieve
templates that were parsed from the transformer body.

=end pod
sub get-collected-templates() is export {
    my @result = @TEMPLATES;
    @TEMPLATES = [];
    return @result;
}

=begin pod

Clear the template collection.
Called by the Transformer HOW class before processing a new transformer body.

=end pod
sub clear-collected-templates() is export {
    @TEMPLATES = [];
}

=begin pod

Get wrappers collected during slang parsing.
Returns array of wrapper hashes with 'type' and 'block' keys.
Clears the collection after retrieval (one-time use per compilation).

=end pod
sub get-collected-wrappers() is export {
    my @wrappers = @WRAPPERS;
    @WRAPPERS = [];
    @wrappers
}

=begin pod

Clear collected wrappers.
Used to reset the wrapper collection between compilations.

=end pod
sub clear-collected-wrappers() is export {
    @WRAPPERS = [];
}

