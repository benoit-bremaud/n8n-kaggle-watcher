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

### CI lint checks

- **PR #15** merged — yamllint, shellcheck, markdownlint added to CI and local `make lint` / `make check`
- Copilot review: 2 comments addressed (blocking on missing tools, markdown lint consistency)

### Security audit and secret detection

- **Repo switched to private** — hardcoded secrets found in workflow exports (chat_id, credential IDs, instance ID)
- **PR #16** merged — gitleaks CI job (scoped to PR diff), workflow JSONs sanitized with placeholders
- Copilot review: 2 comments addressed (gitleaks allowlist path, chat_id dynamic — deferred to #8)
- Private-first repository policy established in global CLAUDE.md
- New issues created for public release roadmap: #17 (git history purge), #18 (documentation), #19 (secret rotation), #20 (public release gate)

### Dynamic chat_id resolution (Issue #8)

- `$env.TELEGRAM_CHAT_ID` blocked by n8n CE (even with `N8N_RESTRICT_ENVIRONMENT_VARIABLES_TO`)
- Solution: external config file `rules/telegram-config.json` (gitignored) read by a dedicated Code node
- Architecture: Match Rule → Read Config → Inject Chat ID → Route → Send Telegram
- Both workflows (Kaggle Email Watcher + Heartbeat) now use dynamic chat_id from config file
- Zero hardcoded secrets in workflow JSONs — all credential IDs, instance IDs, and metadata sanitized
- `make check` passes (JSON validation + lint + secret detection)

## 2026-04-03

### Git history purge (Issue #17)

- Used `git filter-repo` to replace 8 secret values across all 46 commits with placeholders
- Secrets purged: chat_id, credential IDs, instance ID, webhook IDs, workflow IDs
- `gitleaks detect` on full history: **no leaks found**
- Force-pushed cleaned history to GitHub (branch protection temporarily disabled then re-enabled)

### Documentation (Issue #18)

- **PR #22** merged — complete rewrite of `docs/setup-n8n.md`, security checklist in CONTRIBUTING.md, README Quick Start updated
- Copilot review: 4 comments addressed (env var scope, basic-auth wording, chat_id source of truth, checklist wording)

### Secret rotation (Issue #19)

- Telegram bot token rotated via @BotFather
- Gmail OAuth credentials regenerated via Google Cloud Console
- n8n password changed from default
- All workflows tested and functional with new credentials

### Final security audit

- `gitleaks detect` on full history: **no leaks found**
- Zero secrets in tracked files (2 false positives: documentation example + .env.example placeholder)
- All 3 CI checks green (JSON Validation, Lint, Secret Detection)

### Repository made public (Issue #20)

- All prerequisites met: #8 (dynamic chat_id), #17 (history purge), #18 (docs), #19 (secret rotation)
- Repo visibility switched from private to public
- **Issue #17** closed

### Email parsing fix (Issue #23)

- Root cause: Gmail Trigger "Simplify" option was stripping the email body (text + HTML), leaving only a snippet
- Fix: disabled Simplify, updated Filter Kaggle Sender to use `from.value[0].address` instead of `From`
- Added URL cleanup: strip all query params with `.split('?')[0]` for cleaner Telegram notifications
- Tested with real Kaggle email: "Hackathon Launch: The Gemma 4 Good Hackathon" — all fields parsed correctly (name, deadline May 18 2026, prize $200k, URL, track AI/ML)

---

## Milestone v1.0 closed — Workflow fonctionnel + publication

All v1.0 issues closed (10/10). Repo public, workflows operational, post LinkedIn scheduled.

## 2026-04-04

### Roadmap planning

- Created GitHub milestones: v1.0 (closed), v1.1, v2.0
- LinkedIn post standards established in global CLAUDE.md (data-backed: Sprout Social, Social Insider)
- Post LinkedIn drafted, programmed for Tuesday 11h
- LinkedIn debrief cycle defined (48h + 1 week)

### Backlog update — Milestone v1.1 (Fiabilisation + automatisation)

- **Issue #2** — LinkedIn post (programmed)
- **Issue #3** — X/Twitter tweet thread
- **Issue #25** — Add "Launch" subject filter to Gmail Trigger (priority: high)
- **Issue #26** — LinkedIn debrief reminder workflow via n8n + Telegram

### Backlog update — Milestone v2.0 (Telegram interactif)

- **Issue #27** — Inline keyboard buttons in Telegram notifications (blocked by infra)
- **Issue #28** — Automated Kaggle repo creation from Telegram (depends on #27)
- **Issue #29** — AI-powered competition analysis and backlog generation (depends on #28)

## 2026-04-12

### Fix — Docker network incident

- Incident: n8n editor unreachable from host (HTTP 000), Gmail Trigger failing with `'undefined'` error, outbound connectivity broken from container (100% packet loss on custom bridge network).
- Root cause: `iptables-nft` conflict with Docker — `DOCKER-ISOLATION-STAGE-2` chain missing, preventing any custom bridge network from being created. Neither Docker daemon restart nor manual chain creation resolved it.
- Fix: switched `docker-compose.yml` to `network_mode: host` — bypasses Docker bridge networking entirely, appropriate for this single-container deployment. n8n now binds directly to host port 5678.
- Tradeoffs of host mode: Linux-only behavior (Docker Desktop on macOS/Windows emulates via VM and may not expose the port identically), and the container shares the host's network namespace so there is no network isolation. Acceptable here: single-container deployment on a trusted Linux host. Bridge mode remains a drop-in alternative for other environments (see `docs/setup-n8n.md`).
- Also removed deprecated `N8N_BASIC_AUTH_*` environment variables (removed in n8n v1.0, silently ignored by v2.14.2). Auth is now managed via n8n built-in user management.
- Verified: container up, outbound connectivity OK, editor returns HTTP 200, Heartbeat workflow active and firing.
- Remaining: Gmail OAuth refresh token is expired/revoked (independent of network incident) — requires re-authentication via Google Cloud Console.

## 2026-04-13

### Fix — Gmail OAuth re-authentication

- Root cause: Google OAuth app was in "Testing" mode — refresh tokens expire after 7 days automatically.
- Fix: switched OAuth app to "In production" in Google Cloud Console (Audience → Publish). Tokens no longer expire.
- Re-authenticated Gmail credential in n8n UI (Sign in with Google → Connection successful).
- Verified end-to-end: workflow executed, Telegram notification received with correct parsed fields (name, deadline, prize, URL, track AI/ML, rule matched 🏆).
- Workflow republished as v3.0.1. Both Kaggle Email Watcher and Heartbeat active and error-free.

## 2026-04-19

### Feature — Global Error Handler workflow (Issue #39)

- Motivation: both production workflows (Kaggle Email Watcher, Heartbeat) ran silently — a failure was only visible in the n8n Executions tab. No alert path existed for DNS hiccups, Gmail OAuth expiry, Telegram rate-limits, or broken rules files.
- New workflow `Error Handler` added (`workflows/error-handler.json`): Error Trigger → Read/Write Files (reads `/data/rules/telegram-config.json`) → Code node (extracts `chat_id`, formats `⚠️ Workflow error` Markdown message with workflow name, failing node, error message, and Europe/Paris timestamp) → Telegram Send Message.
- DRY/SRP: one centralized handler shared by all workflows, linked via **Workflow Settings → Error Workflow**. Heartbeat and Kaggle Email Watcher both reference it.
- Consistency pass on Telegram nodes across all 3 workflows: `Append n8n Attribution = OFF` (removes promotional footer) and `Parse Mode = Markdown (Legacy)` (matches the `*bold*` / `_italic_` syntax used in message templates; MarkdownV2 would fail on unescaped punctuation).
- Workflows exported via `n8n export:workflow --all --published --pretty --separate`, sanitized with a dedicated `jq` filter (placeholders for `credentials.*.id`, `webhookId`, `settings.errorWorkflow`, tag metadata; `meta` emptied; top-level instance/version fields stripped).
- Sanitization convention documented in `CONTRIBUTING.md` (canonical jq filter + list of fields to placeholder). `docs/setup-n8n.md` updated with the Error Handler import + linking procedure. README Mermaid diagram now shows the Error Handler subgraph.
- Issue #40 opened to track the E2E production-schedule test (deferred from this PR: manual `Execute workflow` doesn't trigger Error Workflows in this n8n version, only real scheduled executions do).

### Fix — Transient n8n fetch failures

- Symptom: intermittent "The DNS server returned an error, perhaps the server is offline" on both Gmail Trigger and Telegram nodes while testing.
- Diagnosis: DNS and HTTPS from the container are fine (Node `dns.resolve` + `https.get` to Gmail/Telegram both succeed); n8n logs show `fetch failed` / `DOMException TimeoutError` on PostHog feature-flag fetches — internal undici socket/keep-alive state got stale.
- Fix: `docker compose restart n8n` flushes the socket pool and DNS cache. Editor back at HTTP 200, nodes retry cleanly.
- No code change required — documented here so the symptom is recognizable next time.

### Fix — Gmail Trigger filters non-Launch emails (Issue #25)

- Symptom: the Parse Email node occasionally produced empty fields because non-Launch Kaggle emails (newsletters, community digests, product announcements) were also passing through the trigger.
- Root cause: the Gmail Trigger only filtered on sender (`no-reply@kaggle.com`), not on subject. All Kaggle emails were pulled in, and the parser happily returned `Unknown`/`Not specified` for anything that wasn't a Launch announcement.
- Fix: added `q: "subject:Launch"` to the Gmail Trigger's `filters` object. Gmail's search syntax is case-insensitive and matches both `"Competition Launch"` and `"Hackathon Launch"` subjects while rejecting everything else.
- Committed in `workflows/kaggle-email-watcher.json` on branch `fix/gmail-subject-filter-launch` — will need a re-import in n8n UI after merge to take effect on the running workflow.
