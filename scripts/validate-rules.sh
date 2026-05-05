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

# Validate state/watchlist.json against its schema, if present.
# The file is gitignored (real runtime data appended by the n8n
# workflows on every Yes/No decision); validation is skipped silently
# when it does not exist so a fresh clone still passes.
if [ -f "$PROJECT_ROOT/state/watchlist.json" ]; then
  if python3 -c "import json; json.load(open('$PROJECT_ROOT/state/watchlist.json'))"; then
    echo "✓ state/watchlist.json is valid JSON"
  else
    echo "✗ state/watchlist.json has invalid JSON syntax"
    exit 1
  fi

  if python3 -c "
import json, sys
try:
    from jsonschema import Draft7Validator, FormatChecker
    from datetime import datetime
    from urllib.parse import urlparse

    # Register stdlib-based checkers so 'format: date-time' and
    # 'format: uri' are actually enforced. The default FormatChecker
    # skips these unless rfc3339-validator / rfc3987 are installed,
    # which we do not want to require in CI. The checks below cover
    # the constraints declared in rules/watchlist.schema.json without
    # adding any external dependency.
    fmt = FormatChecker()

    @fmt.checks('date-time', ValueError)
    def _check_date_time(instance):
        if not isinstance(instance, str):
            return True
        # datetime.fromisoformat handles 'Z' suffix from Python 3.11;
        # normalize for older versions just in case.
        datetime.fromisoformat(instance.replace('Z', '+00:00'))
        return True

    @fmt.checks('uri', ValueError)
    def _check_uri(instance):
        if not isinstance(instance, str):
            return True
        parsed = urlparse(instance)
        if not parsed.scheme or not parsed.netloc:
            raise ValueError('missing scheme or netloc')
        return True

    schema = json.load(open('$PROJECT_ROOT/rules/watchlist.schema.json'))
    data = json.load(open('$PROJECT_ROOT/state/watchlist.json'))
    validator = Draft7Validator(schema, format_checker=fmt)
    errors = sorted(validator.iter_errors(data), key=lambda e: list(e.path))
    if errors:
        for e in errors:
            path = '/'.join(str(p) for p in e.path) or '<root>'
            print(f'  ✗ {path}: {e.message}', file=sys.stderr)
        sys.exit(1)
    print('✓ state/watchlist.json passes schema validation')
except ImportError:
    print('⚠ jsonschema not installed, skipping schema validation (pip install jsonschema)')
"; then
    true
  else
    echo "✗ state/watchlist.json fails schema validation"
    exit 1
  fi
fi

# Validate state/pending-callbacks.json against its schema, if present.
# Same pattern as the watchlist block above: gitignored runtime data
# (one entry per outbound Telegram notification, indexed by shortid),
# validation skipped silently when the file does not exist so a fresh
# clone still passes.
if [ -f "$PROJECT_ROOT/state/pending-callbacks.json" ]; then
  if python3 -c "import json; json.load(open('$PROJECT_ROOT/state/pending-callbacks.json'))"; then
    echo "✓ state/pending-callbacks.json is valid JSON"
  else
    echo "✗ state/pending-callbacks.json has invalid JSON syntax"
    exit 1
  fi

  if python3 -c "
import json, sys
try:
    from jsonschema import Draft7Validator, FormatChecker
    from datetime import datetime
    from urllib.parse import urlparse

    fmt = FormatChecker()

    @fmt.checks('date-time', ValueError)
    def _check_date_time(instance):
        if not isinstance(instance, str):
            return True
        datetime.fromisoformat(instance.replace('Z', '+00:00'))
        return True

    @fmt.checks('uri', ValueError)
    def _check_uri(instance):
        if not isinstance(instance, str):
            return True
        parsed = urlparse(instance)
        if not parsed.scheme or not parsed.netloc:
            raise ValueError('missing scheme or netloc')
        return True

    schema = json.load(open('$PROJECT_ROOT/rules/pending-callbacks.schema.json'))
    data = json.load(open('$PROJECT_ROOT/state/pending-callbacks.json'))
    validator = Draft7Validator(schema, format_checker=fmt)
    errors = sorted(validator.iter_errors(data), key=lambda e: list(e.path))
    if errors:
        for e in errors:
            path = '/'.join(str(p) for p in e.path) or '<root>'
            print(f'  ✗ {path}: {e.message}', file=sys.stderr)
        sys.exit(1)
    print('✓ state/pending-callbacks.json passes schema validation')
except ImportError:
    print('⚠ jsonschema not installed, skipping schema validation (pip install jsonschema)')
"; then
    true
  else
    echo "✗ state/pending-callbacks.json fails schema validation"
    exit 1
  fi

  # Additional integrity check beyond the schema: shortid must be unique
  # across the file. The Telegram Callback Handler resolves callbacks via
  # `list.find((e) => e.shortid === suffix)` so a duplicate would silently
  # route a click to whichever entry comes first in the file. Enforce here
  # so manual edits or a future writer regression cannot introduce one.
  if python3 -c "
import json, sys
data = json.load(open('$PROJECT_ROOT/state/pending-callbacks.json'))
seen = {}
for i, e in enumerate(data):
    sid = e.get('shortid')
    if sid in seen:
        print(f'  ✗ duplicate shortid {sid!r} at indices {seen[sid]} and {i}', file=sys.stderr)
        sys.exit(1)
    seen[sid] = i
print('✓ state/pending-callbacks.json shortids are unique')
"; then
    true
  else
    echo "✗ state/pending-callbacks.json has duplicate shortids"
    exit 1
  fi
fi

echo ""
echo "=== All validations passed ==="
