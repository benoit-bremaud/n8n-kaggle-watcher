# Project Log — n8n-kaggle-watcher

Chronological record of all project activity: PRs, decisions, incidents, backlog changes.
This is the operational logbook, not a release changelog.

---

## 2026-03-31

### Project bootstrap

- **PR #1** (merged) — `feat(init): scaffold n8n-kaggle-watcher repo with Docker, rules engine, and workflow`
  - Initial project structure: Docker Compose for self-hosted n8n, rules engine (`actions.json` + JSON Schema), Gmail trigger workflow, Makefile, CI validation pipeline
  - Architecture decision: rules-driven notification system — actions.json defines per-track rules, n8n workflow reads and matches them at runtime

### Hackathon support

- **PR #2–#4** (merged) — Add hackathon event type, refine email parsing, add Final Submission deadline pattern
  - Kaggle emails use different formats for competitions (`Entry Deadline:`) vs hackathons (`Final Submission:`)
  - Parse Email Code node updated to handle both formats
  - Decision: detect event_type from subject line pattern (`Competition Launch:` vs `Hackathon Launch:`)

### CI fixes

- **PR #5–#6** (merged) — Replace ajv-cli with Python jsonschema for schema validation
  - ajv-cli had compatibility issues with Draft 7; switched to Python `jsonschema` package
  - CI pipeline stabilized

### Track inference

- **Commit d2c7a43** — Infer track from email content via keyword matching
  - Kaggle emails have no explicit track field; added keyword-based classification (AI/ML, Data Science, Healthcare, Environment)
  - Decision: match keywords against subject + body, default to "Other"

### Telegram integration fix

- **PR #7** (merged) — `feat(n8n): fix Telegram integration and live workflow setup`
  - Fixed two blocking bugs: chat_id resolution and template syntax error
  - Template delimiters changed from `{{var}}` to `{var}` to avoid n8n expression parser conflict
  - Chat ID hardcoded as Fixed value in Send Telegram node — all dynamic approaches failed on n8n Community Edition (`$env` blocked, `$vars` Enterprise-only, `process.env` sandboxed, Expression mode returns `chat not found`)
  - Workflow exported from live n8n instance with real credentials
  - Rules version bumped to 1.3.0
  - Codex Review comments addressed: P1 (hardcoded chat_id) deferred with justification, P2 (`=={{ }}` prefix) acknowledged for next export cycle

- **Issue #8** (backlog) — `fix(n8n): replace hardcoded Telegram chat_id with dynamic resolution`
  - Tracking issue to remove the hardcoded chat_id workaround when a viable dynamic approach is found

## 2026-04-01

### PR #7 merged + post-merge cleanup

- **PR #7** merged into `main` — Telegram integration fully operational
- **Issue #6** closed — deploy and configure live workflow (Gmail + Telegram) is substantially complete; remaining items are operational (activate toggle + wait for real Kaggle email)
- Post-merge cleanup: branch `feat/live-workflow-setup` deleted, remote refs pruned

### Project governance

- **PROJECT_LOG.md** created — chronological operational logbook (agent-agnostic, DIP-compliant)
- Principle added to global CLAUDE.md: every project must maintain a `PROJECT_LOG.md`
- Decision: this is NOT a release changelog — it is the day-to-day operational journal

### Heartbeat workflow

- **Issue #9** created — daily heartbeat Telegram notification
- Heartbeat workflow built in n8n UI: Schedule Trigger (07:55 daily) → Send Telegram ("n8n is alive")
- Workflow published and active in n8n
- Exported to `workflows/heartbeat.json`
- PR review comment procedure updated in global CLAUDE.md: added "Disagree" priority, duplicate grouping, re-fetch cycle, and "do NOT resolve conversations" rule; this repository's CLAUDE.md summary updated to match

### PR #10 + #11 merged

- **PR #10** merged — heartbeat workflow added (`workflows/heartbeat.json`)
- **PR #11** merged — fix PR #10 Copilot review comments (active flag, CLAUDE.md wording)
- **Issue #9** closed

### README update

- **PR #12** merged — badges (CI, License, n8n, Docker), updated Mermaid diagram with Heartbeat subgraph, template variables fixed to `{var}` format, intro updated to mention hackathon support
- **Issue #5** closed
- Copilot review: 3 comments addressed (table spacing, chat_id placeholder, intro consistency)

### Social preview

- **PR #13** merged — social preview HTML template (`docs/social-preview.html`), dark theme 1280x640, uploaded to GitHub Settings
- **PR #14** merged — fix PR #13 Copilot review comments (HTML entity escape, emoji fonts, capture procedure documentation)
- **Issue #4** closed
