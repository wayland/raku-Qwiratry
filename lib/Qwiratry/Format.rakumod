=begin pod

Format implementation factory.

Use L<make> with an operation type and format name to obtain a concrete
implementation object:

=begin code
Qwiratry::Format.make(:type<Parse>, :format<JSONdemo>)
Qwiratry::Format.make(:type<Render>, :format<JSONdemo>)
=end code

Format modules live under C<Qwiratry::Format::<FORMAT>> and define operation
classes such as C<Qwiratry::Format::JSONdemo::Parse> and
C<Qwiratry::Format::JSONdemo::Render>.

=end pod
use Implementation::Loader;
use X::Qwiratry;
use Qwiratry::Format::Base;
use Qwiratry::Walker::Providing;

class Qwiratry::Format does Implementation::Loader {

	constant @LIB-PATHS = 'lib';
	constant FORMAT-GLOB = 'Qwiratry::Format::*';

	# Cached implementation instances keyed by operation type and format name.
	has %!implementation-cache;
	# Cached discovered format names keyed by operation type.
	has %!format-list-cache;
	# Cached TreeNavigator instances discovered from format modules.
	has @!format-tree-navigators;
	# Explicitly registered TreeNavigator instances selected by supported-types.
	has @!registered-tree-navigators;
	# Explicit type/role to TreeNavigator registrations.
	has @!registered-tree-navigator-types;
	# Domain label to TreeNavigator registrations.
	has %!domain-tree-navigators;

	my $instance;

	=begin pod

	Return the shared format factory instance.

	=end pod
	method instance() {
		$instance //= self.new
	}

	=begin pod

	Normalize operation type labels by stripping file or namespace decoration.

	=end pod
	method normalize-type-name(Str $type --> Str) {
		my $name = $type.subst(/\.rakumod$/, '');
		$name.contains('::') and $name = $name.split('::').[*-1];
		$name
	}

	=begin pod

	Normalize format labels (for example C<jsondemo> or C<Qwiratry::Format::JSONdemo>)
	to discovered module names when available.

	=end pod
	method normalize-format-name(Str $format --> Str) {
		self.DEFINITE or return self.instance.normalize-format-name($format);
		my $name = $format.subst(/\.rakumod$/, '');
		$name.contains('::') and $name = $name.split('::').[*-1];
		my $canonical = self!canonical-format-name($name);
		$canonical.defined and return $canonical;
		$name.uc
	}

	=begin pod

	Return the fully qualified format module name for C<$format>.

	=end pod
	method format-module-name(Str $format --> Str) {
		'Qwiratry::Format::' ~ self.normalize-format-name($format)
	}

	=begin pod

	Return the fully qualified implementation class name for C<$type> and C<$format>.

	=end pod
	method format-class-name(Str $type, Str $format --> Str) {
		self.format-module-name($format) ~ '::' ~ self.normalize-type-name($type)
	}

	# Return the abstract base class name for an operation type.
	method !base-class-name(Str $type --> Str) {
		'Qwiratry::Format::Base::' ~ self.normalize-type-name($type)
	}

	# Return format module labels from discovered Qwiratry::Format::* modules.
	method !discovered-format-names(--> List) {
		self.find-module-pattern(
			:globs([FORMAT-GLOB]),
			:paths(@LIB-PATHS),
		).map({
			my @parts = .split('::');
			@parts == 3 ?? @parts[2] !! Nil;
		}).grep({
			.defined && .uc ne 'BASE'
		}).Array
	}

	# Resolve user-provided spelling to the format module's canonical name.
	method !canonical-format-name(Str $name --> Mu) {
		self!discovered-format-names.first({ .lc eq $name.lc })
	}

	# Derive a format label from a discovered format module FQCN.
	method !format-name-from-module(Str $module --> Str) {
		$module.split('::').elems == 3 or return Nil;
		my $format = $module.split('::')[2];
		$format.uc eq 'BASE' and return Nil;
		$format
	}

	# Normalize the operation and format pair used by factory dispatch.
	method !type-and-format-names(Str $type, Str $format --> List) {
		(self.normalize-type-name($type), self.normalize-format-name($format))
	}

	# Load a format module, resolve its operation class, and verify inheritance.
	method !implementation-type(Str $type, Str $format) {
		my $module = self.format-module-name($format);
		my $class-name = self.format-class-name($type, $format);
		my $base-class = self!base-class-name($type);
		my $implementation = try {
			self.load-library(
				:module-name($module),
				:type($class-name),
				:return-type(True),
			);
		};
		if !$implementation.defined || $implementation ~~ Bool {
			try {
				self.load-library(:module-name($module));
				$implementation = ::($class-name);
			}
		}
		$implementation ~~ Bool and return False;
		my $base = try { ::($base-class) };
		!($base =:= Nil) && !($implementation =:= Nil) && $implementation ~~ $base and return $implementation;
		False
	}

	=begin pod

	Return sorted format labels for implementations of operation C<$type>.

	=end pod
	method formats(Str :$type! --> List) {
		self.DEFINITE or return self.instance.formats(:$type);
		my $type-name = self.normalize-type-name($type);
		unless %!format-list-cache{$type-name}:exists {
			%!format-list-cache{$type-name} = self.find-module-pattern(
				:globs([FORMAT-GLOB]),
				:paths(@LIB-PATHS),
			).map({ self!format-name-from-module($_) })
			.grep(*.defined)
			.grep({
				my $implementation = self!implementation-type($type-name, $_);
				$implementation !~~ Bool
			})
			.sort.Array;
		}
		%!format-list-cache{$type-name}.list
	}

	=begin pod

	Verify that an implementation exists for C<$type> and C<$format>; throw otherwise.

	=end pod
	method ensure-format(Str :$type!, Str :$format! --> Str) {
		self.DEFINITE or return self.instance.ensure-format(:$type, :$format);
		my ($type-name, $format-name) = self!type-and-format-names($type, $format);
		my $class = self.format-class-name($type-name, $format-name);
		unless $format-name (elem) self.formats(:type($type-name)) {
			X::Qwiratry::Format::NotFound.new(
				:message("$type-name format module not found for $format"),
				:format($format-name),
				:parse-or-render($type-name),
				:operator-type("{$type-name}Operator"),
			).throw;
		}
		$class
	}

	# Load (or return cached) implementation instance for operation type and format.
	method !implementation(Str $type, Str $format) {
		my ($type-name, $format-name) = self!type-and-format-names($type, $format);
		my $key = "$type-name|$format-name";
		unless %!implementation-cache{$key}:exists {
			self.ensure-format(:type($type-name), :format($format-name));
			%!implementation-cache{$key} = self!implementation-type($type-name, $format-name).new;
		}
		%!implementation-cache{$key}
	}

	=begin pod

	Return the concrete implementation for operation C<$type> and C<$format>.

	=end pod
	method make(Str :$type!, Str :$format!) {
		self.instance!implementation($type, $format)
	}

	=begin pod

	Register a navigator that should be selected by its C<supported-types>.

	=end pod
	method register-tree-navigator(Qwiratry::Format::Base::TreeNavigator $navigator --> Mu) {
		self.DEFINITE or return self.instance.register-tree-navigator($navigator);
		@!registered-tree-navigators.push($navigator);
		$navigator
	}

	=begin pod

	Register a navigator for a specific type or role.

	=end pod
	method register-tree-navigator-for-type(Mu $type, Qwiratry::Format::Base::TreeNavigator $navigator --> Mu) {
		self.DEFINITE or return self.instance.register-tree-navigator-for-type($type, $navigator);
		@!registered-tree-navigator-types.push(%(
			type => $type,
			navigator => $navigator,
		));
		$navigator
	}

	=begin pod

	Register a navigator for roots or nodes that provide C<$domain>.

	=end pod
	method register-tree-navigator-for-domain(Str $domain, Qwiratry::Format::Base::TreeNavigator $navigator --> Mu) {
		self.DEFINITE or return self.instance.register-tree-navigator-for-domain($domain, $navigator);
		%!domain-tree-navigators{$domain} //= [];
		%!domain-tree-navigators{$domain}.push($navigator);
		$navigator
	}

	# Return discovered format-supplied tree navigator instances.
	method !format-tree-navigators(--> List) {
		unless @!format-tree-navigators {
			my @navigators;
			for self.formats(:type<TreeNavigator>) -> $format {
				@navigators.push(self!implementation('TreeNavigator', $format));
			}
			@!format-tree-navigators = @navigators;
		}
		@!format-tree-navigators.list
	}

	# Return registered domain navigators matching metadata on the origin or node.
	method !domain-tree-navigators(Mu $node, Mu :$origin --> List) {
		my @domains;
		my $providing = Qwiratry::Walker::Providing.instance;
		if $origin.defined {
			@domains.append($providing.cached-domains($origin) // $providing.domains($origin) // ());
		}
		if !$origin.defined || !($node === $origin) {
			@domains.append($providing.cached-domains($node) // $providing.domains($node) // ());
		}

		my @navigators;
		for @domains.unique -> $domain {
			%!domain-tree-navigators{$domain}:exists or next;
			@navigators.append(|%!domain-tree-navigators{$domain});
		}
		@navigators.list
	}

	=begin pod

	Return registered and discovered tree navigator instances.

	=end pod
	method tree-navigators(--> List) {
		self.DEFINITE or return self.instance.tree-navigators;
		(
			|self!format-tree-navigators,
			|%!domain-tree-navigators.values.flat,
			|@!registered-tree-navigator-types.map(*<navigator>),
			|@!registered-tree-navigators,
			Qwiratry::Format::Base::DefaultTreeNavigator.new,
		).list
	}

	=begin pod

	Select a tree navigator for C<$node>.

	=end pod
	method tree-navigator-for(Mu $node, Mu :$navigator, Mu :$origin) {
		self.DEFINITE or return self.instance.tree-navigator-for($node, :$navigator, :$origin);
		if $navigator.defined {
			$navigator ~~ Qwiratry::Format::Base::TreeNavigator and return $navigator;
			die "tree navigator override must do Qwiratry::Format::Base::TreeNavigator";
		}
		for self!format-tree-navigators -> $navigator {
			$navigator.supports($node) and return $navigator;
		}
		for self!domain-tree-navigators($node, :$origin) -> $navigator {
			$navigator.supports($node) and return $navigator;
		}
		for @!registered-tree-navigator-types -> %registration {
			$node ~~ %registration<type> and return %registration<navigator>;
		}
		for @!registered-tree-navigators -> $navigator {
			$navigator.supports($node) and return $navigator;
		}
		Qwiratry::Format::Base::DefaultTreeNavigator.new
	}
}
