=begin pod

Shared Strategy hook dispatch for Walker iterators.

Encapsulates control-signal handling so concrete iterators (tree, table)
invoke C<before>, C<on-match>, C<after>, and C<should-follow> consistently
and update traversal state in a uniform way.

=end pod
unit module Qwiratry::Strategy::Traversal;

use Qwiratry::Context;
use Qwiratry::QueryMatch;
use Qwiratry::Strategy::ControlSignal;
use Qwiratry::Query::Match;

=begin pod

Call C<strategy.finish> at the end of traversal and store the result on the context.

=end pod
sub invoke-finish(Mu $root, Context $ctx --> Mu) is export {
	return unless $ctx.strategy.defined;
	$ctx.finish-result = $ctx.strategy.finish($root, $ctx)
		if $ctx.can('finish-result');
	Nil
}

=begin pod

Invoke C<strategy.before> for C<$element> and apply any returned control signal.

=end pod
sub run-before(Mu $element, Context $ctx, %state --> Mu) is export {
	return Nil unless $ctx.strategy.defined;
	my $signal = $ctx.strategy.before($element, $ctx);
	$ctx.before-calls.push({ element => $element, signal => $signal })
		if $ctx.can('before-calls');
	handle-signal($signal, %state);
}

=begin pod

When C<$element> matches C<$query>, invoke C<strategy.on-match> and apply signals.

=end pod
sub run-on-match(Mu $element, Mu $query, Mu $origin, Context $ctx, %state --> Mu) is export {
	return Nil unless $ctx.strategy.defined;
	return Nil unless node-matches($query, $element, :$origin);

	my $match = QueryMatch.new(:element($element), :query($query), :origin($origin));
	my $result = $ctx.strategy.on-match($element, $match, $ctx);
	$ctx.on-match-calls.push({ element => $element, result => $result })
		if $ctx.can('on-match-calls');
	handle-signal($result, %state);
}

=begin pod

Invoke C<strategy.after> for C<$element> and apply any returned control signal.

=end pod
sub run-after(Mu $element, Context $ctx, %state --> Mu) is export {
	return Nil unless $ctx.strategy.defined;
	my $signal = $ctx.strategy.after($element, $ctx);
	$ctx.after-calls.push({ element => $element, signal => $signal })
		if $ctx.can('after-calls');
	handle-signal($signal, %state);
}

=begin pod

Delegate edge traversal to C<strategy.should-follow> when a strategy is present.

=end pod
sub should-follow(Mu $origin, Str $relation, Mu $target, Context $ctx --> Bool) is export {
	return True unless $ctx.strategy.defined;
	my $result = $ctx.strategy.should-follow($origin, $relation, $target, $ctx);
	$ctx.should-follow-calls.push({ origin => $origin, target => $target, result => $result })
		if $ctx.can('should-follow-calls');
	$result
}

=begin pod

Update traversal C<%state> from a L<ControlSignal|Qwiratry::Strategy::ControlSignal>.

=end pod
sub handle-signal(Mu $signal, %state --> Mu) is export {
	return Nil unless $signal ~~ ControlSignal;
	if $signal == STOP_TRAVERSAL {
		%state<stopped> = True;
		return STOP_TRAVERSAL;
	}
	if $signal == SKIP_ELEMENT {
		%state<skip-expand> = True;
		return SKIP_ELEMENT;
	}
	Nil
}

=begin pod

Return True when traversal has been stopped by C<STOP_TRAVERSAL>.

=end pod
sub stopped(%state --> Bool) is export {
	%state<stopped>:exists && %state<stopped>
}

=begin pod

Clear the skip-expand flag after processing an element's children.

=end pod
sub clear-skip(%state) is export {
	%state<skip-expand> = False;
}

=begin pod

Return True when the current element's children should not be expanded.

=end pod
sub skip-expand(%state --> Bool) is export {
	%state<skip-expand>:exists && %state<skip-expand>
}
