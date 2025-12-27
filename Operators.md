# Qwiratry Operators Specification

## 1. Introduction

This document specifies the query operators available in Raku Qwiratry. All operators are implemented as **Query AST objects** (descendants of `RakuAST::Node`) that represent declarative query intent. Operators are interpreted by **Walkers** during the planning phase and executed via **QueryIterators** during traversal.

### 1.1 Architecture Integration

In Qwiratry, operators are part of the **Query Group** - they describe *what* to query, not *how* to execute. The architecture separates:

- **Query AST** (operators) - Declarative intent, immutable, composable
- **Walker** - Interprets operators during `plan()` phase, determines execution strategy
- **QueryIterator** - Produces results incrementally during traversal
- **Transformer** - Can use operators in template `when` clauses for node selection

### 1.2 Key Design Principles

- **Declarative Semantics**: Operators specify *what* to find, not *how* to find it
- **Immutability**: Query AST nodes are immutable and can be safely shared
- **Composability**: Operators can be combined to form complex queries
- **Domain Flexibility**: Same operator may have different semantics for trees vs tables
- **Lazy Evaluation**: Results are produced incrementally via QueryIterator
- **Introspectable**: Walkers can examine operator structure for optimization

### 1.3 Usage Contexts

Operators can be used in:

1. **Query Slang expressions** - Direct query construction
2. **Transformer templates** - In `when` clauses for node matching
3. **Inline code** - As part of Raku expressions that produce Query AST

## 2. Operator Precedence

The precedence levels mentioned here follow Raku's [Operator Precedence](https://docs.raku.org/language/operators#Operator_precedence) rules. Qwiratry operators are integrated into this precedence hierarchy.

### 2.1 Precedence Table

Precedence levels in bold are standard Raku levels.  Those not in bold are levels we've added.  

| Precedence Level   | Associativity | Operators | Comments |
|--------------------|---------------|-----------|----------|
| **Symbolic Unary** | non  | ⇤ | Unary postfix |
| **Replication**    | left | σ Π ρ ⪪ ⪫ ⪪⪪ ⪫⪫ ⪨ ⪩ ⪨⪨ ⪩⪩ ⥷  ↱ ⮣ ↴ ⮧ ⮳ ⮷ | |
| **Concatenation**  | list | ⋉ ⋊ ▷ ◁ ⨝ ⟕ ⟖ ⟗ ÷ ▵ X | |
| Junctive Exponentiation | right | 𝒫 | Tighter than Junctive unary |
| Junctive unary     | left | ⧩ | Tighter than Junctive and |
| **Junctive and**   | list | ∩ ⩃ | |
| **Junctive or**    | list | ∪ ⩂ ⊖ ∖ | |
| **Chaining**       | chain | ∈ ∊ (elem) ∉ ∋ ∍ (cont) ∌ ⊂ (<) ⊄ ⊃ (>) ⊅ ⊆ (<=) ⊈ ⊇ (>=) ⊉ ≡ (==) ≢ | |

## 3. I/O and Transformation Operators

I/O and Transformation Operators handle parsing, rendering, and reading/writing data from external sources. These operators take arguments on the right-hand side to specify format or location.

### 3.1 Parse Operator

| Operator | Unicode | Description |
|----------|---------|-------------|
| ↱ or ⮣ | | Parse input (JSON, XML, CSV, etc.) |

The parse operator takes a format argument (e.g., `JSON`, `XML`, `CSV`). Possible values are controlled by the existance of a `Qwiratry::IO::Parse::*` module.

**Parse Examples**:

```raku
# Parse JSON
my $json_root = ⮳ <data.json> ↱ <JSON>;

# Parse XML
my $xml_root = ⮳ <config.xml> ↱ <XML>;
```

### 3.2 Render Operator

| Operator | Unicode | Description |
|----------|---------|-------------|
| ↴ or ⮧ | | Render output (JSON, XML, CSV, formatters) |

The render operator takes a format argument specifying the output format. It converts query results or tree structures into the specified serialization format.

It takes a format argument (e.g., `JSON`, `XML`, `CSV`). Possible values are controlled by the existance of a `Qwiratry::IO::Render::*` module.

**Format Options**: Some formats support additional options via adverbs or named arguments:

```raku
# Render with indentation
my $json = $root ↴ <JSON> :pretty;

# Render CSV with custom delimiter
my $csv = $relation ↴ <CSV> :delimiter<;>;

# Render XML with specific encoding
my $xml = $root ↴ <XML> :encoding<UTF-8>;
```

**Render Examples**:

```raku
# Render to JSON
my $json = $root ↴ <JSON>;

# Pretty-printed JSON
my $pretty_json = $root ↴ <JSON> :pretty;
```

### 3.3 Source Operator

| Operator | Unicode | Description |
|----------|---------|-------------|
| ⮳ | | Read nodes from external sources (filesystem, web, commands) |

The source operator accepts a location parameter that specifies where to read data from. The location can be a file path, URL, or command.

**Location Parameter Rules**:
- If no `:` is found, it's assumed to be a filename (relative or absolute path)
- If a `:` is found, it's assumed to be a URL or protocol-based location

**Example Protocols and URL Schemes**:

- **File System** (`file://` or no protocol):
  - `⮳ <data.json>` - Relative file path
  - `⮳ </absolute/path/data.json>` - Absolute file path

- **HTTP/HTTPS** (`http://`, `https://`):
  - `⮳ <https://example.com/data.json>` - HTTPS URL
  - `⮳ <http://localhost:8080/api/data>` - HTTP URL with port

Note that it's also possible to avoid the source operator:

- Since Raku has shell quoting (`qx`), there's no need for shell execution
- Since Raku has `$*IN`, there's no need for special STDIN-reading semantics
- The `"filename.json".IO.lines` could also be used
- Databases can be read by providing database-reading classes

**Source Examples**:

```raku
# Local file
my $local = ⮳ <data.json>;

# Absolute path
my $absolute = ⮳ </home/user/data.json>;

# HTTP URL
my $http = ⮳ <https://api.example.com/data.json>;
```

### 3.4 Destination Operator

| Operator | Unicode | Description |
|----------|---------|-------------|
| ⮷ | | Write nodes to external destinations |

The destination operator accepts a location parameter that specifies where to write data. It uses the same protocol and URL scheme rules as the source operator.

**Supported Protocols and URL Schemes**:

- **File System** (`file://` or no protocol):
  - `⮷ <output.json>` - Write to relative file path
  - `⮷ </absolute/path/output.json>` - Write to absolute file path

- **HTTP/HTTPS** (`http://`, `https://`):
  - `⮷ <https://api.example.com/upload>` - POST data to HTTPS endpoint
  - `⮷ <http://localhost:8080/api/data>` - POST data to HTTP endpoint
  - Typically uses POST or PUT methods depending on the endpoint

See the Source operator for examples of other alternatives.  

**Destination Examples**:

```raku
# Local file
my $result = $data ↴ <JSON> ⮷ <output.json>;

# Absolute path
my $result = $data ↴ <XML> ⮷ </var/www/data.xml>;

# HTTP POST
my $result = $data ↴ <JSON> ⮷ <https://api.example.com/upload>;
```

### 3.5 Usage Examples

```raku
# Parse JSON from a file
my $json_root = ⮳ <data.json> ↱ <JSON>;

# Parse and select, then render
my $result = ⮳ <data.json> ↱ <JSON> ⪪ <record> ↴ <JSON> ⮷ <output.json>;

# Parse XML from URL
my $xml_root = ⮳ <https://example.com/data.xml> ↱ <XML>;

# Render to CSV
my $csv = $relation ↴ <CSV> ⮷ <output.csv>;
```

### 3.6 I/O Operator Composition and Pipelines

I/O operators are designed to be composed into data processing pipelines. They can be chained together with navigation, selection, and transformation operators to create complex data workflows.

**Basic Pipeline Pattern**: The typical pattern is: **Source → Parse → Query → Render → Destination**

```raku
# Complete pipeline: read, parse, filter, transform, render, write
my $result = ⮳ <data.json> ↱ <JSON> 
              ⪪⪪ <item> 
              σ { ⥷ <price> > 100 } 
              ↴ <JSON> 
              ⮷ <expensive-items.json>;
```

**Multi-Format Pipeline**: Convert between formats in a single pipeline:

```raku
# XML → JSON conversion
my $json = ⮳ <data.xml> ↱ <XML> ↴ <JSON> ⮷ <data.json>;

# CSV → YAML conversion with filtering
my $yaml = ⮳ <data.csv> ↱ <CSV> 
           σ { ⥷ <status> eq 'active' } 
           ↴ <YAML> 
           ⮷ <active-items.yaml>;
```

**Multi-Source Pipeline**: Combine data from multiple sources:

```raku
# Read from multiple sources and combine
my $combined = (⮳ <data1.json> ↱ <JSON> ⪪ <items>) 
               ∪ 
               (⮳ <data2.json> ↱ <JSON> ⪪ <items>);

# Write combined result
my $result = $combined ↴ <JSON> ⮷ <combined.json>;
```

**HTTP Pipeline**: Fetch, process, and upload data:

```raku
# Fetch from API, process, upload to another endpoint
my $result = ⮳ <https://api.example.com/data.json> ↱ <JSON>
              ⪪ <records>
              σ { ⥷ <date> > Date.today - 7 }
              ↴ <JSON>
              ⮷ <https://api.example.com/recent.json>;
```

**Streaming Pipeline**: Process data incrementally (Walker-dependent):

```raku
# Large file processing with streaming
my $stream = ⮳ <large-data.json> ↱ <JSON>
             ⪪⪪ <record>
             σ { ⥷ <category> eq 'important' }
             ↴ <JSON>
             ⮷ <important-records.json>;
# Walker may stream results without loading entire file into memory
```

**Conditional Pipeline**: Use selection to route data:

```raku
# Route data to different destinations based on criteria
my $data = ⮳ <data.json> ↱ <JSON> ⪪ <items>;

# Write active items to one file
($data σ { ⥷ <status> eq 'active' }) ↴ <JSON> ⮷ <active.json>;

# Write inactive items to another file
($data σ { ⥷ <status> eq 'inactive' }) ↴ <JSON> ⮷ <inactive.json>;
```

**Format-Specific Pipeline Examples**:

```raku
# XML processing pipeline
my $xml_result = ⮳ <catalog.xml> ↱ <XML>
                 ⪪⪪ <product>
                 σ { ⥷ <price> < 50 && ⥷ <in_stock> }
                 ↴ <XML>
                 ⮷ <cheap-products.xml>;

# CSV processing pipeline
my $csv_result = ⮳ <sales.csv> ↱ <CSV>
                 σ { ⥷ <amount> > 1000 }
                 ⇅ { ⥷ <date> }
                 ↴ <CSV>
                 ⮷ <large-sales.csv>;

# YAML configuration processing
my $config = ⮳ <config.yaml> ↱ <YAML>
            ⪪ <settings>
            ↴ <JSON>
            ⮷ <settings.json>;
```

## 4. Map-Reduce and Aggregation Operators

These operators perform selection, transformation, sorting, and reduction operations on relations.

| Operator | Unicode | Set Theory Term | Traditional Term | Description |
|----------|---------|-----------------|-------------------|-------------|
| σ, 𜸈 | U+03C3, U+1CE08 | Selection | `grep` | Choose some tuples; equivalent to WHERE clause in SQL |
| ⇅ | U+21C5 | | `sort` | Sorts tuples |
| ». | | | `map` | Hyper operator (core Raku) equivalent to Map call |
| ⌿ | U+233F | | `reduce` | Reduces a set of tuples by repeatedly applying a function/operation |

### 4.1 Usage Examples

```raku
# Selection (filter)
my $filtered = $relation ==> σ { $_.age > 18 };

# Sort
my $sorted = $relation ==> ⇅ { $_.name };

# Map (hyper operator)
my $mapped = $relation ». { $_.name.uc };

# Reduce
my $sum = $relation ==> ⌿ { $^a + $^b.age };
```

## 5. Navigation Operators

Navigation Operators provide axis-based navigation for tree-like structures (XML, JSON, ASTs, Match trees, etc.), but other structures, such as tables. These operators are inspired by XPath axes but stay idiomatically Raku.  All navigation operators require a right operand (which can be a Whatever `*`), except for the root operator (`⇤`) which is a **unary postfix operator**.  If a left operand is provided, they use that as input, otherwise, they use $_ as input.  They may take additional operands as adverbs.  

Navigation operators can be chained: `$node ⪪ * ⪪ *` means "children of children"

### 5.1 Navigation Operators Reference

Each operator returns the set of nodes along the corresponding axis. All axis operators are both **callable** and **iterable**, allowing them to be used in path specifications and composed with other operators.  Navigation operators can be used with trees, but also tables and relational data structures. The semantics depend on the left operand type. 

| Axis              | Unicode | Alias          | Tree | Table | Table Row |
|-------------------|---------|----------------|------|-------|-----------|
| Child             | ⪪  | `child`             | Direct children of the current node | Returns rows | Returns FK rows or nothing (if column has no FK) |
| Parent            | ⪫  | `parent`            | Direct parent of the current node | Returns containing namespace (schema/database/etc.) | Returns the table containing the row |
| Descendant        | ⪪⪪ | `descendant`        | All descendants of the current node | Returns all rows (same as ⪪) | Walker-dependent: may descend into FKs (optionally filtered by labels), or throw exception |
| Ancestor          | ⪫⪫ | `ancestor`          | All ancestors of the current node | Returns namespace hierarchy (schema/database/etc.) | Returns the table (same as ⪫) |
| Following-Sibling | ⪨  | `following-sibling` | Siblings after the current node | Returns nothing/error | Returns next row in table (if ordered) |
| Preceding-Sibling | ⪩  | `preceding-sibling` | Siblings before the current node | Returns nothing/error | Returns previous row in table (if ordered) |
| Following         | ⪨⪨ | `following`         | All nodes following in document order | Returns nothing/error | Returns all rows after this row (if ordered) |
| Preceding         | ⪩⪩ | `preceding`         | All nodes preceding in document order | Returns nothing/error | Returns all rows before this row (if ordered) |
| Root              | ⇤  | `data-root`         | The root node of the tree (unary postfix operator) | Returns root of namespace hierarchy (unary postfix) | Returns root of namespace hierarchy (walks up from table via namespace, unary postfix) |
| Attribute         | ⥷  | `attribute`         | Key/value or associative children | Returns nothing/error | Returns column values |

### 5.1.1 Usage Examples

```raku
# Select all child nodes (wildcard selects all)
my @children = $root ⪪ *;

# Select all descendants (wildcard selects all)
my @all-descendants = $root ⪪⪪ *;

# Compose operators: children's children
my @grandchildren = $root ⪪ * ⪪ *;

# Select with predicate
my @items = $root ⪪ <item>;

# Select descendants matching a pattern
my @divs = $root ⪪⪪ <div> σ { ⥷ <class> };

# Navigate up the tree or namespace
my $parent = $node ⪫ *;

# Get root (unary postfix operator)
my $root = $node ⇤;

# Combine with set operations
my @nodes = $root ⪪ * ∪ $root ⥷ <attr>;
```

### 5.2 Operators

#### 5.2.1 Child Operator (⪪)

**Table → Rows**: When the left operand is a table, the child operator (`⪪`) requires a right operand to select rows. The right operand may be a wildcard to choose all rows, or a selector to choose some.  

```raku
my $table = [[1, 2, 3], [4, 5, 6], [7, 8, 9]];
my @rows = $table ⪪ *;  # Returns the 3 rows (wildcard selects all)
```

**Row → Foreign Key Navigation**: When the left operand is a row and the right operand is a column name that has a foreign key constraint, the child operator (`⪪`) follows the foreign key and returns an array of related rows from the foreign table:

```raku
my $order = get-order(123);
my @customers = $order ⪪ <customer_id>;  # Follows FK, returns customer row(s)
```

**Return value**: Always returns an array/sequence of rows, regardless of cardinality:
- **One-to-one**: Array containing a single row
- **One-to-many**: Array containing multiple rows
- This provides a consistent API regardless of relationship cardinality

**Non-Foreign Key Columns**: When using the child operator (`⪪`) on a column that does not have a foreign key constraint, the default behavior is to return nothing (empty result). Use the attribute operator (`⥷`) to access column values:

```raku
my $row = get-row();
my @nothing = $row ⪪ <non_fk_column>;  # Returns empty (no FK to follow)
my $value = $row ⥷ <non_fk_column>;   # Gets the column value
```

**Note**: This is default behavior; specific walkers may override this semantics.

**Edge Cases and Error Handling**:
- **Null foreign keys**: If a foreign key column contains `NULL`, the child operator returns an empty result (no rows to follow)
- **Invalid foreign key values**: If a foreign key value does not exist in the referenced table, behavior is Walker-dependent (may return empty, throw exception, or handle gracefully)
- **Circular foreign key references**: Walkers must handle circular references appropriately to avoid infinite loops
- **Multiple foreign keys to same table**: If a row has multiple foreign keys pointing to the same table, each FK column must be navigated separately

#### 5.2.3 Attribute Operator (⥷)

The attribute operator (`⥷`) is used to get column values from rows, rather than following foreign keys:

```raku
my $order = get-order(123);
my $customer_id = $order ⥷ <customer_id>;  # Gets the FK value
my @customer = $order ⪪ <customer_id>;     # Follows FK, gets related row(s)
```

When using the child operator (`⪪`) on a column that does not have a foreign key constraint, the default behavior is to return nothing (empty result). Use the attribute operator (`⥷`) to access column values:

```raku
my $row = get-row();
my $value = $row ⥷ <non_fk_column>;   # Gets the column value
```

#### 5.2.4 Descendant Operator (⪪⪪)

**Table → Rows**: When used on a table, the descendant operator (`⪪⪪`) requires a right operand and returns all rows (same as the child operator `⪪`):

```raku
my $table = [[1, 2, 3], [4, 5, 6]];
my @all-rows = $table ⪪⪪ *;  # Returns all rows (wildcard selects all)
```

**Row → Foreign Key Navigation**: The behavior of the descendant operator (`⪪⪪`) on rows is **implementation-dependent** and determined by the Walker. The default behavior is to throw an exception, as recursive foreign key following can lead to circular references and infinite loops.

Walkers may choose to:
- Throw an exception (default)
- Treat it the same as the child operator (`⪪`) - following the FK once
- Implement recursive foreign key following (with appropriate cycle detection)
- Descend into only specific foreign keys based on labels provided as arguments
- Provide an adverb to enable recursive behavior when explicitly requested

When labels are provided, the Walker can selectively descend into only those foreign keys:

```raku
my $row = get-row();
my @direct = $row ⪪ <fk_column>;        # Follows FK once
# my @descendants = $row ⪪⪪ <fk_column>; # Default: throws exception

# If Walker supports label filtering:
my @filtered = $row ⪪⪪ <fk_column1, fk_column2>;  # Only descend into specified FKs
```

If a Walker supports recursive foreign key following, it may provide an adverb:

```raku
# Walker-specific behavior (if supported)
my @recursive = $row ⪪⪪ :recursive <fk_column>;  # Recursively follows FKs
```

#### 5.2.5 Parent Operator (⪫)

The parent operator (`⪫`) can take a `:reference` adverb to navigate back through foreign key relationships.

**Table → Namespace**: When used on a table, the parent operator (`⪫`) requires a right operand and returns the containing namespace (e.g., schema in PostgreSQL, database in MySQL, or equivalent in other systems):

```raku
my $table = get-table('users');
my $schema = $table ⪫ *;  # Returns the schema containing the table
```

**Row → Table**: When used on a row, the parent operator (`⪫`) requires a right operand and returns the table containing the row:

```raku
my $row = get-row();
my $table = $row ⪫ *;  # Returns the table containing the row
```

**Row → Referencing Rows (with `:reference` adverb)**: When used on a row with the `:reference` adverb, the parent operator navigates back to the row(s) that reference this row via foreign keys:

```raku
my $customer = get-customer(123);
my @orders = $customer ⪫ * :reference;  # Returns all orders that reference this customer via FK
```

This is the inverse of the child operator (`⪪`) when used for foreign key navigation.

**Return Value Semantics**: The `:reference` adverb always returns an array/sequence of rows, regardless of how many tables or rows reference the current row:
- **Single reference**: Array containing a single row
- **Multiple references from one table**: Array containing multiple rows from the same table
- **Multiple references from multiple tables**: Array containing rows from all referencing tables

**Multiple Tables**: When multiple tables have foreign keys pointing to the same row, the `:reference` adverb returns rows from all referencing tables. The order of rows in the result is implementation-dependent and may vary by Walker:

```raku
my $product = get-product(456);
# Product might be referenced by: orders, inventory, reviews, etc.
my @all-references = $product ⪫ * :reference;
# Returns: [order_row1, order_row2, inventory_row, review_row1, review_row2, ...]

# Filter by specific table
my @only-orders = @all-references σ { $_.table-name eq 'orders' };
```

#### 5.2.6 Ancestor Operator (⪫⪫)

The ancestor operator (`⪫⪫`) can take a `:reference` adverb to navigate back through foreign key relationships.

**Table → Namespace Hierarchy**: When used on a table, the ancestor operator (`⪫⪫`) requires a right operand and returns the full namespace hierarchy (e.g., database → schema → table):

```raku
my $table = get-table('users');
my @hierarchy = $table ⪫⪫ *;  # Returns [database, schema, table] or equivalent
```

**Row → Table**: When used on a row, the ancestor operator (`⪫⪫`) requires a right operand and returns the table (same as the parent operator `⪫`):

```raku
my $row = get-row();
my $table = $row ⪫⪫ *;  # Returns the table containing the row
```

**Row → Referencing Rows (with `:reference` adverb)**: When used on a row with the `:reference` adverb, the ancestor operator navigates back through foreign key relationships to find all rows that reference this row:

```raku
my $customer = get-customer(123);
my @all-referencing = $customer ⪫⪫ * :reference;  # Returns all rows that reference this customer via FKs
```

**Parent vs. Ancestor with `:reference`**: The exact behavior of `⪫⪫` with `:reference` is Walker-dependent and may:
- Return the same as `⪫ :reference` (direct references only)
- Recursively follow foreign key chains to find all referencing rows
- Throw an exception if recursive behavior is not supported

**Return Value Semantics**: Like the parent operator, the ancestor operator with `:reference` always returns an array/sequence of rows, including rows from all referencing tables.

#### 5.2.7 Root Operator (⇤)

The root operator (`⇤`) is a **unary postfix operator** (unlike other navigation operators which are binary). It returns the root of the namespace hierarchy by walking up from the current node.

**Table → Root of Namespace Hierarchy**: When used on a table, the root operator returns the root of the namespace hierarchy:

```raku
my $table = get-table('users');
my $root = $table ⇤;  # Returns root of namespace hierarchy
```

**Row → Root of Namespace Hierarchy**: When used on a row, the root operator walks up through the table and namespace hierarchy to return the root:

```raku
my $row = get-row();
my $root = $row ⇤;  # Returns root of namespace hierarchy (walks up from table via namespace)
```

#### 5.2.8 Following-Sibling Operator (⪨)

The following-sibling operator (`⪨`) returns the next sibling(s) after the current node in document order.

**Table → Error**: When used on a table, the following-sibling operator (`⪨`) requires a right operand but typically returns nothing or throws an error, as tables do not have a sibling relationship in the namespace hierarchy:

```raku
my $table = get-table('users');
# my @siblings = $table ⪨ *;  # Typically returns nothing or error
```

**Row → Next Row (if ordered)**: When used on a row, the following-sibling operator (`⪨`) requires a right operand and returns the next row(s) in the table, **if the table has a defined ordering**. If the table is unordered or the row is the last row, it returns nothing:

```raku
my $row = get-row();
my @next-rows = $row ⪨ *;  # Returns next row(s) if table is ordered, empty otherwise

# With specific count
my $next-row = $row ⪨ 1;  # Returns the next single row
```

**Ordering Requirements**: The behavior of `⪨` on rows is **Walker-dependent** and requires the table to have a defined ordering (e.g., primary key order, explicit sort order, or insertion order). If no ordering is defined, the operator may:
- Return nothing (empty result)
- Throw an exception
- Use a default ordering (e.g., primary key)

**Edge Cases**:
- **Last row**: Returns nothing
- **Unordered table**: Behavior is Walker-dependent (may return nothing or error)
- **Multiple rows**: The right operand can specify how many following siblings to return

#### 5.2.9 Preceding-Sibling Operator (⪩)

The preceding-sibling operator (`⪩`) returns the previous sibling(s) before the current node in document order.

**Table → Error**: When used on a table, the preceding-sibling operator (`⪩`) requires a right operand but typically returns nothing or throws an error, as tables do not have a sibling relationship in the namespace hierarchy:

```raku
my $table = get-table('users');
# my @siblings = $table ⪩ *;  # Typically returns nothing or error
```

**Row → Previous Row (if ordered)**: When used on a row, the preceding-sibling operator (`⪩`) requires a right operand and returns the previous row(s) in the table, **if the table has a defined ordering**. If the table is unordered or the row is the first row, it returns nothing:

```raku
my $row = get-row();
my @prev-rows = $row ⪩ *;  # Returns previous row(s) if table is ordered, empty otherwise

# With specific count
my $prev-row = $row ⪩ 1;  # Returns the previous single row
```

**Ordering Requirements**: Like the following-sibling operator, the behavior of `⪩` on rows is **Walker-dependent** and requires the table to have a defined ordering. If no ordering is defined, the operator may:
- Return nothing (empty result)
- Throw an exception
- Use a default ordering (e.g., primary key)

**Edge Cases**:
- **First row**: Returns nothing
- **Unordered table**: Behavior is Walker-dependent (may return nothing or error)
- **Multiple rows**: The right operand can specify how many preceding siblings to return

#### 5.2.10 Following Operator (⪨⪨)

The following operator (`⪨⪨`) returns all nodes that follow the current node in document order (not just siblings).

**Table → Error**: When used on a table, the following operator (`⪨⪨`) requires a right operand but typically returns nothing or throws an error:

```raku
my $table = get-table('users');
# my @following = $table ⪨⪨ *;  # Typically returns nothing or error
```

**Row → All Following Rows (if ordered)**: When used on a row, the following operator (`⪨⪨`) requires a right operand and returns all rows that come after the current row in the table, **if the table has a defined ordering**. If the table is unordered, it returns nothing:

```raku
my $row = get-row();
my @all-following = $row ⪨⪨ *;  # Returns all rows after this row if table is ordered

# Combine with filtering
my @recent-following = $row ⪨⪨ * σ { ⥷ <created_at> > Date.today - 7 };
```

**Ordering Requirements**: The behavior of `⪨⪨` on rows is **Walker-dependent** and requires the table to have a defined ordering. The result includes all rows that appear after the current row according to the table's ordering.

**Edge Cases**:
- **Last row**: Returns nothing
- **Unordered table**: Behavior is Walker-dependent (may return nothing or error)
- **Empty result**: If the row is the last row or the table is unordered

#### 5.2.11 Preceding Operator (⪩⪩)

The preceding operator (`⪩⪩`) returns all nodes that precede the current node in document order (not just siblings).

**Table → Error**: When used on a table, the preceding operator (`⪩⪩`) requires a right operand but typically returns nothing or throws an error:

```raku
my $table = get-table('users');
# my @preceding = $table ⪩⪩ *;  # Typically returns nothing or error
```

**Row → All Preceding Rows (if ordered)**: When used on a row, the preceding operator (`⪩⪩`) requires a right operand and returns all rows that come before the current row in the table, **if the table has a defined ordering**. If the table is unordered, it returns nothing:

```raku
my $row = get-row();
my @all-preceding = $row ⪩⪩ *;  # Returns all rows before this row if table is ordered

# Combine with filtering
my @old-preceding = $row ⪩⪩ * σ { ⥷ <created_at> < Date.today - 30 };
```

**Ordering Requirements**: The behavior of `⪩⪩` on rows is **Walker-dependent** and requires the table to have a defined ordering. The result includes all rows that appear before the current row according to the table's ordering.

**Edge Cases**:
- **First row**: Returns nothing
- **Unordered table**: Behavior is Walker-dependent (may return nothing or error)
- **Empty result**: If the row is the first row or the table is unordered

#### 5.2.12 Table Usage Examples

```raku
# Get all rows from a table
my @all-rows = $table ⪪ *;

# Follow a foreign key from a row
my $order = get-order(123);
my @customer = $order ⪪ <customer_id>;  # Get customer row(s)

# Get a column value
my $order-date = $order ⥷ <order_date>;

# Navigate through multiple relationships
my @order-items = $order ⪪ <order_id>;  # Assuming order_items table has FK to orders
my @products = @order-items[0] ⪪ <product_id>;  # Get products for first item

# Combine with filtering
my @recent-orders = $table ⪪ * σ { ⥷ <order_date> > Date.today - 30 };

# Navigate backwards with :reference adverb
my $customer = get-customer(123);
my @customer-orders = $customer ⪫ * :reference;  # All orders referencing this customer
my @recent-customer-orders = $customer ⪫ * :reference σ { ⥷ <order_date> > Date.today - 30 };

# Find all rows referencing a product
my $product = get-product(456);
my @all-references = $product ⪫ * :reference;  # Orders, inventory, reviews, etc.

# Navigate backwards through multiple relationships
my $category = get-category(789);
my @products = $category ⪪ *;  # Products in this category
my @all-referencing = $category ⪫⪫ * :reference;  # All rows referencing this category

# Sibling navigation (requires ordered table)
my $current-row = get-row();
my $next-row = $current-row ⪨ 1;  # Next row
my $prev-row = $current-row ⪩ 1;  # Previous row

# Following/preceding navigation (requires ordered table)
my @all-after = $current-row ⪨⪨ *;  # All rows after current
my @all-before = $current-row ⪩⪩ *;  # All rows before current

# Combine sibling navigation with filtering
my @recent-next = $current-row ⪨ * σ { ⥷ <status> eq 'active' };
```

### 5.3 Implementation Notes

- Axis operators are **implementation-dependent** - different Walkers may implement them differently:
  - They may compose iterators to retrieve nodes along the specified axis
  - They may be translated into other query languages (e.g., SQL for database walkers)
  - They may use domain-specific traversal strategies
- Operators are both **callable** and **iterable**, usable with Transformers for smartmatching
- Operators do not perform traversal themselves; they rely on **Walkers** to interpret and execute them
- Predicates and combinators (like union `∪`, intersection `∩`, difference `∖`) can be applied after or during operator execution

## 6. Set Operators

Set Operators work on collections of elements.  This includes anything that can do Associative, whether table-based, tree nodes (eg. results from navigation operators), or just regular arrays of items. These operators are based on relational algebra and set theory, and include both relational/tuple operations and column-based operations.

### 6.1 Relational/Tuple Operators

Relational/Tuple Operators work on collections of elements that can do Associative. This includes table-based structures, tree nodes (e.g., results from navigation operators), or regular arrays of items. 

#### 6.1.1 Operators Returning `Bool`

These operators compare collections or test membership, returning boolean results.

##### 6.1.1.1 Membership Operators

| Operator | Unicode | Inverse | Inverse Not | Operands | Description |
|----------|---------|---------|-------------|----------|-------------|
| element of/contains | ∈ ∊ (elem) | ∋ ∍ (cont) | ∉ ∌ | A Collection and an Element | Tests if an element is a member of a collection |

##### 6.1.1.2 Subset/Superset Operators

| Operator | Unicode | Inverse | Inverse Not | Operands | Description |
|----------|---------|---------|-------------|----------|-------------|
| strict subset/superset | ⊂ (<) | ⊃ (>) | ⊄ ⊅ | Collections | Tests if one collection is a strict subset/superset of another |
| subset/superset or equal | ⊆ (<=) | ⊇ (>=) | ⊈ ⊉ | Collections | Tests if one collection is a subset/superset or equal to another |

##### 6.1.1.3 Identity Operator

| Operator | Unicode | Inverse | Operands | Description |
|----------|---------|---------|----------|-------------|
| identity | ≡ (==) | ≢ | Collections | Tests if two collections are identical |

#### 6.1.2 Operators Returning Collections

These operators combine collections to produce new collections.

##### 6.1.2.1 Basic Set Operations

| Operator | Unicode | Set Theory Term | Boolean Algebra Term | Description |
|----------|---------|-----------------|---------------------|-------------|
| ∩ | U+2229 | Intersection | AND | Returns elements present in both collections |
| ∪ | U+222A | Union | OR | Returns elements present in either collection |
| ⊖ | U+2296 | Symmetric Set Difference | XOR | Returns elements in exactly one collection |
| ∖ | U+0020 U+2216 | Set Difference | | Returns elements in left collection but not in right |

**Note**: Operators without dots ensure each row is unique; operators with dots accept duplicates.

##### 6.1.2.2 Universe-based Operators

These operators require a Universe set that encompasses both collections. The context variable `$_` must be a collection that's a superset of both operands.

| Operator | Unicode | Set Theory Term | Boolean Algebra Term | Description |
|----------|---------|-----------------|---------------------|-------------|
| ⩃ | U+2A43 | Intersection Complement | NAND | Returns elements not in the intersection |
| ⩂ | U+2A42 | Union Complement | NOR | Returns elements not in the union |
| (none) | | Symmetric Set Difference Complement | XNOR | Returns elements not in the symmetric difference |
| (none) | | Set Difference Complement | | Returns elements not in the set difference |
| (none) | | Complement | NOT | Returns elements not in the collection (unary) |

#### 6.1.3 Operators Returning `Array[Collection]`

| Operator | Unicode | Set Theory Term | Description |
|----------|---------|----------------|-------------|
| ℘ | U+2118 | Power Set | Unary. Makes a set whose members are all possible subsets of the collection |

#### 6.1.4 Collection Types and Semantics

Set operators work with any collection that can do Associative. The semantics depend on the collection type:

| Operator | General Semantics | Notes |
|----------|------------------|-------|
| ∈ ∊ | Tests if an element is in a collection | Element identity depends on collection type |
| ⊂ ⊆ | Tests if one collection is a subset of another | Both collections must be of compatible types |
| ∩ | Returns elements present in both collections | Element matching depends on collection type |
| ∪ | Returns elements present in either collection | Duplicate handling depends on collection type |
| ⊖ | Returns elements in exactly one collection | Element matching depends on collection type |
| ∖ | Returns elements in left collection but not in right | Element matching depends on collection type |
| ℘ | Returns all possible subsets of the collection | Works with any collection type |

**Collection Type Considerations**:
- **Tables/Relations**: Element identity is typically determined by value equality of all columns/fields
- **Tree nodes**: Element identity is typically determined by object identity or a Walker-defined equality
- **Arrays**: Element identity is typically determined by value equality
- **Composability**: Navigation operator results (tree nodes) can be combined with set operators to create complex queries
- **Type compatibility**: Set operations generally require compatible collection types, though Walkers may provide type coercion

#### 6.1.5 Usage Examples

**Table/Relation Examples**:

```raku
# Test membership
if $tuple ∈ $relation { ... }

# Test subset
if $relation1 ⊆ $relation2 { ... }

# Intersection
my $common = $relation1 ∩ $relation2;

# Union
my $combined = $relation1 ∪ $relation2;

# Set difference
my $only-in-first = $relation1 ∖ $relation2;

# Power set
my @subsets = ℘ $relation;
```

**Tree Node Examples**:

```raku
# Union of tree navigation results
my @combined = ($root ⪪ <item>) ∪ ($root ⪪ <product>);

# Intersection of tree queries
my @common = ($root ⪪⪪ <div>) ∩ ($root ⪪⪪ <span>);

# Set difference: nodes in first query but not second
my @unique = ($root ⪪ <item>) ∖ ($root ⪪ <item> σ { ⥷ <archived> });

# Test membership: is this node in the set?
if $node ∈ ($root ⪪⪪ <item>) { ... }

# Test subset: are all active items also in the items set?
if ($root ⪪ <item> σ { ⥷ <active> }) ⊆ ($root ⪪ <item>) { ... }

# Combine navigation with set operations
my @mixed = ($root ⪪ <item>) ∪ ($root ⥷ <metadata>);

# Power set of tree nodes
my @subsets = ℘ ($root ⪪ <item>);
```

**Array Examples**:

```raku
# Union of arrays
my @combined = @array1 ∪ @array2;

# Intersection
my @common = @array1 ∩ @array2;

# Set difference
my @only-in-first = @array1 ∖ @array2;

# Test membership
if $item ∈ @array { ... }

# Test subset
if @subset ⊆ @array { ... }
```

### 6.2 Column-based Operators

Column-based Operators manipulate the structure of relations by selecting, renaming, or combining columns. 

#### 6.2.1 Basic Operators

| Operator | Unicode | Relational Algebra Term | Description |
|----------|---------|-------------------------|-------------|
| Π | U+03A0 | Projection | Choose fields; equivalent to field selection in SQL. May combine with subtraction to select "all fields except..." |
| ρ | U+03C1 | Rename | Rename fields; equivalent to AS statement in SQL |

#### 6.2.2 Sub-Join Operators

These operators return rows from one relation based on matches with another, but don't include rows from the other relation.

| Operator | Unicode | Relational Algebra Term | Description |
|----------|---------|-------------------------|-------------|
| ⋉ | U+22C9 | Left Semijoin | Includes rows from left table that match right table (but no rows from right) |
| ⋊ | U+22CA | Right Semijoin | Includes rows from right table that match left table (but no rows from left) |
| ▷ | U+25B7 | Left Antijoin | Includes rows from left relation which do NOT have a match in the right relation |
| ◁ | U+25C1 | Right Antijoin | Includes rows from right relation which do NOT have a match in the left relation |

#### 6.2.3 Basic Join Operators

These operators combine rows from two relations based on matching conditions.

| Operator | Unicode | Relational Algebra Term | Description |
|----------|---------|-------------------------|-------------|
| ⨝ | U+2A1D | Inner Join | Only include rows that appear in both relations. Mathematically, this is Natural Join |
| ⟕ | U+27D5 | Left Outer Join | Include all rows in left relation, and any that match in right relation |
| ⟖ | U+27D6 | Right Outer Join | Include all rows in right relation, and any that match in left relation |
| ⟗ | U+27D7 | Full Outer Join | Include all rows in both relations, matching up where possible |

#### 6.2.4 Other Join Operators

| Operator | Unicode | Relational Algebra Term | Description |
|----------|---------|-------------------------|-------------|
| ▷=◁ | | Equijoin | Like inner join, but only `=` comparison allowed |
| ≜ | U+225C | Natural Join | Like equijoin, but column names must be the same in both tables |
| ÷ | U+00F7 | Division | Creates a relation listing every item in A that matches all elements in B |
| ▵ | U+25B5 | Named Join | Unary prefix operator that takes a Join operand (for recalling a join) |
| X | | Cross Join | Joins every record in left operand to every record in right operand |

#### 6.2.5 Usage Examples

```raku
# Projection - select specific columns
my $projected = Π <name, age> $relation;

# Rename columns
my $renamed = ρ <old_name => new_name> $relation;

# Inner join
my $joined = $relation1 ⨝ $relation2;

# Left outer join
my $left_joined = $relation1 ⟕ $relation2;

# Natural join
my $natural = $relation1 ≜ $relation2;

# Cross join
my $cartesian = $relation1 X $relation2;
```

## 7. Operator Composition and Usage

### 7.1 Composition Patterns

Operators in Qwiratry are designed to be highly composable. They can be combined in several ways:

#### 7.1.1 Chaining

Operators can be chained to form path expressions:

```raku
# Navigate through tree structure
my @results = $root ⪪⪪ <div> ⪪ <span>;

# Combine tree navigation with filtering
my @filtered = $root ⪪⪪ * σ { $_.name eq 'item' };
```

#### 7.1.2 Set Operations

Multiple query results can be combined using set operators:

```raku
# Union of two queries
my @combined = ($root ⪪ <item>) ∪ ($root ⥷ <metadata>);

# Intersection
my @common = $query1 ∩ $query2;

# Difference
my @unique = $query1 ∖ $query2;
```

#### 7.1.3 Predicates

Operators can be combined with predicates (blocks) for filtering:

```raku
# Tree navigation with predicate
my @items = $root ⪪ <item> σ { $_.value > 10 };

# Relational selection
my $filtered = σ { $_.age > 18 && $_.active } $relation;
```

### 7.2 Integration with Walkers

Operators are interpreted by Walkers during the `plan()` phase:

1. **Query AST Construction**: Operators form Query AST nodes
2. **Walker Planning**: Walker analyzes the AST and creates an execution plan
3. **QueryIterator Execution**: Plan produces a QueryIterator that yields results

Different Walkers may interpret the same operator differently:
- `Tree::Walker::DFS` interprets `⪪` as tree child navigation
- `Table::Walker::Scan` may interpret `⪪` as relation navigation
- `Logic::Walker::Backward` may interpret operators as goal patterns

#### 7.2.1 Default Tree Walker Traversal Behavior

The default tree walker (when no specific walker is specified) treats data structures as follows:
- Objects that `do Positional` as having children
- Objects that `do Associative` as having attributes
- Objects with `.parent` method for up-navigation (error if not available)

This produces a flexible, "duck-typed DOM" suitable for Raku's heterogeneous data structures. However, **different walkers may implement different data models**. For example:
- A JSON walker may treat JSON objects differently than the default
- A database walker may map operators to SQL queries
- A custom walker may define its own traversal semantics

The traversal behavior described here applies only to the default tree walker implementation.

### 7.3 Integration with Transformers

Operators can be used in Transformer templates:

```raku
transformer MyTransformer {
    # Use operators in when clause - uses $_ automatically
    template item() when { ⪪⪪ <item> } do {
        make transform-item($_);
    }
    
    # Combine with predicates - uses $_ automatically
    template active-item() when { 
        ⪪ <item> σ { .active }
    } do {
        make process-active($_);
    }
}
```

### 7.4 Domain-Specific Semantics

The same operator may have different semantics depending on the data model:

- **Tree Model**: `⪪` navigates to child nodes
- **Table Model**: `⪪` may navigate relations
- **Graph Model**: `⪪` may follow edges

Walkers are responsible for interpreting operators according to their domain.

### 7.5 Optimization Opportunities

Since operators are Query AST nodes, Walkers can:

- **Introspect** operator structure for optimization
- **Push down** predicates to data sources
- **Reorder** operations for efficiency
- **Cache** intermediate results
- **Parallelize** independent operations

Example optimization:

```raku
# Original query
my $query = $root ⪪⪪ * σ { $_.name eq 'item' } σ { $_.value > 10 };

# Optimized: combine predicates
my $optimized = $root ⪪⪪ * σ { $_.name eq 'item' && $_.value > 10 };
```

## 8. Summary

Qwiratry operators provide a comprehensive set of tools for querying and transforming data:

1. **I/O Operations** - Parsing, rendering, and external data access
2. **Aggregation** - Selection, sorting, mapping, and reduction
3. **Data Navigation** - Axis-based traversal for hierarchical structures
4. **Set Operations** - Set theory and relational algebra for tables/relations, including column manipulation, projection, renaming, and joins

All operators are:
- **Declarative** - Specify intent, not implementation
- **Composable** - Can be combined to form complex queries
- **Domain-Flexible** - Interpreted by Walkers according to data model
- **Lazy** - Results produced incrementally via QueryIterator
- **Introspectable** - Can be analyzed and optimized by Walkers

This design enables a unified query interface that works across trees, tables, graphs, and other structured data models while maintaining the flexibility for domain-specific optimizations and interpretations.
