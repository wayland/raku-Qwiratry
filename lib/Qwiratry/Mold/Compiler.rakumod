=begin pod

Compile RakuAST mold components into runtime blocks and structures.

Handles blockoid compilation, signature lowering, trait application, and
conceptual method transformation for molds parsed by L<Qwiratry::Mold::Slang>.

=end pod
use v6.e.PREVIEW;
use Qwiratry::Mold;

class Qwiratry::Mold::Compiler {

	my $instance;

	=begin pod

	Return the shared mold compiler instance.

	=end pod
	method instance(--> Qwiratry::Mold::Compiler) {
		$instance //= self.new
	}

	=begin pod

	Compile a RakuAST blockoid capture to an executable C<Block>.

	=end pod
	method compile-blockoid(Mu $cap) {
		return Nil unless $cap.defined;
		my $body = try $cap.ast;
		return Nil unless $body.defined;
		self!compile-block-body($body);
	}

	=begin pod

	Compile a single expression as a one-statement block.

	=end pod
	method compile-block-expr(Mu $expr) {
		self!compile-block-body(RakuAST::StatementList.new(
			RakuAST::Statement::Expression.new(:expression($expr)),
		));
	}

	=begin pod

	Default C<$_> signature for molds without an explicit signature.

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

	Compile a RakuAST signature node to a runtime C<Signature> object.

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

	Build conceptual method structure from mold name, signature, and blocks.

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

	Extract compiled do-block from transformed method structure.

	=end pod
	method compile-rakuast-method(%method-structure) {
		return Nil unless %method-structure<transformed>;
		%method-structure<body>
	}

	=begin pod

	Human-readable label for error messages.

	=end pod
	method display-name($name) {
		$name.defined ?? "mold $name" !! "unnamed mold"
	}

	=begin pod

	Apply C<is streaming>, C<is priority>, C<is tie-breaker>, and C<returns> traits to a mold.

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

	Compile a RakuAST statement list body to a C<Block> at begin time.

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
