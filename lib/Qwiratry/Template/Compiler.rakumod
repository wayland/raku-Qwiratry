=begin pod

Compile RakuAST template components into runtime blocks and structures.

=end pod
use v6.e.PREVIEW;
use Qwiratry::Template;

unit class Qwiratry::Template::Compiler;

my $instance;

method instance(--> Qwiratry::Template::Compiler) {
	$instance //= self.new
}

method compile-blockoid(Mu $cap) {
	return Nil unless $cap.defined;
	my $body = try $cap.ast;
	return Nil unless $body.defined;
	self!compile-block-body($body);
}

method compile-block-expr(Mu $expr) {
	self!compile-block-body(RakuAST::StatementList.new(
		RakuAST::Statement::Expression.new(:expression($expr)),
	));
}

method implicit-template-signature() {
	RakuAST::Signature.new(
		parameters => (
			RakuAST::Parameter.new(
				target => RakuAST::ParameterTarget::Var.new(name => '$_'),
				optional => False,
			),
		),
	);
}

method compile-signature($sig-ast) {
	return Nil unless $sig-ast.defined;
	return $sig-ast if $sig-ast ~~ Signature;
	my $stub := RakuAST::Sub.new(
		:signature($sig-ast),
		body => RakuAST::Blockoid.new(),
	);
	try $stub.compile-time-value.signature // Nil
}

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

method compile-rakuast-method(%method-structure) {
	return Nil unless %method-structure<transformed>;
	%method-structure<body>
}

method display-name($name) {
	$name.defined ?? "template $name" !! "unnamed template"
}

method apply-traits(Template $template, $routine) {
	return unless $routine.traits.defined;
	for $routine.traits -> $trait {
		if $trait ~~ RakuAST::Trait::Is {
			my $name = try $trait.name.simple-identifier // ~$trait.name;
			given $name {
				when 'streaming' { $template.streaming = True }
				when 'priority' {
					$template.priority = $trait.argument.defined
						?? +(~$trait.argument)
						!! 0;
				}
				when 'tie-breaker' {
					$template.tie-breaker = $trait.argument.defined
						?? +(~$trait.argument)
						!! 0;
				}
			}
		}
		elsif $trait ~~ RakuAST::Trait::Returns {
			$template.returns-type = try $trait.type.compile-time-value;
		}
	}
}

method !compile-block-body(Mu $body) {
	my $block = RakuAST::Block.new(body => $body);
	try {
		$block.to-begin-time($*R, $*CU.context);
		my $code = $block.meta-object;
		return $code if $code.defined;
	}
	Nil
}
