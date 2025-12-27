=begin pod

ControlSignal enumeration for Strategy-Walker communication

ControlSignal enum values and their Walker behaviours:

=item C<NO_REWRITE> - Continue traversal normally, no changes to element
=item C<REWRITE_IMMEDIATE> - Element was rewritten in-place; continue with modified element
=item C<REWRITE_DEFERRED> - Schedule rewrite for after current pass; continue normally
=item C<SKIP_ELEMENT> - Do not visit this element's relations; move to next sibling
=item C<STOP_TRAVERSAL> - Halt traversal immediately; proceed to finish()
=item C<FINAL_RESULT> - Used by finish() hook to signal traversal complete

Signal Precedence (when Walker encounters multiple signals):
  STOP_TRAVERSAL > SKIP_ELEMENT > REWRITE_* > NO_REWRITE

These signals are returned from Strategy hooks (before, on-match, after)
to communicate traversal decisions back to the Walker.

=end pod
unit module Qwiratry::ControlSignal;

=begin pod

Enumeration of signals communicating Strategy decisions to Walker.
These signals control traversal behaviour and rewrite scheduling.

=end pod
enum ControlSignal is export <
    NO_REWRITE
    REWRITE_IMMEDIATE
    REWRITE_DEFERRED
    SKIP_ELEMENT
    STOP_TRAVERSAL
    FINAL_RESULT
>;
