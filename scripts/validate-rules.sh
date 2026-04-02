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

# Check all workflow JSON syntax
for wf in "$PROJECT_ROOT"/workflows/*.json; do
  name=$(basename "$wf")
  if python3 -c "import json; json.load(open('$wf'))"; then
    echo "✓ $name is valid JSON"
  else
    echo "✗ $name has invalid JSON syntax"
    exit 1
  fi
done

# Validate against schema (if jsonschema is available)
if python3 -c "
import json
try:
    from jsonschema import validate
    schema = json.load(open('$PROJECT_ROOT/rules/actions.schema.json'))
    data = json.load(open('$PROJECT_ROOT/rules/actions.json'))
    validate(instance=data, schema=schema)
    print('✓ actions.json passes schema validation')
except ImportError:
    print('⚠ jsonschema not installed, skipping schema validation (pip install jsonschema)')
"; then
  true
else
  echo "✗ actions.json fails schema validation"
  exit 1
fi

echo ""
echo "=== All validations passed ==="
