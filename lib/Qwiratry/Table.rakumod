=begin pod

Table catalog for foreign-key-aware navigation (Operators.md section 5.2).

=end pod
unit module Qwiratry::Table;

use Qwiratry::Query::Relational;

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
