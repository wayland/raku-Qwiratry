=begin pod

Extract navigation Query AST values from template C<when> blocks.

When blocks such as C<when { $_ ⪪⪪ <item> }> build navigation operators at
runtime with C<$_> as the subject. A sentinel L<NavQueryTopic|Qwiratry::Query::Match::NavQueryTopic>
stands in for C<$_> during extraction so the query can be stored on the template
for specificity scoring and matching.

=end pod
unit module Qwiratry::Query::Extract;

use Qwiratry::Operator::Navigation;
use Qwiratry::Operator::Capability;
use Qwiratry::Query::Match;

=begin pod

Run C<$when-block> with L<NavQueryTopic> as C<$_> and return a navigation
operator when the block body is a pure query expression.

=end pod
our sub extract-navigation-query(Block $when-block --> Mu) is export {
    my $result = try { $when-block(NavQueryTopic.new) };
    return $result if $result ~~ NavigationOperator;
    Nil
}

=begin pod

Return True when C<$when-block> always evaluates to the same navigation operator
shape (varying only in the C<$_> subject).

=end pod
our sub is-navigation-query-when(Block $when-block --> Bool) is export {
    my $with-topic = extract-navigation-query($when-block);
    return False unless $with-topic.defined;

    my $with-scalar = try { $when-block(42) };
    return False unless $with-scalar ~~ NavigationOperator;
    return False unless $with-scalar.^name eq $with-topic.^name;
    return False unless selectors-equivalent($with-topic, $with-scalar);
    True
}

sub selectors-equivalent(Mu $a, Mu $b --> Bool) {
    return False unless $a.can('selector') && $b.can('selector');
    my $left = $a.selector;
    my $right = $b.selector;
    return True if !$left.defined && !$right.defined;
    return False unless $left.defined && $right.defined;
    return $left eqv $right if $left ~~ Str && $right ~~ Str;
    $left.gist eq $right.gist
}
