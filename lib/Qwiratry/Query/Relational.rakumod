=begin pod

Relational-algebra helpers for set operator execution in L<Qwiratry::Query::Match>.

Pure functions over row lists and associative rows: equality, joins, projections,
and set operations used when evaluating lazy and eager query pipelines.

=end pod
class Qwiratry::Query::Relational {

	my $instance;


	=begin pod

	Return the shared Relational service instance.

	=end pod
	method instance(--> Qwiratry::Query::Relational) {
		$instance //= self.new
	}


	=begin pod

	Compare two rows or scalars for equality (associative rows compare normalized keys).

	=end pod
	method row-equal(Mu $a, Mu $b --> Bool) {
		return True if $a === $b;
		if $a ~~ Associative && $b ~~ Associative {
			my @keys = ($a.keys, $b.keys).flat.map({ self!normalize-key-name($_) }).unique.sort;
			for @keys -> $name {
				next unless $a{$name}:exists && $b{$name}:exists;
				my $va = $a{$name};
				my $vb = $b{$name};
				return False unless $va.defined == $vb.defined;
				next unless $va.defined;
				return False unless ~$va eq ~$vb;
			}
			return True;
		}
		~$a eq ~$b
	}


	=begin pod

	Return True when C<$row> matches any row in C<@list> via L<row-equal>.

	=end pod
	method row-in-list(Mu $row, @list --> Bool) {
		for @list -> $candidate {
			return True if self.row-equal($row, $candidate);
		}
		False
	}


	=begin pod

	Return True when C<$node> is in C<@list> by identity or row equality.

	=end pod
	method node-in-list(Mu $node, @list --> Bool) {
		for @list -> $candidate {
			return True if $candidate === $node;
			return True if $node ~~ Associative && $candidate ~~ Associative
				&& self.row-equal($node, $candidate);
		}
		False
	}


	=begin pod

	Return sorted column names present in both associative rows.

	=end pod
	method common-keys(Mu $left, Mu $right --> List) {
		return () unless $left ~~ Associative && $right ~~ Associative;
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

	Natural (inner) join of two row lists on common keys or a custom condition.

	=end pod
	method natural-join(@left, @right, &condition?) {
		my @result;
		for @left -> $lrow {
			next unless $lrow ~~ Associative;
			for @right -> $rrow {
				next unless $rrow ~~ Associative;
				my $matches = &condition
					?? condition($lrow, $rrow)
					!! self.join-on-common-keys($lrow, $rrow);
				@result.push(self.merge-rows($lrow, $rrow)) if $matches;
			}
		}
		@result
	}


	=begin pod

	Return True when all common keys between two rows have equal string values.

	=end pod
	method join-on-common-keys(Associative $l, Associative $r --> Bool) {
		my @keys = self.common-keys($l, $r);
		return False unless @keys;
		for @keys -> $key {
			my $name = self!normalize-key-name($key);
			next unless $l{$name}:exists && $r{$name}:exists;
			return False unless ~($l{$name}) eq ~($r{$name});
		}
		True
	}


	=begin pod

	Left outer join: all left rows, merged matches or bare left row when none match.

	=end pod
	method left-outer-join(@left, @right, &condition?) {
		my @result;
		for @left -> $lrow {
			my @matches;
			for @right -> $rrow {
				my $ok = &condition ?? condition($lrow, $rrow) !! self.join-on-common-keys($lrow, $rrow);
				@matches.push(self.merge-rows($lrow, $rrow)) if $ok;
			}
			if @matches {
				@result.append(@matches);
			}
			else {
				@result.push(%($lrow));
			}
		}
		@result
	}


	=begin pod

	Right outer join: all right rows, merged matches or bare right row when none match.

	=end pod
	method right-outer-join(@left, @right, &condition?) {
		my @result;
		for @right -> $rrow {
			my @matches;
			for @left -> $lrow {
				my $ok = &condition ?? condition($lrow, $rrow) !! self.join-on-common-keys($lrow, $rrow);
				@matches.push(self.merge-rows($lrow, $rrow)) if $ok;
			}
			if @matches {
				@result.append(@matches);
			}
			else {
				@result.push(%($rrow));
			}
		}
		@result
	}


	=begin pod

	Full outer join: inner join plus unmatched rows from both sides.

	=end pod
	method full-outer-join(@left, @right, &condition?) {
		my @inner = self.natural-join(@left, @right, &condition);
		my @left-only = self.left-antijoin(@left, @right, &condition);
		my @right-only = self.left-antijoin(@right, @left, &condition);
		my @result = @inner;
		@result.append(@left-only);
		@result.append(@right-only);
		@result
	}


	=begin pod

	Left semijoin: left rows that have at least one matching right row (left projected).

	=end pod
	method left-semijoin(@left, @right, &condition?) {
		my @result;
		for @left -> $lrow {
			for @right -> $rrow {
				my $ok = &condition ?? condition($lrow, $rrow) !! self.join-on-common-keys($lrow, $rrow);
				if $ok {
					@result.push(%($lrow));
					last;
				}
			}
		}
		@result
	}


	=begin pod

	Right semijoin: mirror of L<left-semijoin> with sides swapped.

	=end pod
	method right-semijoin(@left, @right, &condition?) {
		self.left-semijoin(@right, @left, &condition)
	}


	=begin pod

	Left antijoin: left rows with no matching right row.

	=end pod
	method left-antijoin(@left, @right, &condition?) {
		my @result;
		for @left -> $lrow {
			my $matched = False;
			for @right -> $rrow {
				my $ok = &condition ?? condition($lrow, $rrow) !! self.join-on-common-keys($lrow, $rrow);
				if $ok {
					$matched = True;
					last;
				}
			}
			@result.push(%($lrow)) unless $matched;
		}
		@result
	}


	=begin pod

	Right antijoin: mirror of L<left-antijoin> with sides swapped.

	=end pod
	method right-antijoin(@left, @right, &condition?) {
		self.left-antijoin(@right, @left, &condition)
	}


	=begin pod

	Cartesian product of two row lists (pairwise merge).

	=end pod
	method cross-join(@left, @right) {
		my @result;
		for @left -> $lrow {
			for @right -> $rrow {
				@result.push(self.merge-rows($lrow, $rrow));
			}
		}
		@result
	}


	=begin pod

	Project associative C<$row> onto the listed C<@columns>.

	=end pod
	method project-row(Associative $row, @columns) {
		my %proj;
		for @columns -> $col {
			my $name = self!normalize-col-name($col);
			%proj{$name} = $row{$name} if $row{$name}:exists;
		}
		%proj
	}


	=begin pod

	Rename columns in an associative row according to C<%renames>.

	=end pod
	method rename-row(Associative $row, %renames) {
		my %result = %($row);
		for %renames.pairs -> $p {
			if %result{$p.key}:exists {
				%result{$p.value} = %result.delete($p.key);
			}
		}
		%result
	}


	=begin pod

	Return True when every left row appears in the right collection.

	=end pod
	method is-subset-of(@left, @right --> Bool) {
		for @left -> $lrow {
			return False unless self.row-in-list($lrow, @right);
		}
		True
	}


	=begin pod

	Return True when two row collections have the same multiset of rows.

	=end pod
	method collections-equal(@left, @right --> Bool) {
		return False unless @left.elems == @right.elems;
		for @left -> $lrow {
			return False unless self.row-in-list($lrow, @right);
		}
		True
	}


	=begin pod

	Rows in either list that do not appear in the other (symmetric difference).

	=end pod
	method symmetric-difference(@left, @right) {
		my @result;
		for @left -> $row {
			@result.push($row) unless self.row-in-list($row, @right);
		}
		for @right -> $row {
			@result.push($row) unless self.row-in-list($row, @left);
		}
		@result
	}


	=begin pod

	Relational division: left rows paired with every right row via join keys.

	=end pod
	method relational-division(@left, @right) {
		return () unless @right;
		my @result;
		for @left -> $candidate {
			my $ok = True;
			for @right -> $rrow {
				my $found = @left.grep(-> $lrow {
					self.row-equal($lrow, $candidate) || (
						self.common-keys($lrow, $rrow).so
						&& self.join-on-common-keys($lrow, $rrow)
					)
				}).so;
				unless $found {
					$ok = False;
					last;
				}
			}
			@result.push($candidate) if $ok;
		}
		@result
	}


	=begin pod

	Normalize a hash key, pair, or string to a string column name.

	=end pod
	method !normalize-key-name(Mu $key --> Str) {
		return $key if $key ~~ Str;
		return $key.key if $key ~~ Pair;
		~$key
	}


	=begin pod

	Normalize a projection column specifier (string, angle-bracket name, or list).

	=end pod
	method !normalize-col-name(Mu $col --> Str) {
		return $col if $col ~~ Str;
		if $col ~~ List && $col.elems == 1 {
			return self!normalize-col-name($col[0]);
		}
		my $name = ~$col;
		$name = $name.substr(1, *-2) if $name.starts-with('<') && $name.ends-with('>');
		$name
	}
}
