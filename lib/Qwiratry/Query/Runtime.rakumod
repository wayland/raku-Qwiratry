=begin pod

=head1 Overview

Runtime engine for evaluating query AST nodes.

The runtime owns evaluator registration and the recursive callbacks that tie
operator-specific evaluators together.

=end pod
unit class Qwiratry::Query::Runtime;

use Qwiratry::Operator::Navigation;
use Qwiratry::Operator::Capability;
use Qwiratry::Operator::Set;
use Qwiratry::Operator::MapReduce;
use Qwiratry::Operator::IO;
use Qwiratry::Query::Relational;
use Qwiratry::Query::Topic;
use Qwiratry::Query::TreeNavigation;
use Qwiratry::Query::Evaluator::Lazy;
use Qwiratry::Query::Evaluator::Union;
use Qwiratry::Query::Evaluator::Set;
use Qwiratry::Query::Evaluator::Join;
use Qwiratry::Query::Evaluator::Row;
use Qwiratry::Query::Evaluator::Filter;
use Qwiratry::Query::Evaluator::Navigation;
use Qwiratry::Query::Evaluator::Relational;
use Qwiratry::Query::Evaluator::MapReduce;

also does TreeNavigation;

	my $instance;
	has %!evaluators;
	has $.relational = Qwiratry::Query::Relational.instance;
	has $.lazy-evaluator = BasicLazyEvaluator.new;

	method instance(--> Qwiratry::Query::Runtime) {
		$instance //= self.new
	}

	method evaluators() {
		unless %!evaluators {
			my &select-list = -> Mu $query, Mu $origin {
				self.select-list($query, $origin)
			};
			my &select-relation = -> Mu $operand, Mu $origin {
				self.select-relation($operand, $origin)
			};

			%!evaluators = %(
				UnionOperator => UnionEvaluator.new,
				IntersectionOperator => IntersectionEvaluator.new,
				SetDifferenceOperator => SetDifferenceEvaluator.new,
				SymmetricDifferenceOperator => SymmetricDifferenceEvaluator.new,
				InnerJoinOperator => InnerJoinEvaluator.new,
				LeftOuterJoinOperator => LeftOuterJoinEvaluator.new,
				RightOuterJoinOperator => RightOuterJoinEvaluator.new,
				FullOuterJoinOperator => FullOuterJoinEvaluator.new,
				LeftSemijoinOperator => LeftSemijoinEvaluator.new,
				RightSemijoinOperator => RightSemijoinEvaluator.new,
				LeftAntijoinOperator => LeftAntijoinEvaluator.new,
				RightAntijoinOperator => RightAntijoinEvaluator.new,
				CrossJoinOperator => CrossJoinEvaluator.new,
				ProjectionOperator => ProjectionEvaluator.new,
				RenameOperator => RenameEvaluator.new,
				SelectionOperator => SelectionEvaluator.new,
				RootOperator => RootEvaluator.new(:&select-list),
				ChildOperator => ChildEvaluator.new(:&select-list),
				DescendantOperator => DescendantEvaluator.new(:&select-list),
				AttributeOperator => AttributeEvaluator.new(:&select-list),
				ParentOperator => ParentEvaluator.new(:&select-list),
				AncestorOperator => AncestorEvaluator.new(:&select-list),
				FollowingSiblingOperator => FollowingSiblingEvaluator.new(:&select-list),
				PrecedingSiblingOperator => PrecedingSiblingEvaluator.new(:&select-list),
				FollowingOperator => FollowingEvaluator.new(:&select-list),
				PrecedingOperator => PrecedingEvaluator.new(:&select-list),
				ElementOfOperator => ElementOfEvaluator.new(:&select-list, :&select-relation),
				ContainsOperator => ContainsEvaluator.new(:&select-list, :&select-relation),
				SubsetOperator => SubsetEvaluator.new(:&select-list, :&select-relation),
				SubsetOrEqualOperator => SubsetOrEqualEvaluator.new(:&select-list, :&select-relation),
				IdentityOperator => IdentityEvaluator.new(:&select-list, :&select-relation),
				DivisionOperator => DivisionEvaluator.new(:&select-list, :&select-relation),
				SortOperator => SortEvaluator.new(:&select-list),
				MapOperator => MapEvaluator.new(:&select-list),
				ReduceOperator => ReduceEvaluator.new(:&select-list),
			);
		}
		%!evaluators
	}

	method when-query-matches(Mu $query, Mu $node, Mu :$origin --> Bool) {
		$query.defined or return False;
		if self.query-uses-topic($query) {
			return self.mold-topic-matches($query, $node, :$origin);
		}
		self.node-matches($query, $node, :$origin);
	}

	method query-uses-topic(Mu $query --> Bool) {
		self.is-topic($query) and return True;
		if $query.can('subject') && $query.subject.defined {
			self.is-topic($query.subject) and return True;
			$query.subject ~~ NavigationOperator
				and return self.query-uses-topic($query.subject);
		}
		if $query.can('left') && $query.can('right') {
			return self.query-uses-topic($query.left)
				|| self.query-uses-topic($query.right);
		}
		False
	}

	method mold-topic-matches(Mu $query, Mu $node, Mu :$origin --> Bool) {
		self.match-topic-chain($query, $node, :$origin);
	}

	method match-topic-chain(Mu $query, Mu $node, Mu :$origin --> Bool) {
		$query.defined or return False;
		self.is-topic($query) and return True;
		$query.can('evaluator-key') or return False;

		my $evaluator = self.evaluators{$query.evaluator-key};
		if $evaluator.defined && $evaluator.can('topic-matches') {
			my &topic-matches = -> Mu $query, Mu $node, Mu :$origin {
				self.match-topic-chain($query, $node, :$origin)
			};
			return $evaluator.topic-matches(
				$query,
				$node,
				:$origin,
				:&topic-matches,
			);
		}

		False
	}

	method select(Mu $query, Mu $origin --> Seq) {
		self.select-seq($query, $origin);
	}

	method node-matches(Mu $query, Mu $node, Mu :$origin --> Bool) {
		my $start = self.query-origin($query, $origin);
		for self.select-list($query, $start) -> $candidate {
			$candidate === $node and return True;
		}
		False
	}

	method select-list(Mu $query, Mu $origin --> List) {
		$query.defined or return ();
		self.select-seq($query, $origin).list;
	}

	method select-seq(Mu $query, Mu $origin --> Seq) {
		$query.defined or return ().Seq;

		given $query {
			when SelectionOperator {
				my $evaluator = self.evaluators{$query.evaluator-key}
					// die "No evaluator registered for {$query.^name}";
				my &select-seq = -> Mu $query, Mu $origin {
					self.select-seq($query, $origin)
				};
				return $evaluator.select-seq(
					$query,
					$origin,
					:&select-seq,
				);
			}
			when LazyEvaluatedOperator {
				my $evaluator = self.evaluators{$query.evaluator-key}
					// die "No evaluator registered for {$query.^name}";
				my &relation-source = -> Mu $operand, Mu $origin {
					self.relation-source($operand, $origin)
				};
				return $evaluator.select-seq($query, $origin, :&relation-source);
			}
			default {
				my @items = self.select-list-eager($query, $origin);
				@items or return ().Seq;
				return $.lazy-evaluator.lazy-from-list(@items);
			}
		}
	}

	method relation-source(Mu $operand, Mu $origin) {
		if $operand ~~ NavigationOperator | SetOperator | MapReduceOperator | AdaptorOperator | RootOperator {
			return self.select-seq($operand, $origin);
		}
		if $operand ~~ Iterator | Positional {
			return $operand;
		}
		self.select-seq($operand, $origin);
	}

	method select-list-eager(Mu $query, Mu $origin --> List) {
		$query.defined or return ();

		given $query {
			when EagerEvaluatedOperator {
				my $evaluator = self.evaluators{$query.evaluator-key}
					// die "No eager evaluator registered for {$query.^name}";
				return $evaluator.eager($query, $origin);
			}
			default {
				if self.is-union-query-list($query) {
					my @combined;
					for $query.list -> $branch {
						@combined.append(self.select-list($branch, $origin));
					}
					return self.unique-nodes(|@combined);
				}
				return ();
			}
		}
	}

	method query-origin(Mu $query, Mu $fallback --> Mu) {
		if $query.can('subject') && $query.subject.defined {
			if $query.subject ~~ NavigationOperator {
				return self.query-origin($query.subject, $fallback);
			}
			return $query.subject;
		}
		$fallback
	}

	method is-union-query-list(Mu $query --> Bool) {
		$query.WHAT === Array || $query.WHAT === List or return False;
		$query.elems > 0 && $query[0] ~~ NavigationOperator;
	}

	method unique-nodes(*@nodes --> List) {
		my @unique;
		for @nodes -> $node {
			next if $.relational.node-in-list($node, @unique);
			@unique.push($node);
		}
		@unique
	}

	method select-relation(Mu $operand, Mu $origin --> List) {
		if $operand ~~ Positional {
			$operand ~~ NavigationOperator or return $operand.list;
		}
		self.select-list($operand, $origin)
	}

	method is-topic(Mu $query --> Bool) {
		$query ~~ NavQueryTopic
	}
