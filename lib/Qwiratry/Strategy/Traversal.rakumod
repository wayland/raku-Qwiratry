=begin pod

Shared Strategy hook dispatch for Walker iterators.

=end pod
use Qwiratry::Context;
use Qwiratry::QueryMatch;
use Qwiratry::Strategy::ControlSignal;
use Qwiratry::Query::Match;

class Qwiratry::Strategy::TraversalState is export {
	has Bool $.stopped is rw = False;
	has Bool $.skip-expand is rw = False;

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

	method clear-skip() {
		$!skip-expand = False;
	}

	method should-skip-expand(--> Bool) {
		$!skip-expand;
	}
}

class Qwiratry::Strategy::Traversal is export {
	my $instance;

	method instance(--> Qwiratry::Strategy::Traversal) {
		$instance //= self.new
	}

	method invoke-finish(Mu $root, Context $ctx --> Mu) {
		return unless $ctx.strategy.defined;
		$ctx.finish-result = $ctx.strategy.finish($root, $ctx)
			if $ctx.can('finish-result');
		Nil
	}

	method run-before(Mu $element, Context $ctx, Qwiratry::Strategy::TraversalState $state --> Mu) {
		return Nil unless $ctx.strategy.defined;
		my $signal = $ctx.strategy.before($element, $ctx);
		$ctx.before-calls.push({ element => $element, signal => $signal })
			if $ctx.can('before-calls');
		$state.handle-signal($signal);
	}

	method run-on-match(Mu $element, Mu $query, Mu $origin, Context $ctx, Qwiratry::Strategy::TraversalState $state --> Mu) {
		return Nil unless $ctx.strategy.defined;
		return Nil unless node-matches($query, $element, :$origin);

		my $match = QueryMatch.new(:element($element), :query($query), :origin($origin));
		my $result = $ctx.strategy.on-match($element, $match, $ctx);
		$ctx.on-match-calls.push({ element => $element, result => $result })
			if $ctx.can('on-match-calls');
		$state.handle-signal($result);
	}

	method run-after(Mu $element, Context $ctx, Qwiratry::Strategy::TraversalState $state --> Mu) {
		return Nil unless $ctx.strategy.defined;
		my $signal = $ctx.strategy.after($element, $ctx);
		$ctx.after-calls.push({ element => $element, signal => $signal })
			if $ctx.can('after-calls');
		$state.handle-signal($signal);
	}

	method should-follow(Mu $origin, Str $relation, Mu $target, Context $ctx --> Bool) {
		return True unless $ctx.strategy.defined;
		my $result = $ctx.strategy.should-follow($origin, $relation, $target, $ctx);
		$ctx.should-follow-calls.push({ origin => $origin, target => $target, result => $result })
			if $ctx.can('should-follow-calls');
		$result
	}
}
