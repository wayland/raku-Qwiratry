=begin pod

Compile RakuAST mold components into runtime blocks and structures.

=head1 Overview

This class is the bridge between the mold slang parser and the runtime
L<Qwiratry::Mold> objects stored in L<Qwiratry::Mold::Registry>. The slang
actions pass it captured RakuAST blockoids, signatures, and trait nodes; it
turns those pieces into executable C<Block> objects, runtime C<Signature>
objects, and mold metadata.

The compiler deliberately works with RakuAST objects rather than strings. Mold
C<when> and C<do> bodies are compiled in the current compilation context, so
they can close over lexical declarations from the user's transformer module.

=end pod
use v6.e.PREVIEW;
use Qwiratry::Mold;

class Qwiratry::Mold::Compiler {

	my $instance;

	=begin pod

	=head1 Methods

	=head2 C<instance()>

	=begin code
	method instance(--> Qwiratry::Mold::Compiler)
	=end code

	Returns the shared mold compiler instance.

	The compiler has no per-transformer state, so callers use this singleton from
	L<Qwiratry::Mold::Slang> actions instead of constructing a fresh helper for
	every parsed mold.

	=end pod
	method instance(--> Qwiratry::Mold::Compiler) {
		$instance //= self.new
	}

	=begin pod

	=head2 C<compile-blockoid(Mu $cap)>

	=begin code
	method compile-blockoid(Mu $cap)
	=end code

	=head3 Parameters

	=item C<$cap>

	 The grammar capture containing the blockoid AST to compile.


	Compiles a RakuAST blockoid capture to an executable C<Block>.

	C<$cap> is expected to be a capture produced by the slang grammar for a
	braced block such as C<when { ... }> or C<do { ... }>. The method extracts
	the blockoid AST and delegates to the private begin-time compiler. It returns
	C<Nil> when the capture is absent or cannot yield an AST.

	=end pod
	method compile-blockoid(Mu $cap) {
		$cap.defined or return Nil;
		my $body = try $cap.ast;
		$body.defined or return Nil;
		self!compile-block-body($body);
	}

	=begin pod

	=head2 C<compile-block-expr(Mu $expr)>

	=begin code
	method compile-block-expr(Mu $expr)
	=end code

	=head3 Parameters

	=item C<$expr>

	 The RakuAST expression to wrap as a one-statement block.


	Compiles a single expression as a one-statement block.

	This is used for split C<when> clauses where
	L<Qwiratry::Query::Extract> separates a navigation query expression from the
	remaining predicate expression. Wrapping the expression in a
	C<RakuAST::StatementList> gives the rest of the pipeline the same C<Block>
	shape as a normal braced block.

	=end pod
	method compile-block-expr(Mu $expr) {
		self!compile-block-body(RakuAST::StatementList.new(
			RakuAST::Statement::Expression.new(:expression($expr)),
		));
	}

	=begin pod

	=head2 C<implicit-mold-signature()>

	=begin code
	method implicit-mold-signature()
	=end code

	Builds the default C<$_> signature for molds without an explicit signature.

	Mold matchers are invoked with the current node as their topic. When the user
	writes C<mold name when { ... } do { ... }> with no parameter list, the slang
	rewrites the generated routine to this implicit signature so C<$_> is bound
	to that node.

	=end pod
	method implicit-mold-signature() {
		RakuAST::Signature.new(
			parameters => (
				RakuAST::Parameter.new(
					target => RakuAST::ParameterTarget::Var.new(name => '$_'),
					optional => False,
				),
			),
		);
	}

	=begin pod

	=head2 C<compile-signature($sig-ast)>

	=begin code
	method compile-signature($sig-ast)
	=end code

	=head3 Parameters

	=item C<$sig-ast>

	 The RakuAST signature node, or existing C<Signature>, to normalize for runtime use.


	Compiles a RakuAST signature node to a runtime C<Signature> object.

	The signature AST is installed on a stub C<RakuAST::Sub> and then inspected
	through its compile-time value. This lets the rest of Qwiratry store the
	actual runtime signature on the C<Mold>, not the parser object that produced
	it. Existing C<Signature> objects are returned unchanged.

	=end pod
	method compile-signature($sig-ast) {
		$sig-ast.defined or return Nil;
		$sig-ast ~~ Signature and return $sig-ast;
		my $stub := RakuAST::Sub.new(
			:signature($sig-ast),
			body => RakuAST::Blockoid.new(),
		);
		try $stub.compile-time-value.signature // Nil
	}

	=begin pod

	=head2 C<source-location(Mu $match)>

	=begin code
	method source-location(Mu $match)
	=end code

	=head3 Parameters

	=item C<$match>

	 The grammar match for the declaration being reported.


	Returns a C<line N, column M> label for a grammar match.

	The slang match gives character offsets into the original source text. Qwiratry
	stores a compact line/column label on compiled molds so anonymous declarations
	can still be identified in diagnostics.

	=end pod
	method source-location(Mu $match) {
		my $from = try $match.from;
		my $orig = try $match.orig;
		$from.defined && $orig.defined or return Nil;

		my $prefix = $orig.substr(0, $from);
		my $line = $prefix.comb("\n").elems + 1;
		my $last-newline = $prefix.rindex("\n");
		my $column = $last-newline.defined ?? $from - $last-newline !! $from + 1;
		"line $line, column $column";
	}

	=begin pod

	=head2 C<display-name($name, :$source-location)>

	=begin code
	method display-name($name, :$source-location)
	=end code

	=head3 Parameters

	=item C<$name>

	 The mold name or display name being normalized.

	=item C<$source-location>

	 Optional source location label for anonymous or named molds.


	Returns a human-readable label for error messages.

	Named molds are reported as C<mold NAME>; anonymous molds are reported as
	C<unnamed mold>. Slang actions use this for diagnostics when a required block
	is missing or cannot be compiled.

	=end pod
	method display-name($name, :$source-location) {
		my $label = $name.defined ?? "mold $name" !! "unnamed mold";
		$source-location.defined ?? "$label at $source-location" !! $label;
	}

	=begin pod

	=head2 C<apply-traits(Mold $mold, $routine)>

	=begin code
	method apply-traits(Mold $mold, $routine)
	=end code

	=head3 Parameters

	=item C<$mold>

	 The C<Mold> instance being registered, ordered, inspected, or copied.

	=item C<$routine>

	 The generated routine whose traits should be transferred onto the mold.


	Applies C<is streaming>, C<is priority>, C<is tie-breaker>, and C<returns>
	traits to a mold.

	C<$routine> is the generated RakuAST routine for the mold definition. The
	=begin code
	method reads its trait nodes and mutates the already-created C<Mold>:
	=end code
	C<is streaming> sets streaming mode, numeric priority and tie-breaker traits
	feed mold ordering, and C<returns(Type)> stores the expected result type for
	later runtime checking.

	=end pod
	method apply-traits(Mold $mold, $routine) {
		$routine.traits.defined or return;
		for $routine.traits -> $trait {
			if $trait ~~ RakuAST::Trait::Is {
				my $name = try $trait.name.simple-identifier // ~$trait.name;
				given $name {
					when 'streaming' { $mold.streaming = True }
					when 'priority' {
						$mold.priority = $trait.argument.defined
							?? +(~$trait.argument)
							!! 0;
					}
					when 'tie-breaker' {
						$mold.tie-breaker = $trait.argument.defined
							?? +(~$trait.argument)
							!! 0;
					}
				}
			}
			elsif $trait ~~ RakuAST::Trait::Returns {
				$mold.returns-type = try $trait.type.compile-time-value;
			}
		}
	}

	=begin pod

	=head2 C<!compile-block-body(Mu $body)>

	=begin code
	method !compile-block-body(Mu $body)
	=end code

	=head3 Parameters

	=item C<$body>

	 The RakuAST block or statement body to compile.


	Compiles a RakuAST statement list body to a C<Block> at begin time.

	The statement list is wrapped in C<RakuAST::Block>, lowered with
	C<to-begin-time>, and read back through its meta-object. This is the low-level
	operation behind C<compile-blockoid> and C<compile-block-expr>; failures are
	contained and reported as C<Nil> so slang actions can produce mold-specific
	error messages.

	=end pod
	method !compile-block-body(Mu $body) {
		my $block = RakuAST::Block.new(body => $body);
		try {
			$block.to-begin-time($*R, $*CU.context);
			my $code = $block.meta-object;
			$code.defined and return $code;
		}
		Nil
	}
}
