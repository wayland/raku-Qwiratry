=begin pod

=head1 Overview

Qwiratry query specialization of the generic L<WalkCursor> role.

Holds C<$current> + C<$origin>, a walk-local Tree Navigator, and Plan/Context
hooks. See C<docs/rakudoc/Developing/Cursor-Proposal.md>.

=end pod
use WalkCursor;
use Qwiratry::Context;
use Qwiratry::QueryIterator;
use Qwiratry::Tree::Navigator;
use Qwiratry::Tree::Navigator::Base;
use X::Qwiratry;

unit class Qwiratry::QueryCursor does WalkCursor;

has Context $.context;
has Mu $.plan;
has Mu $.origin is required;
has Mu $.current is rw;
has Qwiratry::Tree::Navigator::Base $.navigator;

submethod TWEAK(:$current, :$origin, :$navigator) {
	$!origin = $origin;
	$!current = $current // $origin;
	$!navigator = $navigator
		// Qwiratry::Tree::Navigator.tree-navigator-walk-local(
			$!current, :origin($!origin),
		);
}

method cursor-capabilities(--> Associative) {
	%(
		axes => (
			Axis.preceding-following,
			Axis.preceding-following-sibling,
			Axis.ancestor-descendant,
		),
		sectors => <
			self child parent descendant ancestor
			following preceding following-sibling preceding-sibling
		>,
		absolute => True,
	)
}

method !reject-both(Axis :$axis, Sector :$sector) {
	if $axis.defined && $sector.defined {
		X::Qwiratry::Cursor::ConflictingDirection.new(
			message => 'Pass :axis or :sector, not both',
			walker-type => self.^name,
		).throw;
	}
}

method !sector-name(Int $signed-n, Axis :$axis, Sector :$sector --> List) {
	self!reject-both(|direction-args(:$axis, :$sector));
	if $sector.defined {
		return ($sector.Str, True);
	}
	my $ax = $axis // $.default-axis;
	my $name = $signed-n >= 0 ?? $ax.forward.Str !! $ax.backward.Str;
	($name, False)
}

method !apply-step(Int $n, Str $sector-name, Bool $sector-mode --> Mu) {
	if $sector-mode && $n < 0 {
		X::Qwiratry::Cursor::NegativeSectorStep.new(
			message => 'Sector steps require $n >= 0',
			walker-type => self.^name,
		).throw;
	}
	my $count = $sector-mode ?? $n !! $n.abs;
	my $next = $!navigator.tree-along-sector(
		$!current, $sector-name, $count, :origin($!origin),
	);
	$next.defined or return IterationEnd;
	$!current = $next;
	$!current
}

multi method fetch-relative(Int $n, Axis :$axis, Sector :$sector --> Mu) {
	my ($name, $sector-mode) = self!sector-name(
		$n, |direction-args(:$axis, :$sector),
	);
	self!apply-step($n, $name, $sector-mode)
}

multi method fetch-relative(Range $n, Axis :$axis, Sector :$sector --> Seq) {
	self!reject-both(|direction-args(:$axis, :$sector));
	my $start-current = $!current;
	my $open-ended = so ($n.max ~~ Whatever || $n.max === Inf);

	if $open-ended {
		my $ax = $axis // $.default-axis;
		my $sec = $sector;
		return gather {
			$!current = $start-current;
			loop {
				my $got = $sec.defined
					?? self.fetch-relative(1, :sector($sec))
					!! self.fetch-relative(1, :axis($ax));
				last if $got ~~ IterationEnd;
				take $got;
			}
		};
	}

	gather {
		for $n.list -> $step {
			$step ~~ Int or X::Qwiratry::Cursor::InvalidRange.new(
				message => "Range steps must be Int (got {$step.^name})",
				walker-type => self.^name,
			).throw;
			$!current = $start-current;
			my $got = self.fetch-relative(
				$step, |direction-args(:$axis, :$sector),
			);
			last if $got ~~ IterationEnd;
			take $got;
		}
	}
}

multi method fetch-absolute(Int $n, Axis :$axis, Sector :$sector --> Mu) {
	self!reject-both(|direction-args(:$axis, :$sector));
	if $sector.defined {
		return self.fetch-relative($n, :$sector);
	}
	my $ax = $axis // $.default-axis;
	$!current = $!origin;
	$n == 0 and return $!current;
	self.fetch-relative($n, :axis($ax))
}

multi method fetch-absolute(Range $n, Axis :$axis, Sector :$sector --> Seq) {
	my $start = $!current;
	gather for $n.list -> $i {
		next unless $i ~~ Int;
		$!current = $start;
		my $got = self.fetch-absolute(
			$i, |direction-args(:$axis, :$sector),
		);
		last if $got ~~ IterationEnd;
		take $got;
	}
}

method fetch-first(Axis :$axis, Sector :$sector --> Mu) {
	self!reject-both(|direction-args(:$axis, :$sector));
	if $sector.defined {
		return self.fetch-relative(1, :$sector);
	}
	$!current = $!origin;
	$!current
}

method fetch-last(Axis :$axis, Sector :$sector --> Mu) {
	self!reject-both(|direction-args(:$axis, :$sector));
	my Str $name;
	if $sector.defined {
		$name = $sector.Str;
	}
	else {
		my $ax = $axis // $.default-axis;
		$name = $ax.forward.Str;
	}
	my @seq = $!navigator.tree-sector-seq($!current, $name, :origin($!origin)).list;
	@seq.elems or return IterationEnd;
	$!current = @seq[*-1];
	$!current
}

multi method fetch-forward(Range $n, Axis :$axis, Sector :$sector --> Seq) {
	self.fetch-relative($n, |direction-args(:$axis, :$sector))
}

multi method fetch-backward(Range $n, Axis :$axis, Sector :$sector --> Seq) {
	self!reject-both(|direction-args(:$axis, :$sector));
	if $sector.defined {
		X::Qwiratry::Cursor::Unsupported.new(
			message => 'fetch-backward(Range) with :sector is unsupported; use the opposite sector',
			walker-type => self.^name,
		).throw;
	}
	my $ax = $axis // $.default-axis;
	my $start-current = $!current;
	my $open-ended = so ($n.max ~~ Whatever || $n.max === Inf);
	if $open-ended {
		return gather {
			$!current = $start-current;
			loop {
				my $got = self.fetch-relative(-1, :axis($ax));
				last if $got ~~ IterationEnd;
				take $got;
			}
		};
	}
	gather for $n.list -> $step {
		next unless $step ~~ Int;
		$!current = $start-current;
		my $got = self.fetch-relative(-$step.abs, :axis($ax));
		last if $got ~~ IterationEnd;
		take $got;
	}
}

method clone-position(--> ::?CLASS) {
	self.new(
		:origin($!origin),
		:current($!current),
		:navigator($!navigator.walk-local-copy),
		:context($!context),
		:plan($!plan),
		:default-axis($.default-axis),
	)
}

method step(--> Mu) {
	self.fetch-relative(1)
}

method iterator(--> QueryIterator) {
	$!plan.defined or X::Qwiratry::Cursor::Unsupported.new(
		message => 'QueryCursor.iterator requires $.plan (use Plan.cursor then .iterator)',
		walker-type => self.^name,
	).throw;
	# Match-oriented bridge: same sequence as Plan.iterator (Streamable-Pull face).
	$!plan.iterator
}
