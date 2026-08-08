=begin pod

=head1 Overview

C<TypedIterator> extends core C<Iterator> with an element-type advertisement via
C<.of>, analogous to typed C<Array.of>.

Core C<Iterator> / C<Iterable> have no element-type API. Qwiratry uses this role
so adaptor operators can share one pull/sink surface and still tell text chunks
from (later) structured values without parallel C<read-rows> methods.

=item C<.of> returns a type object (C<Mu:U>). Default C<Mu> means unspecified /
heterogeneous: consumers inspect each pulled value.

=item Homogeneous producers SHOULD override C<.of> (File pull uses C<Str>).

=item C<TypedIterator::Wrapper> wraps an existing C<Iterator> with an C<.of>
when the producer does not implement C<TypedIterator> itself.

=item C<iterator-of($iter)> returns C<.of> for a C<TypedIterator>, else C<Mu>
(plain C<Iterator> is treated as untyped).

Design notes: L<docs/rakudoc/Developing/Qwiratry-TOP-Prerequisites.md> §5.3.

=end pod

use v6.e.PREVIEW;

=begin pod

Iterator that advertises a homogeneous (or unspecified) element type.

=end pod
role TypedIterator does Iterator is export {
	=begin pod

	=head2 C<of()>

	=begin code
	method of(--> Mu:U)
	=end code

	Element type for this stream. Default C<Mu> = untyped / per-element handling.

	=end pod
	method of(--> Mu:U) { Mu }
}

=begin pod

Concrete C<TypedIterator> that delegates pulls to an inner C<Iterator>.

Use when wrapping a foreign iterator; prefer a dedicated class that
C<does TypedIterator> when you own the pull logic.

=end pod
class TypedIterator::Wrapper does TypedIterator is export {
	has Mu:U $.of = Mu;
	has Iterator $!source;

	method new(Iterator:D $source, Mu:U :$of = Mu) {
		self.bless(:$of, :$source);
	}

	submethod BUILD(Mu:U :$!of = Mu, Iterator:D :$!source!) {}

	method pull-one() {
		$!source.pull-one
	}

	method skip-one() {
		$!source.skip-one
	}

	method is-lazy(--> Bool) {
		$!source.is-lazy
	}
}

=begin pod

Return C<$iterator.of> when it does C<TypedIterator>; otherwise C<Mu>.

=end pod
sub iterator-of(Iterator:D $iterator --> Mu:U) is export {
	$iterator ~~ TypedIterator ?? $iterator.of !! Mu
}

=begin pod

True when C<$of> is a type compatible with text-chunk streams (C<Str>).

C<Mu> is not text-homogeneous — callers must inspect elements.

=end pod
sub of-is-text(Mu:U $of --> Bool) is export {
	$of !=== Mu && $of ~~ Str
}
