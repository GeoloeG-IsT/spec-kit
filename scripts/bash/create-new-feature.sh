#!/usr/bin/env bash

# ==============================================================================
# Create New Feature Script
# ==============================================================================
#
# DESCRIPTION:
#   Initializes a new feature in the Spec-Driven Development workflow by:
#   1. Creating a new feature branch with proper naming convention
#   2. Setting up the feature directory structure in specs/
#   3. Copying the specification template to start feature definition
#   4. Auto-incrementing feature numbers for consistent organization
#
# USAGE:
#   ./create-new-feature.sh [OPTIONS] <feature_description>
#
# OPTIONS:
#   --json    Output results in JSON format for programmatic consumption
#   --help    Show usage information and exit
#   -h        Show usage information and exit
#
# ARGUMENTS:
#   feature_description    A descriptive name for the feature (multiple words allowed)
#                         Will be normalized to lowercase with hyphens
#
# FEATURE NUMBERING:
#   Features are automatically numbered starting from 001, incrementing based on
#   existing feature directories. The script finds the highest existing number
#   and adds 1 to ensure sequential, non-conflicting feature numbers.
#
# BRANCH NAMING:
#   Created branches follow the pattern: XXX-first-few-words
#   - XXX: 3-digit zero-padded feature number
#   - Only first 3 words of description are used for brevity
#   - All text converted to lowercase with hyphens as separators
#   - Special characters are removed or converted to hyphens
#
# DIRECTORY STRUCTURE CREATED:
#   specs/XXX-feature-name/
#   └── spec.md           # Feature specification (copied from template)
#
# OUTPUT:
#   In default mode: Displays branch name, spec file path, and feature number
#   In JSON mode: Returns structured JSON with BRANCH_NAME, SPEC_FILE, FEATURE_NUM
#
# EXIT CODES:
#   0 - Feature created successfully
#   1 - Missing feature description or other error
#
# EXAMPLES:
#   ./create-new-feature.sh "User Authentication System"
#   ./create-new-feature.sh --json "Payment Processing Integration"
#   ./create-new-feature.sh "Advanced Search and Filtering Capabilities"
#
# RELATED SCRIPTS:
#   - setup-plan.sh: Next step to create implementation plan
#   - check-task-prerequisites.sh: Validates the created structure
#
# ==============================================================================

set -e

JSON_MODE=false
FEATURE_NUM_OVERRIDE=""
ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) JSON_MODE=true; shift ;;
        --feature-num)
            if [[ -z "$2" || "$2" =~ ^- ]]; then
                echo "Error: --feature-num requires a number (1-999)" >&2
                exit 1
            fi
            if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                echo "Error: --feature-num must be a positive integer" >&2
                exit 1
            fi
            if [[ "$2" -lt 1 || "$2" -gt 999 ]]; then
                echo "Error: --feature-num must be between 1 and 999" >&2
                exit 1
            fi
            FEATURE_NUM_OVERRIDE="$2"
            shift 2 ;;
        --help|-h) echo "Usage: $0 [--json] [--feature-num NUMBER(1-999)] <feature_description>"; exit 0 ;;
        *) ARGS+=("$1"); shift ;;
    esac
done

FEATURE_DESCRIPTION="${ARGS[*]}"
if [ -z "$FEATURE_DESCRIPTION" ]; then
    echo "Usage: $0 [--json] [--feature-num NUMBER(1-999)] <feature_description>" >&2
    exit 1
fi

# Resolve repository root. Prefer git information when available, but fall back
# to the script location so the workflow still functions in repositories that
# were initialised with --no-git.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FALLBACK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
if git rev-parse --show-toplevel >/dev/null 2>&1; then
    REPO_ROOT=$(git rev-parse --show-toplevel)
    HAS_GIT=true
else
    REPO_ROOT="$FALLBACK_ROOT"
    HAS_GIT=false
fi

cd "$REPO_ROOT"

SPECS_DIR="$REPO_ROOT/specs"
mkdir -p "$SPECS_DIR"

# Use override if provided, otherwise auto-increment
if [ -n "$FEATURE_NUM_OVERRIDE" ]; then
    FEATURE_NUM=$(printf "%03d" "$FEATURE_NUM_OVERRIDE")
else
    HIGHEST=0
    if [ -d "$SPECS_DIR" ]; then
        for dir in "$SPECS_DIR"/*; do
            [ -d "$dir" ] || continue
            dirname=$(basename "$dir")
            number=$(echo "$dirname" | grep -o '^[0-9]\+' || echo "0")
            number=$((10#$number))
            if [ "$number" -gt "$HIGHEST" ]; then HIGHEST=$number; fi
        done
    fi

    NEXT=$((HIGHEST + 1))
    FEATURE_NUM=$(printf "%03d" "$NEXT")
fi

BRANCH_NAME=$(echo "$FEATURE_DESCRIPTION" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-//' | sed 's/-$//')
WORDS=$(echo "$BRANCH_NAME" | tr '-' '\n' | grep -v '^$' | head -3 | tr '\n' '-' | sed 's/-$//')
BRANCH_NAME="${FEATURE_NUM}-${WORDS}"

if [ "$HAS_GIT" = true ]; then
    git checkout -b "$BRANCH_NAME"
else
    >&2 echo "[specify] Warning: Git repository not detected; skipped branch creation for $BRANCH_NAME"
fi

FEATURE_DIR="$SPECS_DIR/$BRANCH_NAME"
mkdir -p "$FEATURE_DIR"

TEMPLATE="$REPO_ROOT/templates/spec-template.md"
SPEC_FILE="$FEATURE_DIR/spec.md"
if [ -f "$TEMPLATE" ]; then cp "$TEMPLATE" "$SPEC_FILE"; else touch "$SPEC_FILE"; fi

if $JSON_MODE; then
    printf '{"BRANCH_NAME":"%s","SPEC_FILE":"%s","FEATURE_NUM":"%s"}\n' "$BRANCH_NAME" "$SPEC_FILE" "$FEATURE_NUM"
else
    echo "BRANCH_NAME: $BRANCH_NAME"
    echo "SPEC_FILE: $SPEC_FILE"
    echo "FEATURE_NUM: $FEATURE_NUM"
fi
