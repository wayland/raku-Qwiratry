=begin pod

=head1 Overview

Tree navigation protocol, discovery, and registry.

Custom tree models provide navigator classes under
C<Qwiratry::Tree::Navigator::*>. Qwiratry selects a navigator for a node by
checking discovered navigators, domain registrations, explicit type
registrations, and caller supplied registrations before falling back to ordinary
Raku containers.

=end pod
use Implementation::Loader;
use Qwiratry::Tree::Navigator::Base;
use Qwiratry::Walker::Providing;

class Qwiratry::Tree::Navigator does Implementation::Loader {

	constant @LIB-PATHS = 'lib';
	constant NAVIGATOR-GLOB = 'Qwiratry::Tree::Navigator::*';

	# Cached discovered navigator names and instances.
	has @!navigator-names;
	has @!discovered-tree-navigators;
	# Explicitly registered TreeNavigator instances selected by supported-types.
	has @!registered-tree-navigators;
	# Explicit type/role to TreeNavigator registrations.
	has @!registered-tree-navigator-types;
	# Domain label to TreeNavigator registrations.
	has %!domain-tree-navigators;

	my $instance;

	=begin pod

	Return the shared navigator registry instance.

	=end pod
	method instance() {
		$instance //= self.new
	}

	=begin pod

	Normalize navigator labels by stripping file or namespace decoration.

	=end pod
	method normalize-navigator-name(Str $navigator --> Str) {
		my $name = $navigator.subst(/\.rakumod$/, '');
		$name.contains('::') and $name = $name.split('::').[*-1];
		my $canonical = self.DEFINITE ?? self!canonical-navigator-name($name)
			!! self.instance!canonical-navigator-name($name);
		$canonical.defined and return $canonical;
		$name
	}

	=begin pod

	Return the fully qualified navigator module name.

	=end pod
	method navigator-module-name(Str $navigator --> Str) {
		'Qwiratry::Tree::Navigator::' ~ self.normalize-navigator-name($navigator)
	}

	# Return navigator labels from discovered Qwiratry::Tree::Navigator::* modules.
	method !discovered-navigator-names(--> List) {
		unless @!navigator-names {
			@!navigator-names = self.find-module-pattern(
				:globs([NAVIGATOR-GLOB]),
				:paths(@LIB-PATHS),
			).map({
				my @parts = .split('::');
				@parts == 4 ?? @parts[3] !! Nil;
			}).grep({
				.defined && .uc ne 'BASE'
			}).sort.Array;
		}
		@!navigator-names.list
	}

	# Resolve user-provided spelling to the navigator module's canonical name.
	method !canonical-navigator-name(Str $name --> Mu) {
		self!discovered-navigator-names.first({ .lc eq $name.lc })
	}

	# Load a navigator module, resolve its class, and verify the protocol role.
	method !implementation-type(Str $navigator) {
		my $module = self.navigator-module-name($navigator);
		my $class-name = $module;
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
		!($implementation =:= Nil)
			&& $implementation ~~ Qwiratry::Tree::Navigator::Base
			and return $implementation;
		False
	}

	=begin pod

	Return sorted labels for discovered tree navigator implementations.

	=end pod
	method navigators(--> List) {
		self.DEFINITE or return self.instance.navigators;
		self!discovered-navigator-names.grep({
			my $implementation = self!implementation-type($_);
			$implementation !~~ Bool
		}).sort.list
	}

	=begin pod

	Verify that a navigator exists; throw otherwise.

	=end pod
	method ensure-navigator(Str :$navigator! --> Str) {
		self.DEFINITE or return self.instance.ensure-navigator(:$navigator);
		my $navigator-name = self.normalize-navigator-name($navigator);
		my $class = self.navigator-module-name($navigator-name);
		unless $navigator-name (elem) self.navigators {
			die "tree navigator module not found for $navigator";
		}
		$class
	}

	# Load a concrete navigator instance.
	method !implementation(Str $navigator) {
		my $navigator-name = self.normalize-navigator-name($navigator);
		self.ensure-navigator(:navigator($navigator-name));
		self!implementation-type($navigator-name).new
	}

	=begin pod

	Return the concrete navigator for C<$navigator>.

	=end pod
	method make(Str :$navigator!) {
		self.instance!implementation($navigator)
	}

	=begin pod

	Register a navigator that should be selected by its C<supported-types>.

	=end pod
	method register-tree-navigator(Qwiratry::Tree::Navigator::Base $navigator --> Mu) {
		self.DEFINITE or return self.instance.register-tree-navigator($navigator);
		@!registered-tree-navigators.push($navigator);
		$navigator
	}

	=begin pod

	Register a navigator for a specific type or role.

	=end pod
	method register-tree-navigator-for-type(
		Mu $type,
		Qwiratry::Tree::Navigator::Base $navigator --> Mu
	) {
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
	method register-tree-navigator-for-domain(
		Str $domain,
		Qwiratry::Tree::Navigator::Base $navigator --> Mu
	) {
		self.DEFINITE or return self.instance.register-tree-navigator-for-domain($domain, $navigator);
		%!domain-tree-navigators{$domain} //= [];
		%!domain-tree-navigators{$domain}.push($navigator);
		$navigator
	}

	# Return discovered tree navigator instances.
	method !discovered-tree-navigators(--> List) {
		unless @!discovered-tree-navigators {
			my @navigators;
			for self.navigators -> $navigator {
				@navigators.push(self!implementation($navigator));
			}
			@!discovered-tree-navigators = @navigators;
		}
		@!discovered-tree-navigators.list
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
			|self!discovered-tree-navigators,
			|%!domain-tree-navigators.values.flat,
			|@!registered-tree-navigator-types.map(*<navigator>),
			|@!registered-tree-navigators,
			Qwiratry::Tree::Navigator::Base.new,
		).list
	}

	=begin pod

	Select a tree navigator for C<$node>.

	=end pod
	method tree-navigator-for(Mu $node, Mu :$navigator, Mu :$origin) {
		self.DEFINITE or return self.instance.tree-navigator-for($node, :$navigator, :$origin);
		if $navigator.defined {
			$navigator ~~ Qwiratry::Tree::Navigator::Base and return $navigator;
			die "tree navigator override must do Qwiratry::Tree::Navigator::Base";
		}
		for self!discovered-tree-navigators -> $navigator {
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
		Qwiratry::Tree::Navigator::Base.new
	}
}
