#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

ERRORS=0

echo "=== YAML lint ==="
if command -v yamllint &>/dev/null; then
  if yamllint -d relaxed "$PROJECT_ROOT/docker/docker-compose.yml"; then
    echo "✓ docker-compose.yml passes yamllint"
  else
    echo "✗ docker-compose.yml has yamllint errors"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "✗ yamllint not installed (pipx install yamllint)"
  ERRORS=$((ERRORS + 1))
fi

echo ""
echo "=== Shell lint ==="
if command -v shellcheck &>/dev/null; then
  for script in "$PROJECT_ROOT"/scripts/*.sh; do
    name=$(basename "$script")
    if shellcheck "$script"; then
      echo "✓ $name passes shellcheck"
    else
      echo "✗ $name has shellcheck errors"
      ERRORS=$((ERRORS + 1))
    fi
  done
else
  echo "✗ shellcheck not installed"
  ERRORS=$((ERRORS + 1))
fi

echo ""
echo "=== Markdown lint ==="
if command -v npx &>/dev/null; then
  cd "$PROJECT_ROOT"
  if npx --yes markdownlint-cli2 --config .markdownlint.json README.md CONTRIBUTING.md PROJECT_LOG.md 2>&1; then
    echo "✓ Markdown files pass lint"
  else
    echo "✗ Markdown files have lint errors"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "✗ npx not available — cannot run markdown lint"
  ERRORS=$((ERRORS + 1))
fi

echo ""
if [ "$ERRORS" -gt 0 ]; then
  echo "=== $ERRORS lint error(s) found ==="
  exit 1
else
  echo "=== All lint checks passed ==="
fi
