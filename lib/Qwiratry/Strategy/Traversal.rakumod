=begin pod

Shared Strategy hook dispatch for Walker iterators.

Encapsulates control-signal handling so concrete iterators (tree, table)
invoke C<before>, C<on-match>, C<after>, and C<should-follow> consistently
and update traversal state in a uniform way.

=end pod
use Qwiratry::Context;
use Qwiratry::QueryMatch;
use Qwiratry::Strategy::ControlSignal;
use Qwiratry::Query::Match;

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
		return Nil unless $signal ~~ ControlSignal;
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

	=begin pod

	Call C<strategy.finish> at the end of traversal and store the result on the context.

	=end pod
	method invoke-finish(Mu $root, Context $ctx --> Mu) {
		return unless $ctx.strategy.defined;
		$ctx.finish-result = $ctx.strategy.finish($root, $ctx)
			if $ctx.can('finish-result');
		Nil
	}

	=begin pod

	Invoke C<strategy.before> for C<$element> and apply any returned control signal.

	=end pod
	method run-before(Mu $element, Context $ctx, Qwiratry::Strategy::TraversalState $state --> Mu) {
		return Nil unless $ctx.strategy.defined;
		my $signal = $ctx.strategy.before($element, $ctx);
		$ctx.before-calls.push({ element => $element, signal => $signal })
			if $ctx.can('before-calls');
		$state.handle-signal($signal);
	}

	=begin pod

	When C<$element> matches C<$query>, invoke C<strategy.on-match> and apply signals.

	=end pod
	method run-on-match(Mu $element, Mu $query, Mu $origin, Context $ctx, Qwiratry::Strategy::TraversalState $state --> Mu) {
		return Nil unless $ctx.strategy.defined;
		return Nil unless node-matches($query, $element, :$origin);

		my $match = QueryMatch.new(:element($element), :query($query), :origin($origin));
		my $result = $ctx.strategy.on-match($element, $match, $ctx);
		$ctx.on-match-calls.push({ element => $element, result => $result })
			if $ctx.can('on-match-calls');
		$state.handle-signal($result);
	}

	=begin pod

	Invoke C<strategy.after> for C<$element> and apply any returned control signal.

	=end pod
	method run-after(Mu $element, Context $ctx, Qwiratry::Strategy::TraversalState $state --> Mu) {
		return Nil unless $ctx.strategy.defined;
		my $signal = $ctx.strategy.after($element, $ctx);
		$ctx.after-calls.push({ element => $element, signal => $signal })
			if $ctx.can('after-calls');
		$state.handle-signal($signal);
	}

	=begin pod

	Delegate edge traversal to C<strategy.should-follow> when a strategy is present.

	=end pod
	method should-follow(Mu $origin, Str $relation, Mu $target, Context $ctx --> Bool) {
		return True unless $ctx.strategy.defined;
		my $result = $ctx.strategy.should-follow($origin, $relation, $target, $ctx);
		$ctx.should-follow-calls.push({ origin => $origin, target => $target, result => $result })
			if $ctx.can('should-follow-calls');
		$result
	}
}
