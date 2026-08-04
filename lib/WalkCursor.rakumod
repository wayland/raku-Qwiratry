=begin pod

=head1 Overview

Walkable position/movement contract (C<WalkCursor>): a first-class position and movement API in the same
conceptual slot as C<Iterator> / C<Supply>.

A WalkCursor answers I<where> a walk is and I<how> it can move. It is distinct from
pull result streams (L<Qwiratry::QueryIterator>) and from tree shape adaptors
(L<Qwiratry::Tree::Navigator::Base>). Qwiratry’s first specialization is
L<Qwiratry::QueryCursor>. Design notes live in
C<docs/rakudoc/Developing/Cursor-Proposal.md>.

Note: Raku already binds C<CORE::Cursor> to C<Match>, so this contract
cannot ship as a bare C<Cursor> role/module. C<WalkCursor> is the short name
until/unless core frees that symbol. See C<Cursor-Proposal.md>.

This module exports:

=item C<Sector> — oriented half-lines from the current node (child, following, …)

=item C<Axis> — a matched pair of opposite Sectors (one bidirectional line)

=item C<WalkCursor> — the position / C<fetch-*> / C<move-*> role

=item C<direction-args> — helper to build optional C<:axis> / C<:sector> captures

=head1 Sector and Axis

B<Sector> names XPath/Qwiratry navigation half-lines (C<child>, C<parent>,
C<following>, …). Prefer C<Sector::…> qualification so barewords do not collide
with query-slang infixes.

B<Axis> pairs opposite sectors for signed motion:

=begin table
Axis                            | Forward (+)           | Backward (−)
preceding-following             | following             | preceding
preceding-following-sibling     | following-sibling     | preceding-sibling
ancestor-descendant             | descendant            | ancestor
=end table

C<Sector::child> / C<Sector::parent> do not get their own Axis; they are one-step
moves on C<Axis.ancestor-descendant> (C<fetch/move-relative(±1)>).

An advertised Axis is always bidirectional. One-way-only backends advertise
Sectors instead of an Axis.

=head1 Fetch vs Move

PostgreSQL-class scroll comes in two families:

=item C<fetch-*> — reposition and return the item at the new position (C<Mu>), or
C<IterationEnd> when the step is empty. Count-taking forms are C<multi>s on
C<Int> (single item) and C<Range> (C<Seq> over the span; C<*> / C<Inf> = until
exhausted; open and closed ranges both allowed).

=item C<move-*> — same repositioning algebra, return an C<Int> step count (how
many positions advanced; C<0> if none). Count-taking C<move-*> take C<Int> only.

Passing both C<:axis> and C<:sector> is an error. With C<:sector>, steps must be
C<< $n >= 0 >> (C<0> = self). With C<:axis> / default axis, positive steps use the
forward sector and negative steps the backward sector.

=head1 Implementing

Compose C<WalkCursor> and implement the stubbed (C<...>) methods at minimum:
C<current>, C<fetch-first>, C<fetch-last>, C<fetch-absolute>, C<fetch-relative>,
C<fetch-backward(Range)>, and C<clone-position>. Default bodies already provide
C<fetch-next> / C<fetch-prior> / C<fetch-forward(Int)> and the C<move-*> family
in terms of those.

=head1 Example

=begin code
use WalkCursor;

class PointCursor does WalkCursor {
    has @.items;
    has Int $.index is rw = 0;

    method current(--> Mu) { @!items[$!index] }

    method fetch-relative(Int $n, Axis :$axis, Sector :$sector --> Mu) {
        my $i = $!index + $n;
        return IterationEnd unless 0 <= $i < @!items.elems;
        $!index = $i;
        self.current
    }
    # ... other required multis / first / last / clone-position ...
}
=end code

=end pod

# Oriented half-lines from the current node (XPath/Qwiratry navigation names).
enum Sector is export <
	self
	child parent descendant ancestor
	following preceding
	following-sibling preceding-sibling
	attribute
>;

=begin pod

=head1 Class Axis

Matched opposite pair of L<Sector>s — one bidirectional navigation line.

Type methods C<preceding-following>, C<preceding-following-sibling>, and
C<ancestor-descendant> return the standard Axes.

=end pod
class Axis is export {
	has Sector $.forward  is required;
	has Sector $.backward is required;

	method preceding-following(Axis:U: --> Axis) {
		Axis.new(:forward(Sector::following), :backward(Sector::preceding))
	}
	method preceding-following-sibling(Axis:U: --> Axis) {
		Axis.new(
			:forward(Sector::following-sibling),
			:backward(Sector::preceding-sibling),
		)
	}
	method ancestor-descendant(Axis:U: --> Axis) {
		Axis.new(:forward(Sector::descendant), :backward(Sector::ancestor))
	}
}

=begin pod

=head1 Sub C<direction-args>

Build a Hash of defined C<:axis> / C<:sector> pairs for C<|>-flattening into
scroll method calls. Omits undefined direction arguments.

=end pod
sub direction-args(Axis :$axis, Sector :$sector) is export {
	my %h;
	%h<axis> = $axis if $axis.defined;
	%h<sector> = $sector if $sector.defined;
	%h
}

=begin pod

=head1 Role WalkCursor

Position and PostgreSQL-class C<fetch-*> / C<move-*> movement.

=head2 Attributes

=item C<$.default-axis> — Axis used when neither C<:axis> nor C<:sector> is
passed (default C<Axis.preceding-following>).

=head2 Capability probing

C<cursor-capabilities()> returns an Associative (same pattern as Walker
C<capabilities>). Typical keys: C<axes>, C<sectors>, C<absolute>. C<first> /
C<last> are always supported.

=head2 Required stubs

Methods whose bodies are C<...> must be supplied by the composing class.

=end pod
role WalkCursor is export {
	has Axis $.default-axis is rw = Axis.preceding-following;

	=begin pod

	=head2 C<current()>

	=begin code
	method current(--> Mu)
	=end code

	The node or row at the Cursor’s position.

	=end pod
	method current(--> Mu) { ... }

	=begin pod

	=head2 C<cursor-capabilities()>

	=begin code
	method cursor-capabilities(--> Associative)
	=end code

	Structured capability metadata for this Cursor implementation.

	=end pod
	method cursor-capabilities(--> Associative) {
		%(
			axes    => (Axis.preceding-following, Axis.preceding-following-sibling, Axis.ancestor-descendant),
			sectors => Sector.enums.values.List,
			absolute => True,
		)
	}

	=begin pod

	=head2 Scroll methods

	PostgreSQL-class repositioning. C<fetch-*> return the item at the new
	position; C<move-*> return how many positions advanced. See also the module
	overview I<Fetch vs Move>.

	=head3 Shared parameters

	These named arguments appear on every scroll method (except where noted).
	Pass at most one of C<:axis> or C<:sector>; both together is an error.
	When neither is passed, C<$.default-axis> is used.

	=item C<:$axis>

	 An L<Axis> selecting the bidirectional line. Positive steps use
	 C<$axis.forward>; negative steps use C<$axis.backward>.

	=item C<:$sector>

	 A single L<Sector> half-line. Steps must be C<< $n >= 0 >> (C<0> means
	 self / no move along that sector).

	=item C<$n>

	 Count or span for absolute / relative / forward / backward forms:

	 =item C<Int> — one step of that magnitude (sign selects direction on an
	  Axis; must be non-negative with C<:sector>).

	 =item C<Range> — C<fetch-*> only; yield a C<Seq> over the span. Open and
	  closed ranges are allowed; C<*> / C<Inf> means until exhausted.
	  C<move-*> do not take C<Range>.

	=head3 C<fetch-next> / C<fetch-prior> / C<fetch-previous>

	=begin code
	method fetch-next(Axis :$axis, Sector :$sector --> Mu)
	method fetch-prior(Axis :$axis, Sector :$sector --> Mu)
	method fetch-previous(|c)   # alias of fetch-prior
	=end code

	One step forward or backward along the chosen line. Implemented as
	C<fetch-relative(+1)> / C<fetch-relative(-1)>.

	=head3 C<fetch-first> / C<fetch-last>

	=begin code
	method fetch-first(Axis :$axis, Sector :$sector --> Mu)
	method fetch-last(Axis :$axis, Sector :$sector --> Mu)
	=end code

	Jump to the first or last position on the chosen line. Required stubs for
	composing classes.

	=head3 C<fetch-absolute> / C<fetch-relative>

	=begin code
	multi method fetch-absolute(Int $n, Axis :$axis, Sector :$sector --> Mu)
	multi method fetch-absolute(Range $n, Axis :$axis, Sector :$sector --> Seq)
	multi method fetch-relative(Int $n, Axis :$axis, Sector :$sector --> Mu)
	multi method fetch-relative(Range $n, Axis :$axis, Sector :$sector --> Seq)
	=end code

	=item C<$n>

	 Absolute: 1-based (or implementation-defined) index on the line, or a
	 C<Range> of such indices. Relative: signed step count from C<current>, or
	 a C<Range> of relative steps.

	Required stubs for composing classes.

	=head3 C<fetch-forward> / C<fetch-backward>

	=begin code
	multi method fetch-forward(Int $n = 1, Axis :$axis, Sector :$sector --> Mu)
	multi method fetch-forward(Range $n, Axis :$axis, Sector :$sector --> Seq)
	multi method fetch-backward(Int $n = 1, Axis :$axis, Sector :$sector --> Mu)
	multi method fetch-backward(Range $n, Axis :$axis, Sector :$sector --> Seq)
	=end code

	=item C<$n>

	 Defaults to C<1> for the C<Int> candidates. Forward is
	 C<fetch-relative($n)>; backward is C<fetch-relative(-$n)> for C<Int>, with
	 a Range multi stubbed for composing classes.

	=head3 C<move-*>

	=begin code
	method move-next(Axis :$axis, Sector :$sector --> Int)
	method move-prior(Axis :$axis, Sector :$sector --> Int)
	method move-previous(|c)   # alias of move-prior
	method move-first(Axis :$axis, Sector :$sector --> Int)
	method move-last(Axis :$axis, Sector :$sector --> Int)
	method move-absolute(Int $n, Axis :$axis, Sector :$sector --> Int)
	method move-relative(Int $n, Axis :$axis, Sector :$sector --> Int)
	method move-forward(Int $n = 1, Axis :$axis, Sector :$sector --> Int)
	method move-backward(Int $n = 1, Axis :$axis, Sector :$sector --> Int)
	=end code

	Same repositioning as the matching C<fetch-*>, but return an C<Int> step
	count instead of the item. Count-taking forms take C<Int> only (no
	C<Range>). Default bodies wrap the corresponding C<fetch-*>.

	=item C<$n>

	 As for C<fetch-absolute> / C<fetch-relative> / C<fetch-forward> /
	 C<fetch-backward>, restricted to C<Int>. C<move-forward> /
	 C<move-backward> default C<$n> to C<1>.

	=head3 Return Value

	=item C<fetch-*> with C<Int> (or no count)

	 The item at the new position (C<Mu>), or C<IterationEnd> when the step is
	 empty. Unsupported operations should throw (Qwiratry uses
	 C<X::Qwiratry::Cursor::*>).

	=item C<fetch-*> with C<Range>

	 A C<Seq> of items along the span.

	=item C<move-*>

	 An C<Int> count of positions advanced (C<0> if none).

	=end pod
	method fetch-next(Axis :$axis, Sector :$sector --> Mu) {
		self.fetch-relative(1, |direction-args(:$axis, :$sector))
	}
	method fetch-prior(Axis :$axis, Sector :$sector --> Mu) {
		self.fetch-relative(-1, |direction-args(:$axis, :$sector))
	}
	method fetch-previous(|c) { self.fetch-prior(|c) }

	method fetch-first(Axis :$axis, Sector :$sector --> Mu) { ... }
	method fetch-last(Axis :$axis, Sector :$sector --> Mu) { ... }

	multi method fetch-absolute(Int $n, Axis :$axis, Sector :$sector --> Mu) { ... }
	multi method fetch-absolute(Range $n, Axis :$axis, Sector :$sector --> Seq) { ... }

	multi method fetch-relative(Int $n, Axis :$axis, Sector :$sector --> Mu) { ... }
	multi method fetch-relative(Range $n, Axis :$axis, Sector :$sector --> Seq) { ... }

	multi method fetch-forward(Int $n = 1, Axis :$axis, Sector :$sector --> Mu) {
		self.fetch-relative($n, |direction-args(:$axis, :$sector))
	}
	multi method fetch-forward(Range $n, Axis :$axis, Sector :$sector --> Seq) {
		self.fetch-relative($n, |direction-args(:$axis, :$sector))
	}

	multi method fetch-backward(Int $n = 1, Axis :$axis, Sector :$sector --> Mu) {
		self.fetch-relative(-$n, |direction-args(:$axis, :$sector))
	}
	multi method fetch-backward(Range $n, Axis :$axis, Sector :$sector --> Seq) { ... }

	method move-next(Axis :$axis, Sector :$sector --> Int) {
		self!move-from-fetch({ self.fetch-next(|direction-args(:$axis, :$sector)) })
	}
	method move-prior(Axis :$axis, Sector :$sector --> Int) {
		self!move-from-fetch({ self.fetch-prior(|direction-args(:$axis, :$sector)) })
	}
	method move-previous(|c) { self.move-prior(|c) }

	method move-first(Axis :$axis, Sector :$sector --> Int) {
		self!move-from-fetch({ self.fetch-first(|direction-args(:$axis, :$sector)) })
	}
	method move-last(Axis :$axis, Sector :$sector --> Int) {
		self!move-from-fetch({ self.fetch-last(|direction-args(:$axis, :$sector)) })
	}

	method move-absolute(Int $n, Axis :$axis, Sector :$sector --> Int) {
		self!move-from-fetch({ self.fetch-absolute($n, |direction-args(:$axis, :$sector)) })
	}
	method move-relative(Int $n, Axis :$axis, Sector :$sector --> Int) {
		self!move-from-fetch({ self.fetch-relative($n, |direction-args(:$axis, :$sector)) })
	}
	method move-forward(Int $n = 1, Axis :$axis, Sector :$sector --> Int) {
		self.move-relative($n, |direction-args(:$axis, :$sector))
	}
	method move-backward(Int $n = 1, Axis :$axis, Sector :$sector --> Int) {
		self.move-relative(-$n, |direction-args(:$axis, :$sector))
	}

	=begin pod

	=head2 C<clone-position()>

	=begin code
	method clone-position(--> ::?CLASS)
	=end code

	Return a new WalkCursor with the same position-relevant state and independent
	mutable position (for backtracking). Must not share live position or
	walk-local Navigator caches with the original.

	=end pod
	method clone-position(--> ::?CLASS) { ... }

	method !move-from-fetch(&fetch --> Int) {
		my $before = self.current;
		my $got = fetch();
		return 0 if $got ~~ IterationEnd;
		return 0 unless self.current.defined;
		return 0 if $before.defined && self.current === $before && $got === $before;
		1
	}
}
