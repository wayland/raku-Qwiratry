=begin pod

Query operator syntax: infix and prefix forms that evaluate query AST nodes.

Load this module in any compunit that uses navigation operators such as C<⪪> or C<⇤>.
Cross join uses C<×> (U+00D7) with typed multis so numeric C<3 × 4> still works.
Set, map-reduce, relational, and I/O operators share the same slang surface.
Use C<query-ast { ... }> when a planner, mold, or explicit runtime call needs the raw
Qwiratry query AST instead of the evaluated C<Seq>.

Example:

=begin code
use Qwiratry::Query::Slang;

my @items = $root ⪪ * ⪪ <item>;
my @parents = $node ⪫ * :reference;
my $query = query-ast({ $root ⪪ * ⪪ <item> });
my $cartesian = @left × @right;
=end code

=end pod
use v6.e.PREVIEW;

use Qwiratry::Operator::Navigation;
use Qwiratry::Operator::Set;
use Qwiratry::Operator::MapReduce;
use Qwiratry::Operator::IO;
use Qwiratry::Operator::Capability;
use Qwiratry::Query::Topic;

our $*QWIRATRY-BUILD-QUERY is export = False;
our $*QWIRATRY-DATA-ROOT is export = Nil;

sub query-ast(&block) is export {
	my $*QWIRATRY-BUILD-QUERY = True;
	block()
}

sub term:<root>() is export {
	$*QWIRATRY-DATA-ROOT
}

sub given-root(Mu $root, &block) is export {
	my $*QWIRATRY-DATA-ROOT = $root;
	block()
}

sub build-query(*@values --> Bool) {
	$*QWIRATRY-BUILD-QUERY
		|| @values.grep({ $_ ~~ OperatorBase | NavQueryTopic }).so
}

sub query-origin(Mu $fallback --> Mu) {
	$*QWIRATRY-DATA-ROOT // $fallback
}

sub evaluate-query(Mu $query, Mu $fallback --> Seq) {
	require ::('Qwiratry::Query::Runtime');
	::('Qwiratry::Query::Runtime').instance.select($query, query-origin($fallback))
}

=begin pod

Construct a binary set operator AST node.

=end pod
sub set-new(Mu \type, Mu $left, Mu $right, |c) is export {
	type.new(:left($left), :right($right), |c)
}

=begin pod

Construct a navigation operator AST node with subject and selector.

=end pod
sub nav-new(
	Mu \type,
	Mu $subject,
	Mu $selector,
	|c,
) is export {
	type.new(:$subject, :$selector, |c)
}

=begin pod

Child axis (C<⪪>): direct children matching C<$right>.

=end pod
multi sub infix:<⪪>(Mu $left, Mu $right) is equiv(&infix:<x>) is export {
	my $query = nav-new(ChildOperator, $left, $right);
	build-query($left, $right) ?? $query !! evaluate-query($query, $left)
}

=begin pod

Parent axis (C<⪫>): parent or referencing rows; C<:reference> for incoming FKs.

=end pod
multi sub infix:<⪫>(Mu $left, Mu $right, *%adverbs) is equiv(&infix:<x>) is export {
	my $query = nav-new(ParentOperator, $left, $right, |(%adverbs ?? :adverbs(%adverbs) !! |()));
	build-query($left, $right) ?? $query !! evaluate-query($query, $left)
}

=begin pod

Descendant axis (C<⪪⪪>): nested children; C<:recursive> for table FK walks.

=end pod
multi sub infix:<⪪⪪>(Mu $left, Mu $right, *%adverbs) is equiv(&infix:<x>) is export {
	my $query = nav-new(DescendantOperator, $left, $right, |(%adverbs ?? :adverbs(%adverbs) !! |()));
	build-query($left, $right) ?? $query !! evaluate-query($query, $left)
}

=begin pod

Ancestor axis (C<⪫⪫>): ancestor nodes matching C<$right>.

=end pod
multi sub infix:<⪫⪫>(Mu $left, Mu $right) is equiv(&infix:<x>) is export {
	my $query = nav-new(AncestorOperator, $left, $right);
	build-query($left, $right) ?? $query !! evaluate-query($query, $left)
}

=begin pod

Following-sibling axis (C<⪨>): next sibling in document/table order.

=end pod
multi sub infix:<⪨>(Mu $left, Mu $right) is equiv(&infix:<x>) is export {
	my $query = nav-new(FollowingSiblingOperator, $left, $right);
	build-query($left, $right) ?? $query !! evaluate-query($query, $left)
}

=begin pod

Preceding-sibling axis (C<⪩>): previous sibling in document/table order.

=end pod
multi sub infix:<⪩>(Mu $left, Mu $right) is equiv(&infix:<x>) is export {
	my $query = nav-new(PrecedingSiblingOperator, $left, $right);
	build-query($left, $right) ?? $query !! evaluate-query($query, $left)
}

=begin pod

Following axis (C<⪨⪨>): all following nodes in order.

=end pod
multi sub infix:<⪨⪨>(Mu $left, Mu $right) is equiv(&infix:<x>) is export {
	my $query = nav-new(FollowingOperator, $left, $right);
	build-query($left, $right) ?? $query !! evaluate-query($query, $left)
}

=begin pod

Preceding axis (C<⪩⪩>): all preceding nodes in order.

=end pod
multi sub infix:<⪩⪩>(Mu $left, Mu $right) is equiv(&infix:<x>) is export {
	my $query = nav-new(PrecedingOperator, $left, $right);
	build-query($left, $right) ?? $query !! evaluate-query($query, $left)
}

=begin pod

Attribute axis (C<⥷>): read attribute or column C<$right> from C<$left>.

=end pod
multi sub infix:<⥷>(Mu $left, Mu $right) is equiv(&infix:<x>) is export {
	my $query = AttributeOperator.new(:subject($left), :key($right));
	build-query($left, $right) ?? $query !! evaluate-query($query, $left)
}

=begin pod

Root postfix (C<⇤>): re-root the query at C<$subject>.

=end pod
multi sub postfix:<⇤>(Mu $subject) is export {
	my $query = RootOperator.new(:$subject);
	build-query($subject) ?? $query !! evaluate-query($query, $subject)
}

=begin pod

Set union (C<∪>).

=end pod
multi sub infix:<∪>(OperatorBase $left, OperatorBase $right) is export {
	UnionOperator.new(:left($left), :right($right))
}

multi sub infix:<∪>(OperatorBase $left, Mu $right) is export {
	UnionOperator.new(:left($left), :right($right))
}

multi sub infix:<∪>(Mu $left, OperatorBase $right) is export {
	UnionOperator.new(:left($left), :right($right))
}

=begin pod

Set intersection (C<∩>).

=end pod
multi sub infix:<∩>(OperatorBase $left, OperatorBase $right) is export {
	IntersectionOperator.new(:left($left), :right($right))
}

multi sub infix:<∩>(OperatorBase $left, Mu $right) is export {
	IntersectionOperator.new(:left($left), :right($right))
}

multi sub infix:<∩>(Mu $left, OperatorBase $right) is export {
	IntersectionOperator.new(:left($left), :right($right))
}

=begin pod

Set difference (C<∖>).

=end pod
multi sub infix:<∖>(OperatorBase $left, OperatorBase $right) is export {
	SetDifferenceOperator.new(:left($left), :right($right))
}

multi sub infix:<∖>(OperatorBase $left, Mu $right) is export {
	SetDifferenceOperator.new(:left($left), :right($right))
}

multi sub infix:<∖>(Mu $left, OperatorBase $right) is export {
	SetDifferenceOperator.new(:left($left), :right($right))
}

=begin pod

Selection / filter (C<σ>): keep rows matching C<&predicate>.

=end pod
multi sub infix:<σ>(OperatorBase $left, &predicate) is equiv(&infix:<x>) is export {
	SelectionOperator.new(:subject($left), :predicate(&predicate))
}

multi sub infix:<σ>(Mu $left, &predicate) is equiv(&infix:<x>) is export {
	my $query = SelectionOperator.new(:subject($left), :predicate(&predicate));
	build-query($left) ?? $query !! evaluate-query($query, $left)
}

multi sub prefix:<σ>(&predicate, Mu $subject) is export {
	my $query = SelectionOperator.new(:subject($subject), :predicate(&predicate));
	build-query($subject) ?? $query !! evaluate-query($query, $subject)
}

=begin pod

Sort (C<⇅>) by key function.

=end pod
multi sub infix:<⇅>(Mu $left, &key) is equiv(&infix:<x>) is export {
	SortOperator.new(:subject($left), :key-function(&key))
}

=begin pod

Reduce (C<⌿>) with combining operation.

=end pod
multi sub infix:<⌿>(Mu $left, &operation) is equiv(&infix:<x>) is export {
	ReduceOperator.new(:subject($left), :operation(&operation))
}

=begin pod

Map (C<».>) transform over query results.

=end pod
multi sub infix:<».>(OperatorBase $left, &transform) is equiv(&infix:<x>) is export {
	MapOperator.new(:subject($left), :transform(&transform))
}

multi sub infix:<».>(Mu $left, &transform) is equiv(&infix:<x>) is export {
	MapOperator.new(:subject($left), :transform(&transform))
}

=begin pod

Symmetric difference (C<⊖>).

=end pod
multi sub infix:<⊖>(OperatorBase $left, OperatorBase $right) is export {
	SymmetricDifferenceOperator.new(:left($left), :right($right))
}

multi sub infix:<⊖>(Mu $left, Mu $right) is export {
	SymmetricDifferenceOperator.new(:left($left), :right($right))
}

=begin pod

Element-of membership (C<∈>).

=end pod
multi sub infix:<∈>(Mu $element, Mu $collection) is export {
	ElementOfOperator.new(:element($element), :collection($collection))
}

=begin pod

Contains (C<∋>) — collection contains element.

=end pod
multi sub infix:<∋>(Mu $collection, Mu $element) is export {
	ContainsOperator.new(:collection($collection), :element($element))
}

=begin pod

Proper subset (C<⊂>).

=end pod
multi sub infix:<⊂>(Mu $left, Mu $right) is export {
	SubsetOperator.new(:left($left), :right($right))
}

=begin pod

Subset or equal (C<⊆>).

=end pod
multi sub infix:<⊆>(Mu $left, Mu $right) is export {
	SubsetOrEqualOperator.new(:left($left), :right($right))
}

=begin pod

Identity comparison (C<≡>).

=end pod
multi sub infix:<≡>(Mu $left, Mu $right) is export {
	IdentityOperator.new(:left($left), :right($right))
}

=begin pod

Inner join (C<⨝>).

=end pod
multi sub infix:<⨝>(Mu $left, Mu $right, &condition?) is equiv(&infix:<~>) is export {
	InnerJoinOperator.new(:left($left), :right($right), :condition(&condition))
}

=begin pod

Left outer join (C<⟕>).

=end pod
multi sub infix:<⟕>(Mu $left, Mu $right, &condition?) is equiv(&infix:<~>) is export {
	LeftOuterJoinOperator.new(:left($left), :right($right), :condition(&condition))
}

=begin pod

Right outer join (C<⟖>).

=end pod
multi sub infix:<⟖>(Mu $left, Mu $right, &condition?) is equiv(&infix:<~>) is export {
	RightOuterJoinOperator.new(:left($left), :right($right), :condition(&condition))
}

=begin pod

Full outer join (C<⟗>).

=end pod
multi sub infix:<⟗>(Mu $left, Mu $right, &condition?) is equiv(&infix:<~>) is export {
	FullOuterJoinOperator.new(:left($left), :right($right), :condition(&condition))
}

=begin pod

Left semijoin (C<⋉>).

=end pod
multi sub infix:<⋉>(Mu $left, Mu $right, &condition?) is equiv(&infix:<~>) is export {
	LeftSemijoinOperator.new(:left($left), :right($right), :condition(&condition))
}

=begin pod

Right semijoin (C<⋊>).

=end pod
multi sub infix:<⋊>(Mu $left, Mu $right, &condition?) is equiv(&infix:<~>) is export {
	RightSemijoinOperator.new(:left($left), :right($right), :condition(&condition))
}

=begin pod

Left antijoin (C<▷>).

=end pod
multi sub infix:<▷>(Mu $left, Mu $right, &condition?) is equiv(&infix:<~>) is export {
	LeftAntijoinOperator.new(:left($left), :right($right), :condition(&condition))
}

=begin pod

Right antijoin (C<◁>).

=end pod
multi sub infix:<◁>(Mu $left, Mu $right, &condition?) is equiv(&infix:<~>) is export {
	RightAntijoinOperator.new(:left($left), :right($right), :condition(&condition))
}

=begin pod

Relational division (C<÷>).

=end pod
multi sub infix:<÷>(Mu $left, Mu $right) is export {
	DivisionOperator.new(:left($left), :right($right))
}

=begin pod

Cross join (C<×>): cartesian product (typed multis exclude numeric multiply).

=end pod
multi sub infix:<×>(Positional $left, Positional $right) is export {
	CrossJoinOperator.new(:left($left), :right($right))
}

multi sub infix:<×>(OperatorBase $left, Mu $right) is export {
	CrossJoinOperator.new(:left($left), :right($right))
}

multi sub infix:<×>(Mu $left, OperatorBase $right) is export {
	CrossJoinOperator.new(:left($left), :right($right))
}

=begin pod

Projection (C<Π>): select columns from a relation.

=end pod
multi sub prefix:<Π>(Mu $relation, *@columns) is export {
	ProjectionOperator.new(:relation($relation), :columns(@columns))
}

=begin pod

Rename (C<ρ>): rename columns in a relation.

=end pod
multi sub prefix:<ρ>(Mu $relation, *%renames) is export {
	RenameOperator.new(:relation($relation), :renames(%renames))
}

=begin pod

Source prefix (C<⮳>): read from a location string.

=end pod
multi sub prefix:<⮳>(Mu $location) is export {
	SourceOperator.new(location => ~$location)
}

=begin pod

Parse infix (C<↱>): parse subject data with format C<$right>.

=end pod
multi sub infix:<↱>(Mu $left, Mu $right) is equiv(&infix:<x>) is export {
	ParseOperator.new(:subject($left), :format(~$right))
}

=begin pod

Render infix (C<↴>): render subject data to format C<$right>.

=end pod
multi sub infix:<↴>(Mu $left, Mu $right, *%adverbs) is equiv(&infix:<x>) is export {
	RenderOperator.new(:subject($left), :format(~$right), :options(%adverbs))
}

=begin pod

Destination infix (C<⮷>): write pipeline output to location C<$right>.

=end pod
multi sub infix:<⮷>(Mu $left, Mu $right) is equiv(&infix:<x>) is export {
	DestinationOperator.new(:subject($left), :location(~$right))
}
