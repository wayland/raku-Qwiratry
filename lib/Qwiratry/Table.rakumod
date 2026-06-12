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
		return () unless $!active-table.defined && $!tables{$!active-table}:exists;
		$!tables{$!active-table}.list;
	}

	method table-name-for(Associative $row --> Mu) {
		for $!tables.pairs -> $pair {
			for $pair.value.list -> $candidate {
				return $pair.key if $candidate === $row;
				return $pair.key if Qwiratry::Query::Relational.instance.row-equal($candidate, $row);
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
				take $fk if $fk.to-table eq $referenced-table;
			}
		}.List
	}

	method follow-fk(Associative $row, Str $from-table, Str $column --> List) {
		my $fk = self.fk-for($from-table, $column);
		return () unless $fk.defined;
		return () unless $!tables{$fk.to-table}:exists;

		my $value = $row{$column};
		return () unless $value.defined;

		gather {
			for $!tables{$fk.to-table}.list -> $target {
				next unless $target{$fk.to-column}:exists;
				take $target if ~($target{$fk.to-column}) eq ~$value;
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

	method is-table-row(Mu $base --> Bool) {
		$base ~~ Associative && !($base ~~ Catalog)
	}

	method child-results(Mu $base, Mu $op --> List) {
		my $sel = $op.selector;

		if $base ~~ Catalog {
			my $table-name = $base.active-table // '';
			return () unless $table-name && $base.tables{$table-name}:exists;
			my @rows = $base.tables{$table-name}.list;
			return @rows if selector.is-wildcard($sel);
			return @rows.grep({ selector.table-row-matches($_, $sel) }).List;
		}

		if $base ~~ Positional && !($base ~~ Associative) {
			return $base.list if selector.is-wildcard($sel);
			return ();
		}

		if $base ~~ Associative {
			my $from-table = self.table-name-for($base);
			return () unless $from-table.defined;

			return ($base,) if selector.is-wildcard($sel);

			my $column = selector.normalize-key($sel);
			return self.follow-fk($base, $from-table, $column);
		}

		()
	}

	method parent-results(Mu $base, Mu $op --> List) {
		my $reference = self!parent-has-reference($op);
		my $sel = $op.selector;

		if $base ~~ Associative {
			if $reference {
				my $table-name = self.table-name-for($base);
				return () unless $table-name.defined;
				return self.referencing-rows($base, $table-name);
			}
			my $table-name = self.table-name-for($base);
			return () unless $table-name.defined && self.tables{$table-name}:exists;
			return (self.tables{$table-name},);
		}

		if $base ~~ Catalog || ($base ~~ Positional && !($base ~~ Associative)) {
			return ($base,) if selector.is-wildcard($sel);
		}

		()
	}

	method descendant-results(Mu $base, Mu $op --> List) {
		if self.is-table-row($base) {
			unless self!descendant-has-recursive($op) {
				die "⪪⪪ on table rows requires :recursive to follow foreign keys (Operators.md §5.2.4)";
			}
			return self!recursive-fk-results($base, $op);
		}
		self.child-results($base, $op);
	}

	method sibling-results(Mu $base, Mu $op --> List) {
		if $base ~~ Catalog || ($base ~~ Positional && !($base ~~ Associative)) {
			return ();
		}
		return () unless self.is-table-row($base);

		my $ctx = self!row-order-context($base);
		return () unless $ctx.defined;
		my @rows = $ctx<rows>.list;
		my $index = $ctx<index>;

		my @candidates = self!sibling-candidates($op, @rows, $index);
		gather {
			for @candidates -> $candidate {
				take $candidate if self!sibling-matches-selector($candidate, $op.selector);
			}
		}.List
	}

	method !parent-has-reference(Mu $op --> Bool) {
		return True if $op.adverbs.defined && $op.adverbs<reference>;
		try { $op.reference } orelse False
	}

	method !descendant-has-recursive(Mu $op --> Bool) {
		return True if $op.adverbs.defined && $op.adverbs<recursive>;
		try { $op.recursive } orelse False
	}

	method !recursive-fk-results(Associative $row, Mu $op --> List) {
		my $from-table = self.table-name-for($row);
		return () unless $from-table.defined;

		my @columns = self!descendant-fk-columns($op, $from-table);
		return () unless @columns;

		my %visited;
		gather {
			self!recursive-fk-walk($row, @columns, %visited);
		}.List
	}

	method !recursive-fk-walk(
		Associative $row,
		@columns,
		%visited,
	) {
		my $key = self!row-visit-key($row);
		return if %visited{$key}:exists;
		%visited{$key} = True;

		my $from-table = self.table-name-for($row);
		return unless $from-table.defined;

		for @columns -> $column {
			for self.follow-fk($row, $from-table, $column) -> $related {
				take $related;
				self!recursive-fk-walk($related, @columns, %visited);
			}
		}
	}

	method !descendant-fk-columns(Mu $op, Str $from-table --> List) {
		my $sel = $op.selector;
		if selector.is-wildcard($sel) {
			return gather {
				for self.foreign-keys -> $fk {
					take $fk.from-column if $fk.from-table eq $from-table;
				}
			}.unique.List;
		}
		if $sel ~~ List {
			return $sel.map({ selector.normalize-key($_) }).grep(*.chars).unique.List;
		}
		my $column = selector.normalize-key($sel);
		return ($column,) if $column.chars;
		()
	}

	method !row-visit-key(Associative $row --> Str) {
		my $table = self.table-name-for($row);
		return $row.WHICH unless $table.defined;

		my @pk-cols = gather {
			for self.foreign-keys -> $fk {
				take $fk.to-column if $fk.to-table eq $table;
			}
		}.unique;
		@pk-cols = $row.keys.sort unless @pk-cols;

		my $pk = [ $row{$_} // '' for @pk-cols ].join('|');
		"$table|$pk"
	}

	method !row-order-context(Associative $row --> Mu) {
		my $table-name = self.table-name-for($row);
		return unless $table-name.defined && self.tables{$table-name}:exists;
		my @rows = self.tables{$table-name}.list;
		for 0..^@rows -> $i {
			return %(rows => @rows, index => $i) if @rows[$i] === $row
				|| Qwiratry::Query::Relational.instance.row-equal(@rows[$i], $row);
		}
		Nil
	}

	method !sibling-candidates(Mu $op, @rows, Int $index --> List) {
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

	method !sibling-matches-selector(Associative $row, Mu $sel --> Bool) {
		return True if selector.is-wildcard($sel);
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
