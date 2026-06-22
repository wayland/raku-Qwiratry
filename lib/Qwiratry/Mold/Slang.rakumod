=begin pod

Mold slang for transformer bodies: registry, grammar, and Slangify activation.

Load this module in any compunit that uses C<mold> or C<wrapper> syntax
(the Slangify/Piersing pattern). Also load L<Qwiratry::Query::Slang> in the same
compunit when mold C<when> blocks use navigation operators (C<⪪>, C<⪪⪪>, etc.).

Mold syntax (Specification.md section 3.3.3):

=begin code
mold [name] [signature] [traits] when { ... } do { ... }
=end code

=head2 RakuAST implementation

- Components are extracted from RakuAST blockoid/signature nodes
- Molds are structured as conceptual methods: when = where constraint, do = body
- No string-based compilation or MONKEY-SEE-NO-EVAL

=end pod

# File-level compunit (no unit module): required for Slangify in the importer.
use v6.e.PREVIEW;
use Qwiratry::Mold;
use Qwiratry::Query::Slang;
use Qwiratry::Query::Extract;
use Qwiratry::Mold::Registry;
use Qwiratry::Mold::Compiler;

my constant registry = Qwiratry::Mold::Registry.instance;
my constant compiler = Qwiratry::Mold::Compiler.instance;
my constant extract = Qwiratry::Query::Extract.instance;

=begin pod

Slang activation method label recorded after Slangify runs (usually C<slangify>).

=end pod
our $SLANG-ACTIVATION-METHOD = 'slangify';

=begin pod

Collected L<Qwiratry::Mold> instances registered during transformer parsing.

=end pod
my $activation-status;

=begin pod

Register a compiled mold with the module-level collection.

=end pod
sub register-mold(Mold $mold) is export {
	registry.register-mold($mold);
}

=begin pod

Register a wrapper block of the given C<$type> (TRANSFORMER, MOLD_MATCHER, etc.).

=end pod
sub register-wrapper(Str $type, Block $block) is export {
	registry.register-wrapper($type, $block);
}

=begin pod

Return collected molds and clear the module-level list.

=end pod
sub get-collected-molds() is export {
	registry.collected-molds;
}

=begin pod

Clear the mold collection without returning it.

=end pod
sub clear-collected-molds() is export {
	registry.clear-molds;
}

=begin pod

Return collected wrappers and clear the module-level list.

=end pod
sub get-collected-wrappers() is export {
	registry.collected-wrappers;
}

=begin pod

Clear the wrapper collection without returning it.

=end pod
sub clear-collected-wrappers() is export {
	registry.clear-wrappers;
}

=begin pod

Return True when MAIN slang grammar is already the mold grammar.

=end pod
sub slang-already-active() {
	try {
		my $grammar-name = $*LANG.slang_grammar('MAIN').^name;
		return $grammar-name.contains('MoldGrammar');
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

Activate mold slang once and cache the activation status.

=end pod
sub activate-mold-slang() is export {
	$activation-status.defined and return $activation-status;
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

Ensure mold slang is activated (idempotent).

=end pod
sub attempt-slangify-activation() is export {
	activate-mold-slang();
}

=begin pod

Slang grammar role: C<mold> and C<wrapper> routine declarators.

=end pod
our role MoldGrammar {
	=begin pod

	Grammar rule for C<mold name (sig) [traits] [when { }] do { }>.

	=end pod
	rule mold-def($declarator) {
		:my $*BLOCK;
		<.enter-block-scope('Method')>
		$<name>=<mold-name>?
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

	token mold-name {
		<!before ['when'|'do'] <.end-keyword>>
		<identifier>
	}

	=begin pod

	Declare C<mold> as a routine declarator keyword.

	=end pod
	token routine-declarator:sym<mold> {
		'mold'
		<.end-keyword>
		<mold-def=.key-origin('mold-def', 'mold')>
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
		'TRANSFORMER' | 'MOLD_MATCHER' | 'MOLD_ACTION'
	}
}

=begin pod

Slang actions role: compile molds and wrappers into registry entries.

=end pod
our role MoldActions {
	=begin pod

	Attach parsed mold definition AST to the current parse tree.

	=end pod
	method routine-declarator:sym<mold>(Mu $/) {
		self.attach: $/, $<mold-def>.ast;
	}

	=begin pod

	Build a L<Qwiratry::Mold> from parsed mold definition tokens.

	=end pod
	method mold-def(Mu $/) {
		my $name = $<name>.defined ?? ~$<name> !! Nil;
		my $source-location = compiler.source-location($/);
		my $signature = $<signature>.defined ?? compiler.compile-signature($<signature>.ast) !! Nil;

		my $routine := $*BLOCK;
		$routine.replace-scope('my');
		if $name.defined {
			$routine.replace-name(RakuAST::Name.from-identifier("_q_mold_$name"));
		}
		unless $signature.defined && $signature.params.elems > 0 {
			$routine.replace-signature(compiler.implicit-mold-signature);
		}
		unless $<do-block>.defined {
			die "{compiler.display-name($name, :$source-location)}: required 'do' block is missing. "
			~ "Syntax: mold [name] [signature] [traits] when { ... } do { ... }";
		}
		$routine.replace-body($<do-block>.ast);
		self.attach: $/, $routine;

		my $do-block = try $routine.meta-object // compiler.compile-blockoid($<do-block>);
		unless $do-block.defined {
			die "{compiler.display-name($name, :$source-location)}: required 'do' block could not be compiled.";
		}

		my $when-query = Nil;
		my $when-block = Nil;
		my $combine-when-query = False;
		if $<when-block>.defined {
			my %parts = extract.split-from-blockoid($<when-block>);
			if %parts<query>.defined {
				my $query-block = compiler.compile-block-expr(%parts<query>);
				$query-block.defined and $when-query = extract.from-when-block($query-block);
				$when-block = %parts<predicate>:exists
					?? compiler.compile-block-expr(%parts<predicate>)
					!! Nil;
				$combine-when-query = %parts<predicate>:exists;
			}
			else {
				$when-block = compiler.compile-blockoid($<when-block>);
				$when-block.defined and $when-query = extract.from-when-block($when-block);
				if $when-query.defined && extract.is-pure-navigation-when($when-block) {
					$when-block = Nil;
				}
			}
		}

		my $mold = Mold.new(
			:$name, :$source-location, :$signature, :$when-block, :$when-query,
			:$combine-when-query,
			:$do-block,
		);
		compiler.apply-traits($mold, $routine);
		register-mold($mold);
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
		unless $type eq any(<TRANSFORMER MOLD_MATCHER MOLD_ACTION>) {
			die "Invalid wrapper type '$type'. "
			~ "Must be TRANSFORMER, MOLD_MATCHER, or MOLD_ACTION.";
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

use Slangify MoldGrammar, MoldActions;

# Record activation once Slangify has run in the importer.
unless $activation-status.defined {
	$activation-status = slang-already-active() ?? 'slangify' !! 'slangify';
}
