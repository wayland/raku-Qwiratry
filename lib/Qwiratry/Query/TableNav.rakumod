=begin pod

Table-domain navigation helpers used by L<Qwiratry::Query::Match>.

Resolves child, parent, descendant, and sibling navigation against
L<Qwiratry::Table::Catalog> foreign keys and ordered row lists.

=end pod
unit module Qwiratry::Query::TableNav;

use Qwiratry::Operator::Navigation;
use Qwiratry::Table;
use Qwiratry::Table::Schema;
use Qwiratry::Query::Relational;

=begin pod

Discover or return the L<Qwiratry::Table::Catalog> for C<$origin>.

=end pod
our sub table-catalog(Mu $origin is raw --> Mu) is export {
	Qwiratry::Table::Schema.instance.discover($origin)
}

=begin pod

Return True when a parent operator requests C<:reference> (incoming FK lookup).

=end pod
sub parent-has-reference(Mu $op --> Bool) {
	return True if $op.adverbs.defined && $op.adverbs<reference>;
	try { $op.reference } orelse False
}

=begin pod

Return True when a descendant operator requests C<:recursive> FK traversal.

=end pod
sub descendant-has-recursive(Mu $op --> Bool) {
	return True if $op.adverbs.defined && $op.adverbs<recursive>;
	try { $op.recursive } orelse False
}

=begin pod

Return True when C<$base> is a single table row (associative, not a catalog).

=end pod
our sub table-row-base(Mu $base --> Bool) is export {
	$base ~~ Associative && !($base ~~ Qwiratry::Table::Catalog)
}

=begin pod

Normalize a navigation selector to a column name string.

=end pod
sub table-column-name(Mu $selector --> Str) {
	normalize-key($selector)
}

=begin pod

Normalize key, list, or scalar to a string column name.

=end pod
sub normalize-key(Mu $key --> Str) {
	return $key if $key ~~ Str;
	if $key ~~ List && $key.elems == 1 {
		return normalize-key($key[0]);
	}
	~$key
}

=begin pod

Child-axis navigation: active table rows, FK follow, or column filter.

=end pod
our sub table-child-results(Mu $base, Mu $op, Qwiratry::Table::Catalog $catalog --> List) is export {
	my $selector = $op.selector;

	if $base ~~ Qwiratry::Table::Catalog {
		my $table-name = $base.active-table // '';
		return () unless $table-name && $base.tables{$table-name}:exists;
		my @rows = $base.tables{$table-name}.list;
		return @rows if is-wildcard-selector($selector);
		return @rows.grep({ table-row-matches-selector($_, $selector) }).List;
	}

	if $base ~~ Positional && !($base ~~ Associative) {
		return $base.list if is-wildcard-selector($selector);
		return ();
	}

	if $base ~~ Associative {
		my $from-table = $catalog.table-name-for($base);
		return () unless $from-table.defined;

		if is-wildcard-selector($selector) {
			return ($base,);
		}

		my $column = table-column-name($selector);
		return $catalog.follow-fk($base, $from-table, $column);
	}

	()
}

=begin pod

Parent-axis navigation: owning table or referencing rows when C<:reference>.

=end pod
our sub table-parent-results(Mu $base, Mu $op, Qwiratry::Table::Catalog $catalog --> List) is export {
	my $reference = parent-has-reference($op);
	my $selector = $op.selector;

	if $base ~~ Associative {
		if $reference {
			my $table-name = $catalog.table-name-for($base);
			return () unless $table-name.defined;
			return $catalog.referencing-rows($base, $table-name);
		}
		my $table-name = $catalog.table-name-for($base);
		return () unless $table-name.defined && $catalog.tables{$table-name}:exists;
		return ($catalog.tables{$table-name},);
	}

	if $base ~~ Qwiratry::Table::Catalog || ($base ~~ Positional && !($base ~~ Associative)) {
		return ($base,) if is-wildcard-selector($selector);
	}

	()
}

=begin pod

Descendant-axis navigation; table rows require C<:recursive> for FK walks.

=end pod
our sub table-descendant-results(Mu $base, Mu $op, Qwiratry::Table::Catalog $catalog --> List) is export {
	if table-row-base($base) {
		unless descendant-has-recursive($op) {
			die "⪪⪪ on table rows requires :recursive to follow foreign keys (Operators.md §5.2.4)";
		}
		return table-recursive-fk-results($base, $op, $catalog);
	}
	table-child-results($base, $op, $catalog);
}

=begin pod

Recursively follow foreign keys from a row for descendant queries.

=end pod
sub table-recursive-fk-results(Associative $row, Mu $op, Qwiratry::Table::Catalog $catalog --> List) {
	my $from-table = $catalog.table-name-for($row);
	return () unless $from-table.defined;

	my @columns = descendant-fk-columns($op, $catalog, $from-table);
	return () unless @columns;

	my %visited;
	gather {
		table-recursive-fk-walk($row, $catalog, @columns, %visited);
	}.List
}

=begin pod

Depth-first FK walk helper for L<table-recursive-fk-results>.

=end pod
sub table-recursive-fk-walk(
	Associative $row,
	Qwiratry::Table::Catalog $catalog,
	@columns,
	%visited,
) {
	my $key = row-visit-key($row, $catalog);
	return if %visited{$key}:exists;
	%visited{$key} = True;

	my $from-table = $catalog.table-name-for($row);
	return unless $from-table.defined;

	for @columns -> $column {
		for $catalog.follow-fk($row, $from-table, $column) -> $related {
			take $related;
			table-recursive-fk-walk($related, $catalog, @columns, %visited);
		}
	}
}

=begin pod

Columns to follow for recursive descendant navigation from C<$from-table>.

=end pod
sub descendant-fk-columns(Mu $op, Qwiratry::Table::Catalog $catalog, Str $from-table --> List) {
	my $selector = $op.selector;
	if is-wildcard-selector($selector) {
		return gather {
			for $catalog.foreign-keys -> $fk {
				take $fk.from-column if $fk.from-table eq $from-table;
			}
		}.unique.List;
	}
	if $selector ~~ List {
		return $selector.map({ table-column-name($_) }).grep(*.chars).unique.List;
	}
	my $column = table-column-name($selector);
	return ($column,) if $column.chars;
	()
}

=begin pod

Build a visit key for cycle detection during recursive FK walks.

=end pod
sub row-visit-key(Associative $row, Qwiratry::Table::Catalog $catalog --> Str) {
	my $table = $catalog.table-name-for($row);
	return $row.WHICH unless $table.defined;

	my @pk-cols = gather {
		for $catalog.foreign-keys -> $fk {
			take $fk.to-column if $fk.to-table eq $table;
		}
	}.unique;
	@pk-cols = $row.keys.sort unless @pk-cols;

	my $pk = [ $row{$_} // '' for @pk-cols ].join('|');
	"$table|$pk"
}

=begin pod

Return True when a table row matches a child/sibling selector.

=end pod
sub table-row-matches-selector(Associative $row, Mu $selector --> Bool) {
	return True if is-wildcard-selector($selector);
	if $selector ~~ Str {
		my $col = normalize-selector-name($selector);
		return $row{$col}:exists;
	}
	False
}

=begin pod

Strip angle brackets from selector strings.

=end pod
sub normalize-selector-name(Str $selector --> Str) {
	return $selector.substr(1, *-2) if $selector.starts-with('<') && $selector.ends-with('>');
	$selector
}

=begin pod

Return True for wildcard selectors (C<*>, C<**>, C<Whatever>).

=end pod
sub is-wildcard-selector(Mu $selector --> Bool) {
	return True if $selector ~~ Whatever;
	return True if $selector ~~ Str && $selector eq any(<* **>);
	False
}

=begin pod

Return row list for a catalog active table or a positional origin.

=end pod
sub catalog-rows(Mu $origin --> List) {
	return $origin.active-rows if $origin ~~ Qwiratry::Table::Catalog;
	return $origin.list if $origin ~~ Positional;
	($origin,);
}

=begin pod

Locate a row's index and table row list for ordered-row sibling navigation.

=end pod
sub table-row-order-context(Associative $row, Qwiratry::Table::Catalog $catalog --> Mu) {
	my $table-name = $catalog.table-name-for($row);
	return unless $table-name.defined && $catalog.tables{$table-name}:exists;
	my @rows = $catalog.tables{$table-name}.list;
	for 0..^@rows -> $i {
		return %(rows => @rows, index => $i) if @rows[$i] === $row
			|| Qwiratry::Query::Relational.instance.row-equal(@rows[$i], $row);
	}
	Nil
}

=begin pod

Return candidate sibling rows for following/preceding operators.

=end pod
sub table-sibling-candidates(Mu $op, @rows, Int $index --> List) {
	given $op {
		when FollowingSiblingOperator {
			return (@rows[$index + 1],) if $index + 1 < @rows;
			return ();
		}
		when PrecedingSiblingOperator {
			return (@rows[$index - 1],) if $index > 0;
			return ();
		}
		when FollowingOperator {
			return @rows[$index + 1 .. *];
		}
		when PrecedingOperator {
			return @rows[0 ..^ $index];
		}
		default {
			return ();
		}
	}
}

=begin pod

Filter sibling candidates by selector match.

=end pod
sub table-sibling-matches-selector(Associative $row, Mu $selector --> Bool) {
	return True if is-wildcard-selector($selector);
	table-row-matches-selector($row, $selector);
}

=begin pod

Sibling-axis navigation within a table's ordered row list.

=end pod
our sub table-sibling-results(Mu $base, Mu $op, Qwiratry::Table::Catalog $catalog --> List) is export {
	if $base ~~ Qwiratry::Table::Catalog
			|| ($base ~~ Positional && !($base ~~ Associative)) {
		return ();
	}
	return () unless table-row-base($base);

	my $ctx = table-row-order-context($base, $catalog);
	return () unless $ctx.defined;
	my @rows = $ctx<rows>.list;
	my $index = $ctx<index>;

	my @candidates = table-sibling-candidates($op, @rows, $index);
	gather {
		for @candidates -> $candidate {
			take $candidate if table-sibling-matches-selector($candidate, $op.selector);
		}
	}.List
}
