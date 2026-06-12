=begin pod

Relational-algebra helpers for set operator execution in L<Qwiratry::Query::Match>.

Pure functions over row lists and associative rows: equality, joins, projections,
and set operations used when evaluating lazy and eager query pipelines.

=end pod
unit class Qwiratry::Query::Relational;

my $instance;

method instance(--> Qwiratry::Query::Relational) {
	$instance //= self.new
}

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

method row-in-list(Mu $row, @list --> Bool) {
	for @list -> $candidate {
		return True if self.row-equal($row, $candidate);
	}
	False
}

method node-in-list(Mu $node, @list --> Bool) {
	for @list -> $candidate {
		return True if $candidate === $node;
		return True if $node ~~ Associative && $candidate ~~ Associative
			&& self.row-equal($node, $candidate);
	}
	False
}

method common-keys(Mu $left, Mu $right --> List) {
	return () unless $left ~~ Associative && $right ~~ Associative;
	my @left-keys = $left.keys.map({ self!normalize-key-name($_) });
	my @right-keys = $right.keys.map({ self!normalize-key-name($_) });
	(@left-keys (&) @right-keys).sort.List
}

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

method full-outer-join(@left, @right, &condition?) {
	my @inner = self.natural-join(@left, @right, &condition);
	my @left-only = self.left-antijoin(@left, @right, &condition);
	my @right-only = self.left-antijoin(@right, @left, &condition);
	my @result = @inner;
	@result.append(@left-only);
	@result.append(@right-only);
	@result
}

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

method right-semijoin(@left, @right, &condition?) {
	self.left-semijoin(@right, @left, &condition)
}

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

method right-antijoin(@left, @right, &condition?) {
	self.left-antijoin(@right, @left, &condition)
}

method cross-join(@left, @right) {
	my @result;
	for @left -> $lrow {
		for @right -> $rrow {
			@result.push(self.merge-rows($lrow, $rrow));
		}
	}
	@result
}

method project-row(Associative $row, @columns) {
	my %proj;
	for @columns -> $col {
		my $name = self!normalize-col-name($col);
		%proj{$name} = $row{$name} if $row{$name}:exists;
	}
	%proj
}

method rename-row(Associative $row, %renames) {
	my %result = %($row);
	for %renames.pairs -> $p {
		if %result{$p.key}:exists {
			%result{$p.value} = %result.delete($p.key);
		}
	}
	%result
}

method is-subset-of(@left, @right --> Bool) {
	for @left -> $lrow {
		return False unless self.row-in-list($lrow, @right);
	}
	True
}

method collections-equal(@left, @right --> Bool) {
	return False unless @left.elems == @right.elems;
	for @left -> $lrow {
		return False unless self.row-in-list($lrow, @right);
	}
	True
}

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

method !normalize-key-name(Mu $key --> Str) {
	return $key if $key ~~ Str;
	return $key.key if $key ~~ Pair;
	~$key
}

method !normalize-col-name(Mu $col --> Str) {
	return $col if $col ~~ Str;
	if $col ~~ List && $col.elems == 1 {
		return self!normalize-col-name($col[0]);
	}
	my $name = ~$col;
	$name = $name.substr(1, *-2) if $name.starts-with('<') && $name.ends-with('>');
	$name
}
