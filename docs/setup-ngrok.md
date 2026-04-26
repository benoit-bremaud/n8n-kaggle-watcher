# ngrok tunnel — public URL for Telegram webhook

## Why this exists

Telegram inline-button taps are delivered as `callback_query` HTTP POST
requests to a public URL the operator registers via the Bot API
`setWebhook` endpoint. n8n runs on `localhost:5678` (host networking),
which is not reachable from Telegram's servers. ngrok punches a public
tunnel from `https://<random>.ngrok-free.app` straight to that local
port, so the callback chain works without exposing the host's port to
the internet directly.

This is the v1.2 prototype tunnel. The roadmap migrates to
**Cloudflare Tunnel** in v1.3 (stable URL, no per-restart rotation,
zero-trust auth) and to a self-hosted reverse proxy in v3.0 once the
stack moves to the homelab Pi.

## Operator setup (one-time)

1. **Create a free ngrok account** at
   https://dashboard.ngrok.com/signup. The free tier is sufficient for
   prototyping (1 concurrent tunnel, random subdomain per session).
2. **Copy the authtoken** from
   https://dashboard.ngrok.com/get-started/your-authtoken.
3. **Set it in `docker/.env`**:

   ```bash
   echo "NGROK_AUTHTOKEN=<your-token>" >> docker/.env
   ```

   `docker/.env` is gitignored; the placeholder lives in
   `docker/.env.example` for documentation.

4. **Recreate the stack** so the new env var reaches the ngrok
   container:

   ```bash
   make down && make up
   ```

The `ngrok` service runs alongside `n8n` and `autoheal` on the same
host network. It restarts automatically (`restart: unless-stopped`)
and tears down with `make down`.

## Verify the tunnel works

```bash
# 1. Service is up
docker ps --filter "name=docker-ngrok-1" --format "{{.Names}}\t{{.Status}}"

# 2. Read the current public URL from ngrok's local inspector API
PUBLIC_URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')
echo "$PUBLIC_URL"
# expected: https://<random>.ngrok-free.app

# 3. Hit n8n's healthcheck endpoint through the tunnel
curl -i "$PUBLIC_URL/healthz"
# expected: HTTP 200 with {"status":"ok"} (or similar n8n health body)
```

If step 3 returns 200, the chain Telegram → ngrok → n8n is reachable
end-to-end at the network layer. Wiring the actual Telegram webhook
to this URL is handled by issue #31 (callback handler workflow).

## Free-tier limitations

- **URL rotates on every restart.** The hostname looks like
  `https://abc123-xyz.ngrok-free.app` and changes every time the
  ngrok container is recreated. From #31 onwards, a webhook-updater
  sidecar will re-register the new URL with the Telegram Bot API on
  every `make up`, so the rotation is transparent. Until then, the
  URL is informational.
- **Interstitial warning page** on first browser visit per session.
  This affects humans browsing to the URL, **not** Telegram's
  webhook delivery (which the warning page does not gate).
- **40 concurrent connections** and **bandwidth limits** — way above
  anything our use case will reach (a few callback POSTs per day).

## Troubleshooting

### `docker logs docker-ngrok-1` shows `ERR_NGROK_4018` or `authentication failed`

The authtoken is wrong, missing, or for a different account. Double-
check `docker/.env`, then `make down && make up`.

### `curl http://localhost:4040/api/tunnels` returns "connection refused"

ngrok is not running or its inspector API has not started yet. Wait
~3 seconds after `make up`, or check `docker logs docker-ngrok-1` for
errors (often a bad authtoken or an account-level limit hit).

### `curl $PUBLIC_URL/healthz` returns 200 but Telegram delivery fails

The tunnel is fine — the issue is one layer up. Check that the bot
token is correct, that `setWebhook` was called with the right URL,
and that `getWebhookInfo` shows no `last_error_message`. These are
#31 territory.

## Stop / disable the tunnel

```bash
# Tear down everything
make down

# Or temporarily stop just ngrok without affecting n8n
docker stop docker-ngrok-1
```

`make up` brings it back next time. To remove the tunnel from the
stack entirely (e.g. when migrating to Cloudflare Tunnel in v1.3),
delete the `ngrok` service block in `docker/docker-compose.yml`.
