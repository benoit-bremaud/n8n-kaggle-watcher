# n8n Setup Guide

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose installed
- Gmail API credentials ([setup guide](setup-gmail-oauth.md))
- Telegram Bot token (see below)

## 1. Configure Environment

```bash
# Copy the environment template
cp docker/.env.example docker/.env
```

Edit `docker/.env` with your values:

```bash
# Gmail OAuth2 and Telegram credentials are configured directly
# in the n8n UI (see steps 5 and 6 below), not via environment
# variables. The following are kept here for reference only:
GMAIL_CLIENT_ID=
GMAIL_CLIENT_SECRET=
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=
```

> **Authentication:** n8n v1.0+ uses built-in user management. On first launch, the UI prompts you to create an owner account — no env vars needed. The deprecated `N8N_BASIC_AUTH_*` variables are silently ignored by modern n8n versions.
>
> **Note:** The workflows read the Telegram chat ID from `rules/telegram-config.json`, not from `docker/.env`. The `TELEGRAM_CHAT_ID` entry in `.env` is for reference only.

## Network Mode

This deployment uses `network_mode: host` in `docker-compose.yml`. n8n binds directly to the host's port 5678.

**Why host mode:**

- Works around an `iptables-nft` conflict on some Linux hosts where Docker cannot create custom bridge networks (`DOCKER-ISOLATION-STAGE-2` chain missing).
- Simpler setup for a single-container deployment.

**Tradeoffs:**

- **Linux only.** Host networking behaves differently on Docker Desktop for macOS/Windows — the container shares the host's network namespace on Linux, but Docker Desktop emulates this via a VM layer. On macOS/Windows you may need to switch to bridge mode.
- **No network isolation.** The container shares the host's network stack. Acceptable here because n8n is the only service and runs on a trusted host.

**To switch back to bridge networking** (e.g., on macOS/Windows, or if you don't hit the iptables issue), replace `network_mode: host` with:

```yaml
ports:
  - "5678:5678"
```

## 2. Create Telegram Bot and Get Chat ID

### Create the bot

1. Open Telegram and search for [@BotFather](https://t.me/BotFather)
2. Send `/newbot`
3. Choose a name (e.g., `Kaggle Watcher`)
4. Choose a username (e.g., `my_kaggle_watcher_bot`)
5. Copy the **bot token** — paste it as `TELEGRAM_BOT_TOKEN` in `docker/.env`

### Get your chat ID

1. Send any message to your new bot in Telegram (e.g., `/start`)
1. Run this command (replace `YOUR_TOKEN` with your bot token):

```bash
curl -s "https://api.telegram.org/botYOUR_TOKEN/getUpdates" | python3 -m json.tool
```

1. Find `"chat": { "id": 123456789 }` in the response
1. Paste that number as `TELEGRAM_CHAT_ID` in `docker/.env`

### Configure the chat ID for workflows

```bash
# Copy the config template
cp rules/telegram-config.json.example rules/telegram-config.json
```

Edit `rules/telegram-config.json` with your chat ID:

```json
{
  "default_chat_id": 123456789
}
```

## 3. Start n8n

```bash
make up
```

Open the UI at [http://localhost:5678](http://localhost:5678). On first launch, n8n prompts you to create an owner account (email + password) via its built-in user management.

## 4. Import Workflows

Three workflows need to be imported:

### Kaggle Email Watcher (main workflow)

1. Click **Add workflow** → menu `⋮` → **Import from file**
2. Select `workflows/kaggle-email-watcher.json`
3. The workflow loads with all nodes pre-configured

### Heartbeat (health check)

1. Click **Add workflow** → menu `⋮` → **Import from file**
2. Select `workflows/heartbeat.json`

### Error Handler (global failure alerts)

1. Click **Add workflow** → menu `⋮` → **Import from file**
2. Select `workflows/error-handler.json`
3. Publish the workflow so it is available as a target

Then link it as the error workflow of the other two:

1. Open **Heartbeat** → menu `⋮` → **Settings** → **Error Workflow** → select **Error Handler** → **Save**
2. Open **Kaggle Email Watcher** → menu `⋮` → **Settings** → **Error Workflow** → select **Error Handler** → **Save**

Any failed production execution will now trigger a Telegram alert with the workflow name, failing node, error message, and timestamp (Europe/Paris).

## 5. Configure Credentials in n8n

### Gmail OAuth2

1. Open the **Kaggle Email Watcher** workflow
2. Click on the **Gmail Trigger** node
3. Click the credential dropdown → **Create New** → **Gmail OAuth2**
4. Paste your **Client ID** and **Client Secret** (from Google Cloud Console)
5. Click **Sign in with Google** and authorize
6. Save

See [setup-gmail-oauth.md](setup-gmail-oauth.md) for detailed Google Cloud Console instructions.

### Telegram

1. Open any workflow with a Telegram node
2. Click on the Telegram node → credential dropdown → **Create New** → **Telegram API**
3. Paste your **bot token**
4. Save

Both workflows share the same Telegram credential.

## 6. Activate Workflows

For each workflow:

1. Open the workflow
2. Click **Publish** (top right)
3. The schedule triggers will start running:
   - **Heartbeat**: every day at 07:55 (confirms n8n is alive)
   - **Kaggle Email Watcher**: every day at 08:00 (checks Gmail for Kaggle emails)

## 7. Verify

- You should receive the heartbeat Telegram message at 07:55 each day
- When Kaggle sends a "Competition Launch" or "Hackathon Launch" email, you will receive a formatted notification

## Useful Commands

```bash
make up         # Start n8n
make down       # Stop n8n
make logs       # Follow n8n logs
make validate   # Validate JSON files
make lint       # Run linters (YAML, shell, markdown)
make check      # Run all checks (validate + lint)
```

## Health Monitoring

The `n8n` service has a Docker `healthcheck` that probes both **local**
readiness and **outbound connectivity**:

- `wget http://localhost:5678/healthz` — n8n HTTP listener is alive
- `wget https://1.1.1.1/` — DNS resolution + outbound HTTPS work

The outbound probe targets Cloudflare's `1.1.1.1` (the same resolver
configured in `docker/resolv.conf`) rather than `api.telegram.org` to
keep container health decoupled from any single downstream service's
availability. n8n has its own retry/queue handling for transient
Telegram failures; restarting the container on a Telegram outage would
not restore connectivity and could cause a restart loop.

Both must pass for the container to be `healthy`. Parameters: probe
every `60s`, fail after `3` consecutive failures (max ~3 min detection
latency), `60s` grace period on startup.

**Inspect health status:**

```bash
docker inspect --format '{{.State.Health.Status}}' docker-n8n-1
# starting | healthy | unhealthy

docker inspect --format '{{json .State.Health}}' docker-n8n-1 | jq
# full history of the last probes
```

**Auto-recovery via `autoheal` sidecar:** the `autoheal` service
(`willfarrell/autoheal:1.2.0`) listens to Docker events and restarts any
container labeled `autoheal=true` when it becomes `unhealthy`. The n8n
service carries that label, so a stuck `EAI_AGAIN` loop, a frozen Node
process, or a Telegram outage that lasts past the retry window will
trigger an automatic restart with no human intervention.

- Requires mounting the Docker socket (`/var/run/docker.sock`) into the
  sidecar — acceptable on a single-user homelab host. Migrate to
  `tecnativa/docker-socket-proxy` if the threat model tightens.
- An explicit `make down` runs `docker compose down`, which stops and
  removes the container entirely, so neither `restart: unless-stopped`
  nor `autoheal` has anything left to act on. Detecting an explicitly
  stopped-but-still-existing container (for example via
  `docker compose stop` / `docker stop`) requires an external watcher
  independent of Docker (see **External Watchdog** below).

## External Watchdog

A host-side watchdog (`scripts/watchdog.sh`) probes the n8n stack from
**outside Docker** and posts a Telegram alert directly — independent of
n8n itself, so it stays usable when n8n is down, the container is
removed, or DNS is broken inside the container. Runs on a `systemd`
user timer every 15 minutes.

It runs three checks; each one alerts once when it starts failing and
sends a recovery notice when it recovers:

1. **Container running** — `docker inspect` shows `running` for
   `docker-n8n-1` (catches `make down` / `docker stop` / engine crash).
2. **Container health** — Docker reports `healthy` (catches stuck
   probes that autoheal failed to recover).
3. **Heartbeat marker freshness** — `state/last-heartbeat` (written by
   the Heartbeat workflow on every successful run) is younger than 26 h
   (catches a deactivated workflow, expired credential, or any reason
   the heartbeat stops firing without crashing the container).

The marker check is opt-in via `MARKER_CHECK_ENABLED=1` in the env
file. Until the Heartbeat workflow is updated to write the marker (see
the workflow notes in `workflows/heartbeat.json`), leave it at `0` to
avoid false positives.

### Setup

```bash
# 1. Create the env file (chmod 600, kept outside the repo)
mkdir -p ~/.config/n8n-watchdog
cat > ~/.config/n8n-watchdog/env <<'EOF'
TELEGRAM_BOT_TOKEN=123456:abc...           # same bot used by n8n
TELEGRAM_CHAT_ID=123456789                 # same chat id
STATE_DIR=/home/vev/Documents/07_kaggle/n8n-kaggle-watcher/state
MARKER_CHECK_ENABLED=0                     # flip to 1 once the workflow writes the marker
EOF
chmod 600 ~/.config/n8n-watchdog/env

# 2. Install the script + systemd user units, enable the timer
make install-watchdog
```

### Verify

```bash
# Manual one-shot run (should exit 0 silently when everything is fine)
~/.local/bin/n8n-watchdog && echo OK

# Timer state and next firing time
systemctl --user list-timers n8n-watchdog.timer

# Last service run (logs, exit code)
systemctl --user status n8n-watchdog.service
journalctl --user -u n8n-watchdog.service -n 20

# Trigger a controlled failure: stop n8n and wait <= 15 min for the alert.
# After `make up`, the next watchdog run posts a recovery message.
make down
```

### Anti-spam

Each check writes a sentinel under `/tmp/n8n-watchdog-alerted-<check>`
after sending an alert and only re-alerts once that sentinel is
removed (which happens automatically when the check passes again). One
issue → one alert + one recovery notice, regardless of how many timer
ticks the failure spans.

### Uninstall

```bash
make uninstall-watchdog       # removes script, units, disables timer
rm -rf ~/.config/n8n-watchdog # only if you also want to wipe the secrets
```

## Troubleshooting

### "chat not found" when testing Telegram

- Make sure you sent `/start` to your bot in Telegram first
- Verify the chat ID matches what `getUpdates` returns
- Try setting the Chat ID as **Fixed** instead of Expression in the n8n node

### Gmail trigger not firing

- Check that the Gmail OAuth2 credential is properly authorized
- Verify the polling schedule in the Gmail Trigger node (default: daily at 08:00)
- Check `make logs` for n8n error messages

### n8n container won't start

- Verify Docker is running: `docker ps`
- Check the .env file is valid: `make logs`
- Ensure port 5678 is not used by another service

### Heartbeat not received

- Check the workflow is published and active in n8n
- Verify `rules/telegram-config.json` exists and contains your chat ID
- Check timezone: n8n uses `Europe/Paris` (configured in docker-compose.yml)

### `EAI_AGAIN` / `fetch failed` on Gmail or Telegram nodes

- **Symptom**: Gmail Trigger or Telegram Send nodes fail with
  `getaddrinfo EAI_AGAIN api.telegram.org` (or `gmail.googleapis.com`).
  The n8n log also shows `TypeError: fetch failed` on PostHog telemetry
  requests as a leading indicator.
- **Root cause**: with `network_mode: host`, the container inherits the
  host's `/etc/resolv.conf`, which points to `systemd-resolved`
  (`127.0.0.53`). When systemd-resolved has a transient hiccup, Node's
  c-ares resolver caches the failure for the lifetime of the process, so
  every subsequent DNS lookup fails until the container restarts.
- **Fix (shipped)**: `docker/resolv.conf` overrides the container's
  resolver to Cloudflare (`1.1.1.1`) and Google (`8.8.8.8`), bypassing
  systemd-resolved entirely. It is mounted read-only at
  `/etc/resolv.conf` by `docker-compose.yml`. Only the n8n container is
  affected — the host's DNS configuration is untouched.
- **If the symptom still occurs**: the `autoheal` sidecar will now
  restart the container automatically after 3 consecutive failed
  healthchecks (see [Health Monitoring](#health-monitoring) above).
  Capture the logs and open a follow-up referencing
  [issue #43](https://github.com/benoit-bremaud/n8n-kaggle-watcher/issues/43)
  so we can escalate to option D (external log watcher independent of
  Docker).
- **After editing `docker/resolv.conf`**: the updated file is visible
  through the bind mount, so `docker compose restart n8n` is typically
  enough to make n8n/Node re-read `/etc/resolv.conf`. You only need
  `make down && make up` (or `docker compose up -d --force-recreate n8n`)
  if you add or change the `/etc/resolv.conf` volume mount itself in
  `docker-compose.yml`.
