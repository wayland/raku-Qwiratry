=begin pod

ControlSignal enumeration for Strategy–Walker communication.

Strategy hooks (C<before>, C<on-match>, C<after>) return these values to tell
the walker whether to continue, skip, rewrite, or stop. Signal precedence when
multiple apply: C<STOP_TRAVERSAL> > C<SKIP_ELEMENT> > rewrite signals > C<NO_REWRITE>.

=end pod
unit module Qwiratry::Strategy::ControlSignal;

=begin pod

Enumeration of traversal control signals returned from Strategy hooks.

=item C<NO_REWRITE> — continue normally
=item C<REWRITE_IMMEDIATE> — element rewritten in place; continue with new value
=item C<REWRITE_DEFERRED> — schedule rewrite after current pass
=item C<SKIP_ELEMENT> — do not expand this element's children
=item C<STOP_TRAVERSAL> — halt and proceed to C<finish>
=item C<FINAL_RESULT> — used by C<finish> to signal completion

=end pod
enum ControlSignal is export <
	NO_REWRITE
	REWRITE_IMMEDIATE
	REWRITE_DEFERRED
	SKIP_ELEMENT
	STOP_TRAVERSAL
	FINAL_RESULT
>;
