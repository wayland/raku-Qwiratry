#| RewriteSpec stub role for rewrite specifications
#|
#| This module provides the RewriteSpec role as a type marker for
#| rewrite return values from on-match and after hooks.
#|
#| This is intentionally a stub role - it will be expanded in a future
#| feature when rewrite functionality is fully implemented. Currently
#| it serves as a type marker to distinguish rewrite return values
#| from ControlSignal return values in Strategy hooks.
unit module Qwiratry::RewriteSpec;

#| Stub role for rewrite specifications.
#| To be expanded in future feature when rewrite functionality is implemented.
#| Currently serves as a type marker for return values from on-match and after hooks.
role RewriteSpec is export {
    # Marker role - no methods required
    # Concrete implementations will define rewrite specifications in future features
}
