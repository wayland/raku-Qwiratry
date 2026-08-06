=begin pod

RakuAST Topic slang: inject lexical C<$_> into universe (and bare-nav) operator
applications so callees do not dig the caller topic via NQP.

Load B<after> L<Qwiratry::Query::Slang> (or L<Qwiratry::Query::Slang::Ops>) so
operator categoricals settle before this module mixes Topic actions into MAIN
via Slangify. RakuAST-capable Rakudo required (legacy grammar unsupported).

=begin code
use Qwiratry::Query::Slang;
use Qwiratry::Query::Slang::Topic;
=end code

=end pod

# Roles exported for Slangify from Query::Slang.
use v6.e.PREVIEW;

=begin pod

Empty grammar role — Actions-only rewrite of C<PREFIX-EXPR> / C<INFIX-EXPR>.

=end pod
our role TopicGrammar is export { }

=begin pod

Map universe infix glyphs to exported helper names in L<Qwiratry::Query::Slang>.

=end pod
my constant %UNIVERSE-INFIX = %(
	'⩃' => 'qwiratry-universe-nand',
	'⩂' => 'qwiratry-universe-nor',
	'⊙' => 'qwiratry-universe-xnor',
	'⊡' => 'qwiratry-universe-imply',
);

=begin pod

Universe complement prefix glyph.

=end pod
my constant $UNIVERSE-PREFIX = '∁';

=begin pod

Bare navigation prefix glyphs → helper names (LHS = lexical C<$_>).

=end pod
my constant %BARE-NAV-PREFIX = %(
	'⪪' => 'qwiratry-bare-child',
	'⪫' => 'qwiratry-bare-parent',
	'⪪⪪' => 'qwiratry-bare-descendant',
	'⪫⪫' => 'qwiratry-bare-ancestor',
	'⪨' => 'qwiratry-bare-following-sibling',
	'⪩' => 'qwiratry-bare-preceding-sibling',
	'⪨⪨' => 'qwiratry-bare-following',
	'⪩⪩' => 'qwiratry-bare-preceding',
	'⥷' => 'qwiratry-bare-attribute',
);

sub topic-var() {
	RakuAST::Var::Lexical.new('$_')
}

sub op-string(Mu $opish --> Str) {
	return '' unless $opish.defined;
	try {
		my $o = $opish.operator;
		return $o if $o ~~ Str;
		return ~$o;
	}
	try return ~$opish;
	''
}

sub call-helper(Str $name, *@arg-asts) {
	RakuAST::Call::Name.new(
		name => RakuAST::Name.from-identifier($name),
		args => RakuAST::ArgList.new(|@arg-asts),
	)
}

=begin pod

Slang actions: rewrite universe and bare-nav applications to pass lexical C<$_>.

=end pod
our role TopicActions is export {
	=begin pod

	Rewrite universe C<∁> and bare navigation prefixes to helper calls with C<$_>.

	=end pod
	method PREFIX-EXPR(Mu $/) {
		my $core = callsame;
		my $ast = $/.ast;
		return $core unless $ast.defined && $ast ~~ RakuAST::ApplyPrefix;
		my $op = op-string($ast.prefix);

		if $op eq $UNIVERSE-PREFIX {
			my $rewritten = call-helper('qwiratry-universe-complement', $ast.operand, topic-var());
			self.attach: $/, $rewritten;
			return $rewritten;
		}

		if %BARE-NAV-PREFIX{$op}:exists {
			my $rewritten = call-helper(%BARE-NAV-PREFIX{$op}, topic-var(), $ast.operand);
			self.attach: $/, $rewritten;
			return $rewritten;
		}

		$core
	}

	=begin pod

	Rewrite universe infixes to helper calls with C<$_> as C<$universe>.

	=end pod
	method INFIX-EXPR(Mu $/) {
		my $core = callsame;
		my $ast = $/.ast;
		return $core unless $ast.defined && $ast ~~ RakuAST::ApplyInfix;
		my $op = op-string($ast.infix);
		return $core unless %UNIVERSE-INFIX{$op}:exists;
		my $rewritten = call-helper(
			%UNIVERSE-INFIX{$op},
			$ast.left,
			$ast.right,
			topic-var(),
		);
		self.attach: $/, $rewritten;
		$rewritten
	}

	=begin pod

	Lower C<given> through C<qwiratry-given-topic> so C<$*QWIRATRY-TOPIC> is visible
	to C<query-ast> (lexical C<$_> from C<given> is not reliably diggable under
	C<subtest>).

	=end pod
	method statement-control:sym<given>(Mu $/) {
		my $core = callsame;
		my $ast = $/.ast;
		return $core unless $ast.defined && $ast ~~ RakuAST::Statement::Given;
		my $rewritten = RakuAST::Statement::Expression.new(
			expression => call-helper('qwiratry-given-topic', $ast.source, $ast.body),
		);
		self.attach: $/, $rewritten;
		$rewritten
	}
}

use Slangify TopicGrammar, TopicActions;
