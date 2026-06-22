=begin pod

=head1 Overview

Walker factory for automatic walker selection based on input data shape.

Transformers call this factory when the user has not supplied an explicit
walker. It first honors explicit registrations keyed by type or role, then uses
the built-in data-shape heuristic: flat positional collections of associative
rows use L<Qwiratry::Walker::Implementation::Table>; other defined data uses
L<Qwiratry::Walker::Implementation::Tree>.

Discovery support is retained for tests and future plugin-style walker loading,
but normal transformation currently depends on the built-in tree/table
implementations.

=head1 Selection Order

=item Explicit registry entry for the data type name.

=item Explicit registry entry for a role composed by the data type.

=item Built-in data-shape heuristic: table data uses the table walker; other
 defined data uses the tree walker.

=item C<Nil> when the input is undefined or no walker can be selected.

=end pod

use Qwiratry::Walker;
use X::Qwiratry;
use Implementation::Loader;
use Qwiratry::Walker::Implementation::Tree;
use Qwiratry::Walker::Implementation::Table;

sub is-table-data($data --> Bool) {
	$data ~~ Positional or return False;
	$data.elems == 0 and return False;
	$data[0] ~~ Associative or return False;
	$data[0]<children>:exists and return False;
	True
}

=begin pod

=head1 Class

C<Qwiratry::Walker::Factory> maintains explicit walker registrations, caches
discovered walker types, and creates fresh walker instances for selected data.

=end pod
class Qwiratry::Walker::Factory {
	# Registry of Walker types keyed by data type/role
	has %!walker-registry;
    
	# Cached discovered walkers (lazy initialization)
	has @!discovered-walkers;
    
	# Flag indicating if discovery has been performed
	has Bool $!discovery-performed = False;
    
	# Singleton instance (optional - can also instantiate directly)
	my $instance;
    
	=begin pod

	=head1 Methods

	=head2 C<instance()>

	=begin code
	method instance(--> Qwiratry::Walker::Factory)
	=end code

	Returns the shared walker factory instance.

	=end pod
	method instance(--> Qwiratry::Walker::Factory) {
		$instance //= Qwiratry::Walker::Factory.new;
	}
    
	=begin pod

	=head2 C<get-walker($data)>

	=begin code
	method get-walker($data --> Mu)
	=end code

	=head3 Parameters

	=item C<$data>

	 The input data, root value, or rendered value handled by this operation.


	Returns an appropriate walker instance for C<$data>, or C<Nil> for undefined
	data.

	Explicit registrations win over heuristics. If no registration matches, the
	factory distinguishes table rows from tree-shaped data and returns the built-in
	table or tree walker accordingly.

	This makes automatic selection predictable while still allowing tests and
	future domain adapters to override selection through C<register-walker>.

	=end pod
	method get-walker($data --> Mu) {
		# T028: Get Walker for data type
		# Check explicit registry first
		my $type = $data.WHAT;
		my $type-name = $type.^name;
        
		# Check registry by type name
		if %!walker-registry{$type-name}:exists {
			my $walker-type = %!walker-registry{$type-name};
			return $walker-type.new;
		}
        
		# Check registry by role composition
		# Iterate through roles that $data does
		for $type.^roles -> $role {
			my $role-name = $role.^name;
			if %!walker-registry{$role-name}:exists {
				my $walker-type = %!walker-registry{$role-name};
				return $walker-type.new;
			}
		}
        
		# Use heuristics for common types
		# Positional (arrays, lists) - could use a default array walker
		if $data ~~ Positional {
			# For MVP, return Nil - specific walkers can be registered
			# Future: return default Positional walker if available
		}
        
		# Associative (hashes, maps) - could use a default hash walker
		if $data ~~ Associative {
			# For MVP, return Nil - specific walkers can be registered
			# Future: return default Associative walker if available
		}

		if $data.defined {
			if is-table-data($data) {
				return Qwiratry::Walker::Implementation::Table.new;
			}
			return Qwiratry::Walker::Implementation::Tree.new;
		}

		# No Walker found
		# Explicitly return Nil to avoid returning Any (type object)
		return Nil;
	}
    
	=begin pod

	=head2 C<register-walker($type, $walker-type)>

	=begin code
	method register-walker($type, $walker-type)
	=end code

	=head3 Parameters

	=item C<$type>

	 The operation or wrapper type used to group the registration.

	=item C<$walker-type>

	 The walker implementation type to register for the data type.


	Registers C<$walker-type> for a type or role name.

	C<$type> may be a type object or a string. Registered entries are consulted
	before the built-in table/tree heuristics, allowing tests and future adapters
	to override selection for custom domains.

	=end pod
	method register-walker($type, $walker-type) {
		# T028: Register Walker for type
		my $type-name = $type ~~ Str ?? $type !! $type.^name;
		%!walker-registry{$type-name} = $walker-type;
	}
    
	=begin pod

	=head2 C<!extract-walker-types(@raw)>

	=begin code
	method !extract-walker-types(@raw --> Array)
	=end code

	=head3 Parameters

	=item C<@raw>

	 Raw discovered walker type names before normalization.


	Converts raw C<Implementation::Loader> results into walker type objects.

	Loader failures are ignored per entry; only values that resolve and compose
	L<Qwiratry::Walker> are returned.

	=end pod
	method !extract-walker-types(@raw --> Array) {
		my @found;
		for @raw -> $item {
			next unless $item ~~ Associative;
			for $item.keys -> $name {
				my $value = $item{$name};
				next if $value ~~ Exception;
				try {
					my $type = ::($name);
					$type.does(Qwiratry::Walker) and @found.push($type);
				}
			}
		}
		return @found;
	}

	=begin pod

	=head2 C<discover-walkers(:@paths, Bool :$refresh)>

	=begin code
	method discover-walkers(:@paths = ['lib'], Bool :$refresh = False)
	=end code

	=head3 Parameters

	=item C<@paths>

	 Directories to search when discovering walker implementations.

	=item C<$refresh>

	 Whether discovery should ignore cached results and rescan.


	Discovers walker implementation type objects via C<Implementation::Loader>.

	Results are cached unless C<:$refresh> is true. Discovery scans the built-in
	C<Qwiratry::Walker::Implementation::*> namespace and test walker patterns, then
	filters the result through C<!extract-walker-types>.

	=end pod
	method discover-walkers(:@paths = ['lib'], Bool :$refresh = False) {
		# Return cached result if discovery already performed and refresh not requested
		if $!discovery-performed && !$refresh {
			return @!discovered-walkers;
		}

		my @search-paths = @paths;
		@search-paths.grep(* eq 'lib') or @search-paths.push('lib');

		try {
			my $discoverer = Implementation::Loader.new;
			my @raw = $discoverer.load-module-pattern(
				:globs([
					'Qwiratry::Walker::Implementation::*',
					'Qwiratry::Walker::Test*',
				]),
				:paths(@search-paths)
			);
			@!discovered-walkers = self!extract-walker-types(@raw).sort(*.^name);
			$!discovery-performed = True;
		}
		CATCH {
			default {
				X::Qwiratry::Walker.new(
					message => "Implementation::Loader discovery failed. Version 0.0.7 or higher is required. Error: {.message}",
					walker-type => 'Qwiratry::Walker::Factory'
				).throw;
			}
		}

		return @!discovered-walkers;
	}
}
