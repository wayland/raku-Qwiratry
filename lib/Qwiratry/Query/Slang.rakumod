=begin pod

Query operator syntax entry point.

Re-exports L<Qwiratry::Query::Slang::Ops>. For universe operators and bare
navigation under C<given>, also load Topic B<after> this module:

=begin code
use Qwiratry::Query::Slang;
use Qwiratry::Query::Slang::Topic;
=end code

Infix categoricals from Ops must settle before Topic is mixed (RakuAST).

=end pod

use v6.e.PREVIEW;
need Qwiratry::Query::Slang::Ops;

sub EXPORT {
	Map.new(Qwiratry::Query::Slang::Ops::EXPORT::DEFAULT.WHO.pairs)
}
