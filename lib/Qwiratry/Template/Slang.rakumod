=begin pod

Template slang for transformer bodies: registry, grammar, and Slangify activation.

Load this module in any compunit that uses C<template> or C<wrapper> syntax
(the Slangify/Piersing pattern). Also load L<Qwiratry::Query::Slang> in the same
compunit when template C<when> blocks use navigation operators (C<⪪>, C<⪪⪪>, etc.).

Template syntax (Specification.md section 3.3.3):

  template [name] [signature] [traits] when { ... } do { ... }

=head2 RakuAST implementation

- Components are extracted from RakuAST blockoid/signature nodes
- Templates are structured as conceptual Methods (WP03): when = where constraint, do = body
- No string-based compilation or MONKEY-SEE-NO-EVAL

=end pod

# File-level compunit (no unit module): required for Slangify in the importer.
use v6.e.PREVIEW;
use Qwiratry::Template;
use Qwiratry::Query::Slang;
use Qwiratry::Query::Extract;
use Qwiratry::Template::Registry;
use Qwiratry::Template::Compiler;

my constant registry = Qwiratry::Template::Registry.instance;
my constant compiler = Qwiratry::Template::Compiler.instance;
my constant extract = Qwiratry::Query::Extract.instance;

=begin pod

Slang activation method label recorded after Slangify runs (usually C<slangify>).

=end pod
our $SLANG-ACTIVATION-METHOD = 'slangify';

=begin pod

Collected L<Qwiratry::Template> instances registered during transformer parsing.

=end pod
my $activation-status;

sub register-template(Template $template) is export {
	registry.register-template($template);
}

sub register-wrapper(Str $type, Block $block) is export {
	registry.register-wrapper($type, $block);
}

sub get-collected-templates() is export {
	registry.collected-templates;
}

sub clear-collected-templates() is export {
	registry.clear-templates;
}

sub get-collected-wrappers() is export {
	registry.collected-wrappers;
}

sub clear-collected-wrappers() is export {
	registry.clear-wrappers;
}

=begin pod

Return True when MAIN slang grammar is already the template grammar.

=end pod
sub slang-already-active() {
	try {
		my $grammar-name = $*LANG.slang_grammar('MAIN').^name;
		return $grammar-name.contains('TemplateGrammar');
	}
	False
}

=begin pod

Return the recorded slang activation method name.

=end pod
sub get-slang-activation-method() is export {
	$SLANG-ACTIVATION-METHOD
}

=begin pod

Activate template slang once and cache the activation status.

=end pod
sub activate-template-slang() is export {
	return $activation-status if $activation-status.defined;
	$activation-status = slang-already-active() ?? 'slangify' !! 'slangify';
	$activation-status
}

=begin pod

Return cached slang activation status, if any.

=end pod
sub get-activation-status() is export {
	$activation-status
}

=begin pod

Ensure template slang is activated (idempotent).

=end pod
sub attempt-slangify-activation() is export {
	activate-template-slang();
}

=begin pod

Compile a RakuAST blockoid capture to an executable C<Block>.

=end pod

=begin pod

Slang grammar role: C<template> and C<wrapper> routine declarators.

=end pod
our role TemplateGrammar {
	=begin pod

	Grammar rule for C<template name (sig) [traits] [when { }] do { }>.

	=end pod
	rule template-def($declarator) {
		:my $*BLOCK;
		<.enter-block-scope('Sub')>
		$<name>=<identifier>?
		[ '(' <signature> ')' ]?
		:my $*ALSO-TARGET := $*BLOCK;
		<trait($*BLOCK)>* :!s
		{ if $<signature> { $*BLOCK.replace-signature($<signature>.ast); } }
		[
			'when' <.ws> $<when-block>=<blockoid> <.ws>
		]?
		'do' <.ws> $<do-block>=<blockoid>
		<.leave-block-scope>
	}

	=begin pod

	Declare C<template> as a routine declarator keyword.

	=end pod
	token routine-declarator:sym<template> {
		'template'
		<.end-keyword>
		<template-def=.key-origin('template-def', 'template')>
	}

	=begin pod

	Grammar rule for C<wrapper TYPE { ... }>.

	=end pod
	rule wrapper-def($declarator) {
		:my $*BLOCK;
		<.enter-block-scope('Sub')>
		$<wrapper-type>=<wrapper-type>
		$<wrap-block>=<blockoid>
		<.leave-block-scope>
	}

	=begin pod

	Declare C<wrapper> as a routine declarator keyword.

	=end pod
	token routine-declarator:sym<wrapper> {
		'wrapper'
		<.end-keyword>
		<wrapper-def=.key-origin('wrapper-def', 'wrapper')>
	}

	=begin pod

	Allowed wrapper type names.

	=end pod
	token wrapper-type {
		'TRANSFORMER' | 'TEMPLATE_MATCHER' | 'TEMPLATE_ACTION'
	}
}

=begin pod

Slang actions role: compile templates and wrappers into registry entries.

=end pod
our role TemplateActions {
	=begin pod

	Attach parsed template definition AST to the current parse tree.

	=end pod
	method routine-declarator:sym<template>(Mu $/) {
		self.attach: $/, $<template-def>.ast;
	}

	=begin pod

	Build a L<Qwiratry::Template> from parsed template definition tokens.

	=end pod
	method template-def(Mu $/) {
		my $name = $<name>.defined ?? ~$<name> !! Nil;
		my $signature = $<signature>.defined ?? compiler.compile-signature($<signature>.ast) !! Nil;

		my $routine := $*BLOCK;
		if $name.defined {
			$routine.replace-name(RakuAST::Name.from-identifier("_q_tpl_$name"));
		}
		unless $<signature>.defined {
			$routine.replace-signature(compiler.implicit-template-signature);
		}
		unless $<do-block>.defined {
			die "{compiler.display-name($name)}: required 'do' block is missing. "
			~ "Syntax: template [name] [signature] [traits] when { ... } do { ... }";
		}
		$routine.replace-body($<do-block>.ast);
		self.attach: $/, $routine;

		my $do-block = compiler.compile-blockoid($<do-block>) // try $routine.meta-object;
		unless $do-block.defined {
			die "{compiler.display-name($name)}: required 'do' block could not be compiled.";
		}

		my $when-query = Nil;
		my $when-block = Nil;
		my $combine-when-query = False;
		if $<when-block>.defined {
			my %parts = extract.split-from-blockoid($<when-block>);
			if %parts<query>.defined {
				my $query-block = compiler.compile-block-expr(%parts<query>);
				$when-query = extract.from-when-block($query-block) if $query-block.defined;
				$when-block = %parts<predicate>:exists
					?? compiler.compile-block-expr(%parts<predicate>)
					!! Nil;
				$combine-when-query = %parts<predicate>:exists;
			}
			else {
				$when-block = compiler.compile-blockoid($<when-block>);
				$when-query = extract.from-when-block($when-block) if $when-block.defined;
				if $when-query.defined && extract.is-pure-navigation-when($when-block) {
					$when-block = Nil;
				}
			}
		}

		my %method-structure = compiler.transform-to-method(
			:$name, :$signature, :$when-block, :$do-block,
		);
		$when-block = %method-structure<where-constraint>;
		$do-block   = compiler.compile-rakuast-method(%method-structure) // $do-block;

		my $template = Template.new(
			:$name, :$signature, :$when-block, :$when-query,
			:$combine-when-query,
			:$do-block,
		);
		compiler.apply-traits($template, $routine);
		register-template($template);
	}

	=begin pod

	Attach parsed wrapper definition AST to the current parse tree.

	=end pod
	method routine-declarator:sym<wrapper>(Mu $/) {
		self.attach: $/, $<wrapper-def>.ast;
	}

	=begin pod

	Compile and register a wrapper block for the given wrapper type.

	=end pod
	method wrapper-def(Mu $/) {
		my $type = ~$<wrapper-type>;
		unless $type eq any(<TRANSFORMER TEMPLATE_MATCHER TEMPLATE_ACTION>) {
			die "Invalid wrapper type '$type'. "
			~ "Must be TRANSFORMER, TEMPLATE_MATCHER, or TEMPLATE_ACTION.";
		}
		my $routine := $*BLOCK;
		$routine.replace-name(RakuAST::Name.from-identifier("_q_wrap_$type"));
		unless $<wrap-block>.defined {
			die "Wrapper $type: required block is missing. Syntax: wrapper $type { ... }";
		}
		$routine.replace-body($<wrap-block>.ast);
		self.attach: $/, $routine;
		my $block = try $routine.meta-object // compiler.compile-blockoid($<wrap-block>);
		unless $block.defined {
			die "Wrapper $type: block could not be compiled.";
		}
		register-wrapper($type, $block);
	}
}

use Slangify TemplateGrammar, TemplateActions;

# Record activation once Slangify has run in the importer.
unless $activation-status.defined {
	$activation-status = slang-already-active() ?? 'slangify' !! 'slangify';
}
