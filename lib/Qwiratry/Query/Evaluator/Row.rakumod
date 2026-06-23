=begin pod

=head1 Overview

Lazy evaluators for row-shaping relational operators.

=end pod
unit module Qwiratry::Query::Evaluator::Row;

use Qwiratry::Operator::Set;
use Qwiratry::Query::Evaluator::Lazy;

=begin pod

=head2 C<role RowShapingEvaluator>

=begin code :lang<raku>
role RowShapingEvaluator does LazyEvaluator
=end code

Defines C<RowShapingEvaluator>.

=end pod
role RowShapingEvaluator does LazyEvaluator {
	=begin pod

	=head2 C<method project-row>

	=begin code :lang<raku>
	method project-row(Associative $row, @columns)
	=end code

	Documents C<method project-row>.

	=item C<$row>

	The C<$row> parameter.

	=item C<@columns>

	The C<@columns> parameter.

	=end pod
	method project-row(Associative $row, @columns) {
		my %proj;
		for @columns -> $col {
			my $name = self!normalize-col-name($col);
			$row{$name}:exists and %proj{$name} = $row{$name};
		}
		%proj
	}

	=begin pod

	=head2 C<method rename-row>

	=begin code :lang<raku>
	method rename-row(Associative $row, %renames)
	=end code

	Documents C<method rename-row>.

	=item C<$row>

	The C<$row> parameter.

	=item C<%renames>

	The C<%renames> parameter.

	=end pod
	method rename-row(Associative $row, %renames) {
		my %result = %($row);
		for %renames.pairs -> $p {
			if %result{$p.key}:exists {
				%result{$p.value} = %result.delete($p.key);
			}
		}
		%result
	}

	# method !normalize-col-name(Mu $col --> Str)
	#
	# Documents the private C<method !normalize-col-name> helper.
	# $col - The $col parameter.
	method !normalize-col-name(Mu $col --> Str) {
		$col ~~ Str and return $col;
		if $col ~~ List && $col.elems == 1 {
			return self!normalize-col-name($col[0]);
		}
		my $name = ~$col;
		$name.starts-with('<') && $name.ends-with('>') and $name = $name.substr(1, *-2);
		$name
	}
}

=begin pod

=head2 C<class ProjectionIterator>

=begin code :lang<raku>
class ProjectionIterator does Iterator does RowShapingEvaluator is export
=end code

Defines C<ProjectionIterator>.

=end pod
class ProjectionIterator does Iterator does RowShapingEvaluator is export {
	has Mu $.rows is required;
	has Mu @.columns is required;
	has Iterator $!iter;

	=begin pod

	=head2 C<method pull-one>

	=begin code :lang<raku>
	method pull-one
	=end code

	Documents C<method pull-one>.

	=end pod
	method pull-one {
		$!iter //= self.iterator-for($.rows);
		loop {
			my $row = self.pull-next($!iter);
			$row ~~ IterationEnd and return IterationEnd;
			return $row ~~ Associative ?? self.project-row($row, @.columns) !! $row;
		}
	}
}

=begin pod

=head2 C<class RenameIterator>

=begin code :lang<raku>
class RenameIterator does Iterator does RowShapingEvaluator is export
=end code

Defines C<RenameIterator>.

=end pod
class RenameIterator does Iterator does RowShapingEvaluator is export {
	has Mu $.rows is required;
	has %.renames is required;
	has Iterator $!iter;

	=begin pod

	=head2 C<method pull-one>

	=begin code :lang<raku>
	method pull-one
	=end code

	Documents C<method pull-one>.

	=end pod
	method pull-one {
		$!iter //= self.iterator-for($.rows);
		loop {
			my $row = self.pull-next($!iter);
			$row ~~ IterationEnd and return IterationEnd;
			return $row ~~ Associative ?? self.rename-row($row, %.renames) !! $row;
		}
	}
}

=begin pod

=head2 C<class ProjectionEvaluator>

=begin code :lang<raku>
class ProjectionEvaluator does LazyEvaluator is export
=end code

Defines C<ProjectionEvaluator>.

=end pod
class ProjectionEvaluator does LazyEvaluator is export {
	=begin pod

	=head2 C<method select-seq>

	=begin code :lang<raku>
	method select-seq(ProjectionOperator $query, Mu $origin, :&relation-source! --> Seq)
	=end code

	Documents C<method select-seq>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=item C<&relation-source>

	The C<&relation-source> parameter.

	=end pod
	method select-seq(ProjectionOperator $query, Mu $origin, :&relation-source! --> Seq) {
		self.lazy(
			relation-source($query.relation, $origin),
			$query.columns,
		)
	}

	=begin pod

	=head2 C<method lazy>

	=begin code :lang<raku>
	method lazy($rows, @columns --> Seq)
	=end code

	Documents C<method lazy>.

	=item C<$rows>

	The C<$rows> parameter.

	=item C<@columns>

	The C<@columns> parameter.

	=end pod
	method lazy($rows, @columns --> Seq) {
		self.seq-from-iterator(ProjectionIterator.new(:$rows, :@columns))
	}
}

=begin pod

=head2 C<class RenameEvaluator>

=begin code :lang<raku>
class RenameEvaluator does LazyEvaluator is export
=end code

Defines C<RenameEvaluator>.

=end pod
class RenameEvaluator does LazyEvaluator is export {
	=begin pod

	=head2 C<method select-seq>

	=begin code :lang<raku>
	method select-seq(RenameOperator $query, Mu $origin, :&relation-source! --> Seq)
	=end code

	Documents C<method select-seq>.

	=item C<$query>

	The C<$query> parameter.

	=item C<$origin>

	The C<$origin> parameter.

	=item C<&relation-source>

	The C<&relation-source> parameter.

	=end pod
	method select-seq(RenameOperator $query, Mu $origin, :&relation-source! --> Seq) {
		self.lazy(
			relation-source($query.relation, $origin),
			$query.renames,
		)
	}

	=begin pod

	=head2 C<method lazy>

	=begin code :lang<raku>
	method lazy($rows, %renames --> Seq)
	=end code

	Documents C<method lazy>.

	=item C<$rows>

	The C<$rows> parameter.

	=item C<%renames>

	The C<%renames> parameter.

	=end pod
	method lazy($rows, %renames --> Seq) {
		self.seq-from-iterator(RenameIterator.new(:$rows, :%renames))
	}
}
