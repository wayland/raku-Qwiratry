=begin pod

Relational-algebra helpers for set operator execution in L<Qwiratry::Query::Match>.

Pure functions over row lists and associative rows: equality, joins, projections,
and set operations used when evaluating lazy and eager query pipelines.

=end pod
unit module Qwiratry::Query::Relational;

=begin pod

Compare two rows or scalars for equality (associative rows compare normalized keys).

=end pod
our sub row-equal(Mu $a, Mu $b --> Bool) is export {
	return True if $a === $b;
	if $a ~~ Associative && $b ~~ Associative {
		my @keys = ($a.keys, $b.keys).flat.map(&normalize-key-name).unique.sort;
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
our sub row-in-list(Mu $row, @list --> Bool) is export {
	for @list -> $candidate {
		return True if row-equal($row, $candidate);
	}
	False
}

=begin pod

Return True when C<$node> is in C<@list> by identity or row equality.

=end pod
our sub node-in-list(Mu $node, @list --> Bool) is export {
	for @list -> $candidate {
		return True if $candidate === $node;
		return True if $node ~~ Associative && $candidate ~~ Associative
			&& row-equal($node, $candidate);
	}
	False
}

=begin pod

Normalize a hash key, pair, or string to a string column name.

=end pod
sub normalize-key-name(Mu $key --> Str) {
	return $key if $key ~~ Str;
	return $key.key if $key ~~ Pair;
	~$key
}

=begin pod

Return sorted column names present in both associative rows.

=end pod
our sub common-keys(Mu $left, Mu $right --> List) is export {
	return () unless $left ~~ Associative && $right ~~ Associative;
	my @left-keys = $left.keys.map(&normalize-key-name);
	my @right-keys = $right.keys.map(&normalize-key-name);
	(@left-keys (&) @right-keys).sort.List
}

=begin pod

Merge two associative rows; conflicting values must stringify equally.

=end pod
our sub merge-rows(Associative $left, Associative $right --> Hash) is export {
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
our sub natural-join(@left, @right, &condition?) is export {
	my @result;
	for @left -> $lrow {
		next unless $lrow ~~ Associative;
		for @right -> $rrow {
			next unless $rrow ~~ Associative;
			my $matches = &condition
				?? condition($lrow, $rrow)
				!! join-on-common-keys($lrow, $rrow);
			@result.push(merge-rows($lrow, $rrow)) if $matches;
		}
	}
	@result
}

=begin pod

Return True when all common keys between two rows have equal string values.

=end pod
our sub join-on-common-keys(Associative $l, Associative $r --> Bool) is export {
	my @keys = common-keys($l, $r);
	return False unless @keys;
	for @keys -> $key {
		my $name = normalize-key-name($key);
		next unless $l{$name}:exists && $r{$name}:exists;
		return False unless ~($l{$name}) eq ~($r{$name});
	}
	True
}

=begin pod

Left outer join: all left rows, merged matches or bare left row when none match.

=end pod
our sub left-outer-join(@left, @right, &condition?) is export {
	my @result;
	for @left -> $lrow {
		my @matches;
		for @right -> $rrow {
			my $ok = &condition ?? condition($lrow, $rrow) !! join-on-common-keys($lrow, $rrow);
			@matches.push(merge-rows($lrow, $rrow)) if $ok;
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
our sub right-outer-join(@left, @right, &condition?) is export {
	my @result;
	for @right -> $rrow {
		my @matches;
		for @left -> $lrow {
			my $ok = &condition ?? condition($lrow, $rrow) !! join-on-common-keys($lrow, $rrow);
			@matches.push(merge-rows($lrow, $rrow)) if $ok;
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
our sub full-outer-join(@left, @right, &condition?) is export {
	my @inner = natural-join(@left, @right, &condition);
	my @left-only = left-antijoin(@left, @right, &condition);
	my @right-only = left-antijoin(@right, @left, &condition);
	my @result = @inner;
	@result.append(@left-only);
	@result.append(@right-only);
	@result
}

=begin pod

Left semijoin: left rows that have at least one matching right row (left projected).

=end pod
our sub left-semijoin(@left, @right, &condition?) is export {
	my @result;
	for @left -> $lrow {
		for @right -> $rrow {
			my $ok = &condition ?? condition($lrow, $rrow) !! join-on-common-keys($lrow, $rrow);
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
our sub right-semijoin(@left, @right, &condition?) is export {
	left-semijoin(@right, @left, &condition)
}

=begin pod

Left antijoin: left rows with no matching right row.

=end pod
our sub left-antijoin(@left, @right, &condition?) is export {
	my @result;
	for @left -> $lrow {
		my $matched = False;
		for @right -> $rrow {
			my $ok = &condition ?? condition($lrow, $rrow) !! join-on-common-keys($lrow, $rrow);
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
our sub right-antijoin(@left, @right, &condition?) is export {
	left-antijoin(@right, @left, &condition)
}

=begin pod

Cartesian product of two row lists (pairwise merge).

=end pod
our sub cross-join(@left, @right) is export {
	my @result;
	for @left -> $lrow {
		for @right -> $rrow {
			@result.push(merge-rows($lrow, $rrow));
		}
	}
	@result
}

=begin pod

Project associative C<$row> onto the listed C<@columns>.

=end pod
our sub project-row(Associative $row, @columns) is export {
	my %proj;
	for @columns -> $col {
		my $name = normalize-col-name($col);
		%proj{$name} = $row{$name} if $row{$name}:exists;
	}
	%proj
}

=begin pod

Rename columns in an associative row according to C<%renames>.

=end pod
our sub rename-row(Associative $row, %renames) is export {
	my %result = %($row);
	for %renames.pairs -> $p {
		if %result{$p.key}:exists {
			%result{$p.value} = %result.delete($p.key);
		}
	}
	%result
}

=begin pod

Normalize a projection column specifier (string, angle-bracket name, or list).

=end pod
sub normalize-col-name(Mu $col --> Str) {
	return $col if $col ~~ Str;
	if $col ~~ List && $col.elems == 1 {
		return normalize-col-name($col[0]);
	}
	my $name = ~$col;
	$name = $name.substr(1, *-2) if $name.starts-with('<') && $name.ends-with('>');
	$name
}

=begin pod

Return True when every left row appears in the right collection.

=end pod
our sub is-subset-of(@left, @right --> Bool) is export {
	for @left -> $lrow {
		return False unless row-in-list($lrow, @right);
	}
	True
}

=begin pod

Return True when two row collections have the same multiset of rows.

=end pod
our sub collections-equal(@left, @right --> Bool) is export {
	return False unless @left.elems == @right.elems;
	for @left -> $lrow {
		return False unless row-in-list($lrow, @right);
	}
	True
}

=begin pod

Rows in either list that do not appear in the other (symmetric difference).

=end pod
our sub symmetric-difference(@left, @right) is export {
	my @result;
	for @left -> $row {
		@result.push($row) unless row-in-list($row, @right);
	}
	for @right -> $row {
		@result.push($row) unless row-in-list($row, @left);
	}
	@result
}

=begin pod

Relational division: left rows paired with every right row via join keys.

=end pod
our sub relational-division(@left, @right) is export {
	return () unless @right;
	my @result;
	for @left -> $candidate {
		my $ok = True;
		for @right -> $rrow {
			my $found = @left.grep(-> $lrow {
				row-equal($lrow, $candidate) || (
					common-keys($lrow, $rrow).so
					&& join-on-common-keys($lrow, $rrow)
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
