#| Copy service class for shallow and deep copying of transformable nodes
#|
#| This module provides `copy()` and `deepcopy()` multi subs for copying
#| transformable nodes (nodes with Walkers that have supports-rewrite capability).
#| Default implementations are provided for Positional and Associative types,
#| with support for custom `.copy()` methods and cycle detection for deep copies.
unit module Qwiratry::Copy;

#| Copy service functions - will be implemented in WP07
#| Multi subs for copy() and deepcopy() with:
#| - Default implementations for Positional and Associative
#| - Custom method detection
#| - Cycle detection for deepcopy
#| - DAG preservation
#| (Placeholder - implementation in WP07)

