=begin pod

Collect molds and wrappers registered during transformer parsing.

Module-level storage keyed by compilation pass; drained when a transformer
class is finalized.

=end pod
use Qwiratry::Mold;

class Qwiratry::Mold::Registry {

	my $instance;

	=begin pod

	Return the shared mold registry instance.

	=end pod
	method instance(--> Qwiratry::Mold::Registry) {
		$instance //= self.new
	}

	has @!molds;
	has @!wrappers;

	=begin pod

	Register a compiled mold with the module-level collection.

	=end pod
	method register-mold(Mold $mold) {
		@!molds.push($mold);
	}

	=begin pod

	Register a wrapper block of the given C<$type> (TRANSFORMER, MOLD_MATCHER, etc.).

	=end pod
	method register-wrapper(Str $type, Block $block) {
		@!wrappers.push(%(type => $type, block => $block));
	}

	=begin pod

	Return collected molds and clear the module-level list.

	=end pod
	method collected-molds() {
		my @result = @!molds;
		@!molds = [];
		@result
	}

	=begin pod

	Clear the mold collection without returning it.

	=end pod
	method clear-molds() {
		@!molds = [];
	}

	=begin pod

	Return collected wrappers and clear the module-level list.

	=end pod
	method collected-wrappers() {
		my @wrappers = @!wrappers;
		@!wrappers = [];
		@wrappers
	}

	=begin pod

	Clear the wrapper collection without returning it.

	=end pod
	method clear-wrappers() {
		@!wrappers = [];
	}
}
