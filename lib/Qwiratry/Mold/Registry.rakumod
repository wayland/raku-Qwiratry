=begin pod

=head1 Overview

Collect molds and wrappers registered during transformer parsing.

The mold slang parses C<mold> and C<wrapper> declarations while the transformer
class is still being composed. This registry is the short-lived handoff point
between those slang actions and L<Qwiratry::Transformer>: actions push compiled
L<Qwiratry::Mold> objects and wrapper blocks here, and the transformer HOW drains
the lists when the class is finalized.

The storage is intentionally process-local and drain-on-read. It is not a
runtime catalog of all molds; it is a compile-time staging area for the current
transformer definition.

=end pod
use Qwiratry::Mold;

class Qwiratry::Mold::Registry {

	my $instance;

	=begin pod

	=head1 Methods

	=head2 C<instance()>

	=begin code
	method instance(--> Qwiratry::Mold::Registry)
	=end code

	Returns the shared mold registry instance.

	The slang and transformer code use a singleton so independent grammar action
	objects can write to the same staging area during one compilation pass.

	=end pod
	method instance(--> Qwiratry::Mold::Registry) {
		$instance //= self.new
	}

	has @!molds;
	has @!wrappers;

	=begin pod

	=head2 C<register-mold(Mold $mold)>

	=begin code
	method register-mold(Mold $mold)
	=end code

	=head3 Parameters

	=item C<$mold>

	 The C<Mold> instance being registered, ordered, inspected, or copied.


	Registers a compiled mold with the current collection.

	The mold has already had its blocks, signature, ordering metadata, and traits
	lowered by L<Qwiratry::Mold::Compiler>. The registry only preserves ordering
	until the transformer class drains the collection.

	=end pod
	method register-mold(Mold $mold) {
		@!molds.push($mold);
	}

	=begin pod

	=head2 C<register-wrapper(Str $type, Block $block)>

	=begin code
	method register-wrapper(Str $type, Block $block)
	=end code

	=head3 Parameters

	=item C<$type>

	 The operation or wrapper type used to group the registration.

	=item C<$block>

	 The wrapper block to register for later transformer integration.


	Registers a wrapper block of the given C<$type>.

	Wrapper types such as C<TRANSFORMER>, C<MOLD_MATCHER>, and C<MOLD_ACTION>
	are recorded with their compiled block so the transformer can install the
	corresponding runtime wrapper behavior.

	=end pod
	method register-wrapper(Str $type, Block $block) {
		@!wrappers.push(%(type => $type, block => $block));
	}

	=begin pod

	=head2 C<collected-molds()>

	=begin code
	method collected-molds()
	=end code

	Returns collected molds and clears the mold list.

	This is the normal handoff path used by transformer composition. Clearing on
	read prevents molds from one transformer declaration leaking into the next.

	=end pod
	method collected-molds() {
		my @result = @!molds;
		@!molds = [];
		@result
	}

	=begin pod

	=head2 C<clear-molds()>

	=begin code
	method clear-molds()
	=end code

	Clears the mold collection without returning it.

	Slang activation and test setup use this to discard partial state after an
	error or between isolated parse attempts.

	=end pod
	method clear-molds() {
		@!molds = [];
	}

	=begin pod

	=head2 C<collected-wrappers()>

	=begin code
	method collected-wrappers()
	=end code

	Returns collected wrappers and clears the wrapper list.

	Like C<collected-molds>, this transfers compile-time wrapper declarations to
	the transformer class while preserving the declaration order seen by the slang.

	=end pod
	method collected-wrappers() {
		my @wrappers = @!wrappers;
		@!wrappers = [];
		@wrappers
	}

	=begin pod

	=head2 C<clear-wrappers()>

	=begin code
	method clear-wrappers()
	=end code

	Clears the wrapper collection without returning it.

	=end pod
	method clear-wrappers() {
		@!wrappers = [];
	}
}
