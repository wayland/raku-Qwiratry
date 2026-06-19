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

	    method instance(--> Qwiratry::Mold::Compiler)

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

	    method compile-blockoid(Mu $cap)

	Compiles a RakuAST blockoid capture to an executable C<Block>.

	C<$cap> is expected to be a capture produced by the slang grammar for a
	braced block such as C<when { ... }> or C<do { ... }>. The method extracts
	the blockoid AST and delegates to the private begin-time compiler. It returns
	C<Nil> when the capture is absent or cannot yield an AST.

	=end pod
	method compile-blockoid(Mu $cap) {
		return Nil unless $cap.defined;
		my $body = try $cap.ast;
		return Nil unless $body.defined;
		self!compile-block-body($body);
	}

	=begin pod

	=head2 C<compile-block-expr(Mu $expr)>

	    method compile-block-expr(Mu $expr)

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

	    method implicit-mold-signature()

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

	    method compile-signature($sig-ast)

	Compiles a RakuAST signature node to a runtime C<Signature> object.

	The signature AST is installed on a stub C<RakuAST::Sub> and then inspected
	through its compile-time value. This lets the rest of Qwiratry store the
	actual runtime signature on the C<Mold>, not the parser object that produced
	it. Existing C<Signature> objects are returned unchanged.

	=end pod
	method compile-signature($sig-ast) {
		return Nil unless $sig-ast.defined;
		return $sig-ast if $sig-ast ~~ Signature;
		my $stub := RakuAST::Sub.new(
			:signature($sig-ast),
			body => RakuAST::Blockoid.new(),
		);
		try $stub.compile-time-value.signature // Nil
	}

	=begin pod

	=head2 C<transform-to-method(:$name, :$signature, :$when-block, :$do-block)>

	    method transform-to-method(:$name, :$signature, :$when-block, :$do-block)

	Builds conceptual method structure from mold name, signature, and blocks.

	WP03 models a mold as a method-like unit: a name, an optional signature, a
	C<where>-style constraint from the C<when> block, and a body from the C<do>
	block. Today this structure is a hash consumed immediately by
	C<compile-rakuast-method>; keeping it explicit documents the transformation
	boundary between slang parsing and runtime mold construction.

	=end pod
	method transform-to-method(
		:$name,
		:$signature,
		:$when-block,
		:$do-block,
	) {
		%(
			name             => $name,
			signature        => $signature,
			where-constraint => $when-block,
			body             => $do-block,
			transformed      => True,
		)
	}

	=begin pod

	=head2 C<compile-rakuast-method(%method-structure)>

	    method compile-rakuast-method(%method-structure)

	Extracts the compiled do-block from transformed method structure.

	Returns the C<body> block only for structures produced by
	C<transform-to-method>. Invalid or untransformed hashes return C<Nil>, letting
	the caller fall back to the block it had already compiled.

	=end pod
	method compile-rakuast-method(%method-structure) {
		return Nil unless %method-structure<transformed>;
		%method-structure<body>
	}

	=begin pod

	=head2 C<display-name($name)>

	    method display-name($name)

	Returns a human-readable label for error messages.

	Named molds are reported as C<mold NAME>; anonymous molds are reported as
	C<unnamed mold>. Slang actions use this for diagnostics when a required block
	is missing or cannot be compiled.

	=end pod
	method display-name($name) {
		$name.defined ?? "mold $name" !! "unnamed mold"
	}

	=begin pod

	=head2 C<apply-traits(Mold $mold, $routine)>

	    method apply-traits(Mold $mold, $routine)

	Applies C<is streaming>, C<is priority>, C<is tie-breaker>, and C<returns>
	traits to a mold.

	C<$routine> is the generated RakuAST routine for the mold definition. The
	method reads its trait nodes and mutates the already-created C<Mold>:
	C<is streaming> sets streaming mode, numeric priority and tie-breaker traits
	feed mold ordering, and C<returns(Type)> stores the expected result type for
	later runtime checking.

	=end pod
	method apply-traits(Mold $mold, $routine) {
		return unless $routine.traits.defined;
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

	    method !compile-block-body(Mu $body)

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
			return $code if $code.defined;
		}
		Nil
	}
}
