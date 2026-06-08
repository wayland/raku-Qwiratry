# Feature Specification: Qwiratry Operators Specification
*Path: [templates/spec-template.md](templates/spec-template.md)*

**Feature Branch**: `006-qwiratry-operators-specification`  
**Created**: 2025-01-27  
**Status**: Draft  
**Input**: User description: "Create a feature specification for implementing the Qwiratry query operators as described in Operators.md. This includes I/O operators (parse, render, source, destination), map-reduce operators (selection, sort, map, reduce), navigation operators (child, parent, descendant, ancestor, etc.), and set operators (union, intersection, difference, joins, etc.). All operators must be implemented as Query AST objects that are interpreted by Walkers during planning and executed via QueryIterators."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Basic Query Construction with Navigation Operators (Priority: P1)

A developer wants to query hierarchical data structures (JSON, XML, ASTs) using declarative navigation operators. They can compose operators to traverse tree structures and select nodes based on relationships.

**Why this priority**: Navigation operators are fundamental to querying tree-like data structures, which is a core use case for Qwiratry. Without these, users cannot traverse and select data from hierarchical sources.

**Independent Test**: Can be fully tested by creating a simple tree structure, applying child and descendant operators, and verifying correct node selection. This delivers the ability to query hierarchical data declaratively.

**Acceptance Scenarios**:

1. **Given** a JSON document with nested objects, **When** a developer uses the child operator (`⪪`) to select child nodes, **Then** the system returns only direct children of the current node
2. **Given** a tree structure, **When** a developer uses the descendant operator (`⪪⪪`) with a wildcard, **Then** the system returns all descendant nodes at any depth
3. **Given** a node in a tree, **When** a developer uses the parent operator (`⪫`), **Then** the system returns the direct parent node
4. **Given** a node in a tree, **When** a developer uses the root operator (`⇤`) as a unary postfix, **Then** the system returns the root node of the tree
5. **Given** a row in a table with foreign key relationships, **When** a developer uses the child operator on a foreign key column, **Then** the system follows the foreign key and returns related rows

---

### User Story 2 - Data Filtering and Transformation with Map-Reduce Operators (Priority: P1)

A developer wants to filter, sort, and transform query results using selection, sorting, mapping, and reduction operators. They can combine these with navigation to create complex queries.

**Why this priority**: Filtering and transformation are essential for practical data queries. Users need to select subsets of data, sort results, transform values, and aggregate information.

**Independent Test**: Can be fully tested by creating a collection of data items, applying selection filters, sorting operations, and verifying correct results. This delivers the ability to refine and process query results.

**Acceptance Scenarios**:

1. **Given** a collection of data items, **When** a developer uses the selection operator (`σ`) with a predicate, **Then** the system returns only items matching the predicate
2. **Given** a collection of data items, **When** a developer uses the sort operator (`⇅`) with a key function, **Then** the system returns items sorted by the specified key
3. **Given** a collection of data items, **When** a developer uses the map operator (`».`) to transform values, **Then** the system returns transformed items
4. **Given** a collection of numeric values, **When** a developer uses the reduce operator (`⌿`) with an operation, **Then** the system returns a single aggregated value

---

### User Story 3 - Set Operations on Query Results (Priority: P2)

A developer wants to combine multiple query results using set theory operations (union, intersection, difference) and relational algebra operations (joins, projections). They can merge results from different queries or combine related data.

**Why this priority**: Set operations enable combining data from multiple sources and performing relational queries. This is essential for complex data integration scenarios.

**Independent Test**: Can be fully tested by creating two collections, applying union, intersection, or difference operators, and verifying correct results. This delivers the ability to combine and relate data from multiple queries.

**Acceptance Scenarios**:

1. **Given** two collections of query results, **When** a developer uses the union operator (`∪`), **Then** the system returns all unique elements from both collections
2. **Given** two collections of query results, **When** a developer uses the intersection operator (`∩`), **Then** the system returns only elements present in both collections
3. **Given** two collections of query results, **When** a developer uses the set difference operator (`∖`), **Then** the system returns elements in the first collection but not in the second
4. **Given** two relations with matching columns, **When** a developer uses the inner join operator (`⨝`), **Then** the system returns combined rows where columns match
5. **Given** a relation, **When** a developer uses the projection operator (`Π`) to select specific columns, **Then** the system returns only the specified columns

---

### User Story 4 - I/O Operations for External Data Sources (Priority: P2)

A developer wants to read data from external sources (files, URLs, databases) and write query results to destinations. They can parse various formats (JSON, XML, CSV) and render results in different formats.

**Why this priority**: I/O operations enable Qwiratry to work with real-world data sources and formats. Without these, the system cannot read or write data, limiting practical utility.

**Independent Test**: Can be fully tested by reading a JSON file, parsing it, applying a simple query, and writing results to another file. This delivers the ability to process external data sources.

**Acceptance Scenarios**:

1. **Given** a JSON file on the filesystem, **When** a developer uses the source operator (`⮳`) followed by the parse operator (`↱`) with JSON format, **Then** the system reads and parses the file into a queryable structure
2. **Given** a query result, **When** a developer uses the render operator (`↴`) with JSON format, **Then** the system converts the result to JSON format
3. **Given** a query result and a file path, **When** a developer uses the destination operator (`⮷`), **Then** the system writes the result to the specified location
4. **Given** an HTTP URL, **When** a developer uses the source operator with the URL, **Then** the system fetches data from the URL
5. **Given** a query result, **When** a developer uses render with format options (e.g., `:pretty` for JSON), **Then** the system applies the formatting options

---

### User Story 5 - Operator Composition and Complex Queries (Priority: P3)

A developer wants to compose multiple operators into complex query pipelines. They can chain navigation, filtering, transformation, and set operations to create sophisticated data processing workflows.

**Why this priority**: Real-world queries often require combining multiple operations. Composition enables powerful data processing pipelines that solve complex problems.

**Independent Test**: Can be fully tested by creating a pipeline that reads data, navigates structure, filters results, transforms values, and writes output. This delivers the ability to create end-to-end data processing workflows.

**Acceptance Scenarios**:

1. **Given** a data source, **When** a developer chains navigation, selection, and rendering operators, **Then** the system executes the pipeline and produces the expected output
2. **Given** multiple query expressions, **When** a developer combines them with set operators, **Then** the system correctly evaluates the composed query
3. **Given** a complex query with multiple operators, **When** a Walker processes the query AST, **Then** the system can introspect and optimize the query structure
4. **Given** a query AST, **When** a QueryIterator executes it, **Then** the system produces results incrementally without loading all data into memory

---

### Edge Cases

- What happens when navigation operators are applied to incompatible data types (e.g., child operator on a scalar value)?
- How does the system handle circular foreign key references when using descendant operators on table rows?
- What happens when set operations are applied to collections with incompatible element types?
- How does the system handle missing or invalid format modules for parse/render operators?
- What happens when source operators reference non-existent files or inaccessible URLs?
- How does the system handle null foreign key values when navigating relationships?
- What happens when operators are applied to empty collections or null values?
- How does the system handle operator precedence when composing complex expressions?
- What happens when Walkers encounter operators they don't support for their domain?
- How does the system handle large datasets that exceed available memory during query execution?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST implement all navigation operators (child `⪪`, parent `⪫`, descendant `⪪⪪`, ancestor `⪫⪫`, following-sibling `⪨`, preceding-sibling `⪩`, following `⪨⪨`, preceding `⪩⪩`, root `⇤`, attribute `⥷`) as Query AST nodes
- **FR-002**: System MUST implement all map-reduce operators (selection `σ`, sort `⇅`, map `».`, reduce `⌿`) as Query AST nodes
- **FR-003**: System MUST implement all set operators (union `∪`, intersection `∩`, symmetric difference `⊖`, set difference `∖`, membership `∈`, subset `⊂`, identity `≡`) as Query AST nodes
- **FR-004**: System MUST implement all relational algebra operators (projection `Π`, rename `ρ`, inner join `⨝`, left outer join `⟕`, right outer join `⟖`, full outer join `⟗`, semijoins `⋉` `⋊`, antijoins `▷` `◁`, division `÷`, cross join `×` U+00D7) as Query AST nodes
- **FR-005**: System MUST implement all I/O operators (source `⮳`, parse `↱`, render `↴`, destination `⮷`) as Query AST nodes
- **FR-006**: System MUST support operator composition, allowing operators to be chained and combined
- **FR-007**: System MUST respect operator precedence as defined in the specification
- **FR-008**: All operators MUST be immutable Query AST nodes that can be safely shared
- **FR-009**: System MUST allow Walkers to introspect operator structure for optimization
- **FR-010**: System MUST support domain-specific operator semantics (e.g., tree navigation vs. table navigation)
- **FR-011**: Navigation operators MUST support wildcard selection (`*`) to select all nodes along an axis
- **FR-012**: Navigation operators MUST support label-based selection (e.g., `⪪ <item>`)
- **FR-013**: Child operator (`⪪`) on table rows MUST follow foreign key relationships when the right operand is a foreign key column
- **FR-014**: Child operator (`⪪`) on table rows MUST return empty result when applied to non-foreign-key columns
- **FR-015**: Attribute operator (`⥷`) MUST retrieve column values from table rows
- **FR-016**: Parent operator (`⪫`) with `:reference` adverb MUST navigate backwards through foreign key relationships
- **FR-017**: Root operator (`⇤`) MUST be implemented as a unary postfix operator
- **FR-018**: Parse operator (`↱`) MUST support format detection based on available `Qwiratry::IO::Parse::*` modules
- **FR-019**: Render operator (`↴`) MUST support format options via adverbs or named arguments
- **FR-020**: Source operator (`⮳`) MUST support file paths, absolute paths, and URL schemes (http://, https://, file://)
- **FR-021**: Destination operator (`⮷`) MUST support writing to file paths and HTTP endpoints
- **FR-022**: Selection operator (`σ`) MUST accept predicate blocks for filtering
- **FR-023**: Sort operator (`⇅`) MUST accept key functions for ordering
- **FR-024**: Set operators MUST work with any collection type that can do Associative
- **FR-025**: Join operators MUST support matching conditions between relations
- **FR-026**: System MUST produce QueryIterators that yield results incrementally during traversal
- **FR-027**: Operators MUST be usable in Transformer templates for node matching in `when` clauses
- **FR-028**: System MUST handle operator errors gracefully (e.g., invalid formats, missing data, circular references)

### Key Entities *(include if feature involves data)*

- **Query AST Node**: Represents a declarative query operator. Immutable, composable, introspectable. All operators are instances of this entity.
- **Operator**: A specific query operation (navigation, set, I/O, etc.) implemented as a Query AST node. Has precedence, associativity, and domain-specific semantics.
- **Walker**: Interprets Query AST operators during planning phase, determines execution strategy, and produces QueryIterators. Different Walkers may interpret the same operator differently based on domain.
- **QueryIterator**: Produces query results incrementally during traversal. Created by Walkers from Query AST plans.
- **Collection**: Any data structure that can do Associative. Includes tables, tree nodes, arrays. Set operators work with collections.
- **Tree Node**: A node in a hierarchical structure (XML, JSON, AST). Navigation operators traverse tree nodes.
- **Table/Relation**: A tabular data structure with rows and columns. Navigation and set operators work with tables.
- **Row**: A single record in a table. Navigation operators can follow foreign key relationships from rows.
- **Format Module**: A module implementing `Qwiratry::IO::Parse::*` or `Qwiratry::IO::Render::*` for specific data formats (JSON, XML, CSV, etc.).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developers can construct queries using all specified operators (navigation, map-reduce, set, I/O) with correct syntax and semantics
- **SC-002**: Query AST nodes can be composed into complex query pipelines without errors
- **SC-003**: Walkers can successfully interpret operator ASTs and produce execution plans for their domains
- **SC-004**: QueryIterators produce correct results incrementally without loading entire datasets into memory
- **SC-005**: Operators work correctly with tree structures (JSON, XML, ASTs) for navigation and selection
- **SC-006**: Operators work correctly with table structures for relational queries and foreign key navigation
- **SC-007**: I/O operators successfully read from and write to files, URLs, and other external sources
- **SC-008**: Parse and render operators support at least JSON, XML, and CSV formats
- **SC-009**: Set operations produce correct results when combining collections from different query sources
- **SC-010**: Operator precedence is correctly enforced in complex expressions
- **SC-011**: All operators can be used in Transformer templates for node matching
- **SC-012**: System handles edge cases gracefully (null values, empty collections, invalid inputs, circular references)

## Assumptions

- Operators will be implemented as RakuAST::Node descendants, following Raku's AST structure
- Walkers will be responsible for domain-specific operator interpretation and optimization
- QueryIterators will be lazy and produce results incrementally
- Format modules (Qwiratry::IO::Parse::*, Qwiratry::IO::Render::*) will be implemented separately and discovered dynamically
- Foreign key relationships in tables will be discoverable by Walkers through metadata
- Operator precedence follows Raku's standard precedence hierarchy with additional levels for Qwiratry-specific operators
- Default tree walker will treat Positional objects as having children and Associative objects as having attributes
- Operators are declarative and do not perform execution themselves; execution is delegated to Walkers and QueryIterators

