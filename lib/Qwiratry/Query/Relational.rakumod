=begin pod

Relational-algebra helpers for set operator execution in L<Qwiratry::Query::Match>.

=end pod
unit module Qwiratry::Query::Relational;

our sub row-equal(Mu $a, Mu $b --> Bool) is export {
    return $a === $b if $a ~~ Mu && $b ~~ Mu;
    if $a ~~ Associative && $b ~~ Associative {
        my @keys = ($a.keys.sort, $b.keys.sort).unique;
        for @keys -> $key {
            my $name = normalize-key-name($key);
            next unless $a{$name}:exists && $b{$name}:exists;
            return False unless ~($a{$name}) eq ~($b{$name});
        }
        return True;
    }
    ~$a eq ~$b
}

our sub row-in-list(Mu $row, @list --> Bool) is export {
    for @list -> $candidate {
        return True if row-equal($row, $candidate);
    }
    False
}

sub normalize-key-name(Mu $key --> Str) {
    return $key if $key ~~ Str;
    return $key.key if $key ~~ Pair;
    ~$key
}

our sub common-keys(Mu $left, Mu $right --> List) is export {
    return () unless $left ~~ Associative && $right ~~ Associative;
    my @left-keys = $left.keys.map(&normalize-key-name);
    my @right-keys = $right.keys.map(&normalize-key-name);
    (@left-keys (&) @right-keys).sort.List
}

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

our sub full-outer-join(@left, @right, &condition?) is export {
    my @inner = natural-join(@left, @right, &condition);
    my @left-only = left-antijoin(@left, @right, &condition);
    my @right-only = left-antijoin(@right, @left, &condition);
    my @result = @inner;
    @result.append(@left-only);
    @result.append(@right-only);
    @result
}

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

our sub right-semijoin(@left, @right, &condition?) is export {
    left-semijoin(@right, @left, &condition)
}

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

our sub right-antijoin(@left, @right, &condition?) is export {
    left-antijoin(@right, @left, &condition)
}

our sub cross-join(@left, @right) is export {
    my @result;
    for @left -> $lrow {
        for @right -> $rrow {
            @result.push(merge-rows($lrow, $rrow));
        }
    }
    @result
}

our sub project-row(Associative $row, @columns) is export {
    my %proj;
    for @columns -> $col {
        my $name = normalize-col-name($col);
        %proj{$name} = $row{$name} if $row{$name}:exists;
    }
    %proj
}

our sub rename-row(Associative $row, %renames) is export {
    my %result = %($row);
    for %renames.pairs -> $p {
        if %result{$p.key}:exists {
            %result{$p.value} = %result.delete($p.key);
        }
    }
    %result
}

sub normalize-col-name(Mu $col --> Str) {
    return $col if $col ~~ Str;
    if $col ~~ List && $col.elems == 1 {
        return normalize-col-name($col[0]);
    }
    my $name = ~$col;
    $name = $name.substr(1, *-2) if $name.starts-with('<') && $name.ends-with('>');
    $name
}

our sub is-subset-of(@left, @right --> Bool) is export {
    for @left -> $lrow {
        return False unless row-in-list($lrow, @right);
    }
    True
}

our sub collections-equal(@left, @right --> Bool) is export {
    return False unless @left.elems == @right.elems;
    for @left -> $lrow {
        return False unless row-in-list($lrow, @right);
    }
    True
}

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
