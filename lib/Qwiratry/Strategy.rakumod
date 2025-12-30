=begin pod

Strategy role for element-level traversal behaviour

This module provides the Strategy role with hooks that are called
at key points during data traversal. Strategies are walker-agnostic
and reusable across different data models.

All hooks are optional - a class composing Strategy need not implement
all hooks. Undefined hooks use sensible default behaviour.

Hook Call Order:
  1. before($element, $ctx) - Pre-visit hook
  2. on-match($element, $match, $ctx) - Called when query matches
  3. should-follow($origin, $relation, $target, $ctx) - Decide to follow relation
  4. after($element, $ctx) - Post-visit hook
  5. finish($root, $ctx) - Called when traversal completes
  6. should-continue($root, $ctx) - Decide if another pass is needed

=end pod
unit module Qwiratry::Strategy;

use Qwiratry::Context;
use Qwiratry::Strategy::ControlSignal;
use Qwiratry::Strategy::RewriteSpec;
use Qwiratry::Strategy::FinishResult;

=begin pod

Role defining element-level traversal behaviour through hooks.

Strategies are walker-agnostic and reusable across data models.
They provide pluggable behaviour for element processing during traversal.
All hooks are optional; undefined hooks use default behaviour.

Example:
  class CollectingStrategy does Strategy {
      has @.results;
      method on-match($element, Match $match, Context $ctx) {
          @!results.push($element);
          NO_REWRITE
      }
  }

=end pod
role Strategy is export {
    
    =begin pod

    Called before visiting an element (pre-visit).

    This hook is called before processing an element and its relations.
    It can return a ControlSignal to control traversal:
      - NO_REWRITE: Continue normally
      - SKIP_ELEMENT: Skip this element and its relations
      - STOP_TRAVERSAL: Halt traversal immediately
      - Nil: Same as NO_REWRITE (default)

    @param $element - The element being visited
    @param $ctx - The Context for this traversal
    @returns ControlSignal|Nil - Traversal control signal, or Nil for default

    =end pod
    method before($element, Context $ctx) { Nil }
    
    =begin pod

    Called when a query matches an element.

    This hook is called when the query successfully matches an element.
    It can return:
      - ControlSignal: To control traversal (NO_REWRITE, SKIP_ELEMENT, STOP_TRAVERSAL)
      - RewriteSpec: To indicate the element was rewritten (future feature)
      - Nil: Continue normally (default)

    @param $element - The matched element
    @param $match - The Match object from the query
    @param $ctx - The Context for this traversal
    @returns ControlSignal|RewriteSpec|Nil - Traversal control or rewrite spec, or Nil for default

    =end pod
    method on-match($element, Match $match, Context $ctx) { Nil }
    
    =begin pod

    Decide whether to follow a relation to another element.

    This hook is called for each relation of an element to decide whether
    to traverse into the related element. Return False to prune this branch.

    @param $origin - The source element
    @param $relation - The relation name or identifier
    @param $target - The target element
    @param $ctx - The Context for this traversal
    @returns Bool - True to follow the relation, False to prune

    =end pod
    method should-follow($origin, $relation, $target, Context $ctx --> Bool) { True }
    
    =begin pod

    Called after visiting all relations of an element (post-visit).

    This hook is called after processing an element and all its relations.
    It can return:
      - ControlSignal: To control traversal (NO_REWRITE, SKIP_ELEMENT, STOP_TRAVERSAL)
      - RewriteSpec: To indicate the element was rewritten (future feature)
      - Nil: Continue normally (default)

    @param $element - The element that was visited
    @param $ctx - The Context for this traversal
    @returns ControlSignal|RewriteSpec|Nil - Traversal control or rewrite spec, or Nil for default

    =end pod
    method after($element, Context $ctx) { Nil }
    
    =begin pod

    Called after completing a full traversal.

    This hook is called once when the traversal completes (or is stopped).
    It should return a FinishResult containing the traversal outcome.

    @param $root - The root element of the traversal
    @param $ctx - The Context for this traversal
    @returns FinishResult - The traversal outcome

    =end pod
    method finish($root, Context $ctx --> FinishResult) {
        FinishResult.new(type => 'final-result', value => Nil)
    }
    
    =begin pod

    Decide whether to continue with another traversal pass.

    This hook is called after finish() to support fixed-point iteration.
    Return True to trigger another traversal pass. This enables multi-pass
    algorithms like iterative dataflow analysis or rewrite until stable.

    @param $root - The root element of the traversal
    @param $ctx - The Context for this traversal
    @returns Bool - True to continue with another pass, False to stop (default)

    =end pod
    method should-continue($root, Context $ctx --> Bool) { False }
}
