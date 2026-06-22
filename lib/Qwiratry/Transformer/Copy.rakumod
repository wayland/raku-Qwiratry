=begin pod

=head1 Overview

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

	=head1 Methods

	=head2 C<instance()>

	=begin code
	method instance(--> Qwiratry::Transformer::Copy)
	=end code

	Returns the shared copy service instance.

	=end pod
	method instance(--> Qwiratry::Transformer::Copy) {
		$instance //= self.new
	}

	=begin pod

	=head2 C<copy(Mu $x)>

	=begin code
	multi method copy(Mu $x --> Mu)
	=end code

	=head3 Parameters

	=item C<$x>

	 The scalar value to copy or deep-copy.


	Returns a shallow copy of a scalar or identity object.

	Values that provide a custom C<copy> method use it; otherwise the original
	value is returned unchanged.

	=end pod
	multi method copy(Mu $x --> Mu) {
		if $x.^find_method('copy', :no_fallback) {
			return $x.copy();
		}
		$x
	}

	=begin pod

	=head2 C<copy(Positional $p)>

	=begin code
	multi method copy(Positional $p --> Positional)
	=end code

	=head3 Parameters

	=item C<$p>

	 The positional container whose elements should be copied.


	Returns a shallow positional copy.

	Custom C<copy> methods win; otherwise C<clone> copies the container while
	sharing child values with the original.

	=end pod
	multi method copy(Positional $p --> Positional) {
		if $p.^find_method('copy', :no_fallback) {
			return $p.copy();
		}
		$p.clone
	}

	=begin pod

	=head2 C<copy(Associative $a)>

	=begin code
	multi method copy(Associative $a --> Associative)
	=end code

	=head3 Parameters

	=item C<$a>

	 The associative container whose values should be copied.


	Returns a shallow associative copy.

	Custom C<copy> methods win; otherwise C<clone> copies the container while
	sharing child values with the original.

	=end pod
	multi method copy(Associative $a --> Associative) {
		if $a.^find_method('copy', :no_fallback) {
			return $a.copy();
		}
		$a.clone
	}

	=begin pod

	=head2 C<deepcopy(Mu $x, :%visited)>

	=begin code
	multi method deepcopy(Mu $x, :%visited = %() --> Mu)
	=end code

	=head3 Parameters

	=item C<$x>

	 The scalar value to copy or deep-copy.

	=item C<%visited>

	 The identity map used to preserve cycles and shared references during deep copy.


	Returns scalar and identity values unchanged.

	The C<:%visited> parameter is accepted for dispatch consistency with
	container overloads.

	=end pod
	multi method deepcopy(Mu $x, :%visited = %() --> Mu) {
		$x
	}

	=begin pod

	=head2 C<deepcopy(Positional $p, :%visited)>

	=begin code
	multi method deepcopy(Positional $p, :%visited = %() --> Positional)
	=end code

	=head3 Parameters

	=item C<$p>

	 The positional container whose elements should be copied.

	=item C<%visited>

	 The identity map used to preserve cycles and shared references during deep copy.


	Recursively deep-copies a positional container.

	C<%visited> preserves cycles and shared subgraphs within a single deepcopy
	call, so repeated references in the input remain repeated references in the
	copy.

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

	=head2 C<deepcopy(Associative $a, :%visited)>

	=begin code
	multi method deepcopy(Associative $a, :%visited = %() --> Associative)
	=end code

	=head3 Parameters

	=item C<$a>

	 The associative container whose values should be copied.

	=item C<%visited>

	 The identity map used to preserve cycles and shared references during deep copy.


	Recursively deep-copies an associative container.

	Keys are preserved and values are copied through the service. C<%visited>
	handles cycles and shared subgraphs.

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
