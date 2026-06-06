=begin pod

Calculate template ordering specificity scores from navigation Query AST nodes.

Scoring follows Specification.md section 3.3.2.4 (ORDER-TEMPLATES):

- Multilevel axes (descendant, ancestor, following, preceding) -> -100
- Wildcards -> -10
- Explicit path elements -> +5
- Attribute axes -> +5

=end pod
unit module Qwiratry::Query::Specificity;

use Qwiratry::Operator::Navigation;
use Qwiratry::Operator::Capability;
use Qwiratry::Operator::Set;
use Qwiratry::Operator::MapReduce;

=begin pod

Return a specificity score for a query AST fragment. Higher scores are more specific.

Nested navigation operators accumulate scores from subject chains. Union-like
structures (Positional lists of queries) use the maximum branch score.

=end pod
sub is-union-query(Mu $query --> Bool) {
    return False unless $query.WHAT === Array || $query.WHAT === List;
    $query.elems > 0 && $query[0] ~~ NavigationOperator;
}

our sub score(Mu $query --> Int) is export {
    return 0 unless $query.defined;

    if $query ~~ NavigationOperator {
        my $total = operator-contribution($query);
        if $query.can('subject') && $query.subject.defined {
            $total += score($query.subject);
        }
        return $total;
    }

    if is-union-query($query) {
        my $max = 0;
        for $query.list -> $branch {
            my $branch-score = score($branch);
            $max = $branch-score if $branch-score > $max;
        }
        return $max;
    }

    if $query ~~ UnionOperator | IntersectionOperator | SetDifferenceOperator {
        my $left = score($query.left);
        my $right = score($query.right);
        return $left > $right ?? $left !! $right;
    }

    if $query ~~ SelectionOperator {
        return score($query.subject);
    }

    0;
}

sub operator-contribution(Mu $op --> Int) {
    given $op {
        when DescendantOperator | AncestorOperator | FollowingOperator | PrecedingOperator {
            selector-contribution($op.selector) - 100;
        }
        when AttributeOperator {
            selector-contribution($op.key) + 5;
        }
        when RootOperator {
            0;
        }
        when ChildOperator | ParentOperator | FollowingSiblingOperator | PrecedingSiblingOperator {
            selector-contribution($op.selector);
        }
        default {
            0;
        }
    }
}

sub selector-contribution(Mu $selector --> Int) {
    return -10 if is-wildcard-selector($selector);
    return 5 if is-explicit-path-selector($selector);
    0;
}

sub is-wildcard-selector(Mu $selector --> Bool) {
    return True if $selector ~~ Whatever;
    return True if $selector ~~ Str && $selector eq any(<* **>);
    False;
}

sub is-explicit-path-selector(Mu $selector --> Bool) {
    return False unless $selector.defined;
    return False if is-wildcard-selector($selector);
    return True if $selector ~~ Str && $selector.chars > 0;
    return True if $selector ~~ Callable;
    False;
}
