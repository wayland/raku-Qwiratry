=begin pod

=head1 Overview

Shared relation comparison and merge helpers used across query evaluators.

=end pod
class Qwiratry::Query::RelationCommon {

	my $instance;

	=begin pod

	Return the shared RelationCommon service instance.

	=end pod
	method instance(--> Qwiratry::Query::RelationCommon) {
		$instance //= self.new
	}

	=begin pod

	Compare two rows or scalars for equality (associative rows compare normalized keys).

	=end pod
	method row-equal(Mu $a, Mu $b --> Bool) {
		$a === $b and return True;
		if $a ~~ Associative && $b ~~ Associative {
			my @keys = ($a.keys, $b.keys).flat.map({ self!normalize-key-name($_) }).unique.sort;
			for @keys -> $name {
				next unless $a{$name}:exists && $b{$name}:exists;
				my $va = $a{$name};
				my $vb = $b{$name};
				$va.defined == $vb.defined or return False;
				next unless $va.defined;
				$va.gist eq $vb.gist or return False;
			}
			return True;
		}
		$a.defined == $b.defined or return False;
		$a.defined or return True;
		$a.gist eq $b.gist
	}

	=begin pod

	Return True when C<$row> matches any row in C<@list> via L<row-equal>.

	=end pod
	method row-in-list(Mu $row, @list --> Bool) {
		for @list -> $candidate {
			self.row-equal($row, $candidate) and return True;
		}
		False
	}

	=begin pod

	Return True when C<$node> is in C<@list> by identity or row equality.

	=end pod
	method node-in-list(Mu $node, @list --> Bool) {
		for @list -> $candidate {
			$candidate === $node and return True;
			return True if $node ~~ Associative && $candidate ~~ Associative
				&& self.row-equal($node, $candidate);
		}
		False
	}

	=begin pod

	Return sorted column names present in both associative rows.

	=end pod
	method common-keys(Mu $left, Mu $right --> List) {
		$left ~~ Associative && $right ~~ Associative or return ();
		my @left-keys = $left.keys.map({ self!normalize-key-name($_) });
		my @right-keys = $right.keys.map({ self!normalize-key-name($_) });
		(@left-keys (&) @right-keys).sort.List
	}

	=begin pod

	Merge two associative rows; conflicting values must stringify equally.

	=end pod
	method merge-rows(Associative $left, Associative $right --> Hash) {
		my %merged = %($left);
		for $right.pairs -> $p {
			if %merged{$p.key}:exists {
				next if ~(%merged{$p.key}) eq ~($p.value);
			}
			%merged{$p.key} = $p.value;
		}
		%merged
	}

	=begin pod

	Return True when all common keys between two rows have equal string values.

	=end pod
	method join-on-common-keys(Associative $l, Associative $r --> Bool) {
		my @keys = self.common-keys($l, $r);
		@keys or return False;
		for @keys -> $key {
			my $name = self!normalize-key-name($key);
			next unless $l{$name}:exists && $r{$name}:exists;
			$l{$name}.gist eq $r{$name}.gist or return False;
		}
		True
	}

	=begin pod

	Normalize a hash key, pair, or string to a string column name.

	=end pod
	method !normalize-key-name(Mu $key --> Str) {
		$key ~~ Str and return $key;
		$key ~~ Pair and return $key.key;
		~$key
	}
}
