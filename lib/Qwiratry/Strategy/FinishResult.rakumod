=begin pod

=head1 Overview

Result object for L<Qwiratry::Strategy.finish> hook outcomes.

Walkers invoke C<finish> when traversal completes or is stopped. Strategies use
C<FinishResult> to return a typed outcome and optional payload without requiring
walkers to know the shape of strategy-specific results.

=end pod
unit module Qwiratry::Strategy::FinishResult;

=begin pod

=head1 Class

=begin code
my $result = FinishResult.new(type => 'final-result', value => $data);
=end code

C<type> is a strategy-defined label, while C<value> can hold any final aggregate,
diagnostic object, or C<Nil>.

=head1 Usage

=begin code
my $result = FinishResult.new(type => 'final-result', value => $data);
say $result.gist;
=end code

=end pod
class FinishResult is export {
	has Str $.type is required;
	has $.value;

	=begin pod

	=head1 Methods

	=head2 C<gist()>

	=begin code
	method gist(--> Str)
	=end code

	Returns a human-readable representation for logs and tests.

	=end pod
	method gist(--> Str) {
		"FinishResult(type: $.type, value: {$.value.gist})"
	}
}
