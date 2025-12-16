# Feature Shells for spec-kitty.specify

This directory contains feature shells extracted from `Specification.md` that can be processed by `spec-kitty.specify` to generate detailed feature specifications and ticket breakdowns.

## Files

- `feature-shells.md` - Master mapping document listing all shells with spec references
- `*-shell.md` - Individual feature shell descriptions ready for spec-kitty processing

## Usage

Each shell file contains:
- **Title**: Feature name
- **Scope**: 2-3 line description of what the feature covers
- **Key Deliverables**: High-level list of what needs to be implemented

### Quick Start

1. **Generate formatted inputs** (optional but recommended):
   ```bash
   ./docs/tickets/process-shells.sh > docs/tickets/spec-kitty-inputs.md
   ```

2. **Process each feature with spec-kitty**:
   - Open `spec-kitty-inputs.md` and copy each feature description section
   - In Cursor, invoke `/spec-kitty.specify` and paste the description
   - Follow the discovery interview (spec-kitty will ask clarifying questions)
   - spec-kitty will generate the detailed feature spec and ticket breakdown

### Manual Processing

Alternatively, you can manually extract from individual shell files:
- Copy the **Title** and **Scope** sections from any `*-shell.md` file
- Use as input to `/spec-kitty.specify`
- The **Key Deliverables** section provides additional context for the discovery interview

## Processing Order

Process shells in this order (dependencies respected):

1. structure-spec-shell.md
2. walker-core-shell.md
3. strategy-control-shell.md
4. composite-handover-shell.md
5. slang-and-query-shell.md
6. transformer-templates-shell.md
7. examples-and-demos-shell.md

## Spec References

Each shell references specific sections in `Specification.md`. See `feature-shells.md` for the complete mapping.

