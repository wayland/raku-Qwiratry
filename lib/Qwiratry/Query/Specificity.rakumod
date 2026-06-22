=begin pod

Calculate mold ordering specificity scores from navigation Query AST nodes.

Scoring follows Specification.md section 3.3.2.4 (ORDER-MOLDS):

- Multilevel axes (descendant, ancestor, following, preceding) → −100
- Wildcards → −10
- Explicit path elements → +5
- Attribute axes → +5

Higher scores mean more specific molds and win ordering ties.

=end pod
use Qwiratry::Operator::Navigation;
use Qwiratry::Operator::Capability;
use Qwiratry::Operator::Set;
use Qwiratry::Operator::MapReduce;
use Qwiratry::Query::Selector;

class Qwiratry::Query::Specificity {

	my constant selector = Qwiratry::Query::Selector.instance;

	my $instance;

	=begin pod

	Return the shared Specificity scorer instance.

	=end pod
	method instance(--> Qwiratry::Query::Specificity) {
		$instance //= self.new
	}

	=begin pod

	Return a specificity score for a query AST fragment. Higher scores are more specific.

	Nested navigation operators accumulate scores from subject chains. Union-like
	structures use the maximum branch score.

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

	=begin pod

	Return True when C<$query> is a positional list of navigation operators (union syntax).

	=end pod
	method !is-union-query(Mu $query --> Bool) {
		$query.WHAT === Array || $query.WHAT === List or return False;
		$query.elems > 0 && $query[0] ~~ NavigationOperator;
	}

	=begin pod

	Score contribution from a single navigation operator node.

	=end pod
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

	=begin pod

	Score a navigation selector (wildcard, explicit path, or other).

	=end pod
	method !selector-contribution(Mu $selector --> Int) {
		selector.is-wildcard($selector) and return -10;
		selector.is-explicit-path($selector) and return 5;
		0;
	}
}
