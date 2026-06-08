# Quickstart: Qwiratry Operators

**Feature**: 006-qwiratry-operators-specification  
**Date**: 2025-01-27

## Overview

Qwiratry operators are RakuAST::Node descendants that represent declarative query intent. They work in both Query Slang expressions and regular Raku code, enabling flexible query composition across different data domains.

## Key Concepts

### Operator Categories

1. **Navigation Operators** - Traverse hierarchical structures (trees, tables, graphs)
2. **Map-Reduce Operators** - Filter, sort, transform, and aggregate collections
3. **Set Operators** - Combine collections using set theory and relational algebra
4. **I/O Operators** - Read, parse, render, and write data

### Core Principles

- **Immutability**: Operators are immutable and safely shareable
- **Composability**: Operators can be chained and combined
- **Domain Flexibility**: Same operator may have different semantics per domain
- **Capability System**: Operators declare capabilities; Walkers check compatibility

## Basic Usage

### Creating Operators

```raku
use Qwiratry::Operator::Navigation;
use Qwiratry::Operator::MapReduce;

# Navigation operator
my $child-op = ChildOperator.new(selector => '*');

# Selection operator
my $select-op = SelectionOperator.new(
    predicate => { $_.age > 18 }
);
```

### Operator Composition

```raku
use Qwiratry::Operator::Set;

# Union of two queries
my $union-op = UnionOperator.new(
    left => $query1,
    right => $query2
);

# Chained navigation
my $nested = ChildOperator.new(
    selector => ChildOperator.new(selector => '*')
);
```

### Checking Capabilities

```raku
my $caps = $operator.capabilities;
if $caps<navigation> && 'tree' ∈ $caps<domains> {
    say "Operator supports tree navigation";
}
```

## Integration with Walkers

### Walker Compatibility

Walkers check operator compatibility during planning:

```raku
class TreeWalker does Walker {
    method plan(RakuAST::Node $query, Mu:D $root --> Walker::Plan) {
        # Check if operator is supported
        unless self.supports($query) {
            die X::Qwiratry::UnknownQueryElement.new(
                query-ast => $query,
                walker-type => self.^name
            );
        }
        # Create execution plan...
    }
    
    method supports(RakuAST::Node $query --> Bool) {
        my $caps = $query.capabilities;
        return $caps<navigation> && 'tree' ∈ $caps<domains>;
    }
}
```

## Common Patterns

### Navigation Pattern

```raku
# Navigate tree structure
my $children = ChildOperator.new(selector => 'item');
my $descendants = DescendantOperator.new(selector => '*');
```

### Table Foreign Key Navigation

Table-domain `⪪` follows foreign keys when the origin resolves to a `Catalog` (explicit
or discovered). Use `⥷` for column values without following the FK.

```raku
use Qwiratry::Table;
use Qwiratry::Query::Slang;
use Qwiratry::Query::Match;

my @orders = [(%(order_id => 1, customer_id => 10),)];
my @customers = [(%(customer_id => 10, name => 'Alice'),)];

my $catalog = make-catalog(
    :orders(@orders), :customers(@customers),
    :foreign-keys(
        ForeignKey.new(
            :from-table('orders'), :from-column('customer_id'),
            :to-table('customers'), :to-column('customer_id'),
        ),
    ),
    :active-table('orders'),
);

my $order = @orders[0];
my @customer = select($order ⪪ <customer_id>, $catalog).List;
my $fk-value = select($order ⥷ <customer_id>, $catalog).List[0];

# Reverse FK: rows that reference this customer
my @referencing = select(@customers[0] ⪫ <*> :reference, $catalog).List;
```

`⪪⪪` on a table **row** throws by default; add `:recursive` to follow the FK once:

```raku
my @once = select($order ⪪⪪ <customer_id> :recursive, $catalog).List;
```

### Schema Discovery

Skip manual `ForeignKey` declarations when table names and columns follow conventions
(`orders.customer_id` → `customers.customer_id`):

```raku
use Qwiratry::Table::Schema;

my %database = %(orders => @orders, customers => @customers);
my @related = select($order ⪪ <customer_id>, %database).List;

# Or attach schema to a single Positional root:
attach-schema(@orders, %(
    table-name => 'orders',
    tables => %(orders => @orders, customers => @customers),
));
```

### Ordered Row Navigation

Sibling and following/preceding operators use **positional order** in the catalog's
active table:

```raku
my @orders = [
    %(order_id => 1), %(order_id => 2), %(order_id => 3),
];
my $catalog = make-catalog(:orders(@orders), :active-table('orders'));

my $row = @orders[1];
my $next = select($row ⪨ <*>, $catalog).List[0];      # order_id 3
my $prev = select($row ⪩ <*>, $catalog).List[0];      # order_id 2
my @later = select($row ⪨⪨ <*>, $catalog).List;      # rows after index 1
```

### Lazy Evaluation

`select` returns a lazy `Seq`. Set operators and joins pull operands incrementally.

```raku
use Qwiratry::Query::Match;

my $query = @rows σ -> $_ { $_<score> >= 3 };
my $seq = select($query, @rows);           # lazy — not evaluated yet
my $first = $seq.first;                    # pulls until first match

# Walker execution is also incremental:
my $iter = $walker.plan($query, @rows).iterator;
while (my $row = $iter.pull-one) !~~ IterationEnd {
    # one row at a time
}
```

Avoid `.list` on `select` results unless you need full materialization.

### Filtering Pattern

```raku
# Selection with predicate
my $filtered = SelectionOperator.new(
    predicate => { $_.price > 100 && $_.active }
);

# Sort by key
my $sorted = SortOperator.new(
    key-function => { $_.name }
);
```

### Set Operations Pattern

```raku
# Union
my $combined = UnionOperator.new(
    left => $query1,
    right => $query2
);

# Intersection
my $common = IntersectionOperator.new(
    left => $query1,
    right => $query2
);

# Cross join (Cartesian product) - U+00D7, via slang when Query::Slang is loaded
my $cartesian = $relation1 × $relation2;
```

### I/O Pattern

```raku
# Read and parse
my $source = SourceOperator.new(location => 'data.json');
my $parsed = ParseOperator.new(format => 'JSON');

# Render and write
my $rendered = RenderOperator.new(
    format => 'JSON',
    options => { pretty => True }
);
my $dest = DestinationOperator.new(location => 'output.json');
```

## Error Handling

### Compile-Time Errors

Invalid operator syntax is caught by Raku compiler:

```raku
# This will fail at compile-time
my $bad = ChildOperator.new();  # Missing required selector
```

### Planning-Time Errors

Unsupported operators throw during planning:

```raku
try {
    my $plan = $walker.plan($unsupported-operator, $root);
} catch X::Qwiratry::UnknownQueryElement {
    say "Operator not supported by this walker";
}
```

### Runtime Errors

Data validation errors occur during execution:

```raku
# Invalid foreign key navigation
try {
    my $iter = $walker.start($query, $root);
    $iter.pull-one;
} catch X::Qwiratry::Navigation::InvalidForeignKey {
    say "Foreign key not found";
}
```

## Next Steps

All operator categories from the 006 specification are implemented:

1. Navigation operators (WP03)
2. Map-reduce operators: selection, sort, map, reduce (WP04)
3. Set and relational algebra operators (WP05)
4. I/O operators with JSON, XML, and CSV format modules (WP06)
5. Integration tests, precedence checks, and performance baselines (WP07)

Load `Qwiratry::Query::Slang` for unicode operator syntax. Load format modules
(e.g. `Qwiratry::IO::Parse::JSON`) before constructing parse/render operators.

See `t/integration/quickstart-examples.rakutest` for runnable examples.

## References

- **Specification**: [spec.md](spec.md)
- **Data Model**: [data-model.md](data-model.md)
- **API Contract**: [contracts/operator-api.md](contracts/operator-api.md)
- **Operators Reference**: `../../Operators.md`

