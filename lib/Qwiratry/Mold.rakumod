=begin pod

=head1 Overview

Runtime representation of pattern-matching transformation rules.

A C<Mold> is the compiled form of a C<mold> declaration from
L<Qwiratry::Mold::Slang>. It combines a matcher (C<when> block and/or extracted
navigation query), an action (C<do> block), optional signature binding, and
ordering metadata used by L<Qwiratry::Transformer>.

Mold execution is also where the transformer dynamic variables are established:
C<$_>, C<$*CONTEXT>, C<$*MAKE-OUTPUT>, C<$*TRANSFORM-ROOT>, and related rewrite
state. That lets mold bodies look like ordinary Raku blocks while still
participating in Qwiratry's traversal and output protocol.

=end pod
unit module Qwiratry::Mold;

use X::Qwiratry;  # For X::Qwiratry::TypeCheck
use Qwiratry::Query::Runtime;
use Qwiratry::Tree::Replace;

my constant query-runtime = Qwiratry::Query::Runtime.instance;

=begin pod

Collector for C<make> calls during mold execution. When defined, C<make>
pushes values here instead of using the block's return value.

=end pod
our $*MAKE-OUTPUT is export;

=begin pod

Root data structure for the current C<TRANSFORM> pass. Used for parent lookup
during query matching when nodes do not provide a C<.parent> method.

=end pod
our $*TRANSFORM-ROOT is export;

=begin pod

Node currently being transformed. Set during C<APPLY> and C<TRANSFORM>.

=end pod
our $*TRANSFORM-NODE is export;

=begin pod

When True, C<make> replaces the current node in the transform tree.

=end pod
our $*TRANSFORM-REWRITE is export;

=begin pod

=head1 Functions

=head2 C<make(Mu $value)>

=begin code
sub make(Mu $value) is export
=end code

=head3 Parameters

=item C<$value>

 The value to emit as this mold action's result.


 Adds C<$value> to the current mold's output stream.

 C<make> is valid only while a mold action is running. If the active transformer
 is in tree-rewrite mode, C<make> also asks L<Qwiratry::Tree::Replace> to replace
 the current transform node under the current root. The value is returned so mold
 actions can use C<make> in expression position.

=end pod
sub make(Mu $value) is export {
	unless $*MAKE-OUTPUT.defined {
		X::Qwiratry::Walker.new(
			message => 'make() called outside mold execution',
			walker-type => 'Mold',
		).throw;
	}
	$*MAKE-OUTPUT.push($value);
	if $*TRANSFORM-REWRITE && $*TRANSFORM-NODE.defined && $*TRANSFORM-ROOT.defined {
		Qwiratry::Tree::Replace.instance.replace-node($*TRANSFORM-NODE, $value, $*TRANSFORM-ROOT);
	}
	$value;
}

=begin pod

=head1 Control Flow

C<NextMold.throw> raises L<X::Qwiratry::NextMold>, which tells
L<Qwiratry::Transformer.APPLY> to abandon the current mold action and continue
with the next matching mold.

=end pod
class NextMold is export {
	method throw(NextMold:U: ) {
		X::Qwiratry::NextMold.new(
			message => 'Continue to next matching mold',
			walker-type => 'Mold',
		).throw;
	}
}

=begin pod

=head1 Class

C<Mold> represents a match-and-action rule within a transformer.

Molds are ordered by priority, query specificity, and tie-breaker before
application. Named molds can also be installed as methods on the transformer
class, while anonymous molds participate only in traversal.

=head2 Example

=begin code
mold section() when { $_.name eq 'section' } do {
    make Node.new(name => $_.name);
}
=end code

=end pod
class Mold is export {
	# Optional mold name (makes mold callable as method on transformer)
	has Str $.name;

	=begin pod

	Source location of the mold declaration, usually C<line N, column M>.
	Used to identify anonymous molds in diagnostics.

	=end pod
	has Str $.source-location;
    
	# Optional mold signature (for parameters)
	has Signature $.signature;
    
	=begin pod
    
	Code block for matching nodes (mold matcher).
	Evaluated against each node during transformation.
	Returns True if mold should apply to this node.
    
	=end pod
	has Block $.when-block;
    
	=begin pod
    
	Code block for producing output (mold action).
	Executed when mold matches a node.
	Produces output via `make` or return value.
    
	=end pod
	has Block $.do-block;
    
	=begin pod
    
	Mold priority (from `:priority` trait, default 0).
	Higher priority molds are tried first.
    
	=end pod
	has Int $.priority = 0;
    
	=begin pod
    
	Calculated specificity score (cached after calculation).
	Higher specificity molds are tried first when priority is equal.
    
	=end pod
	has Int $.specificity;
    
	=begin pod
    
	Tie-breaker value (from `:tie-breaker` trait, default 0).
	Used to break ties when priority and specificity are equal.
    
	=end pod
	has Int $.tie-breaker = 0;
    
	=begin pod
    
	Whether mold has `:streaming` trait.
	Streaming molds can produce lazy iterators.
    
	=end pod
	has Bool $.streaming = False;
    
	=begin pod
    
	Output type constraint (from `returns(Type)` trait).
	Enforces the type of output returned by mold.
    
	=end pod
	has Mu $.returns-type;

	=begin pod

	Optional Query AST extracted from the C<when> clause for specificity calculation.

	=end pod
	has Mu $.when-query is rw;

	=begin pod

	When True, C<when-query> and C<when-block> are both required to match (mixed query
	+ predicate). When False, a defined C<when-block> alone controls matching and
	C<when-query> is used only for specificity ordering.

	=end pod
	has Bool $.combine-when-query = False;
    
	# Constructor
	submethod BUILD(
		:$name,
		:$source-location,
		:$signature,
		:$when-block,
		:$when-query,
		:$combine-when-query = False,
		:$!do-block!,
		:$!priority = 0,
		:$specificity,
		:$!tie-breaker = 0,
		:$!streaming = False,
		:$returns-type
	) {
		$name.defined and $!name = $name;
		$source-location.defined and $!source-location = $source-location;
		$signature.defined and $!signature = $signature;
		$when-block.defined and $!when-block = $when-block;
		$when-query.defined and $!when-query = $when-query;
		$!combine-when-query = $combine-when-query;
		$specificity.defined and $!specificity = $specificity;
		$returns-type.defined and $!returns-type = $returns-type;
	}
    
	=begin pod

	=head1 Methods

	=head2 C<display-name()>

	=begin code
	method display-name(--> Str)
	=end code

	Returns a diagnostic label for this mold.

	Named molds use their declaration name. Anonymous molds use C<unnamed mold>,
	with source location appended when available.

	=end pod
	method display-name(--> Str) {
		my $label = $!name // '<unnamed mold>';
		$!source-location.defined ?? "$label at $!source-location" !! $label;
	}

	=begin pod

	=head2 C<matches($node)>

	=begin code
	method matches($node --> Bool)
	=end code

	=head3 Parameters

	=item C<$node>

	 The current node or element being matched, transformed, copied, or replaced.


	Returns true when this mold applies to C<$node>.

	If the slang extracted a navigation query, the query is evaluated against the
	current transform root. For mixed query-plus-predicate molds, the query must
	match before the predicate block runs. Predicate failures are contained and
	reported as C<False>, keeping one bad matcher from aborting the whole mold
	ordering pass.

	=end pod
	method matches($node --> Bool) {
		my $origin = $*TRANSFORM-ROOT // $node;

		if $.combine-when-query && $!when-query.defined {
			query-runtime.when-query-matches($!when-query, $node, :$origin) or return False;
			return $!when-block.defined ?? self!evaluate-when-block($node) !! True;
		}

		if $!when-query.defined && !$!when-block.defined {
			return query-runtime.when-query-matches($!when-query, $node, :$origin);
		}

		if !$!when-block.defined {
			return True;
		}

		self!evaluate-when-block($node);
	}

	# Runs the when predicate with mold dynamic variables and turns failures into a non-match.
	method !evaluate-when-block($node --> Bool) {
		my $*MAKE-OUTPUT := Nil;
		try {
			return self!run-with-magic-variables(
				$node,
				{ ?self!invoke-block($!when-block, $node) },
				:setup-capture($!signature.defined),
			);
		}
		False;
	}

	# Establishes the dynamic context shared by when/do blocks before invoking user code.
	method !run-with-magic-variables($node, &code, :$context, :$setup-capture = False, :$make-output) {
		my $*CONTEXT = $context // $node;
		my $*MAKE-OUTPUT := $make-output if $make-output.defined;
		my $capture = self!capture-signature($node) if $setup-capture;
		my $*CAPTURE = $capture if $capture.defined;
		$/ = $capture if $capture.defined;
		code();
	}

	# Converts a signature parameter into the node field name it should bind.
	method !param-field-name($param --> Str) {
		my $name = $param.name;
		$name.=subst(/^ <[\$\@\%]> /, '');
		$name eq '_' ?? 'topic' !! $name;
	}

	# Builds the capture used for parameterized mold blocks from the current node.
	method !capture-signature($node) {
		$!signature.defined or return %();

		my @params = $!signature.params;
		if !@params || (@params == 1 && self!param-field-name(@params[0]) eq 'topic') {
			return %(topic => $node);
		}

		my @pos;
		my %named;
		for @params -> $param {
			next if $param.slurpy;
			my $field = self!param-field-name($param);
			if $param.named {
				my $val = self!extract-field($node, $field);
				next unless $val.defined;
				%named{$field} = $val;
			}
			elsif $field eq 'topic' {
				@pos.push($node);
			}
			else {
				my $val = self!extract-field($node, $field);
				next unless $val.defined;
				%named{$field} = $val;
				@pos.push($val);
			}
		}

		@pos == 0 and return %named;
		@pos and return %(|%named, pos => @pos);
		%named;
	}

	# Reads a field from topic, associative nodes, or method-like node objects.
	method !extract-field($node, $field) {
		$field eq 'topic' and return $node;
		if $node ~~ Associative {
			$node{$field}:exists and return $node{$field};
		}
		try {
			return $node."$field"();
		}
		Nil;
	}

	# Invokes an arity-zero block with the current node installed as the topic.
	method !invoke-arity0($node, &code) {
		if $node.defined {
			with $node { code() }
		}
		else {
			$node.&({ code() })
		}
	}

	# Dispatches a generic when/do block according to its declared arity.
	method !invoke-block($block, $node) {
		if $block.arity == 0 && $block.count == 0 {
			return self!invoke-arity0($node, { $block() });
		}
		$block.arity == 1 and return $block($node);
		$block($node);
	}

	# Runs the mold action, handling method blocks, transformer invocants, and captures.
	method !invoke-do-block($block, $node, $transformer, :$context, :$make-output) {
		my $mold = self;
		$mold!run-with-magic-variables(
			$node,
			{
				if $block ~~ Method {
					my $method-self;
					my $has-method-self = False;
					unless $transformer.defined {
						try {
							$method-self = $block.signature.params[0].type;
							$has-method-self = True;
						}
					}
					my $self = $transformer.defined
						?? $transformer
						!! ($has-method-self ?? $method-self !! $mold);
					if $block.arity <= 1 && $block.count <= 1 {
						$mold!invoke-arity0($node, { $block($self) });
					}
					elsif $block.arity >= 2 {
						$block($self, $node);
					}
					else {
						$block($self);
					}
				}
				elsif $block.arity == 0 && $block.count == 0 {
					$mold!invoke-arity0($node, { $block() });
				}
				elsif $block.arity == 1 {
					$block($node);
				}
				else {
					$block($node);
				}
			},
			:$context,
			:setup-capture(True),
			:$make-output,
		);
	}

	# Chooses make output over the block return value when the action emitted values.
	method !finalize-result($block-result, @make-output) {
		if @make-output {
			return @make-output.elems == 1 ?? @make-output[0] !! @make-output.List;
		}
		$block-result;
	}
    
	=begin pod

	=head2 C<execute($node, :$transformer, :$context)>

	=begin code
	method execute($node, :$transformer, :$context --> Mu)
	=end code

	=head3 Parameters

	=item C<$node>

	 The current node or element being matched, transformed, copied, or replaced.

	=item C<$transformer>

	 The transformer instance executing this mold, used for wrapper hooks and action
	 post-processing.

	=item C<$context>

	 Optional caller-provided traversal context.


	Executes the C<do> block for C<$node> and returns the transformation result.

	The method sets topic/context dynamic variables, prepares signature captures
	for parameterized molds, chooses the correct invocant for method-like blocks,
	and collects values emitted through C<make>. C<make> output wins over the
	block's return value; multiple C<make> calls become a list.

	When a transformer instance is supplied, mold-action wrappers and return-type
	checking are applied before the final result is returned.

	=end pod
	method execute($node, :$transformer, :$context --> Mu) {
		if !$!do-block.defined {
			return Nil;
		}

		my @make-output;
		my $result = self!invoke-do-block(
			$!do-block,
			$node,
			$transformer,
			:$context,
			:make-output(@make-output),
		);
		$result = self!finalize-result($result, @make-output);

		if $transformer.defined {
			try {
				$result = $transformer.WRAP_MOLD_ACTION($node, $result);
				CATCH {
					when X::Method::NotFound { }
				}
			}
		}

		if $!returns-type.WHICH ne Mu.WHICH {
			unless $result ~~ $!returns-type {
				X::Qwiratry::TypeCheck.new(
					expected => $!returns-type,
					got => $result.WHAT,
					message => "Mold result does not match returns type constraint"
				).throw;
			}
		}

		return $result;
	}
}
