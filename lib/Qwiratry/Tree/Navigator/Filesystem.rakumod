=begin pod

=head1 Overview

Filesystem tree navigator.

Adapts C<IO::Path> nodes to Qwiratry's tree navigation protocol so a directory
returned by L<Qwiratry::Location::File::Source> can be queried with the usual
axis operators.

Directories expose their entries as children. Ordinary files are leaves.
Symlink directories are listed as children but are not descended into, which
avoids cycles. String selectors match entry basenames via
L<Qwiratry::Query::Selector> (exact, glob, or regex).

=end pod
use Qwiratry::Query::Selector;
use Qwiratry::Tree::Navigator::Base;

class Qwiratry::Tree::Navigator::Filesystem does Qwiratry::Tree::Navigator::Base {
	method supported-types(--> List) {
		(IO::Path,)
	}

	# Real directories only: symlink directories stay visible to the parent but have no
	# children, so descendant walks cannot loop through link cycles.
	multi method tree-children(IO::Path:D $node --> List) {
		return () unless $node.d;
		return () if $node.l;
		$node.dir.List
	}

	multi method tree-child-results(IO::Path:D $node, List $selector, Int :$limit --> List) {
		self!fan-out-child-results($node, $selector, |%(:$limit if $limit.defined))
	}

	multi method tree-child-results(
		IO::Path:D $node,
		Mu $selector where {
			$_ ~~ Regex
			|| ($_ ~~ Str && !Qwiratry::Query::Selector.instance.is-wildcard($_))
		},
		Int :$limit --> List
	) {
		my $sel = self!selector;
		my @out;
		for self.tree-children($node) -> $child {
			next unless $sel.matches($selector, $child);
			@out.push($child);
			last if $limit.defined && @out.elems >= $limit;
		}
		@out.list
	}

	multi method tree-child-results(
		IO::Path:D $node,
		Mu $selector where { Qwiratry::Query::Selector.instance.is-wildcard($_) },
		Int :$limit --> List
	) {
		self!apply-limit(self.tree-children($node), $limit)
	}

	multi method tree-child-results(IO::Path:D $node, Mu $selector, Int :$limit --> List) {
		self!filter-child-results($node, $selector, |%(:$limit if $limit.defined))
	}

	multi method tree-attributes(IO::Path:D $node --> Associative) {
		%(
			name => $node.basename,
			basename => $node.basename,
			path => ~$node,
			absolute => ~$node.absolute,
			d => $node.d,
			f => $node.f,
			l => $node.l,
			e => $node.e,
			s => $node.s,
		)
	}

	multi method tree-attribute-value(IO::Path:D $node, Mu $key --> Mu) {
		my $name = self!selector.normalize-key($key);
		my %attrs = self.tree-attributes($node);
		return %attrs{$name} if %attrs{$name}:exists;
		Nil
	}
}
