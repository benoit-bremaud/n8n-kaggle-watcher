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
- Fix: added `q: '(subject:"Competition Launch" OR subject:"Hackathon Launch")'` to the Gmail Trigger's `filters` object. Quoted phrase matching ensures only those two exact subjects reach the parser; broader forms like `subject:Launch` would still let through product-launch announcements and similar noise.
- Committed in `workflows/kaggle-email-watcher.json` on branch `fix/gmail-subject-filter-launch` — will need a re-import in n8n UI after merge to take effect on the running workflow.

## 2026-04-23

### Incident — Silent n8n outage for 3 days

- Symptom reported: no Telegram notifications at all (including daily 07:55 Heartbeat) for ~3 days.
- Root cause: container `docker-n8n-1` stopped on 2026-04-20 15:45 UTC via SIGTERM (exit 0, clean shutdown — most likely a `make down` during earlier work on the DNS fix branch). Restart policy `unless-stopped` honors explicit stops and did not restart despite 5 host reboots between 2026-04-20 and 2026-04-22.
- Precursor in logs: repeated `EAI_AGAIN` on `telemetry.n8n.io` / `us.i.posthog.com` / `api.telegram.org` — the signature of issue #43 (Node's c-ares caches `systemd-resolved` stub failures for the process lifetime).
- Monitoring gap: the Error Handler depends on Telegram too, so the only alert path was silenced by the same DNS failure. No out-of-band detection exists — the outage was invisible from the outside.

### Fix — DNS resolver override (PR #44 merged, issue #43 option B)

- **PR #44** merged — `fix(docker): override container resolv.conf to bypass systemd-resolved` (merge commit `a72a90b`).
- Mounts `docker/resolv.conf` (Cloudflare `1.1.1.1` + Google `8.8.8.8`, `options timeout:2 attempts:2`) onto `/etc/resolv.conf` inside the container. Host DNS configuration untouched.
- Validation: `cat /etc/resolv.conf` inside container confirms override under `network_mode: host`; Node `dns.resolve4` resolves `api.telegram.org`, `gmail.googleapis.com`, `telemetry.n8n.io`, `us.i.posthog.com`; zero `EAI_AGAIN` / `fetch failed` in the 90 seconds after `make down && make up` (vs. errors within 2s on the previous run); end-to-end confirmed by a real Kaggle Competition Launch email triggering the full pipeline.
- Documentation: troubleshooting section added in `docs/setup-n8n.md` with symptom, root cause, and the restart-vs-recreate caveat.
- Copilot review addressed inline (commit `3736a89`): scoped the DNS note to `EAI_AGAIN` only (dropped misleading `ECONNRESET`), documented the split-DNS/VPN tradeoff in `docker/resolv.conf` with a commented `search` template, and corrected the restart guidance (a live edit is visible through the bind mount; `force-recreate` is only needed when the mount definition itself changes).

### Fix — Docker healthcheck + autoheal sidecar (PR #50 merged, issue #43 option A)

- **PR #50** merged — `chore(docker): add n8n healthcheck and autoheal sidecar` (merge commit `a4d2691`).
- Docker `healthcheck` on the n8n service probes both local readiness (`http://localhost:5678/healthz`) and outbound connectivity (`https://1.1.1.1/`). Parameters: `interval: 60s`, `timeout: 10s`, `start_period: 60s`, `retries: 3` — detection latency ≤ 3 minutes.
- New `autoheal` sidecar (`willfarrell/autoheal:1.2.0`) watches containers labeled `autoheal=true` (n8n carries the label) and issues a restart when Docker reports them unhealthy. Requires `/var/run/docker.sock` mount — accepted tradeoff on a single-user homelab host.
- `restart: unless-stopped` on n8n kept unchanged — the sidecar adds the unhealthy-state recovery layer Docker restart policies do not cover on their own.
- Outbound probe target chosen as `1.1.1.1` (not `api.telegram.org`) to decouple container health from any single downstream service's availability — a Telegram outage would otherwise trigger restart loops without restoring connectivity. Also matches the DNS resolver already configured in `docker/resolv.conf` (Cloudflare anycast).
- Copilot review: 3 Should Have comments (`make down` semantics vs `docker compose stop`, wget timeout budget, third-party coupling) all addressed inline in commit `7a37e67`.

### Fix — Pin n8n image to 2.14.2 (PR #52 merged, issue #43 option C)

- **PR #52** merged — `chore(docker): pin n8n image to 2.14.2` (merge commit `f1d9924`).
- `docker/docker-compose.yml` switched from `image: n8nio/n8n:latest` to `image: n8nio/n8n:2.14.2` — the version already running in production at the time of pinning.
- Rationale: tracking `latest` meant any `docker compose pull` (or fresh `make up` after image removal) would silently roll forward to whatever n8n ships next, re-opening the class of transient environmental surface that triggered the 2026-04-20 incident. Future upgrades now go through an explicit version-bump PR (pin change + `make down && make up` + healthcheck validation).
- Copilot review: summary only, 0 actionable comments.

### Fix — External watchdog with heartbeat marker (PR #53 merged, issue #43 option D, **issue #43 closed**)

- **PR #53** merged — `feat(docker): external watchdog with heartbeat marker` (merge commit `acb0205`). With this PR, **issue #43 is closed**: A (healthcheck + autoheal), B (DNS resolver override), C (pin n8n version) and D (external watchdog) are all shipped.
- Host-side `scripts/watchdog.sh` runs every 15 minutes via a `systemd` user timer. Three independent probes, each with a `/tmp` sentinel file for one-alert-per-failure-streak anti-spam: (1) Docker daemon is reachable (`docker info`), (2) container `docker-n8n-1` is `running`, (3) container Docker health is `healthy` (alerts on `none` because that means the healthcheck block was removed), (4) marker file `state/last-heartbeat` is younger than 26 h. The daemon probe short-circuits the rest of the tick on failure so the operator sees the actual root cause rather than a misleading "container missing" alert.
- Workflow `Heartbeat` republished as v1.2.0 in n8n UI: a Code node `Write Heartbeat Marker` writes `new Date().toISOString()` to `/data/state/last-heartbeat` after the existing Telegram Send. Gating the marker check on the workflow's actual successful execution (rather than a separate cron or n8n internal state) guarantees the alert path detects every reason the heartbeat could stop firing — workflow toggled off, credential expired, sub-task crash — without false positives during a legitimate Telegram outage.
- Two compose tweaks needed to make this work: `NODE_FUNCTION_ALLOW_BUILTIN=fs` (n8n CE blocks builtin Node modules in Code nodes by default), and `N8N_RESTRICT_FILE_ACCESS_TO=/data` (n8n 2.14.2 does not parse separators in this env var, so a single common parent path is the only working shape; the read-only protection on `/data/rules` is enforced by the Docker bind mount `:ro` rather than by n8n itself).
- Telegram alerts go directly via `curl --fail` to the Bot API — independent of n8n, so they keep working when n8n is down or the container is gone. The `--fail` flag means a failed delivery (bad token, Telegram down) does not silently mark the alert as sent; the sentinel is only created on a real 2xx, and the next tick will retry.
- New `scripts/n8n-watchdog.{service,timer}` plus `make install-watchdog` / `make uninstall-watchdog` targets manage install on the host (script copied to `~/.local/bin/n8n-watchdog`, units to `~/.config/systemd/user/`). Install does not require root; the operator runs `sudo loginctl enable-linger $USER` once if they want the timer to survive reboots without an interactive login (mandatory on a future headless host like the Pi 5 in #37).
- Reviews: 3 Copilot Should Have comments and 2 Codex P2 comments, all addressed inline. Copilot caught (a) `docker inspect ... || echo "missing"` confusing daemon-down with container-missing — fixed with the explicit daemon probe; (b) the user systemd unit declaring `After=docker.service` / `Wants=docker.service`, which user units cannot honor — directives dropped, the script-side daemon probe handles "Docker not ready" with a distinct alert; (c) `check_container_health` treating `none` as passing — tightened to alert on `none`, keep `starting` silent. Codex caught (d) the script's `STATE_DIR` fallback being computed from the script location, which would resolve to `~/.local/state` after install — replaced with a required env var and fail-fast `:?` guard; (e) the user timer not running after a reboot without an interactive login — added a `loginctl show-user $USER -p Linger` warning in `make install-watchdog` and a "Lingering" subsection in `docs/setup-n8n.md`. Both fix-ups landed before merge in commits `4353950` and `7ebd971`.

### Workflow versioning convention captured

- New section in `CONTRIBUTING.md` formalizing the `vX.Y.Z — <description>` shape the n8n Publish modal expects, with bump rules (MAJOR for contract breaks, MINOR for new node / new branch, PATCH for fixes) and change-description shape (what / why / operator-visible impact). The Heartbeat workflow's history was the trigger — `v1.0.0 — Initial publish`, `v1.1.0 — Disable n8n attribution`, now `v1.2.0 — Write heartbeat marker for external watchdog`.

### Backlog follow-ups

- Issue #43 closed — full silent-stop detection chain in place: Docker healthcheck → autoheal sidecar → external watchdog. The remaining failure mode this stack does *not* catch is "the entire host is down" — only addressable via a watchdog deported to a second machine (Tier 4), which is gated on #37 (Pi 5 migration) for the second host to exist.

### Operator install — external watchdog activated on `vev-XPS-15-9530`

- `~/.config/n8n-watchdog/env` created (chmod 600) with `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` sourced from `docker/.env`, plus `STATE_DIR=/home/vev/Documents/07_kaggle/n8n-kaggle-watcher/state` and `MARKER_CHECK_ENABLED=1`.
- `make install-watchdog` ran clean: script copied to `~/.local/bin/n8n-watchdog`, `n8n-watchdog.{service,timer}` units installed under `~/.config/systemd/user/`, timer enabled and active. First tick at install time exited 0 (all three checks pass), next firing every 15 minutes.
- `loginctl show-user vev -p Linger` returns `yes` — lingering already enabled on this host, so the timer survives reboots without an interactive login. No `sudo loginctl enable-linger` needed. (Will need to be run explicitly when the stack moves to a headless Pi 5 — see #37.)

### E2E validation — alerting paths

- **External watchdog (#43 option D):** controlled `make down` triggered the watchdog within seconds (next tick forced via `systemctl --user start n8n-watchdog.service`). Two distinct alerts received: 🚨 container missing + 🚨 health unknown (each gated by its own sentinel in `/tmp`). After `make up` and the next tick, both sentinels were cleared and recovery messages were sent: ✅ container running + ✅ health healthy. Total: 4 Telegram messages in ~2 minutes, anti-spam logic working as designed (no duplicate alerts).
- **Error Handler (#40, deferred from PR #41):** Heartbeat workflow temporarily published as v1.3.0 with two breaking changes (Schedule Minutes/1 + Read Config path `/data/rules/telegram-config-TEST.json`). Two scheduled executions failed at 16:32 and 16:33 (Europe/Paris), both produced the expected Telegram payload via the global Error Handler — `Workflow: Heartbeat`, `Node: Read Config`, `Error: No file(s) found`, ISO timestamp, no n8n attribution footer, Markdown Legacy formatting renders correctly. Heartbeat v1.4.0 published immediately after to revert both changes; restoration verified via `n8n export:workflow --published`. **Issue #40 closed.**

### Epic — Interactive Telegram decisions for Kaggle events (Issue #45)

- Created epic meta-issue #45 (`epic(n8n): interactive Telegram decisions for Kaggle events`, milestone `v2.0`) to orchestrate the Yes/No flow for Kaggle competition notifications: Yes → deterministic GitHub repo bootstrap (Phase A) + AI-assisted enrichment (Phase B); No → mark Gmail email as read, edit the Telegram message in place, log the decline in `rules/watchlist.json`.
- Audited existing children and aligned their scope: #27 narrowed to 2 buttons (Yes/No, dropped Later), #28 restricted to Phase A (deterministic scaffold, no AI), #29 locked to Claude API for Phase B, #31 actions scoped to `join`/`skip`, #32 narrowed to read-only `/status` command.
- Created 4 new child issues: #46 (skip branch — 3 coordinated side-effects), #47 (watchlist.json schema + shared writer + validation), #48 (repo scaffold template under `templates/kaggle-repo/`), #49 (GitHub token + API access infra, routed to `v1.2` as infra prerequisite).
- Architecture decision captured in the epic body: split Yes branch across 2 phases (n8n owns GitHub API with narrow PAT scope, Claude API owns reasoning/content generation). Rationale: token budget, failure recovery (repo exists even if AI times out), independent shipping per phase.
- All 5 new issues added to the Kaggle GitHub Project (`PVT_kwHOB8rwIc4BSr5_`). Milestone routing unchanged: infra (ngrok #30, token #49) in `v1.2`, interactive flow in `v2.0`, AI enrichment (#29, #34) in `v1.3`.

### Feature — Watchlist schema + writer template (PR #54 merged, issue #47 closed, foundation of epic #45)

- **PR #54** merged — `feat(rules): watchlist schema + validator + writer template` (merge commit `ca8c907`). First brick of epic #45 — both upcoming branches (#28 accept, #46 decline) and the future `/status` command (#32) now have a stable contract to read from and write to.
- `rules/watchlist.schema.json` defines the per-entry shape: required `competition_id`, `decision` (enum `accept` / `decline`), `timestamp` (ISO 8601), `source_email_id`; optional `competition_name`, `competition_url`, `repo_url` (populated by #28 once the GitHub repo is scaffolded). `additionalProperties: false` to fail loudly on shape drift. `state/watchlist.json.example` ships an empty array `[]` so a fresh install can `cp` to bootstrap; the runtime `state/watchlist.json` is gitignored (the directory itself remains tracked via `state/.gitkeep`).
- **Deviation from issue spec (`rules/watchlist.json` → `state/watchlist.json`):** the original spec placed the runtime file under `rules/`, but the rules directory is bind-mounted **read-only** since the early days (`../rules:/data/rules:ro`) to prevent any n8n Code node from accidentally overwriting `actions.json` or `telegram-config.json`. Moving the runtime data to `state/` (read-write since PR #53 for the heartbeat marker) preserves that protection, splits config from runtime cleanly, and avoids any compose change. Schema stays in `rules/` because it is part of the project's contract, not runtime data. Rationale documented in `docs/watchlist.md` so it survives.
- `scripts/validate-rules.sh` extended: when `state/watchlist.json` exists, validates JSON syntax then runs it through the schema. **Custom format checkers** (`date-time` via `datetime.fromisoformat`, `uri` via `urllib.parse.urlparse`) registered on the `FormatChecker` so the schema's `format` constraints are actually enforced — without them, `jsonschema.validate()` silently ignores `format` keywords, and bad timestamps / URLs would slip through. Stdlib-only, no extra CI dependencies.
- `docs/watchlist.md` ships the operator + developer documentation including a copy-pasteable Code node snippet (`require('fs')`, read-append-write with dedup by `source_email_id`). The `fs` access in Code nodes is enabled by `NODE_FUNCTION_ALLOW_BUILTIN=fs` already added in PR #53.
- Reviews: 3 Copilot Should Have comments (atomic claim wording, read/parse error handling split, format checker enforcement) and 1 Codex P2 (same format-checker point) all addressed inline in commit `686ab7b`.
- Validation: `make validate` correctly passes on a seeded valid file with one `accept` + one `decline` entry, and fails with a path-and-message error on bad enum (`'maybe' is not one of ['accept', 'decline']`), bad date-time (`'yesterday at noon' is not a 'date-time'`), and bad URI (`'not-a-real-url' is not a 'uri'`).
- Unblocks: #46 (skip branch — first consumer of the writer), #28 (accept branch — second consumer, with `repo_url` field), #32 (`/status` command — first reader).

## 2026-04-27

### Infra — ngrok tunnel for Telegram webhook (PR #55 merged, issue #30 closed)

- **PR #55** merged — `chore(infra): setup ngrok tunnel for Telegram webhook` (merge commit `028463a`). Adds the public-tunnel infrastructure that epic #45 needs: Telegram inline-button `callback_query` events have to reach n8n, but n8n stays on `localhost:5678` (host networking), so a tunnel is mandatory. Only ngrok faces the public internet; n8n itself remains unchanged.
- New `ngrok` Compose service alongside `n8n` and `autoheal`, pinned to `ngrok/ngrok:3.38.0-debian` (matches the version pinning policy from PR #52 — no more silent upgrades on `make up`). `network_mode: host` so the tunnel target is a simple `localhost:5678` and ngrok's local inspector API on port 4040 is reachable from the host (the discovery path the future webhook-updater in #31 will use).
- `NGROK_AUTHTOKEN` is required at compose-time via `${NGROK_AUTHTOKEN:?...}` syntax with a custom error message pointing operators to `docs/setup-ngrok.md`. Compose refuses to even start when the var is unset, instead of looping on auth errors at runtime.
- Operator setup ran end-to-end on `vev-XPS-15-9530`: free-tier ngrok account created, authtoken added to `docker/.env`, `make up` brings the tunnel up cleanly. Public URL is `https://laboring-laziness-generic.ngrok-free.dev` (rotates on every restart per free-tier limitation). End-to-end public reachability proven: external `curl <public>/healthz` returns `HTTP/2 200` from n8n.
- **Scope strict**: tunnel + docs only. Webhook **registration** with the Telegram Bot API (`setWebhook`) is deferred to #31 alongside the Telegram Trigger workflow it serves — wiring it now would point Telegram at a non-existent endpoint.
- New `docs/setup-ngrok.md` covers signup, the URL-rotates-on-restart caveat, manual verification commands, troubleshooting (`ERR_NGROK_4018` auth, inspector API unreachable, webhook delivery failures), and how to disable. `README.md` mentions the tunnel in the architecture section and adds ngrok signup to prerequisites.
- Reviews: 3 Copilot + 2 Codex P2 inline comments on PR #55, all addressed in fix-up commit `279cba8`. Three unique points (two were doublons across reviewers): pin ngrok image (regression vs PR #52's policy), fail-fast on missing `NGROK_AUTHTOKEN`, tighten the docs jq selector to filter `proto == "https"` rather than picking `.tunnels[0]` (HTTPS is mandatory for Telegram webhooks). Side-discovery during the pin: ngrok's Docker Hub tag scheme is `<version>-<distro>` composite (`3.38.0-debian`, `3.38.0-alpine`), not bare `<version>` — the obvious `3.38.0` does not exist as a tag.
- **Security envelope** explicitly accepted for v1.2: random `ngrok-free.dev` subdomain rotates per restart, n8n user-management password protects the editor and REST API, webhook endpoints generated by n8n use unpredictable 32-char IDs. Acceptable for "single-user homelab prototype". v1.3 roadmap migrates to Cloudflare Tunnel for stable URL + zero-trust auth.
- Unblocks: #31 (Telegram callback handler workflow + webhook-updater sidecar), then #27 (inline buttons on Kaggle email notifications), then the consumer flows #46 (skip) and #28 (accept).
