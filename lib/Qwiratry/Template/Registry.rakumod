=begin pod

Collect templates and wrappers registered during transformer parsing.

Module-level storage keyed by compilation pass; drained when a transformer
class is finalized.

=end pod
use Qwiratry::Template;

unit class Qwiratry::Template::Registry;

my $instance;

=begin pod

Return the shared template registry instance.

=end pod
method instance(--> Qwiratry::Template::Registry) {
	$instance //= self.new
}

has @!templates;
has @!wrappers;

=begin pod

Register a compiled template with the module-level collection.

=end pod
method register-template(Template $template) {
	@!templates.push($template);
}

=begin pod

Register a wrapper block of the given C<$type> (TRANSFORMER, TEMPLATE_MATCHER, etc.).

=end pod
method register-wrapper(Str $type, Block $block) {
	@!wrappers.push(%(type => $type, block => $block));
}

=begin pod

Return collected templates and clear the module-level list.

=end pod
method collected-templates() {
	my @result = @!templates;
	@!templates = [];
	@result
}

=begin pod

Clear the template collection without returning it.

=end pod
method clear-templates() {
	@!templates = [];
}

=begin pod

Return collected wrappers and clear the module-level list.

=end pod
method collected-wrappers() {
	my @wrappers = @!wrappers;
	@!wrappers = [];
	@wrappers
}

=begin pod

Clear the wrapper collection without returning it.

=end pod
method clear-wrappers() {
	@!wrappers = [];
}
