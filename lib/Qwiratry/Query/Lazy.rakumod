=begin pod

Lazy, pull-driven query evaluation for set and relational operators.

C<select-seq> yields results incrementally so joins and set operations do not
materialize full intermediate relations before the first row is consumed.

=end pod
unit module Qwiratry::Query::Lazy;

use Qwiratry::Operator::Navigation;
use Qwiratry::Operator::Set;
use Qwiratry::Operator::MapReduce;
use Qwiratry::Operator::IO;
use Qwiratry::Query::Relational;

sub iterator-for(Mu $source --> Iterator) {
    return $source if $source ~~ Iterator;
    if $source ~~ Seq {
        return $source.iterator;
    }
    $source.list.iterator;
}

our sub lazy-natural-join($left, $right, &condition) is export {
    lazy gather {
        my $left-iter = iterator-for($left);
        loop {
            my $lrow = $left-iter.pull-one;
            last if $lrow ~~ IterationEnd;
            next unless $lrow ~~ Associative;
            my $right-iter = iterator-for($right);
            loop {
            my $rrow = $right-iter.pull-one;
            last if $rrow ~~ IterationEnd;
                next unless $rrow ~~ Associative;
                my $matches = &condition.defined
                    ?? condition($lrow, $rrow)
                    !! join-on-common-keys($lrow, $rrow);
                take merge-rows($lrow, $rrow) if $matches;
            }
        }
    }
}

our sub lazy-left-outer-join($left, $right, &condition) is export {
    lazy gather {
        my $left-iter = iterator-for($left);
        loop {
            my $lrow = $left-iter.pull-one;
            last if $lrow ~~ IterationEnd;
            my @matches;
            my $right-iter = iterator-for($right);
            loop {
            my $rrow = $right-iter.pull-one;
            last if $rrow ~~ IterationEnd;
                my $ok = &condition.defined
                    ?? condition($lrow, $rrow)
                    !! join-on-common-keys($lrow, $rrow);
                @matches.push(merge-rows($lrow, $rrow)) if $ok;
            }
            if @matches {
                take $_ for @matches;
            }
            else {
                take %($lrow);
            }
        }
    }
}

our sub lazy-right-outer-join($left, $right, &condition) is export {
    lazy gather {
        my $right-iter = iterator-for($right);
        loop {
            my $rrow = $right-iter.pull-one;
            last if $rrow ~~ IterationEnd;
            my @matches;
            my $left-iter = iterator-for($left);
            loop {
            my $lrow = $left-iter.pull-one;
            last if $lrow ~~ IterationEnd;
                my $ok = &condition.defined
                    ?? condition($lrow, $rrow)
                    !! join-on-common-keys($lrow, $rrow);
                @matches.push(merge-rows($lrow, $rrow)) if $ok;
            }
            if @matches {
                take $_ for @matches;
            }
            else {
                take %($rrow);
            }
        }
    }
}

our sub lazy-left-semijoin($left, $right, &condition) is export {
    lazy gather {
        my $left-iter = iterator-for($left);
        loop {
            my $lrow = $left-iter.pull-one;
            last if $lrow ~~ IterationEnd;
            my $right-iter = iterator-for($right);
            loop {
            my $rrow = $right-iter.pull-one;
            last if $rrow ~~ IterationEnd;
                my $ok = &condition.defined
                    ?? condition($lrow, $rrow)
                    !! join-on-common-keys($lrow, $rrow);
                if $ok {
                    take %($lrow);
                    last;
                }
            }
        }
    }
}

our sub lazy-left-antijoin($left, $right, &condition) is export {
    lazy gather {
        my $left-iter = iterator-for($left);
        loop {
            my $lrow = $left-iter.pull-one;
            last if $lrow ~~ IterationEnd;
            my $matched = False;
            my $right-iter = iterator-for($right);
            loop {
            my $rrow = $right-iter.pull-one;
            last if $rrow ~~ IterationEnd;
                my $ok = &condition.defined
                    ?? condition($lrow, $rrow)
                    !! join-on-common-keys($lrow, $rrow);
                if $ok {
                    $matched = True;
                    last;
                }
            }
            take %($lrow) unless $matched;
        }
    }
}

our sub lazy-cross-join($left, $right) is export {
    lazy gather {
        my $left-iter = iterator-for($left);
        loop {
            my $lrow = $left-iter.pull-one;
            last if $lrow ~~ IterationEnd;
            my $right-iter = iterator-for($right);
            loop {
            my $rrow = $right-iter.pull-one;
            last if $rrow ~~ IterationEnd;
                take merge-rows($lrow, $rrow);
            }
        }
    }
}

our sub lazy-union(*@sources) is export {
    my %seen;
    lazy gather {
        for @sources -> $source {
            my $iter = iterator-for($source);
            loop {
            my $row = $iter.pull-one;
            last if $row ~~ IterationEnd;
                my $key = row-key($row);
                unless %seen{$key}:exists {
                    %seen{$key} = True;
                    take $row;
                }
            }
        }
    }
}

our sub lazy-intersection($left, $right) is export {
    my @right-list = iterator-for($right).list;
    lazy gather {
        my $left-iter = iterator-for($left);
        loop {
            my $lrow = $left-iter.pull-one;
            last if $lrow ~~ IterationEnd;
            take $lrow if row-in-list($lrow, @right-list);
        }
    }
}

our sub lazy-set-difference($left, $right) is export {
    my @right-list = iterator-for($right).list;
    lazy gather {
        my $left-iter = iterator-for($left);
        loop {
            my $lrow = $left-iter.pull-one;
            last if $lrow ~~ IterationEnd;
            take $lrow unless row-in-list($lrow, @right-list);
        }
    }
}

our sub lazy-symmetric-difference($left, $right) is export {
    my @right-list = iterator-for($right).list;
    my @left-list = iterator-for($left).list;
    lazy gather {
        for @left-list -> $row {
            take $row unless row-in-list($row, @right-list);
        }
        for @right-list -> $row {
            take $row unless row-in-list($row, @left-list);
        }
    }
}

our sub lazy-projection($rows, @columns) is export {
    lazy gather {
        my $iter = iterator-for($rows);
        loop {
            my $row = $iter.pull-one;
            last if $row ~~ IterationEnd;
            take $row ~~ Associative ?? project-row($row, @columns) !! $row;
        }
    }
}

our sub lazy-filter($source, &match) is export {
    lazy gather {
        my $iter = iterator-for($source);
        loop {
            my $item = $iter.pull-one;
            last if $item ~~ IterationEnd;
            take $item if match($item);
        }
    }
}

our sub lazy-rename($rows, %renames) is export {
    lazy gather {
        my $iter = iterator-for($rows);
        loop {
            my $row = $iter.pull-one;
            last if $row ~~ IterationEnd;
            take $row ~~ Associative ?? rename-row($row, %renames) !! $row;
        }
    }
}

sub row-key(Mu $row --> Str) {
    if $row ~~ Associative {
        my @parts;
        for $row.keys.sort -> $key {
            @parts.push("$key=" ~($row{$key}));
        }
        return @parts.join('|');
    }
    return ~$row.WHICH if $row ~~ Mu;
    ~$row
}
