=begin pod

Query operator syntax: infix and postfix forms that build navigation Query AST nodes.

Load this module in any compunit that uses navigation operators such as C<⪪> or C<⇤>.
Cross join uses C<×> (U+00D7) with typed multis so numeric C<3 × 4> still works.

Example:

  use Qwiratry::Query::Slang;

  my $query = $root ⪪ * ⪪ <item>;
  my $parent = $node ⪫ * :reference;
  my $cartesian = @left × @right;

=end pod
unit module Qwiratry::Query::Slang;

use Qwiratry::Operator::Navigation;
use Qwiratry::Operator::Set;
use Qwiratry::Operator::MapReduce;
use Qwiratry::Operator::IO;
use Qwiratry::Operator::Capability;

sub set-new(Mu \type, Mu $left, Mu $right, |c) is export {
    type.new(:left($left), :right($right), |c)
}

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

multi sub infix:<∪>(OperatorBase $left, OperatorBase $right) is export {
    UnionOperator.new(:left($left), :right($right))
}

multi sub infix:<∪>(OperatorBase $left, Mu $right) is export {
    UnionOperator.new(:left($left), :right($right))
}

multi sub infix:<∪>(Mu $left, OperatorBase $right) is export {
    UnionOperator.new(:left($left), :right($right))
}

multi sub infix:<∩>(OperatorBase $left, OperatorBase $right) is export {
    IntersectionOperator.new(:left($left), :right($right))
}

multi sub infix:<∩>(OperatorBase $left, Mu $right) is export {
    IntersectionOperator.new(:left($left), :right($right))
}

multi sub infix:<∩>(Mu $left, OperatorBase $right) is export {
    IntersectionOperator.new(:left($left), :right($right))
}

multi sub infix:<∖>(OperatorBase $left, OperatorBase $right) is export {
    SetDifferenceOperator.new(:left($left), :right($right))
}

multi sub infix:<∖>(OperatorBase $left, Mu $right) is export {
    SetDifferenceOperator.new(:left($left), :right($right))
}

multi sub infix:<∖>(Mu $left, OperatorBase $right) is export {
    SetDifferenceOperator.new(:left($left), :right($right))
}

multi sub infix:<σ>(OperatorBase $left, &predicate) is export {
    SelectionOperator.new(:subject($left), :predicate(&predicate))
}

multi sub infix:<σ>(Mu $left, &predicate) is export {
    SelectionOperator.new(:subject($left), :predicate(&predicate))
}

multi sub prefix:<σ>(&predicate, Mu $subject) is export {
    SelectionOperator.new(:subject($subject), :predicate(&predicate))
}

multi sub infix:<⇅>(Mu $left, &key) is export {
    SortOperator.new(:subject($left), :key-function(&key))
}

multi sub infix:<⌿>(Mu $left, &operation) is export {
    ReduceOperator.new(:subject($left), :operation(&operation))
}

multi sub infix:<».>(OperatorBase $left, &transform) is export {
    MapOperator.new(:subject($left), :transform(&transform))
}

multi sub infix:<».>(Mu $left, &transform) is export {
    MapOperator.new(:subject($left), :transform(&transform))
}

multi sub infix:<⊖>(OperatorBase $left, OperatorBase $right) is export {
    SymmetricDifferenceOperator.new(:left($left), :right($right))
}

multi sub infix:<⊖>(Mu $left, Mu $right) is export {
    SymmetricDifferenceOperator.new(:left($left), :right($right))
}

multi sub infix:<∈>(Mu $element, Mu $collection) is export {
    ElementOfOperator.new(:element($element), :collection($collection))
}

multi sub infix:<∋>(Mu $collection, Mu $element) is export {
    ContainsOperator.new(:collection($collection), :element($element))
}

multi sub infix:<⊂>(Mu $left, Mu $right) is export {
    SubsetOperator.new(:left($left), :right($right))
}

multi sub infix:<⊆>(Mu $left, Mu $right) is export {
    SubsetOrEqualOperator.new(:left($left), :right($right))
}

multi sub infix:<≡>(Mu $left, Mu $right) is export {
    IdentityOperator.new(:left($left), :right($right))
}

multi sub infix:<⨝>(Mu $left, Mu $right, &condition?) is export {
    InnerJoinOperator.new(:left($left), :right($right), :condition(&condition))
}

multi sub infix:<⟕>(Mu $left, Mu $right, &condition?) is export {
    LeftOuterJoinOperator.new(:left($left), :right($right), :condition(&condition))
}

multi sub infix:<⟖>(Mu $left, Mu $right, &condition?) is export {
    RightOuterJoinOperator.new(:left($left), :right($right), :condition(&condition))
}

multi sub infix:<⟗>(Mu $left, Mu $right, &condition?) is export {
    FullOuterJoinOperator.new(:left($left), :right($right), :condition(&condition))
}

multi sub infix:<⋉>(Mu $left, Mu $right, &condition?) is export {
    LeftSemijoinOperator.new(:left($left), :right($right), :condition(&condition))
}

multi sub infix:<⋊>(Mu $left, Mu $right, &condition?) is export {
    RightSemijoinOperator.new(:left($left), :right($right), :condition(&condition))
}

multi sub infix:<▷>(Mu $left, Mu $right, &condition?) is export {
    LeftAntijoinOperator.new(:left($left), :right($right), :condition(&condition))
}

multi sub infix:<◁>(Mu $left, Mu $right, &condition?) is export {
    RightAntijoinOperator.new(:left($left), :right($right), :condition(&condition))
}

multi sub infix:<÷>(Mu $left, Mu $right) is export {
    DivisionOperator.new(:left($left), :right($right))
}

multi sub infix:<×>(Positional $left, Positional $right) is export {
    CrossJoinOperator.new(:left($left), :right($right))
}

multi sub infix:<×>(OperatorBase $left, Mu $right) is export {
    CrossJoinOperator.new(:left($left), :right($right))
}

multi sub infix:<×>(Mu $left, OperatorBase $right) is export {
    CrossJoinOperator.new(:left($left), :right($right))
}

multi sub prefix:<Π>(Mu $relation, *@columns) is export {
    ProjectionOperator.new(:relation($relation), :columns(@columns))
}

multi sub prefix:<ρ>(Mu $relation, *%renames) is export {
    RenameOperator.new(:relation($relation), :renames(%renames))
}

multi sub prefix:<⮳>(Mu $location) is export {
    SourceOperator.new(location => ~$location)
}

multi sub infix:<↱>(Mu $left, Mu $right) is export {
    ParseOperator.new(:subject($left), :format(~$right))
}

multi sub infix:<↴>(Mu $left, Mu $right, *%adverbs) is export {
    RenderOperator.new(:subject($left), :format(~$right), :options(%adverbs))
}

multi sub infix:<⮷>(Mu $left, Mu $right) is export {
    DestinationOperator.new(:subject($left), :location(~$right))
}
