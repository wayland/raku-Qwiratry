=begin pod

Calculate mold ordering specificity scores from navigation Query AST nodes.

Scoring follows Specification.md section 3.3.2.4 (ORDER-MOLDS):

=item Multilevel axes (descendant, ancestor, following, preceding) → −100

=item Wildcards → −10

=item Explicit path elements → +5

=item Attribute axes → +5

Higher scores mean more specific molds and win ordering ties.

=end pod
use Qwiratry::Operator::Navigation;
use Qwiratry::Operator::Capability;
use Qwiratry::Operator::Set;
use Qwiratry::Operator::MapReduce;
use Qwiratry::Query::Selector;

=begin pod

=head2 C<class Qwiratry::Query::Specificity>

=begin code :lang<raku>
class Qwiratry::Query::Specificity
=end code

Defines C<Qwiratry::Query::Specificity>.

=end pod
class Qwiratry::Query::Specificity {

	my constant selector = Qwiratry::Query::Selector.instance;

	my $instance;

	=begin pod

	Return the shared Specificity scorer instance.

	=end pod
	=begin pod

	=head2 C<method instance>

	=begin code :lang<raku>
	method instance(--> Qwiratry::Query::Specificity)
	=end code

	Documents C<method instance>.

	=end pod
	method instance(--> Qwiratry::Query::Specificity) {
		$instance //= self.new
	}

	=begin pod

	Return a specificity score for a query AST fragment. Higher scores are more specific.

	Nested navigation operators accumulate scores from subject chains. Union-like
	structures use the maximum branch score.

	=end pod
	=begin pod

	=head2 C<method score>

	=begin code :lang<raku>
	method score(Mu $query --> Int)
	=end code

	Documents C<method score>.

	=item C<$query>

	The C<$query> parameter.

	=end pod
	method score(Mu $query --> Int) {
		$query.defined or return 0;

		if $query ~~ NavigationOperator {
			my $total = self!operator-contribution($query);
			if $query.can('subject') && $query.subject.defined {
				$total += self.score($query.subject);
			}
			return $total;
		}

		if self!is-union-query($query) {
			my $max = 0;
			for $query.list -> $branch {
				my $branch-score = self.score($branch);
				$branch-score > $max and $max = $branch-score;
			}
			return $max;
		}

		if $query ~~ UnionOperator | IntersectionOperator | SetDifferenceOperator
				| SymmetricDifferenceOperator {
			my $left = self.score($query.left);
			my $right = self.score($query.right);
			return $left > $right ?? $left !! $right;
		}

		if $query ~~ SelectionOperator | SortOperator | MapOperator | ReduceOperator {
			$query.can('subject') && $query.subject.defined and return self.score($query.subject);
			return 0;
		}

		0;
	}

	# method !is-union-query(Mu $query --> Bool)
	#
	# Documents the private C<method !is-union-query> helper.
	# $query - The $query parameter.
	method !is-union-query(Mu $query --> Bool) {
		$query.WHAT === Array || $query.WHAT === List or return False;
		$query.elems > 0 && $query[0] ~~ NavigationOperator;
	}

	# method !operator-contribution(Mu $op --> Int)
	#
	# Documents the private C<method !operator-contribution> helper.
	# $op - The $op parameter.
	method !operator-contribution(Mu $op --> Int) {
		given $op {
			when DescendantOperator | AncestorOperator | FollowingOperator | PrecedingOperator {
				self!selector-contribution($op.selector) - 100;
			}
			when AttributeOperator {
				self!selector-contribution($op.key) + 5;
			}
			when RootOperator {
				0;
			}
			when ChildOperator | ParentOperator | FollowingSiblingOperator | PrecedingSiblingOperator {
				self!selector-contribution($op.selector);
			}
			default {
				0;
			}
		}
	}

	# method !selector-contribution(Mu $selector --> Int)
	#
	# Documents the private C<method !selector-contribution> helper.
	# $selector - The $selector parameter.
	method !selector-contribution(Mu $selector --> Int) {
		selector.is-wildcard($selector) and return -10;
		selector.is-explicit-path($selector) and return 5;
		0;
	}
}
