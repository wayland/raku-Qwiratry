=begin pod

=head1 Overview

Registry for named joins recalled by the C<▵> prefix (Operators.md §6.2.4).

=end pod
unit class Qwiratry::Query::NamedJoins;

my $instance;
has %!joins;

=begin pod

=head2 C<method instance>

=begin code :lang<raku>
method instance(--> Qwiratry::Query::NamedJoins)
=end code

Return the shared named-join registry.

=end pod
method instance(--> Qwiratry::Query::NamedJoins) {
	$instance //= self.new
}

=begin pod

=head2 C<method register>

=begin code :lang<raku>
method register(Str $name, Mu $join --> Nil)
=end code

Store C<$join> under C<$name> for later recall via C<▵>.

=end pod
method register(Str $name, Mu $join --> Nil) {
	%!joins{$name} = $join;
}

=begin pod

=head2 C<method lookup>

=begin code :lang<raku>
method lookup(Str $name)
=end code

Return the join registered as C<$name>, or C<Nil> if absent.

=end pod
method lookup(Str $name) {
	%!joins{$name}:exists ?? %!joins{$name} !! Nil
}

=begin pod

=head2 C<method clear>

=begin code :lang<raku>
method clear(--> Nil)
=end code

Remove all registered joins (useful in tests).

=end pod
method clear(--> Nil) {
	%!joins = %()
}
