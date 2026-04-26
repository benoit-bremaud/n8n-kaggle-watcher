#!/usr/bin/env bash
# n8n external watchdog
#
# Probes the n8n stack from outside Docker and alerts via Telegram
# when the container is missing, unhealthy, or has stopped firing the
# daily Heartbeat workflow. Designed to be run on a systemd timer
# every 15 minutes (see scripts/n8n-watchdog.timer).
#
# Configuration is read from ${WATCHDOG_ENV_FILE:-$HOME/.config/n8n-watchdog/env}.
# Required variables:
#   TELEGRAM_BOT_TOKEN     bot token used to post the alert
#   TELEGRAM_CHAT_ID       chat id receiving the alert
# Optional variables (with defaults):
#   CONTAINER_NAME         docker container name        (default: docker-n8n-1)
#   STATE_DIR              host path of the state mount (default: derived from script location)
#   MARKER_FILE_NAME       marker file inside STATE_DIR (default: last-heartbeat)
#   MARKER_MAX_AGE_SECONDS marker freshness threshold   (default: 93600 = 26 h)
#   MARKER_CHECK_ENABLED   1 to enable marker check     (default: 0 — flipped on once the
#                                                        Heartbeat workflow writes the marker)
#   SENTINEL_DIR           dir holding per-check anti-spam sentinels (default: /tmp)

set -euo pipefail

WATCHDOG_ENV_FILE="${WATCHDOG_ENV_FILE:-$HOME/.config/n8n-watchdog/env}"

if [ ! -r "$WATCHDOG_ENV_FILE" ]; then
  echo "watchdog: env file not found or not readable: $WATCHDOG_ENV_FILE" >&2
  exit 2
fi

# shellcheck source=/dev/null
. "$WATCHDOG_ENV_FILE"

: "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN must be set in $WATCHDOG_ENV_FILE}"
: "${TELEGRAM_CHAT_ID:?TELEGRAM_CHAT_ID must be set in $WATCHDOG_ENV_FILE}"

CONTAINER_NAME="${CONTAINER_NAME:-docker-n8n-1}"
MARKER_FILE_NAME="${MARKER_FILE_NAME:-last-heartbeat}"
MARKER_MAX_AGE_SECONDS="${MARKER_MAX_AGE_SECONDS:-93600}"
MARKER_CHECK_ENABLED="${MARKER_CHECK_ENABLED:-0}"
SENTINEL_DIR="${SENTINEL_DIR:-/tmp}"

# STATE_DIR must be set explicitly. A previous version derived a default
# from the script's location, but `make install-watchdog` copies the
# script to ~/.local/bin, which would then resolve STATE_DIR to a wrong
# path and surface false "marker missing" alerts. Forcing the operator
# to set it makes the install path obvious and matches the env-file
# template documented in docs/setup-n8n.md.
: "${STATE_DIR:?STATE_DIR must be set in $WATCHDOG_ENV_FILE (absolute path to the host-side state directory containing the heartbeat marker)}"

send_telegram() {
  local text="$1"
  # --fail makes curl exit non-zero on 4xx/5xx so a bad token, revoked
  # bot, or Telegram outage does NOT create a sentinel — the next
  # watchdog tick will retry the alert.
  curl --silent --show-error --fail --max-time 10 \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=${text}" \
    --data-urlencode "parse_mode=Markdown" \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    >/dev/null
}

# alert_once <check_id> <message> — sends a Telegram alert at most once per
# failure streak. The sentinel file is removed by clear_alert when the check
# recovers, so the next failure can alert again.
alert_once() {
  local check_id="$1"
  local message="$2"
  local sentinel="${SENTINEL_DIR}/n8n-watchdog-alerted-${check_id}"
  if [ -f "$sentinel" ]; then
    return 0
  fi
  if send_telegram "$message"; then
    : >"$sentinel"
  fi
}

# clear_alert <check_id> [recovery_message] — if a sentinel exists for this
# check, removes it and (if a message was provided) sends a recovery notice.
clear_alert() {
  local check_id="$1"
  local recovery_message="${2:-}"
  local sentinel="${SENTINEL_DIR}/n8n-watchdog-alerted-${check_id}"
  if [ ! -f "$sentinel" ]; then
    return 0
  fi
  rm -f "$sentinel"
  if [ -n "$recovery_message" ]; then
    send_telegram "$recovery_message" || true
  fi
}

check_docker_daemon() {
  # Probe the daemon explicitly so we can distinguish "container is gone"
  # from "Docker is unreachable" (daemon down, socket missing, no perms).
  # Without this, every check below would say "container missing" — which
  # would be misleading since the operator should restart Docker, not the
  # container.
  if docker info >/dev/null 2>&1; then
    clear_alert "daemon" "✅ *n8n watchdog* — Docker daemon is reachable again."
    return 0
  fi
  alert_once "daemon" "🚨 *n8n watchdog* — Docker daemon is *unreachable* (\`docker info\` failed). Container, health, and heartbeat checks were skipped this tick. Restart Docker (\`sudo systemctl restart docker\`) or check user permissions."
  return 1
}

check_container_running() {
  local status
  status="$(docker inspect --format '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "missing")"
  if [ "$status" = "running" ]; then
    clear_alert "container" "✅ *n8n watchdog* — container \`${CONTAINER_NAME}\` is back to *running*."
    return 0
  fi
  alert_once "container" "🚨 *n8n watchdog* — container \`${CONTAINER_NAME}\` is *${status}* (expected: running). The next Heartbeat will not fire until this is resolved."
  return 1
}

check_container_health() {
  local health
  health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$CONTAINER_NAME" 2>/dev/null || echo "missing")"
  case "$health" in
    healthy)
      clear_alert "health" "✅ *n8n watchdog* — container health is back to *healthy*."
      return 0
      ;;
    starting)
      # Transient state during boot or autoheal recovery — neither alert
      # nor recovery. The next tick will re-evaluate.
      return 0
      ;;
    none)
      # No healthcheck configured. Either the docker-compose.yml lost its
      # `healthcheck:` block or someone is running an out-of-tree image.
      # Either way the second probe of this watchdog is now ineffective,
      # so flag it loudly.
      alert_once "health" "🚨 *n8n watchdog* — container \`${CONTAINER_NAME}\` has *no Docker healthcheck configured* (status: \`none\`). The watchdog cannot verify that n8n becomes *healthy*. Restore the \`healthcheck:\` block in docker-compose.yml."
      return 1
      ;;
    unhealthy)
      alert_once "health" "🚨 *n8n watchdog* — container \`${CONTAINER_NAME}\` is *unhealthy*. autoheal should restart it shortly; if this alert persists, the restart is failing."
      return 1
      ;;
    *)
      alert_once "health" "🚨 *n8n watchdog* — container \`${CONTAINER_NAME}\` health is unknown (\`${health}\`). Check the container state manually."
      return 1
      ;;
  esac
}

check_heartbeat_marker() {
  if [ "$MARKER_CHECK_ENABLED" != "1" ]; then
    return 0
  fi
  local marker="${STATE_DIR}/${MARKER_FILE_NAME}"
  if [ ! -f "$marker" ]; then
    alert_once "marker" "🚨 *n8n watchdog* — heartbeat marker \`${marker}\` is missing. The Heartbeat workflow has not run since the last reset, or the volume mount is broken."
    return 1
  fi
  local mtime now age
  mtime="$(stat -c %Y "$marker")"
  now="$(date +%s)"
  age=$(( now - mtime ))
  if [ "$age" -gt "$MARKER_MAX_AGE_SECONDS" ]; then
    local hours=$(( age / 3600 ))
    alert_once "marker" "🚨 *n8n watchdog* — heartbeat marker is *${hours}h* old (threshold: $(( MARKER_MAX_AGE_SECONDS / 3600 ))h). The Heartbeat workflow has stopped firing — check it is published and active in n8n."
    return 1
  fi
  clear_alert "marker" "✅ *n8n watchdog* — heartbeat marker is fresh again."
  return 0
}

# Probe the Docker daemon first. If it is unreachable, every downstream
# check would surface a misleading "container missing" — short-circuit
# instead so the operator sees the actual root cause (daemon down).
if ! check_docker_daemon; then
  exit 1
fi

# Each container-level check is independent: a failure on one does not
# skip the others, so a single watchdog tick can surface multiple
# distinct issues.
overall=0
check_container_running || overall=1
check_container_health  || overall=1
check_heartbeat_marker  || overall=1

exit "$overall"
