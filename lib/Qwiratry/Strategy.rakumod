=begin pod

=head1 Overview

Strategy role for element-level traversal behaviour.

Strategies are walker-agnostic hook collections. A walker calls them while
traversing data so user code can observe matches, prune traversal, stop early,
accumulate results, or request future rewrite behavior. All hooks are optional;
the defaults continue traversal and return an empty final result.

The usual hook order is C<before>, C<on-match>, C<should-follow>, C<after>,
C<finish>, then C<should-continue>. Concrete walkers may skip hooks that do not
apply to their domain, but they share the same L<Qwiratry::Context> through a
single traversal.

=head1 Hook Call Order

For walkers that support the full traversal lifecycle, hooks are called in this
order:

=item C<before($element, $ctx)>: pre-visit hook for the element.

=item C<on-match($element, $match, $ctx)>: called when the query matches.

=item C<should-follow($origin, $relation, $target, $ctx)>: decides whether to
 follow a relation.

=item C<after($element, $ctx)>: post-visit hook for the element.

=item C<finish($root, $ctx)>: called when traversal completes or stops.

=item C<should-continue($root, $ctx)>: decides whether another pass is needed.

=head1 Control Signals

Hooks that return traversal control values use
L<Qwiratry::Strategy::ControlSignal>:

=item C<NO_REWRITE>

 Continue normally.

=item C<SKIP_ELEMENT>

 Skip this element's expansion or relations.

=item C<STOP_TRAVERSAL>

 Halt traversal and proceed to C<finish>.

=item C<REWRITE_IMMEDIATE> and C<REWRITE_DEFERRED>

 Reserved rewrite signals for walkers that support rewrite specifications.

=item C<Nil>

 Same as the default continue behavior for hooks whose return value is optional.

 C<RewriteSpec> values are separate from control signals. A control signal says
 what traversal should do next; a rewrite spec carries an edit payload.

=end pod
unit module Qwiratry::Strategy;

use Qwiratry::Context;
use Qwiratry::Strategy::ControlSignal;
use Qwiratry::Strategy::RewriteSpec;
use Qwiratry::Strategy::FinishResult;
use Qwiratry::QueryMatch;

=begin pod

=head1 Role

C<Strategy> defines traversal hooks. Compose it into a class and override only
the methods needed for the analysis or transform.

=head2 Example

=begin code
class CollectingStrategy does Strategy {
    has @.results;
    method on-match($element, QueryMatch $match, Context $ctx) {
        @!results.push($element);
        NO_REWRITE
    }
}
=end code

=end pod
role Strategy is export {
    
	=begin pod

	=head1 Methods

	=head2 C<before($element, Context $ctx)>

	=begin code
	method before($element, Context $ctx)
	=end code

	=head3 Parameters

	=item C<$element>

	 The element about to be visited.

	=item C<$ctx>

	 The context shared by this traversal, including walker state and the active
	 strategy.

	Called before visiting an element.

	=head3 Return Value

	=item C<NO_REWRITE>

	Continue normally.

	=item C<SKIP_ELEMENT>

	Skip this element's expansion or relations.

	=item C<STOP_TRAVERSAL>

	Halt traversal and proceed to C<finish>.

	=item C<Nil>

	Use the default continue behavior.

	=end pod
	method before($element, Context $ctx) { Nil }
    
	=begin pod

	=head2 C<on-match($element, QueryMatch $match, Context $ctx)>

	=begin code
	method on-match($element, QueryMatch $match, Context $ctx)
	=end code

	=head3 Parameters

	=item C<$element>

	 The element matched by the active query.

	=item C<$match>

	 The match record, including the matched query, origin, and optional path.

	=item C<$ctx>

	 The shared traversal context.

	Called when the active query matches C<$element>.

	The C<QueryMatch> records the matched element, query fragment, origin, and
	optional path. Return a C<ControlSignal> to control traversal, a C<RewriteSpec>
	to describe a rewrite, or C<Nil> to continue normally.

	=head3 Return Value

	=item C<ControlSignal>

	Controls traversal, for example C<NO_REWRITE>, C<SKIP_ELEMENT>, or
	C<STOP_TRAVERSAL>.

	=item C<RewriteSpec>

	Describes a rewrite for walkers that support rewrite specifications.

	=item C<Nil>

	Continue normally.

	=end pod
	method on-match($element, QueryMatch $match, Context $ctx) { Nil }
    
	=begin pod

	=head2 C<should-follow($origin, $relation, $target, Context $ctx)>

	=begin code
	method should-follow($origin, $relation, $target, Context $ctx --> Bool)
	=end code

	=head3 Parameters

	=item C<$origin>

	 The source element for the relation.

	=item C<$relation>

	 The relation name or domain-specific relation identifier.

	=item C<$target>

	 The element that would be visited next.

	=item C<$ctx>

	 The shared traversal context.

	Returns whether traversal should follow a relation from C<$origin> to
	C<$target>.

	Tree walkers use relation labels such as C<child>; other walkers can use
	domain-specific labels. Return C<False> to prune that branch.

	=head3 Return Value

	Return C<True> to follow the relation, or C<False> to prune that branch.

	=end pod
	method should-follow($origin, $relation, $target, Context $ctx --> Bool) { True }
    
	=begin pod

	=head2 C<after($element, Context $ctx)>

	=begin code
	method after($element, Context $ctx)
	=end code

	=head3 Parameters

	=item C<$element>

	 The element whose post-visit phase is running.

	=item C<$ctx>

	 The shared traversal context.

	Called after visiting an element and its followed relations.

	Return a C<ControlSignal> to control traversal, a C<RewriteSpec> to describe
	a rewrite, or C<Nil> to continue normally.

	=head3 Return Value

	=item C<ControlSignal>

	Controls traversal after post-visit processing.

	=item C<RewriteSpec>

	Describes a rewrite for walkers that support rewrite specifications.

	=item C<Nil>

	Continue normally.

	=end pod
	method after($element, Context $ctx) { Nil }
    
	=begin pod

	=head2 C<finish($root, Context $ctx)>

	=begin code
	method finish($root, Context $ctx --> FinishResult)
	=end code

	=head3 Parameters

	=item C<$root>

	 The root element for the traversal.

	=item C<$ctx>

	 The final shared context for the traversal.

	Called once when traversal completes or is stopped.

	Return a L<Qwiratry::Strategy::FinishResult> with any aggregate or diagnostic
	value the strategy wants to expose.

	=head3 Return Value

	Returns a C<FinishResult> describing the traversal outcome.

	=end pod
	method finish($root, Context $ctx --> FinishResult) {
		FinishResult.new(type => 'final-result', value => Nil)
	}
    
	=begin pod

	=head2 C<should-continue($root, Context $ctx)>

	=begin code
	method should-continue($root, Context $ctx --> Bool)
	=end code

	=head3 Parameters

	=item C<$root>

	 The root element for the traversal.

	=item C<$ctx>

	 The shared context after the last pass.

	Called after C<finish> to support multi-pass strategies.

	Return C<True> to request another traversal pass, for example for fixed-point
	analysis or rewrite-until-stable algorithms.

	=head3 Return Value

	Returns C<True> to continue with another pass, or C<False> to stop.

	=end pod
	method should-continue($root, Context $ctx --> Bool) { False }
}
