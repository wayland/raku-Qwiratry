=begin pod

Collect templates and wrappers registered during transformer parsing.

=end pod
use Qwiratry::Template;

unit class Qwiratry::Template::Registry;

my $instance;

method instance(--> Qwiratry::Template::Registry) {
	$instance //= self.new
}

has @!templates;
has @!wrappers;

method register-template(Template $template) {
	@!templates.push($template);
}

method register-wrapper(Str $type, Block $block) {
	@!wrappers.push(%(type => $type, block => $block));
}

method collected-templates() {
	my @result = @!templates;
	@!templates = [];
	@result
}

method clear-templates() {
	@!templates = [];
}

method collected-wrappers() {
	my @wrappers = @!wrappers;
	@!wrappers = [];
	@wrappers
}

method clear-wrappers() {
	@!wrappers = [];
}
