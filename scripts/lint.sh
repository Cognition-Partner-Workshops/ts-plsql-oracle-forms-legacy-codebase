#!/usr/bin/env bash
# ============================================================================
# HRMS SQL Lint Script
# Runs sqlfluff linting on all SQL and PL/SQL files
#
# Usage: ./scripts/lint.sh [--fix]
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

FIX_MODE=""
for arg in "$@"; do
    case "$arg" in
        --fix) FIX_MODE="fix" ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

if ! command -v sqlfluff &> /dev/null; then
    echo "sqlfluff not found. Install with: pip install sqlfluff"
    exit 1
fi

echo "Running sqlfluff ${FIX_MODE:-lint} on SQL files..."
echo ""

if [ "$FIX_MODE" = "fix" ]; then
    sqlfluff fix "$PROJECT_DIR/schema/" "$PROJECT_DIR/plsql/" "$PROJECT_DIR/data/" \
        --force --format human 2>&1
else
    sqlfluff lint "$PROJECT_DIR/schema/" "$PROJECT_DIR/plsql/" "$PROJECT_DIR/data/" \
        --format human 2>&1
fi

exit_code=$?

echo ""
if [ $exit_code -eq 0 ]; then
    echo "Lint passed!"
else
    echo "Lint completed with findings (exit code: $exit_code)"
    echo "Note: Some PL/SQL syntax may not be fully supported by sqlfluff's Oracle dialect."
    echo "Run with --fix to auto-fix applicable issues."
fi

exit $exit_code
