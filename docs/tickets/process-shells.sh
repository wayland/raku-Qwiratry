#!/usr/bin/env bash
# Helper script to extract feature descriptions from shell files for spec-kitty.specify

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TICKETS_DIR="$SCRIPT_DIR"

if [ ! -d "$TICKETS_DIR" ]; then
    echo "Error: tickets directory not found at $TICKETS_DIR" >&2
    exit 1
fi

extract_scope() {
    local shell_file="$1"
    if [ ! -f "$shell_file" ]; then
        echo "Error: shell file not found: $shell_file" >&2
        return 1
    fi
    
    # Extract title (text after "**Title**:")
    local title=$(grep "^\*\*Title\*\*:" "$shell_file" | sed 's/^\*\*Title\*\*:[[:space:]]*//' | sed 's/[[:space:]]*$//')
    
    # Extract scope (text after "**Scope**:")
    local scope=$(grep "^\*\*Scope\*\*:" "$shell_file" | sed 's/^\*\*Scope\*\*:[[:space:]]*//' | sed 's/[[:space:]]*$//')
    
    # Extract key deliverables (lines starting with "-" after "**Key Deliverables**:")
    local in_deliverables=false
    local deliverables=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^\*\*Key\ Deliverables\*\*: ]]; then
            in_deliverables=true
            continue
        fi
        if [ "$in_deliverables" = true ]; then
            if [[ "$line" =~ ^- ]]; then
                deliverables="${deliverables}${line#- }"$'\n'
            elif [[ "$line" =~ ^[[:space:]]*$ ]] && [ -n "$deliverables" ]; then
                break
            fi
        fi
    done < "$shell_file"
    
    echo "=== $title ==="
    echo ""
    echo "$scope"
    echo ""
    if [ -n "$deliverables" ]; then
        echo "Key deliverables:"
        echo "$deliverables" | while IFS= read -r line; do
            if [ -n "$line" ]; then
                echo "  - $line"
            fi
        done
    fi
    echo ""
}

# Process each shell in priority order
SHELLS=(
    "structure-spec-shell.md"
    "walker-core-shell.md"
    "strategy-control-shell.md"
    "composite-handover-shell.md"
    "slang-and-query-shell.md"
    "transformer-templates-shell.md"
    "examples-and-demos-shell.md"
)

echo "# Feature Descriptions for spec-kitty.specify"
echo ""
echo "Copy each section below and use it as input to \`/spec-kitty.specify\`"
echo "Process them in order (dependencies respected)."
echo ""
echo "---"
echo ""

for shell in "${SHELLS[@]}"; do
    shell_path="$TICKETS_DIR/$shell"
    if [ -f "$shell_path" ]; then
        extract_scope "$shell_path"
        echo "---"
        echo ""
    else
        echo "Warning: Shell file not found: $shell" >&2
    fi
done

