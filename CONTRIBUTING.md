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

## Security — Public Release Checklist

Before making the repository public, **all** of the following must be verified:

- [ ] `gitleaks detect --source . --verbose` passes on full git history (zero findings)
- [ ] No secrets in any tracked file: tokens, API keys, chat IDs, credential IDs, passwords
- [ ] `docker/.env.example` has placeholder values only
- [ ] `rules/telegram-config.json.example` contains only non-sensitive dummy values
- [ ] All development secrets rotated (Telegram bot token, Gmail OAuth, n8n password)
- [ ] CI includes a secret detection job (gitleaks)
- [ ] `make check` passes (JSON validation + lint)

## Workflow Export Convention

When exporting workflows from n8n UI to commit in git:

1. Export via the n8n UI (menu `⋮` → Download)
1. Before committing, verify the exported JSON does **not** contain:
   - Real chat IDs (numeric values like `899627563`)
   - Real credential IDs (alphanumeric strings in `credentials.*.id`)
   - Instance IDs, webhook IDs, or version IDs
1. Replace any leaked values with placeholders: `YOUR_CHAT_ID`, `YOUR_CREDENTIAL_ID`
1. Run `make check` to validate
