=begin pod

Schema discovery and catalog construction for table foreign-key navigation.

Builds a L<Qwiratry::Table::Catalog> from explicit schema metadata, the
C<providing> trait, multi-table roots, or inferred foreign-key relationships.

=end pod
unit module Qwiratry::Table::Schema;

use Qwiratry::Table;
use Qwiratry::Walker::Providing;
use Qwiratry::Query::Relational;

our sub catalog-from-tables(
	Associative $tables!,
	:@foreign-keys,
	Str :$active-table,
	Bool :$infer-fks = True,
) is export {
	my %table-map = %$tables;
	my @fks = @foreign-keys;
	@fks = infer-foreign-keys($tables) if !@fks && $infer-fks;
	my $active = $active-table;
	unless $active.defined {
		$active = %table-map.keys.first if %table-map.keys.elems == 1;
	}
	Qwiratry::Table::Catalog.new(
		:tables(Hash.new(%table-map)),
		:foreign-keys(@fks),
		:active-table($active),
	);
}

our sub attach-schema(Mu $container is raw, Associative $schema!) is export {
	bind-providing-schema($container, %$schema);
	$container
}

our sub discover-catalog(Mu $origin is raw --> Mu) is export {
	return $origin if $origin ~~ Qwiratry::Table::Catalog;

	my $schema = providing-schema($origin);
	if $schema.defined {
		return catalog-from-providing-schema($schema, $origin);
	}

	if $origin ~~ Associative {
		if $origin<qwiratry-schema> ~~ Associative {
			return catalog-from-providing-schema($origin<qwiratry-schema>, $origin);
		}
		if $origin<tables> ~~ Associative {
			my %tables = %($origin<tables>);
			return catalog-from-tables(
				%tables,
				:foreign-keys(schema-foreign-keys($origin)),
				:active-table(schema-active-table($origin)),
			);
		}
		if is-multi-table-root($origin) {
			my %tables = table-entries($origin);
			return catalog-from-tables(%tables);
		}
	}

	if $origin ~~ Positional && !( $origin ~~ Associative ) {
		my @domains = providing-domains($origin) // ();
		if @domains.grep(* eq 'table').so {
			my $name = schema-table-name($origin) // 'rows';
			my %tables = %($name => $origin);
			return catalog-from-tables(%tables, :active-table($name));
		}
	}

	Nil
}

sub catalog-from-providing-schema(Associative $schema, Mu $origin --> Mu) {
	my %tables = schema-tables($schema, $origin);
	return Nil unless %tables;
	catalog-from-tables(
		%tables,
		:foreign-keys(schema-foreign-keys($schema)),
		:active-table(schema-active-table($schema) // schema-active-table($origin)),
		:infer-fks(!schema-foreign-keys($schema)),
	)
}

sub schema-tables(Associative $schema, Mu $origin --> Associative) {
	return %($schema<tables>) if $schema<tables> ~~ Associative;
	if $schema<table-name>.defined && $origin ~~ Positional {
		return %(($schema<table-name> => $origin));
	}
	if $origin ~~ Associative && is-multi-table-root($origin) {
		return table-entries($origin);
	}
	if $origin ~~ Positional {
		my $name = $schema<table-name> // 'rows';
		return %($name => $origin);
	}
	Associative
}

sub schema-foreign-keys(Associative $source --> List) {
	return () unless $source<foreign-keys>:exists;
	my $raw = $source<foreign-keys>;
	return $raw.list if $raw ~~ Positional;
	()
}

sub schema-active-table(Associative $source --> Mu) {
	$source<active-table> // $source<table-name>
}

sub schema-table-name(Mu $origin --> Mu) {
	my $schema = providing-schema($origin);
	return $schema<table-name> if $schema.defined && $schema<table-name>.defined;
	Nil
}

sub is-multi-table-root(Associative $root --> Bool) {
	return False unless $root.keys;
	$root.pairs.grep({ $_.value ~~ Positional && !($_.value ~~ Associative) }).so
}

sub table-entries(Associative $root --> Associative) {
	my %tables;
	for $root.pairs -> $pair {
		next unless $pair.value ~~ Positional && !($pair.value ~~ Associative);
		%tables{$pair.key} = $pair.value;
	}
	%tables
}

our sub infer-foreign-keys(Associative $tables! --> List) is export {
	my %table-map = %$tables;
	my @fks;
	for %table-map.pairs -> $from {
		my $from-table = $from.key;
		my @rows = $from.value.list;
		next unless @rows && @rows[0] ~~ Associative;
		for @rows[0].keys.sort -> $column {
			for %table-map.pairs -> $to {
				next if $from-table eq $to.key;
				my $to-pk = infer-primary-key($to.value, $to.key);
				next unless $to-pk.defined;
				next unless column-references-table($column, $to.key, $to-pk);
				@fks.push(ForeignKey.new(
					:from-table($from-table), :from-column($column),
					:to-table($to.key), :to-column($to-pk),
				));
			}
		}
	}
	@fks
}

sub infer-primary-key(Positional $rows, Str $table-name --> Mu) {
	return Nil unless $rows.elems && $rows[0] ~~ Associative;
	my @cols = $rows[0].keys.sort;
	my $singular = singular-table-name($table-name);
	my $preferred = "{$singular}_id";
	return $preferred if @cols.grep(* eq $preferred).so;
	my @id-cols = @cols.grep({ $_ ~~ / '_id' $ / });
	return @id-cols[0] if @id-cols;
	@cols[0]
}

sub singular-table-name(Str $table-name --> Str) {
	return $table-name.substr(0, *-1) if $table-name.ends-with('s') && $table-name.chars > 1;
	$table-name
}

sub column-references-table(Str $column, Str $to-table, Str $to-pk --> Bool) {
	return True if $column eq $to-pk;
	my $singular = singular-table-name($to-table);
	return True if $column eq "{$singular}_id" && $to-pk eq "{$singular}_id";
	False
}
