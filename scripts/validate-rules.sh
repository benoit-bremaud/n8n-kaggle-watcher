#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Validating rules/actions.json ==="

# Check JSON syntax
if python3 -c "import json; json.load(open('$PROJECT_ROOT/rules/actions.json'))"; then
  echo "✓ actions.json is valid JSON"
else
  echo "✗ actions.json has invalid JSON syntax"
  exit 1
fi

# Check workflow JSON syntax
if python3 -c "import json; json.load(open('$PROJECT_ROOT/workflows/kaggle-email-watcher.json'))"; then
  echo "✓ kaggle-email-watcher.json is valid JSON"
else
  echo "✗ kaggle-email-watcher.json has invalid JSON syntax"
  exit 1
fi

# Validate against schema (if ajv-cli is available)
if command -v ajv &> /dev/null; then
  if ajv validate -s "$PROJECT_ROOT/rules/actions.schema.json" -d "$PROJECT_ROOT/rules/actions.json"; then
    echo "✓ actions.json passes schema validation"
  else
    echo "✗ actions.json fails schema validation"
    exit 1
  fi
else
  echo "⚠ ajv-cli not installed, skipping schema validation (npm install -g ajv-cli)"
fi

echo ""
echo "=== All validations passed ==="
