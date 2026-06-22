=begin pod

=head1 Overview

Abstract base classes for location I/O implementations.

L<Qwiratry::Location> discovers backend modules dynamically and verifies that
their operation classes inherit from these contracts. A backend module usually
defines C<::Source> and/or C<::Destination> classes under its backend namespace,
for example C<Qwiratry::Location::File::Source>.

These base classes deliberately throw from their operation methods. They exist
to make backend discovery and validation explicit; concrete backends provide the
actual transport or storage behavior.

=end pod
class Qwiratry::Location::Base::Source {

	=begin pod

	=head1 Methods

	=head2 C<read(Str $location)>

	=begin code
	method read(Str $location --> Str)
	=end code

	=head3 Parameters

	=item C<$location>

	 The location string or URI handled by the backend.


	Reads text from C<$location>.

	Concrete source backends override this method. The pipeline reaches it through
	L<Qwiratry::Operator::IO::SourceOperator> after L<Qwiratry::Location> has chosen
	and validated the backend.

	=end pod
	method read(Str $location --> Str) {
		die "read not implemented by {self.^name}";
	}
}

class Qwiratry::Location::Base::Destination {

	=begin pod

	=head2 C<write(Str $location, Mu $content)>

	=begin code
	method write(Str $location, Mu $content --> Mu)
	=end code

	=head3 Parameters

	=item C<$location>

	 The location string or URI handled by the backend.

	=item C<$content>

	 The content to write to the destination location.


	Writes C<$content> to C<$location>.

	Concrete destination backends override this method and return the written
	content so adaptor pipelines can pass the value through after the side effect.

	=end pod
	method write(Str $location, Mu $content --> Mu) {
		die "write not implemented by {self.^name}";
	}
}
