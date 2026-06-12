=begin pod

Schema discovery and catalog construction for table foreign-key navigation.

Builds a L<Qwiratry::Table::Catalog> from explicit schema metadata, the
C<providing> trait, multi-table roots, or inferred foreign-key relationships.

=end pod
use Qwiratry::Table;
use Qwiratry::Walker::Providing;

class Qwiratry::Table::Schema {

	my $instance;

	=begin pod

	Return the shared Schema service instance.

	=end pod
	method instance(--> Qwiratry::Table::Schema) {
		$instance //= self.new
	}

	=begin pod

	Build a catalog from explicit table map, foreign keys, and active table name.

	=end pod
	method catalog-from-tables(
		Associative $tables!,
		:@foreign-keys,
		Str :$active-table,
		Bool :$infer-fks = True,
	) {
		my %table-map = %$tables;
		my @fks = @foreign-keys;
		@fks = self.infer-foreign-keys($tables) if !@fks && $infer-fks;
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

	=begin pod

	Attach schema metadata to a container via the providing-schema registry.

	=end pod
	method attach(Mu $container is raw, Associative $schema!) {
		Qwiratry::Walker::Providing.instance.bind-schema($container, %$schema);
		$container
	}

	=begin pod

	Discover or return a L<Qwiratry::Table::Catalog> for C<$origin> data.

	=end pod
	method discover(Mu $origin is raw --> Mu) {
		return $origin if $origin ~~ Qwiratry::Table::Catalog;

		my $schema = Qwiratry::Walker::Providing.instance.schema($origin);
		if $schema.defined {
			return self!catalog-from-providing-schema($schema, $origin);
		}

		if $origin ~~ Associative {
			if $origin<qwiratry-schema> ~~ Associative {
				return self!catalog-from-providing-schema($origin<qwiratry-schema>, $origin);
			}
			if $origin<tables> ~~ Associative {
				my %tables = %($origin<tables>);
				return self.catalog-from-tables(
					%tables,
					:foreign-keys(self!schema-foreign-keys($origin)),
					:active-table(self!schema-active-table($origin)),
				);
			}
			if self!is-multi-table-root($origin) {
				my %tables = self!table-entries($origin);
				return self.catalog-from-tables(%tables);
			}
		}

		if $origin ~~ Positional && !( $origin ~~ Associative ) {
			my @domains = Qwiratry::Walker::Providing.instance.domains($origin) // ();
			if @domains.grep(* eq 'table').so {
				my $name = self!schema-table-name($origin) // 'rows';
				my %tables = %($name => $origin);
				return self.catalog-from-tables(%tables, :active-table($name));
			}
		}

		Nil
	}

	=begin pod

	Infer L<ForeignKey|Qwiratry::Table::ForeignKey> edges from column naming conventions.

	=end pod
	method infer-foreign-keys(Associative $tables! --> List) {
		my %table-map = %$tables;
		my @fks;
		for %table-map.pairs -> $from {
			my $from-table = $from.key;
			my @rows = $from.value.list;
			next unless @rows && @rows[0] ~~ Associative;
			for @rows[0].keys.sort -> $column {
				for %table-map.pairs -> $to {
					next if $from-table eq $to.key;
					my $to-pk = self!infer-primary-key($to.value, $to.key);
					next unless $to-pk.defined;
					next unless self!column-references-table($column, $to.key, $to-pk);
					@fks.push(ForeignKey.new(
						:from-table($from-table), :from-column($column),
						:to-table($to.key), :to-column($to-pk),
					));
				}
			}
		}
		@fks
	}

	=begin pod

	Build a catalog from providing-schema metadata and row data in C<$origin>.

	=end pod
	method !catalog-from-providing-schema(Associative $schema, Mu $origin --> Mu) {
		my %tables = self!schema-tables($schema, $origin);
		return Nil unless %tables;
		self.catalog-from-tables(
			%tables,
			:foreign-keys(self!schema-foreign-keys($schema)),
			:active-table(self!schema-active-table($schema) // self!schema-active-table($origin)),
			:infer-fks(!self!schema-foreign-keys($schema)),
		)
	}

	=begin pod

	Extract table name to row-list map from schema metadata and origin data.

	=end pod
	method !schema-tables(Associative $schema, Mu $origin --> Associative) {
		return %($schema<tables>) if $schema<tables> ~~ Associative;
		if $schema<table-name>.defined && $origin ~~ Positional {
			return %(($schema<table-name> => $origin));
		}
		if $origin ~~ Associative && self!is-multi-table-root($origin) {
			return self!table-entries($origin);
		}
		if $origin ~~ Positional {
			my $name = $schema<table-name> // 'rows';
			return %($name => $origin);
		}
		Associative
	}

	=begin pod

	Read foreign-key list from a schema associative.

	=end pod
	method !schema-foreign-keys(Associative $source --> List) {
		return () unless $source<foreign-keys>:exists;
		my $raw = $source<foreign-keys>;
		return $raw.list if $raw ~~ Positional;
		()
	}

	=begin pod

	Read active table name from schema or root metadata.

	=end pod
	method !schema-active-table(Associative $source --> Mu) {
		$source<active-table> // $source<table-name>
	}

	=begin pod

	Resolve table name from providing-schema on C<$origin>.

	=end pod
	method !schema-table-name(Mu $origin --> Mu) {
		my $schema = Qwiratry::Walker::Providing.instance.schema($origin);
		return $schema<table-name> if $schema.defined && $schema<table-name>.defined;
		Nil
	}

	=begin pod

	Return True when C<$root> maps names to positional row lists (multi-table root).

	=end pod
	method !is-multi-table-root(Associative $root --> Bool) {
		return False unless $root.keys;
		$root.pairs.grep({ $_.value ~~ Positional && !($_.value ~~ Associative) }).so
	}

	=begin pod

	Collect positional table values from a multi-table associative root.

	=end pod
	method !table-entries(Associative $root --> Associative) {
		my %tables;
		for $root.pairs -> $pair {
			next unless $pair.value ~~ Positional && !($pair.value ~~ Associative);
			%tables{$pair.key} = $pair.value;
		}
		%tables
	}

	=begin pod

	Guess primary-key column for a table from naming conventions.

	=end pod
	method !infer-primary-key(Positional $rows, Str $table-name --> Mu) {
		return Nil unless $rows.elems && $rows[0] ~~ Associative;
		my @cols = $rows[0].keys.sort;
		my $singular = self!singular-table-name($table-name);
		my $preferred = "{$singular}_id";
		return $preferred if @cols.grep(* eq $preferred).so;
		my @id-cols = @cols.grep({ $_ ~~ / '_id' $ / });
		return @id-cols[0] if @id-cols;
		@cols[0]
	}

	=begin pod

	Singularize a table name for C<{table}_id> column guessing.

	=end pod
	method !singular-table-name(Str $table-name --> Str) {
		return $table-name.substr(0, *-1) if $table-name.ends-with('s') && $table-name.chars > 1;
		$table-name
	}

	=begin pod

	Return True when C<$column> looks like a foreign key referencing C<$to-table>.

	=end pod
	method !column-references-table(Str $column, Str $to-table, Str $to-pk --> Bool) {
		return True if $column eq $to-pk;
		my $singular = self!singular-table-name($to-table);
		return True if $column eq "{$singular}_id" && $to-pk eq "{$singular}_id";
		False
	}
}
