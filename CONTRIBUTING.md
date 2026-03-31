# Contributing

## Branch Naming

```
feat/<short-description>    # New feature
fix/<short-description>     # Bug fix
chore/<short-description>   # Maintenance, config
docs/<short-description>    # Documentation only
```

Always branch from `main`. Never commit directly to `main`.

## Commit Convention

[Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <short description>
```

**Types:** `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`

**Scopes:** `n8n`, `rules`, `docker`, `ci`, `docs`

**Examples:**
```
feat(n8n): add Telegram notification node
fix(rules): correct track matching logic
chore(docker): update n8n image version
docs(readme): add Gmail OAuth2 setup instructions
ci(validate): add JSON schema validation workflow
```

## Pull Request Template

```markdown
## Summary

- What was done and why

## Checklist

- [ ] JSON files are valid (`make validate`)
- [ ] n8n workflow imports successfully
- [ ] Docker compose starts without errors (`make up`)
- [ ] No secrets or credentials committed

Closes #xx
```

## PR Workflow

```bash
# 1. Create PR
gh pr create --title "feat(scope): short description" --body "$(cat <<'EOF'
## Summary

- ...

## Checklist

- [ ] JSON files are valid (`make validate`)
- [ ] n8n workflow imports successfully
- [ ] Docker compose starts without errors (`make up`)
- [ ] No secrets or credentials committed

Closes #xx
EOF
)"

# 2. Assignee + labels
gh api repos/benoit-bremaud/n8n-kaggle-watcher/issues/PR_NUMBER/assignees \
  -X POST --input - <<'EOF'
{"assignees": ["benoit-bremaud"]}
EOF

gh api repos/benoit-bremaud/n8n-kaggle-watcher/issues/PR_NUMBER/labels \
  -X POST --input - <<'EOF'
{"labels": ["type:feature", "area:n8n"]}
EOF

# 3. Copilot reviewer (best-effort)
gh api repos/benoit-bremaud/n8n-kaggle-watcher/pulls/PR_NUMBER/requested_reviewers \
  -X POST --input - <<'EOF'
{"reviewers": ["copilot-pull-request-reviewer"]}
EOF
```

## Labels

| Label | Description |
|-------|-------------|
| `type:feature` | New feature or enhancement |
| `type:fix` | Bug fix |
| `type:chore` | Maintenance, config, tooling |
| `type:docs` | Documentation only |
| `area:n8n` | n8n workflow changes |
| `area:rules` | Rules engine (actions.json) |
| `area:docker` | Docker / deployment |
| `area:ci` | CI/CD pipeline |
