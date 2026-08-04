=begin pod

Shared Strategy hook dispatch for Walker iterators.

Encapsulates control-signal handling so concrete iterators (tree, table)
invoke C<before>, C<on-match>, C<after>, and C<should-follow> consistently
and update traversal state in a uniform way.

=end pod
use WalkCursor;
use Qwiratry::Context;
use Qwiratry::QueryMatch;
use Qwiratry::Strategy;
use Qwiratry::Strategy::ControlSignal;
use Qwiratry::Query::Runtime;

my constant query-runtime = Qwiratry::Query::Runtime.instance;

=begin pod

Mutable traversal flags updated by L<ControlSignal|Qwiratry::Strategy::ControlSignal> values.

=end pod
class Qwiratry::Strategy::TraversalState is export {
	has Bool $.stopped is rw = False;
	has Bool $.skip-expand is rw = False;

	=begin pod

	Apply a control signal and update stopped / skip-expand flags.

	=end pod
	method handle-signal(Mu $signal --> Mu) {
		$signal ~~ ControlSignal or return Nil;
		if $signal == STOP_TRAVERSAL {
			$!stopped = True;
			return STOP_TRAVERSAL;
		}
		if $signal == SKIP_ELEMENT {
			$!skip-expand = True;
			return SKIP_ELEMENT;
		}
		Nil
	}

	=begin pod

	Clear the skip-expand flag after processing an element's children.

	=end pod
	method clear-skip() {
		$!skip-expand = False;
	}

	=begin pod

	Return True when the current element's children should not be expanded.

	=end pod
	method should-skip-expand(--> Bool) {
		$!skip-expand;
	}
}

=begin pod

Singleton dispatcher for strategy hooks during walker traversal.

=end pod
class Qwiratry::Strategy::Traversal is export {
	my $instance;

	=begin pod

	Return the shared Traversal dispatcher instance.

	=end pod
	method instance(--> Qwiratry::Strategy::Traversal) {
		$instance //= self.new
	}

	method !accepts-cursor(Mu $obj, Str $method --> Bool) {
		for $obj.can($method) -> $m {
			for $m.signature.params -> $p {
				return True if $p.named && !$p.positional && (
					$p.usage-name eq 'cursor'
					|| ($p.slurpy && $p.name eq '%_')
				);
			}
		}
		False
	}

	method !call-hook(Strategy $strategy, Str $method, Capture $args, WalkCursor :$cursor --> Mu) {
		if $cursor.defined && self!accepts-cursor($strategy, $method) {
			return $strategy."$method"(|$args, :$cursor);
		}
		$strategy."$method"(|$args)
	}

	=begin pod

	Call C<strategy.finish> at the end of traversal and store the result on the context.

	=end pod
	method invoke-finish(Mu $root, Context $ctx, WalkCursor :$cursor --> Mu) {
		$ctx.strategy.defined or return;
		my $result = self!call-hook($ctx.strategy, 'finish', \($root, $ctx), |%(:$cursor if $cursor.defined));
		$ctx.can('finish-result') and $ctx.finish-result = $result;
		Nil
	}

	=begin pod

	Invoke C<strategy.before> for C<$element> and apply any returned control signal.

	=end pod
	method run-before(Mu $element, Context $ctx, Qwiratry::Strategy::TraversalState $state, WalkCursor :$cursor --> Mu) {
		$ctx.strategy.defined or return Nil;
		my $signal = self!call-hook($ctx.strategy, 'before', \($element, $ctx), |%(:$cursor if $cursor.defined));
		$ctx.can('before-calls') and $ctx.before-calls.push({ element => $element, signal => $signal });
		$state.handle-signal($signal);
	}

	=begin pod

	When C<$element> matches C<$query>, invoke C<strategy.on-match> and apply signals.

	=end pod
	method run-on-match(Mu $element, Mu $query, Mu $origin, Context $ctx, Qwiratry::Strategy::TraversalState $state, WalkCursor :$cursor --> Mu) {
		$ctx.strategy.defined or return Nil;
		query-runtime.node-matches($query, $element, :$origin) or return Nil;

		my $match = QueryMatch.new(:element($element), :query($query), :origin($origin));
		my $result = self!call-hook($ctx.strategy, 'on-match', \($element, $match, $ctx), |%(:$cursor if $cursor.defined));
		$ctx.can('on-match-calls') and $ctx.on-match-calls.push({ element => $element, result => $result });
		$state.handle-signal($result);
	}

	=begin pod

	Invoke C<strategy.after> for C<$element> and apply any returned control signal.

	=end pod
	method run-after(Mu $element, Context $ctx, Qwiratry::Strategy::TraversalState $state, WalkCursor :$cursor --> Mu) {
		$ctx.strategy.defined or return Nil;
		my $signal = self!call-hook($ctx.strategy, 'after', \($element, $ctx), |%(:$cursor if $cursor.defined));
		$ctx.can('after-calls') and $ctx.after-calls.push({ element => $element, signal => $signal });
		$state.handle-signal($signal);
	}

	=begin pod

	Delegate edge traversal to C<strategy.should-follow> when a strategy is present.

	=end pod
	method should-follow(Mu $origin, Str $relation, Mu $target, Context $ctx, WalkCursor :$cursor --> Bool) {
		$ctx.strategy.defined or return True;
		my $result = self!call-hook($ctx.strategy, 'should-follow', \($origin, $relation, $target, $ctx), |%(:$cursor if $cursor.defined));
		$ctx.can('should-follow-calls') and $ctx.should-follow-calls.push({ origin => $origin, target => $target, result => $result });
		$result
	}
}
