#!/bin/sh
# Telegram webhook updater — runs as a one-shot Docker sidecar at stack
# startup. Polls the local ngrok inspector API for the current public
# URL, then registers it with the Telegram Bot API via setWebhook so
# inline-button callback_query events are routed back to n8n.
#
# Why this exists
#   ngrok free-tier rotates the public URL on every container restart.
#   Without this script, the operator would have to manually re-call
#   setWebhook after every `make up`. With it, registration is fully
#   automated and the only operator state is the single bot token in
#   docker/.env.
#
# Required env
#   TELEGRAM_BOT_TOKEN   bot token used to call the Bot API
#
# Optional env (with defaults)
#   WEBHOOK_PATH         path appended to the ngrok URL when registering
#                        (default: /webhook/telegram-callback — matches
#                        the Webhook node path in
#                        workflows/telegram-callback-handler.json)
#   NGROK_API            ngrok local inspector URL
#                        (default: http://localhost:4040/api/tunnels)
#   MAX_ATTEMPTS         polling attempts on the ngrok API
#                        (default: 30 — at 2s each = 1 minute total)
#   SLEEP_BETWEEN        seconds between polling attempts (default: 2)
#
# Exit codes
#   0  webhook successfully registered (or already registered with the
#      same URL — Telegram is idempotent on setWebhook)
#   1  unrecoverable failure: ngrok never came up, Telegram returned
#      ok=false, or the verification getWebhookInfo did not match
#      (Compose `restart: on-failure` will retry up to its policy)

set -eu

: "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN must be set}"
WEBHOOK_PATH="${WEBHOOK_PATH:-/webhook/telegram-callback}"
NGROK_API="${NGROK_API:-http://localhost:4040/api/tunnels}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-30}"
SLEEP_BETWEEN="${SLEEP_BETWEEN:-2}"

echo "webhook-updater starting"
echo "  ngrok API:      $NGROK_API"
echo "  webhook path:   $WEBHOOK_PATH"
echo "  max attempts:   $MAX_ATTEMPTS (sleep ${SLEEP_BETWEEN}s)"

# 1. Wait for ngrok to expose its HTTPS tunnel.
PUBLIC_URL=""
attempt=1
while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
  RESPONSE="$(curl -fsS --max-time 3 "$NGROK_API" 2>/dev/null || true)"
  if [ -n "$RESPONSE" ]; then
    PUBLIC_URL="$(printf '%s' "$RESPONSE" | jq -r '.tunnels[]? | select(.proto == "https") | .public_url' 2>/dev/null | head -1)"
    if [ -n "$PUBLIC_URL" ] && [ "$PUBLIC_URL" != "null" ]; then
      echo "Got public URL on attempt $attempt: $PUBLIC_URL"
      break
    fi
  fi
  echo "  attempt $attempt/$MAX_ATTEMPTS — ngrok not ready, retrying in ${SLEEP_BETWEEN}s"
  attempt=$((attempt + 1))
  sleep "$SLEEP_BETWEEN"
done

if [ -z "$PUBLIC_URL" ] || [ "$PUBLIC_URL" = "null" ]; then
  echo "ERROR: failed to obtain ngrok public URL after $MAX_ATTEMPTS attempts" >&2
  exit 1
fi

# 2. Register the webhook with Telegram.
WEBHOOK_URL="${PUBLIC_URL}${WEBHOOK_PATH}"
echo "Registering Telegram webhook: $WEBHOOK_URL"

# Restrict allowed_updates to callback_query so unrelated bot updates
# (chat messages, forwards, etc.) do not hit our handler unexpectedly.
SET_RESPONSE="$(curl -fsS --max-time 10 \
  --data-urlencode "url=$WEBHOOK_URL" \
  --data-urlencode 'allowed_updates=["callback_query"]' \
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/setWebhook")"

OK="$(printf '%s' "$SET_RESPONSE" | jq -r '.ok')"
if [ "$OK" != "true" ]; then
  echo "ERROR: Telegram setWebhook returned ok=false" >&2
  printf '%s' "$SET_RESPONSE" | jq . >&2 || printf '%s' "$SET_RESPONSE" >&2
  exit 1
fi

DESCRIPTION="$(printf '%s' "$SET_RESPONSE" | jq -r '.description // empty')"
echo "✓ setWebhook ok: $DESCRIPTION"

# 3. Verify via getWebhookInfo.
INFO="$(curl -fsS --max-time 10 "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getWebhookInfo")"
ACTUAL_URL="$(printf '%s' "$INFO" | jq -r '.result.url')"
if [ "$ACTUAL_URL" = "$WEBHOOK_URL" ]; then
  echo "✓ getWebhookInfo confirms URL: $ACTUAL_URL"
else
  echo "ERROR: getWebhookInfo URL mismatch" >&2
  echo "  expected: $WEBHOOK_URL" >&2
  echo "  actual:   $ACTUAL_URL" >&2
  exit 1
fi

LAST_ERROR="$(printf '%s' "$INFO" | jq -r '.result.last_error_message // empty')"
if [ -n "$LAST_ERROR" ]; then
  echo "WARNING: Telegram reports a previous delivery error: $LAST_ERROR" >&2
fi

echo "webhook-updater done"
exit 0
