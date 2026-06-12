=begin pod

Copy service for shallow and deep copying of transformable nodes.

Provides C<.copy> and C<.deepcopy> for cloning node trees before or during
transforms. Transformable nodes are those handled by a L<Qwiratry::Walker>
with the C<supports-rewrite> capability.

Access via L<Qwiratry::Transformer::Copy.instance> or the convenience methods
on L<Qwiratry::Transformer>.

Follows spec section 3.3.6.

=end pod
class Qwiratry::Transformer::Copy {

	my $instance;

	=begin pod

	Return the shared Copy service instance.

	=end pod
	method instance(--> Qwiratry::Transformer::Copy) {
		$instance //= self.new
	}

	=begin pod

	Shallow copy for immutable primitives and objects with identity.

	Returns the value as-is unless the node defines a custom C<.copy> method.

	@param $x - Value to copy
	@returns Mu - Shallow copy (or original if identity)

	=end pod
	multi method copy(Mu $x --> Mu) {
		if $x.^find_method('copy', :no_fallback) {
			return $x.copy();
		}
		$x
	}

	=begin pod

	Shallow copy for positional types (arrays, lists).

	First checks for a custom C<.copy> method; otherwise uses C<clone> (O(1)).

	@param $p - Positional value to copy
	@returns Positional - Shallow copy (children shared with original)

	=end pod
	multi method copy(Positional $p --> Positional) {
		if $p.^find_method('copy', :no_fallback) {
			return $p.copy();
		}
		$p.clone
	}

	=begin pod

	Shallow copy for associative types (hashes, maps).

	First checks for a custom C<.copy> method; otherwise uses C<clone> (O(1)).

	@param $a - Associative value to copy
	@returns Associative - Shallow copy (children shared with original)

	=end pod
	multi method copy(Associative $a --> Associative) {
		if $a.^find_method('copy', :no_fallback) {
			return $a.copy();
		}
		$a.clone
	}

	=begin pod

	Deep copy for immutable primitives and objects with identity.

	Returns the value as-is (Str, Numeric, Bool, and identity objects).

	@param $x - Value to deep copy
	@param :%visited - Internal visited hash for cycle detection (optional)
	@returns Mu - Deep copy (or original if identity)

	=end pod
	multi method deepcopy(Mu $x, :%visited = %() --> Mu) {
		$x
	}

	=begin pod

	Recursive deep copy for positional types.

	Recursively calls C<.deepcopy> on each element. Uses the visited hash
	for cycle detection and DAG preservation within a single call.

	@param $p - Positional value to deep copy
	@param :%visited - Internal visited hash for cycle detection
	@returns Positional - Deep copy with all descendants cloned

	=end pod
	multi method deepcopy(Positional $p, :%visited = %() --> Positional) {
		my $identity = $p.WHICH;
		if %visited{$identity}:exists {
			return %visited{$identity};
		}

		my $cloned = Array.new;
		%visited{$identity} = $cloned;

		for $p -> $elem {
			$cloned.push(self.deepcopy($elem, :%visited));
		}

		$cloned
	}

	=begin pod

	Recursive deep copy for associative types.

	Recursively calls C<.deepcopy> on each value. Uses the visited hash
	for cycle detection and DAG preservation within a single call.

	@param $a - Associative value to deep copy
	@param :%visited - Internal visited hash for cycle detection
	@returns Associative - Deep copy with all descendants cloned

	=end pod
	multi method deepcopy(Associative $a, :%visited = %() --> Associative) {
		my $identity = $a.WHICH;
		if %visited{$identity}:exists {
			return %visited{$identity};
		}

		my $cloned = Hash.new;
		%visited{$identity} = $cloned;

		for $a.kv -> $key, $value {
			$cloned{$key} = self.deepcopy($value, :%visited);
		}

		$cloned
	}
}
