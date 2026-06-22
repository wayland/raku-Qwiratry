=begin pod

Table catalog for foreign-key-aware navigation (Operators.md section 5.2).

=end pod
unit module Qwiratry::Table;

use Qwiratry::Operator::Navigation;
use Qwiratry::Query::Relational;
use Qwiratry::Query::Selector;

my constant selector = Qwiratry::Query::Selector.instance;

=begin pod

Foreign-key link from one table column to another table column.

=end pod
class ForeignKey is export {
	has Str $.from-table is required;
	has Str $.from-column is required;
	has Str $.to-table is required;
	has Str $.to-column is required;
}

=begin pod

Named tables, FK metadata, and an optional active table for row scans.

=end pod
class Catalog is export {
	has Hash $.tables is required;
	has @.foreign-keys = [];
	has Str $.active-table;

	method table(Str $name --> Mu) {
		$!tables{$name}
	}

	method tables(--> Hash) {
		$!tables
	}

	method active-rows(--> List) {
		$!active-table.defined && $!tables{$!active-table}:exists or return ();
		$!tables{$!active-table}.list;
	}

	method table-name-for(Associative $row --> Mu) {
		for $!tables.pairs -> $pair {
			for $pair.value.list -> $candidate {
				$candidate === $row and return $pair.key;
				Qwiratry::Query::Relational.instance.row-equal($candidate, $row) and return $pair.key;
			}
		}
		Nil
	}

	method fk-for(Str $from-table, Str $from-column --> Mu) {
		for @!foreign-keys -> $fk {
			next unless $fk.from-table eq $from-table;
			next unless $fk.from-column eq $from-column;
			return $fk;
		}
		Nil
	}

	method referencing-keys-for(Str $referenced-table --> List) {
		gather {
			for @!foreign-keys -> $fk {
				if $fk.to-table eq $referenced-table {
					take $fk;
				}
			}
		}.List
	}

	method follow-fk(Associative $row, Str $from-table, Str $column --> List) {
		my $fk = self.fk-for($from-table, $column);
		$fk.defined or return ();
		$!tables{$fk.to-table}:exists or return ();

		my $value = $row{$column};
		$value.defined or return ();

		gather {
			for $!tables{$fk.to-table}.list -> $target {
				next unless $target{$fk.to-column}:exists;
				if ~($target{$fk.to-column}) eq ~$value {
					take $target;
				}
			}
		}.List
	}

	method referencing-rows(Associative $row, Str $referenced-table --> List) {
		my $table-name = self.table-name-for($row) // $referenced-table;
		my @results;
		for self.referencing-keys-for($table-name) -> $fk {
			next unless $!tables{$fk.from-table}:exists;
			my $pk = $row{$fk.to-column};
			next unless $pk.defined;
			for $!tables{$fk.from-table}.list -> $referencing {
				next unless $referencing{$fk.from-column}:exists;
				my $fk-value = $referencing{$fk.from-column};
				next unless $fk-value.defined;
				next unless ~$fk-value eq ~$pk;
				@results.push($referencing);
			}
		}
		@results
	}


=begin pod

Return True when C<$base> is a single table row (associative, not a catalog).

=end pod
	method is-table-row(Mu $base --> Bool) {
		$base ~~ Associative && !($base ~~ Catalog)
	}


=begin pod

Child-axis navigation: active table rows, FK follow, or column filter.

=end pod
	method child-results(Mu $base, Mu $op --> List) {
		my $sel = $op.selector;

		if $base ~~ Catalog {
			my $table-name = $base.active-table // '';
			$table-name && $base.tables{$table-name}:exists or return ();
			my @rows = $base.tables{$table-name}.list;
			selector.is-wildcard($sel) and return @rows;
			return @rows.grep({ selector.table-row-matches($_, $sel) }).List;
		}

		if $base ~~ Positional && !($base ~~ Associative) {
			selector.is-wildcard($sel) and return $base.list;
			return ();
		}

		if $base ~~ Associative {
			my $from-table = self.table-name-for($base);
			$from-table.defined or return ();

			selector.is-wildcard($sel) and return ($base,);

			my $column = selector.normalize-key($sel);
			return self.follow-fk($base, $from-table, $column);
		}

		()
	}


=begin pod

Parent-axis navigation: owning table or referencing rows when C<:reference>.

=end pod
	method parent-results(Mu $base, Mu $op --> List) {
		my $reference = self!parent-has-reference($op);
		my $sel = $op.selector;

		if $base ~~ Associative {
			if $reference {
				my $table-name = self.table-name-for($base);
				$table-name.defined or return ();
				return self.referencing-rows($base, $table-name);
			}
			my $table-name = self.table-name-for($base);
			$table-name.defined && self.tables{$table-name}:exists or return ();
			return (self.tables{$table-name},);
		}

		if $base ~~ Catalog || ($base ~~ Positional && !($base ~~ Associative)) {
			selector.is-wildcard($sel) and return ($base,);
		}

		()
	}


=begin pod

Descendant-axis navigation; table rows require C<:recursive> for FK walks.

=end pod
	method descendant-results(Mu $base, Mu $op --> List) {
		if self.is-table-row($base) {
			unless self!descendant-has-recursive($op) {
				die "⪪⪪ on table rows requires :recursive to follow foreign keys (Operators.md §5.2.4)";
			}
			return self!recursive-fk-results($base, $op);
		}
		self.child-results($base, $op);
	}


=begin pod

Sibling-axis navigation within a table's ordered row list.

=end pod
	method sibling-results(Mu $base, Mu $op --> List) {
		if $base ~~ Catalog || ($base ~~ Positional && !($base ~~ Associative)) {
			return ();
		}
		self.is-table-row($base) or return ();

		my $ctx = self!row-order-context($base);
		$ctx.defined or return ();
		my @rows = $ctx<rows>.list;
		my $index = $ctx<index>;

		my @candidates = self!sibling-candidates($op, @rows, $index);
		gather {
			for @candidates -> $candidate {
				if self!sibling-matches-selector($candidate, $op.selector) {
					take $candidate;
				}
			}
		}.List
	}


=begin pod

Return True when a parent operator requests C<:reference> (incoming FK lookup).

=end pod
	method !parent-has-reference(Mu $op --> Bool) {
		$op.adverbs.defined && $op.adverbs<reference> and return True;
		try { $op.reference } orelse False
	}


=begin pod

Return True when a descendant operator requests C<:recursive> FK traversal.

=end pod
	method !descendant-has-recursive(Mu $op --> Bool) {
		$op.adverbs.defined && $op.adverbs<recursive> and return True;
		try { $op.recursive } orelse False
	}


=begin pod

Recursively follow foreign keys from a row for descendant queries.

=end pod
	method !recursive-fk-results(Associative $row, Mu $op --> List) {
		my $from-table = self.table-name-for($row);
		$from-table.defined or return ();

		my @columns = self!descendant-fk-columns($op, $from-table);
		@columns or return ();

		my %visited;
		gather {
			self!recursive-fk-walk($row, @columns, %visited);
		}.List
	}


=begin pod

Depth-first FK walk helper for L<table-recursive-fk-results>.

=end pod
	method !recursive-fk-walk(
		Associative $row,
		@columns,
		%visited,
	) {
		my $key = self!row-visit-key($row);
		%visited{$key}:exists and return;
		%visited{$key} = True;

		my $from-table = self.table-name-for($row);
		$from-table.defined or return;

		for @columns -> $column {
			for self.follow-fk($row, $from-table, $column) -> $related {
				take $related;
				self!recursive-fk-walk($related, @columns, %visited);
			}
		}
	}


=begin pod

Columns to follow for recursive descendant navigation from C<$from-table>.

=end pod
	method !descendant-fk-columns(Mu $op, Str $from-table --> List) {
		my $sel = $op.selector;
		if selector.is-wildcard($sel) {
			return gather {
				for self.foreign-keys -> $fk {
					if $fk.from-table eq $from-table {
						take $fk.from-column;
					}
				}
			}.unique.List;
		}
		if $sel ~~ List {
			return $sel.map({ selector.normalize-key($_) }).grep(*.chars).unique.List;
		}
		my $column = selector.normalize-key($sel);
		$column.chars and return ($column,);
		()
	}


=begin pod

Build a visit key for cycle detection during recursive FK walks.

=end pod
	method !row-visit-key(Associative $row --> Str) {
		my $table = self.table-name-for($row);
		$table.defined or return $row.WHICH;

		my @pk-cols = gather {
			for self.foreign-keys -> $fk {
				if $fk.to-table eq $table {
					take $fk.to-column;
				}
			}
		}.unique;
		@pk-cols or @pk-cols = $row.keys.sort;

		my $pk = [ $row{$_} // '' for @pk-cols ].join('|');
		"$table|$pk"
	}


=begin pod

Locate a row's index and table row list for ordered-row sibling navigation.

=end pod
	method !row-order-context(Associative $row --> Mu) {
		my $table-name = self.table-name-for($row);
		$table-name.defined && self.tables{$table-name}:exists or return;
		my @rows = self.tables{$table-name}.list;
		for 0..^@rows -> $i {
			return %(rows => @rows, index => $i) if @rows[$i] === $row
				|| Qwiratry::Query::Relational.instance.row-equal(@rows[$i], $row);
		}
		Nil
	}


=begin pod

Return candidate sibling rows for following/preceding operators.

=end pod
	method !sibling-candidates(Mu $op, @rows, Int $index --> List) {
		given $op {
			when FollowingSiblingOperator {
				$index + 1 < @rows and return (@rows[$index + 1],);
				return ();
			}
			when PrecedingSiblingOperator {
				$index > 0 and return (@rows[$index - 1],);
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
	method !sibling-matches-selector(Associative $row, Mu $sel --> Bool) {
		selector.is-wildcard($sel) and return True;
		selector.table-row-matches($row, $sel);
	}
}

our sub make-catalog(
	*%tables,
	:@foreign-keys,
	Str :$active-table,
) is export {
	Catalog.new(
		:tables(Hash.new(%tables)),
		:active-table($active-table),
		:@foreign-keys,
	)
}
