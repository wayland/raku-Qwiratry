=begin pod

=head1 Overview

Abstract base classes for format implementations.

L<Qwiratry::Format> discovers concrete format modules dynamically and verifies
that each operation class inherits from the matching base class here. A format
module normally provides C<::Parse> and/or C<::Render> classes under its format
namespace, for example C<Qwiratry::Format::MyFormat::Parse>.

Formats whose parser emits a custom tree model may also provide a C<::TreeNavigator>
class that does C<Qwiratry::Format::Base::TreeNavigator>.

These classes are contracts rather than useful implementations. The default
methods throw so an incomplete plugin fails at the first attempted parse or
render instead of silently returning an invalid value.

=end pod
class Qwiratry::Format::Base::Parse {

	=begin pod

	=head1 Methods

	=head2 C<parse(Str $input-string)>

	=begin code
	method parse(Str $input-string --> Mu)
	=end code

	=head3 Parameters

	=item C<$input-string>

	 The external text to parse into Qwiratry data.


	Parses external text into structured Raku data.

	Concrete parsers override this method. Callers normally reach it through
	L<Qwiratry::Operator::IO::ParseOperator> or
	C<Qwiratry::Format.make(:type<Parse>, :format(...))>.

	=end pod
	method parse(Str $input-string --> Mu) {
		die "parse not implemented by {self.^name}";
	}
}

class Qwiratry::Format::Base::Render {

	=begin pod

	=head2 C<render(Mu $data, Associative :%options)>

	=begin code
	method render(Mu $data, Associative :%options --> Str)
	=end code

	=head3 Parameters

	=item C<$data>

	 The input data, root value, or rendered value handled by this operation.

	=item C<%options>

	 Named format options, such as rendering preferences.


	Renders structured Raku data to external text.

	Concrete renderers override this method and may interpret C<%options> in a
	format-specific way. The pipeline normalizes lazy query results before calling
	the renderer.

	=end pod
	method render(Mu $data, Associative :%options --> Str) {
		die "render not implemented by {self.^name}";
	}
}

role Qwiratry::Format::Base::TreeNavigator {
	=begin pod

	=head2 C<supported-types()>

	=begin code
	method supported-types(--> List)
	=end code

	Returns the types or roles this navigator handles. The default navigator
	handles ordinary Raku containers.

	=end pod
	method supported-types(--> List) { ... }

	=begin pod

	=head2 C<supports(Mu $node)>

	=begin code
	method supports(Mu $node --> Bool)
	=end code

	Returns whether C<$node> matches one of C<supported-types>.

	=end pod
	method supports(Mu $node --> Bool) {
		for self.supported-types -> $type {
			$node ~~ $type and return True;
		}
		False
	}

	=begin pod

	=head2 C<tree-children(Mu $node)>

	=begin code
	method tree-children(Mu $node --> List)
	=end code

	Returns direct children for ordinary Raku tree-shaped values.

	=end pod
	method tree-children(Mu $node --> List) { ... }

	=begin pod

	=head2 C<tree-parent(Mu $node, Mu :$origin)>

	=begin code
	method tree-parent(Mu $node, Mu :$origin --> Mu)
	=end code

	Returns a direct parent when the node model exposes one. Callers should fall
	back to context caches when this returns C<Nil>. When C<origin> is supplied,
	the default implementation walks from that root using this navigator's
	C<tree-children> method.

	=end pod
	method tree-parent(Mu $node, Mu :$origin --> Mu) {
		$node.can('parent') and return $node.parent;
		$origin.defined and return self.find-parent-in-tree($node, $origin);
		Nil
	}

	=begin pod

	=head2 C<find-parent-in-tree(Mu $node, Mu $current)>

	=begin code
	method find-parent-in-tree(Mu $node, Mu $current --> Mu)
	=end code

	Finds C<$node>'s direct parent by identity while walking from C<$current>.

	=end pod
	method find-parent-in-tree(Mu $node, Mu $current --> Mu) {
		$current.defined or return Nil;
		for self.tree-children($current) -> $child {
			$child === $node and return $current;
			my $found = self.find-parent-in-tree($node, $child);
			$found.defined and return $found;
		}
		Nil
	}

	=begin pod

	=head2 C<tree-attributes(Mu $node)>

	=begin code
	method tree-attributes(Mu $node --> Associative)
	=end code

	Returns attribute-like values when the node naturally exposes them.

	=end pod
	method tree-attributes(Mu $node --> Associative) {
		$node ~~ Associative and return $node;
		%()
	}
}

class Qwiratry::Format::Base::DefaultTreeNavigator does Qwiratry::Format::Base::TreeNavigator {
	method supported-types(--> List) {
		(Positional, Associative)
	}

	method tree-children(Mu $node --> List) {
		$node ~~ Positional and return $node.list;
		if $node ~~ Associative {
			if $node<children> ~~ Positional {
				return $node<children>.list;
			}
		}
		()
	}
}
