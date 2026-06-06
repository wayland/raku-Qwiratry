=begin pod

Query operator syntax: infix and postfix forms that build navigation Query AST nodes.

Load this module in any compunit that uses navigation operators such as C<⪪> or C<⇤>.

Example:

  use Qwiratry::Query::Slang;

  my $query = $root ⪪ * ⪪ <item>;
  my $parent = $node ⪫ * :reference;

=end pod
unit module Qwiratry::Query::Slang;

use Qwiratry::Operator::Navigation;

sub nav-new(
    Mu \type,
    Mu $subject,
    Mu $selector,
    |c,
) is export {
    type.new(:$subject, :$selector, |c)
}

multi sub infix:<⪪>(Mu $left, Mu $right) is export {
    nav-new(ChildOperator, $left, $right)
}

multi sub infix:<⪫>(Mu $left, Mu $right, *%adverbs) is export {
    nav-new(ParentOperator, $left, $right, |(%adverbs ?? :adverbs(%adverbs) !! |()))
}

multi sub infix:<⪪⪪>(Mu $left, Mu $right) is export {
    nav-new(DescendantOperator, $left, $right)
}

multi sub infix:<⪫⪫>(Mu $left, Mu $right) is export {
    nav-new(AncestorOperator, $left, $right)
}

multi sub infix:<⪨>(Mu $left, Mu $right) is export {
    nav-new(FollowingSiblingOperator, $left, $right)
}

multi sub infix:<⪩>(Mu $left, Mu $right) is export {
    nav-new(PrecedingSiblingOperator, $left, $right)
}

multi sub infix:<⪨⪨>(Mu $left, Mu $right) is export {
    nav-new(FollowingOperator, $left, $right)
}

multi sub infix:<⪩⪩>(Mu $left, Mu $right) is export {
    nav-new(PrecedingOperator, $left, $right)
}

multi sub infix:<⥷>(Mu $left, Mu $right) is export {
    AttributeOperator.new(:subject($left), :key($right))
}

multi sub postfix:<⇤>(Mu $subject) is export {
    RootOperator.new(:$subject)
}
