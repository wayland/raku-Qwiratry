=begin pod

Mold class for pattern-matching transformation rules

This module provides the Mold class that represents individual
transformation rules within a Transformer. Molds consist of
a `when` block (matcher) and a `do` block (action), along with
metadata for ordering (priority, specificity, tie-breaker).

=end pod
unit module Qwiratry::Mold;

use X::Qwiratry;  # For X::Qwiratry::TypeCheck
use Qwiratry::Query::Match;
use Qwiratry::Tree::Replace;

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

Add a value to the current mold's output stream.

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

Skip the current mold action and continue with the next matching mold.

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

Mold class representing a match-and-action rule within a Transformer.

Molds define how nodes are selected (via `when` block) and transformed
(via `do` block). Molds are ordered by priority → specificity → tie-breaker
to determine which mold applies when multiple could match.

Example:
  mold section() when { $_.name eq 'section' } do {
      make Node.new(name => $_.name);
  }

=end pod
class Mold is export {
	# Optional mold name (makes mold callable as method on transformer)
	has Str $.name;
    
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
		$!name = $name if $name.defined;
		$!signature = $signature if $signature.defined;
		$!when-block = $when-block if $when-block.defined;
		$!when-query = $when-query if $when-query.defined;
		$!combine-when-query = $combine-when-query;
		$!specificity = $specificity if $specificity.defined;
		$!returns-type = $returns-type if $returns-type.defined;
	}
    
	=begin pod

	Evaluates `when` block against node, returns True if matches.

	Sets magic variables ($*CONTEXT, $_) before evaluating the when block.
	Handles errors gracefully by returning False if evaluation fails.

	@param $node - Node to match against
	@returns Bool - True if mold matches node

	=end pod
	method matches($node --> Bool) {
		my $origin = $*TRANSFORM-ROOT // $node;

		if $.combine-when-query && $!when-query.defined {
			return False unless when-query-matches($!when-query, $node, :$origin);
			return $!when-block.defined ?? self!evaluate-when-block($node) !! True;
		}

		if $!when-query.defined && !$!when-block.defined {
			return when-query-matches($!when-query, $node, :$origin);
		}

		if !$!when-block.defined {
			return True;
		}

		self!evaluate-when-block($node);
	}

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

	method !run-with-magic-variables($node, &code, :$context, :$setup-capture = False, :$make-output) {
		my $*CONTEXT = $context // $node;
		my $*MAKE-OUTPUT := $make-output if $make-output.defined;
		my $capture = self!capture-signature($node) if $setup-capture;
		my $*CAPTURE = $capture if $capture.defined;
		$/ = $capture if $capture.defined;
		code();
	}

	method !param-field-name($param --> Str) {
		my $name = $param.name;
		$name.=subst(/^\$/, '');
		$name.=subst(/^\@/, '');
		$name.=subst(/^\%/, '');
		$name eq '_' ?? 'topic' !! $name;
	}

	method !capture-signature($node) {
		return %() unless $!signature.defined;

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

		return %named if @pos == 0;
		return %(|%named, pos => @pos) if @pos;
		%named;
	}

	method !extract-field($node, $field) {
		return $node if $field eq 'topic';
		if $node ~~ Associative {
			return $node{$field} if $node{$field}:exists;
		}
		try {
			return $node."$field"();
		}
		Nil;
	}

	method !invoke-arity0($node, &code) {
		if $node.defined {
			with $node { code() }
		}
		else {
			$node.&({ code() })
		}
	}

	method !invoke-block($block, $node) {
		if $block.arity == 0 && $block.count == 0 {
			return self!invoke-arity0($node, { $block() });
		}
		return $block($node) if $block.arity == 1;
		$block($node);
	}

	method !invoke-do-block($block, $node, $transformer, :$context, :$make-output) {
		my $mold = self;
		$mold!run-with-magic-variables(
			$node,
			{
				if $block ~~ Method && $transformer.defined {
					if $block.arity == 0 && $block.count == 0 {
						$mold!invoke-arity0($node, { $block($transformer) });
					}
					elsif $block.arity >= 1 {
						$block($transformer, $node);
					}
					else {
						$block($transformer);
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

	method !finalize-result($block-result, @make-output) {
		if @make-output {
			return @make-output.elems == 1 ?? @make-output[0] !! @make-output.List;
		}
		$block-result;
	}
    
	=begin pod

	Executes `do` block with magic variables set, returns result.

	Sets all magic variables ($*CONTEXT, $_, $*CAPTURE, $/, self) before
	executing the do block. Handles both `make` calls and return values.

	@param $node - Node to transform
	@param :$transformer - Transformer instance (for self reference)
	@param :$context - Optional context (defaults to $node)
	@returns Iterator|Mu|List|Nil - Transformation result

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
