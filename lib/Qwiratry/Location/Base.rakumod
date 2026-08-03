=begin pod

=head1 Overview

Abstract base classes for location I/O implementations.

L<Qwiratry::Location> discovers backend modules dynamically and verifies that
their operation classes inherit from these walkable contracts. A backend module
usually defines C<::Source> and/or C<::Destination> classes under its backend
namespace, for example C<Qwiratry::Location::File::Source>, which inherit
C<SourceWalkable> / C<DestinationWalkable>.

These base classes deliberately throw from their operation methods. They exist
to make backend discovery and validation explicit; concrete backends provide the
actual transport or storage behavior.

Optional pull and sink roles add chunk-oriented capabilities alongside the
walkable whole-value path. "Streaming" as a capability means a pull or sink
path is available. Full push (C<Supply>) edges are planned for later.

=end pod
class Qwiratry::Location::Base::SourceWalkable {

	=begin pod

	=head1 Methods

	=head2 C<read-walkable(Str $location)>

	=begin code
	method read-walkable(Str $location --> Mu)
	=end code

	=head3 Parameters

	=item C<$location>

	 The location string or URI handled by the backend.


	Reads from C<$location> as a complete payload. The abstract contract is
	deliberately C<Mu>: concrete backends may return text, path objects, binary
	blobs, or other payloads. File backends typically return C<Str> for ordinary
	files and C<IO::Path> for directories (see L<Qwiratry::Location::File>).

	Concrete source backends override this method. The pipeline reaches it through
	L<Qwiratry::Operator::IO::SourceOperator> after L<Qwiratry::Location> has chosen
	and validated the backend.

	=end pod
	method read-walkable(Str $location --> Mu) {
		die "read-walkable not implemented by {self.^name}";
	}
}

class Qwiratry::Location::Base::DestinationWalkable {

	=begin pod

	=head2 C<write-walkable(Str $location, Mu $content)>

	=begin code
	method write-walkable(Str $location, Mu $content --> Mu)
	=end code

	=head3 Parameters

	=item C<$location>

	 The location string or URI handled by the backend.

	=item C<$content>

	 The content to write to the destination location.


	Writes a complete C<$content> payload to C<$location>.

	Concrete destination backends override this method and return the written
	content so adaptor pipelines can pass the value through after the side effect.

	=end pod
	method write-walkable(Str $location, Mu $content --> Mu) {
		die "write-walkable not implemented by {self.^name}";
	}
}

=begin pod

Optional capability for sources that yield a pull stream of text chunks.

When a location source does this role, L<Qwiratry::Operator::IO::ParseOperator>
may prefer C<read-pull> together with a matching pull parser. Downstream parsers
that do not support pull adapt by joining chunks before calling
C<parse-walkable>.

=end pod
role Qwiratry::Location::Base::SourcePull {
	=begin pod

	=head2 C<read-pull(Str:D $location)>

	=begin code
	method read-pull(Str:D $location --> Iterator:D)
	=end code

	=head3 Parameters

	=item C<$location>

	 The location string or URI handled by the backend.


	Reads C<$location> as a pull iterator of C<Str> chunks.

	Concrete pull sources override this method. Chunk boundaries are
	backend-defined (for example lines or fixed-size blocks).

	=end pod
	method read-pull(Str:D $location --> Iterator:D) {
		die "read-pull not implemented by {self.^name}";
	}
}

=begin pod

Optional capability for destinations that accept incremental text writes via a
sink API.

When a location destination does this role and the upstream value is a text-chunk
C<Iterator>, L<Qwiratry::Operator::IO::DestinationOperator> opens a sink and
writes chunks without assembling one complete C<Str> first.

A sink object should provide C<write-chunk(Str:D --> Nil)> and C<close(--> Nil)>.

=end pod
role Qwiratry::Location::Base::DestinationPush {
	=begin pod

	=head2 C<open-sink-push(Str:D $location)>

	=begin code
	method open-sink-push(Str:D $location --> Mu)
	=end code

	=head3 Parameters

	=item C<$location>

	 The location string or URI handled by the backend.


	Opens an incremental write sink for C<$location>.

	The returned sink owns the destination resource until C<close> is called.
	Concrete push destinations override this method.

	=end pod
	method open-sink-push(Str:D $location --> Mu) {
		die "open-sink-push not implemented by {self.^name}";
	}
}
