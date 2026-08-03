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
use Qwiratry::Query::NamedJoins;
use X::Qwiratry;
use nqp;

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

sub auto-query(Mu $query, Mu $fallback, *@values --> Mu) {
	build-query(|@values) ?? $query !! evaluate-query($query, $fallback)
}

sub auto-adaptor(Mu $query, Mu $fallback, *@values --> Mu) {
	build-query(|@values) ?? $query !! execute($query, :origin(query-origin($fallback)))
}

# Caller topic ($_) for bare navigation prefixes. $_ is not dynamic, so
# CALLER::<$_> fails; PseudoStash is also empty across compilation units.
# Callers pass nqp::ctxcaller(nqp::ctx()) from the prefix frame.
sub navigation-topic(Mu $caller-ctx --> Mu) {
	my Mu $got := nqp::getlexrel(nqp::decont($caller-ctx), '$_');
	my $topic = nqp::isnull($got) ?? Mu !! nqp::hllize($got);
	$topic.defined
		?? $topic
		!! X::Qwiratry::Operator.new(
			message => 'Navigation operator without a left-hand side requires a defined topic ($_)',
			:operator-type<Navigation>,
		).throw
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

Child sector (C<⪪>): direct children matching C<$right>.

Bare form (no LHS) uses the caller topic C<$_>.

=end pod
multi sub infix:<⪪>(Mu $left, Mu $right) is equiv(&infix:<x>) is export {
	my $query = nav-new(ChildOperator, $left, $right);
	build-query($left, $right) ?? $query !! evaluate-query($query, $left)
}

multi sub prefix:<⪪>(Mu $right) is export {
	my $left = navigation-topic(nqp::ctxcaller(nqp::ctx()));
	infix:<⪪>($left, $right)
}

=begin pod

Parent sector (C<⪫>): parent or referencing rows; C<:reference> for incoming FKs.

Bare form (no LHS) uses the caller topic C<$_>.

=end pod
multi sub infix:<⪫>(Mu $left, Mu $right, *%adverbs) is equiv(&infix:<x>) is export {
	my $query = nav-new(ParentOperator, $left, $right, |(%adverbs ?? :adverbs(%adverbs) !! |()));
	build-query($left, $right) ?? $query !! evaluate-query($query, $left)
}

multi sub prefix:<⪫>(Mu $right, *%adverbs) is export {
	my $left = navigation-topic(nqp::ctxcaller(nqp::ctx()));
	infix:<⪫>($left, $right, |%adverbs)
}

=begin pod

Descendant sector (C<⪪⪪>): nested children; C<:recursive> for table FK walks.

Bare form (no LHS) uses the caller topic C<$_>.

=end pod
multi sub infix:<⪪⪪>(Mu $left, Mu $right, *%adverbs) is equiv(&infix:<x>) is export {
	my $query = nav-new(DescendantOperator, $left, $right, |(%adverbs ?? :adverbs(%adverbs) !! |()));
	build-query($left, $right) ?? $query !! evaluate-query($query, $left)
}

multi sub prefix:<⪪⪪>(Mu $right, *%adverbs) is export {
	my $left = navigation-topic(nqp::ctxcaller(nqp::ctx()));
	infix:<⪪⪪>($left, $right, |%adverbs)
}

=begin pod

Ancestor sector (C<⪫⪫>): ancestor nodes matching C<$right>; C<:reference> for incoming FKs.

Bare form (no LHS) uses the caller topic C<$_>.

=end pod
multi sub infix:<⪫⪫>(Mu $left, Mu $right, *%adverbs) is equiv(&infix:<x>) is export {
	my $query = nav-new(AncestorOperator, $left, $right, |(%adverbs ?? :adverbs(%adverbs) !! |()));
	build-query($left, $right) ?? $query !! evaluate-query($query, $left)
}

multi sub prefix:<⪫⪫>(Mu $right, *%adverbs) is export {
	my $left = navigation-topic(nqp::ctxcaller(nqp::ctx()));
	infix:<⪫⪫>($left, $right, |%adverbs)
}

=begin pod

Following-sibling sector (C<⪨>): next sibling in document/table order.

Bare form (no LHS) uses the caller topic C<$_>.

=end pod
multi sub infix:<⪨>(Mu $left, Mu $right) is equiv(&infix:<x>) is export {
	my $query = nav-new(FollowingSiblingOperator, $left, $right);
	build-query($left, $right) ?? $query !! evaluate-query($query, $left)
}

multi sub prefix:<⪨>(Mu $right) is export {
	my $left = navigation-topic(nqp::ctxcaller(nqp::ctx()));
	infix:<⪨>($left, $right)
}

=begin pod

Preceding-sibling sector (C<⪩>): previous sibling in document/table order.

Bare form (no LHS) uses the caller topic C<$_>.

=end pod
multi sub infix:<⪩>(Mu $left, Mu $right) is equiv(&infix:<x>) is export {
	my $query = nav-new(PrecedingSiblingOperator, $left, $right);
	build-query($left, $right) ?? $query !! evaluate-query($query, $left)
}

multi sub prefix:<⪩>(Mu $right) is export {
	my $left = navigation-topic(nqp::ctxcaller(nqp::ctx()));
	infix:<⪩>($left, $right)
}

=begin pod

Following sector (C<⪨⪨>): all following nodes in order.

Bare form (no LHS) uses the caller topic C<$_>.

=end pod
multi sub infix:<⪨⪨>(Mu $left, Mu $right) is equiv(&infix:<x>) is export {
	my $query = nav-new(FollowingOperator, $left, $right);
	build-query($left, $right) ?? $query !! evaluate-query($query, $left)
}

multi sub prefix:<⪨⪨>(Mu $right) is export {
	my $left = navigation-topic(nqp::ctxcaller(nqp::ctx()));
	infix:<⪨⪨>($left, $right)
}

=begin pod

Preceding sector (C<⪩⪩>): all preceding nodes in order.

Bare form (no LHS) uses the caller topic C<$_>.

=end pod
multi sub infix:<⪩⪩>(Mu $left, Mu $right) is equiv(&infix:<x>) is export {
	my $query = nav-new(PrecedingOperator, $left, $right);
	build-query($left, $right) ?? $query !! evaluate-query($query, $left)
}

multi sub prefix:<⪩⪩>(Mu $right) is export {
	my $left = navigation-topic(nqp::ctxcaller(nqp::ctx()));
	infix:<⪩⪩>($left, $right)
}

=begin pod

Attribute sector (C<⥷>): read attribute or column C<$right> from C<$left>.

Bare form (no LHS) uses the caller topic C<$_>.

=end pod
multi sub infix:<⥷>(Mu $left, Mu $right) is equiv(&infix:<x>) is export {
	my $query = AttributeOperator.new(:subject($left), :key($right));
	build-query($left, $right) ?? $query !! evaluate-query($query, $left)
}

multi sub prefix:<⥷>(Mu $right) is export {
	my $left = navigation-topic(nqp::ctxcaller(nqp::ctx()));
	infix:<⥷>($left, $right)
}

=begin pod

Root postfix (C<⇤>): re-root the query at C<$subject>.

=end pod
multi sub postfix:<⇤>(Mu $subject) is export {
	my $query = RootOperator.new(:$subject);
	build-query($subject) ?? $query !! evaluate-query($query, $subject)
}

=begin pod

Named aliases for navigation sectors (Operators.md §5.1).

C<data-root> is a postfix; use unspace when a space is wanted (C<$node\ data-root>).

=end pod
multi sub infix:<child>(Mu $left, Mu $right) is equiv(&infix:<x>) is export {
	infix:<⪪>($left, $right)
}
multi sub infix:<parent>(Mu $left, Mu $right, *%adverbs) is equiv(&infix:<x>) is export {
	infix:<⪫>($left, $right, |%adverbs)
}
multi sub infix:<descendant>(Mu $left, Mu $right, *%adverbs) is equiv(&infix:<x>) is export {
	infix:<⪪⪪>($left, $right, |%adverbs)
}
multi sub infix:<ancestor>(Mu $left, Mu $right, *%adverbs) is equiv(&infix:<x>) is export {
	infix:<⪫⪫>($left, $right, |%adverbs)
}
multi sub infix:<attribute>(Mu $left, Mu $right) is equiv(&infix:<x>) is export {
	infix:<⥷>($left, $right)
}
multi sub postfix:<data-root>(Mu $subject) is export {
	postfix:<⇤>($subject)
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

multi sub infix:<∪>(Mu $left, Mu $right) is export {
	my $query = UnionOperator.new(:left($left), :right($right));
	auto-query($query, $left, $left, $right)
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

multi sub infix:<∩>(Mu $left, Mu $right) is export {
	my $query = IntersectionOperator.new(:left($left), :right($right));
	auto-query($query, $left, $left, $right)
}

=begin pod

Set difference (canonical C<⊟> U+229F; alias C<∖> U+2216).

=end pod
multi sub infix:<⊟>(OperatorBase $left, OperatorBase $right) is export {
	SetDifferenceOperator.new(:left($left), :right($right))
}

multi sub infix:<⊟>(OperatorBase $left, Mu $right) is export {
	SetDifferenceOperator.new(:left($left), :right($right))
}

multi sub infix:<⊟>(Mu $left, OperatorBase $right) is export {
	SetDifferenceOperator.new(:left($left), :right($right))
}

multi sub infix:<⊟>(Mu $left, Mu $right) is export {
	my $query = SetDifferenceOperator.new(:left($left), :right($right));
	auto-query($query, $left, $left, $right)
}

multi sub infix:<∖>(OperatorBase $left, OperatorBase $right) is export {
	infix:<⊟>($left, $right)
}

multi sub infix:<∖>(OperatorBase $left, Mu $right) is export {
	infix:<⊟>($left, $right)
}

multi sub infix:<∖>(Mu $left, OperatorBase $right) is export {
	infix:<⊟>($left, $right)
}

multi sub infix:<∖>(Mu $left, Mu $right) is export {
	infix:<⊟>($left, $right)
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

Selection alias (C<𜸈> U+1CE08): same as C<σ>.

=end pod
multi sub infix:<𜸈>(OperatorBase $left, &predicate) is equiv(&infix:<x>) is export {
	infix:<σ>($left, &predicate)
}

multi sub infix:<𜸈>(Mu $left, &predicate) is equiv(&infix:<x>) is export {
	infix:<σ>($left, &predicate)
}

multi sub prefix:<𜸈>(&predicate, Mu $subject) is export {
	prefix:<σ>(&predicate, $subject)
}

=begin pod

Sort (C<⇅>) by key function.

=end pod
multi sub infix:<⇅>(Mu $left, &key) is equiv(&infix:<x>) is export {
	my $query = SortOperator.new(:subject($left), :key-function(&key));
	auto-query($query, $left, $left)
}

=begin pod

Reduce (C<⌿>) with combining operation.

=end pod
multi sub infix:<⌿>(Mu $left, &operation) is equiv(&infix:<x>) is export {
	my $query = ReduceOperator.new(:subject($left), :operation(&operation));
	auto-query($query, $left, $left)
}

=begin pod

Map (C<».>) transform over query results.

=end pod
multi sub infix:<».>(OperatorBase $left, &transform) is equiv(&infix:<x>) is export {
	MapOperator.new(:subject($left), :transform(&transform))
}

multi sub infix:<».>(Mu $left, &transform) is equiv(&infix:<x>) is export {
	return MapOperator.new(:subject($left), :transform(&transform))
		if $*QWIRATRY-BUILD-QUERY;
	$left.map(&transform)
}

=begin pod

Symmetric difference (C<⊖>).

Positional candidates beat Raku core C<Set>/C<List> dispatch so C<query-ast>
builds Qwiratry nodes for relation arrays and lists.

=end pod
multi sub infix:<⊖>(OperatorBase $left, OperatorBase $right) is export {
	SymmetricDifferenceOperator.new(:left($left), :right($right))
}

multi sub infix:<⊖>(Positional $left, Positional $right) is export {
	my $query = SymmetricDifferenceOperator.new(:left($left), :right($right));
	auto-query($query, $left, $left, $right)
}

multi sub infix:<⊖>(Mu $left, Mu $right) is export {
	my $query = SymmetricDifferenceOperator.new(:left($left), :right($right));
	auto-query($query, $left, $left, $right)
}

=begin pod

Element-of membership (C<∈>).

=end pod
multi sub infix:<∈>(Mu $element, Mu $collection) is export {
	my $query = ElementOfOperator.new(:element($element), :collection($collection));
	auto-query($query, $collection, $element, $collection)
}

=begin pod

Contains (C<∋>) — collection contains element.

=end pod
multi sub infix:<∋>(Mu $collection, Mu $element) is export {
	my $query = ContainsOperator.new(:collection($collection), :element($element));
	auto-query($query, $collection, $collection, $element)
}

=begin pod

Proper subset (C<⊂>).

=end pod
multi sub infix:<⊂>(Mu $left, Mu $right) is export {
	my $query = SubsetOperator.new(:left($left), :right($right));
	auto-query($query, $left, $left, $right)
}

=begin pod

Subset or equal (C<⊆>).

=end pod
multi sub infix:<⊆>(Mu $left, Mu $right) is export {
	my $query = SubsetOrEqualOperator.new(:left($left), :right($right));
	auto-query($query, $left, $left, $right)
}

=begin pod

Identity comparison (C<≡>).

Positional candidates beat Raku core Boolean C<≡> so C<query-ast> builds
C<IdentityOperator> for relation arrays and lists.

=end pod
multi sub infix:<≡>(Positional $left, Positional $right) is export {
	my $query = IdentityOperator.new(:left($left), :right($right));
	auto-query($query, $left, $left, $right)
}

multi sub infix:<≡>(Mu $left, Mu $right) is export {
	my $query = IdentityOperator.new(:left($left), :right($right));
	auto-query($query, $left, $left, $right)
}

=begin pod

Universe-relative set operators (Operators.md §6.1.2.2).

Caller topic C<$_> is the universe (must be a superset of both operands).

=end pod
sub universe-from-caller(Mu $caller-ctx --> Mu) {
	navigation-topic($caller-ctx)
}

multi sub infix:<⩃>(Mu $left, Mu $right) is export {
	my $universe = universe-from-caller(nqp::ctxcaller(nqp::ctx()));
	my $query = SetDifferenceOperator.new(
		:left($universe),
		:right(IntersectionOperator.new(:left($left), :right($right))),
	);
	auto-query($query, $universe, $left, $right, $universe)
}

multi sub infix:<⩂>(Mu $left, Mu $right) is export {
	my $universe = universe-from-caller(nqp::ctxcaller(nqp::ctx()));
	my $query = SetDifferenceOperator.new(
		:left($universe),
		:right(UnionOperator.new(:left($left), :right($right))),
	);
	auto-query($query, $universe, $left, $right, $universe)
}

multi sub infix:<⊙>(Mu $left, Mu $right) is export {
	my $universe = universe-from-caller(nqp::ctxcaller(nqp::ctx()));
	my $query = SetDifferenceOperator.new(
		:left($universe),
		:right(SymmetricDifferenceOperator.new(:left($left), :right($right))),
	);
	auto-query($query, $universe, $left, $right, $universe)
}

multi sub infix:<⊡>(Mu $left, Mu $right) is export {
	my $universe = universe-from-caller(nqp::ctxcaller(nqp::ctx()));
	my $query = SetDifferenceOperator.new(
		:left($universe),
		:right(SetDifferenceOperator.new(:left($left), :right($right))),
	);
	auto-query($query, $universe, $left, $right, $universe)
}

=begin pod

Unary complement (C<∁>): C<$_ ⊟ operand> (Operators.md §6.1.2.2).

=end pod
multi sub prefix:<∁>(Mu $collection) is tighter(&infix:<&>) is export {
	my $universe = universe-from-caller(nqp::ctxcaller(nqp::ctx()));
	my $query = SetDifferenceOperator.new(:left($universe), :right($collection));
	auto-query($query, $universe, $collection, $universe)
}

=begin pod

Inner join (C<⨝>).

=end pod
multi sub infix:<⨝>(Mu $left, Mu $right, &condition?) is equiv(&infix:<~>) is export {
	my $query = InnerJoinOperator.new(:left($left), :right($right), :condition(&condition));
	auto-query($query, $left, $left, $right)
}

=begin pod

Equijoin (C<▷=◁>): inner join restricted to equality matching.

=end pod
multi sub infix:<▷=◁>(Mu $left, Mu $right, &condition?) is equiv(&infix:<~>) is export {
	my $query = EquijoinOperator.new(:left($left), :right($right), :condition(&condition));
	auto-query($query, $left, $left, $right)
}

=begin pod

Natural join (C<≜>): equijoin on shared column names.

=end pod
multi sub infix:<≜>(Mu $left, Mu $right) is equiv(&infix:<~>) is export {
	my $query = NaturalJoinOperator.new(:left($left), :right($right));
	auto-query($query, $left, $left, $right)
}

=begin pod

Named join recall (C<▵>): look up a join registered via
C<Qwiratry::Query::NamedJoins.instance.register(...)>.

=end pod
multi sub prefix:<▵>(Str $name) is export {
	my $query = NamedJoinOperator.new(:name($name));
	return $query if $*QWIRATRY-BUILD-QUERY;
	return $query unless Qwiratry::Query::NamedJoins.instance.lookup($name).defined;
	evaluate-query($query, Nil)
}

=begin pod

Left outer join (C<⟕>).

=end pod
multi sub infix:<⟕>(Mu $left, Mu $right, &condition?) is equiv(&infix:<~>) is export {
	my $query = LeftOuterJoinOperator.new(:left($left), :right($right), :condition(&condition));
	auto-query($query, $left, $left, $right)
}

=begin pod

Right outer join (C<⟖>).

=end pod
multi sub infix:<⟖>(Mu $left, Mu $right, &condition?) is equiv(&infix:<~>) is export {
	my $query = RightOuterJoinOperator.new(:left($left), :right($right), :condition(&condition));
	auto-query($query, $left, $left, $right)
}

=begin pod

Full outer join (C<⟗>).

=end pod
multi sub infix:<⟗>(Mu $left, Mu $right, &condition?) is equiv(&infix:<~>) is export {
	my $query = FullOuterJoinOperator.new(:left($left), :right($right), :condition(&condition));
	auto-query($query, $left, $left, $right)
}

=begin pod

Left semijoin (C<⋉>).

=end pod
multi sub infix:<⋉>(Mu $left, Mu $right, &condition?) is equiv(&infix:<~>) is export {
	my $query = LeftSemijoinOperator.new(:left($left), :right($right), :condition(&condition));
	auto-query($query, $left, $left, $right)
}

=begin pod

Right semijoin (C<⋊>).

=end pod
multi sub infix:<⋊>(Mu $left, Mu $right, &condition?) is equiv(&infix:<~>) is export {
	my $query = RightSemijoinOperator.new(:left($left), :right($right), :condition(&condition));
	auto-query($query, $left, $left, $right)
}

=begin pod

Left antijoin (C<▷>).

=end pod
multi sub infix:<▷>(Mu $left, Mu $right, &condition?) is equiv(&infix:<~>) is export {
	my $query = LeftAntijoinOperator.new(:left($left), :right($right), :condition(&condition));
	auto-query($query, $left, $left, $right)
}

=begin pod

Right antijoin (C<◁>).

=end pod
multi sub infix:<◁>(Mu $left, Mu $right, &condition?) is equiv(&infix:<~>) is export {
	my $query = RightAntijoinOperator.new(:left($left), :right($right), :condition(&condition));
	auto-query($query, $left, $left, $right)
}

=begin pod

Relational division (C<÷>).

=end pod
multi sub infix:<÷>(Mu $left, Mu $right) is export {
	my $query = DivisionOperator.new(:left($left), :right($right));
	auto-query($query, $left, $left, $right)
}

=begin pod

Cross join (C<×>): cartesian product (typed multis exclude numeric multiply).

=end pod
multi sub infix:<×>(Positional $left, Positional $right) is export {
	my $query = CrossJoinOperator.new(:left($left), :right($right));
	auto-query($query, $left, $left, $right)
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
	my $query = ProjectionOperator.new(:relation($relation), :columns(@columns));
	auto-query($query, $relation, $relation)
}

=begin pod

Rename (C<ρ>): rename columns in a relation.

=end pod
multi sub prefix:<ρ>(Mu $relation, *%renames) is export {
	my $query = RenameOperator.new(:relation($relation), :renames(%renames));
	auto-query($query, $relation, $relation)
}

=begin pod

Power set (canonical C<𝒫> U+1D4AB; alias C<℘> U+2118): all subsets of a collection (Operators.md §6.1.3).

=end pod
multi sub prefix:<℘>(Mu $collection) is export {
	my $query = PowerSetOperator.new(:collection($collection));
	auto-query($query, $collection, $collection)
}

multi sub prefix:<𝒫>(Mu $collection) is export {
	my $query = PowerSetOperator.new(:collection($collection));
	auto-query($query, $collection, $collection)
}

=begin pod

Source prefix (C<⮳>): read from a location string.

=end pod
multi sub prefix:<⮳>(Mu $location) is export {
	my $query = SourceOperator.new(location => ~$location);
	auto-adaptor($query, $location, $location)
}

=begin pod

Parse infix (C<↱>): parse subject data with format C<$right>.

=end pod
multi sub infix:<↱>(Mu $left, Mu $right) is equiv(&infix:<x>) is export {
	my $query = ParseOperator.new(:subject($left), :format(~$right));
	auto-adaptor($query, $left, $left, $right)
}

=begin pod

Render infix (C<↴>): render subject data to format C<$right>.

=end pod
multi sub infix:<↴>(Mu $left, Mu $right, *%adverbs) is equiv(&infix:<x>) is export {
	my $query = RenderOperator.new(:subject($left), :format(~$right), :options(%adverbs));
	auto-adaptor($query, $left, $left, $right)
}

=begin pod

Destination infix (C<⮷>): write pipeline output to location C<$right>.

=end pod
multi sub infix:<⮷>(Mu $left, Mu $right) is equiv(&infix:<x>) is export {
	my $query = DestinationOperator.new(:subject($left), :location(~$right));
	auto-adaptor($query, $left, $left, $right)
}
