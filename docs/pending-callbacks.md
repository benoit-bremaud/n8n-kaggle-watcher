# Pending Callbacks — context stash for Telegram inline buttons

The pending-callbacks stash is the append-only journal of context for Telegram inline-button callbacks. Each entry corresponds to one Kaggle notification that was sent with `j:<shortid>` / `s:<shortid>` callback_data; when the user clicks a button, the Telegram Callback Handler looks up `<shortid>` here to get back the full context (slug, URL, name, Gmail email_id, chat_id, message_id) and dispatch downstream consumers (#46 skip, #28 accept) without re-deriving anything.

This file exists because Telegram caps `callback_data` at 64 bytes, which is too tight to inline both the action and a typical Kaggle competition slug (the `house-prices-advanced-regression-techniques` slug alone is 43 chars). Phase A of the inline-buttons rollout (PR #67 / #65) shipped a compact `j:<slug>` / `s:<slug>` format that works for ~95% of real slugs; Phase B (PR #66) replaces the slug with a deterministic 8-char hash and persists the rich context separately.

## File layout

| Path | Tracking | Mode |
|---|---|---|
| `rules/pending-callbacks.schema.json` | committed | n/a (config) |
| `state/pending-callbacks.json.example` | committed | n/a (bootstrap) |
| `state/pending-callbacks.json` | **gitignored** | rw at runtime |

The schema lives under `rules/` because it is part of the project's config contract. The runtime data lives under `state/` because:

- `state/` is bind-mounted **read-write** in `docker-compose.yml` (`../state:/data/state`), so n8n Code nodes can append to it.
- `rules/` is bind-mounted **read-only** (`../rules:/data/rules:ro`) to prevent accidental writes to `actions.json` or `telegram-config.json` from any node.

Inside the n8n container, the path is `/data/state/pending-callbacks.json`.

## Schema

See [`rules/pending-callbacks.schema.json`](../rules/pending-callbacks.schema.json) for the canonical definition. Required fields per entry:

- `shortid` (string, 6–16 chars) — deterministic 8-char hash used as the `callback_data` suffix
- `competition_id` (string) — Kaggle slug used in URLs
- `competition_url` (uri) — canonical kaggle.com URL
- `competition_name` (string) — human-readable name parsed from the Launch email subject
- `chat_id` (integer or string) — Telegram chat where the notification was sent
- `email_id` (string) — Gmail message id, used by #46 for mark-as-read + label
- `ts` (ISO 8601 date-time) — when the entry was written; input to the shortid hash and the 30-day pruning rule

Optional: `message_id` (integer or null) — Telegram message id of the original notification. Null at write time (the message has not been sent yet); the live `callback_query.message.message_id` from the click payload is the authoritative value at read time.

## Bootstrap

On a fresh install, copy the empty example file:

```bash
cp state/pending-callbacks.json.example state/pending-callbacks.json
```

The Telegram Callback Handler tolerates the file being absent (treated as empty — the lookup misses and the handler falls back to the legacy `j:<slug>` / `s:<slug>` parsing for the simulated curl test harness).

## Writer — n8n Code node template

Use this snippet in a Code node placed **after `Match Rule` and before `Send Telegram`** in the Kaggle Email Watcher workflow. It generates the deterministic shortid, prunes entries older than 30 days, appends the new entry, and exposes `shortid` on the node output so the downstream `Send Telegram` inline-keyboard expressions can reference `{{ $json.shortid }}`.

```javascript
const fs = require('fs');
const crypto = require('crypto');
const PATH = '/data/state/pending-callbacks.json';
const TTL_DAYS = 30;

const item = $input.first().json;
const ts = new Date().toISOString();

// Deterministic 8-char shortid: sha256(competition_id + ts), hex slice.
// competition_id alone is not unique enough (same slug across days collides);
// adding ts guarantees a fresh hash per notification while staying stable
// for that specific notification's callbacks (the same shortid resolves
// back to the same entry no matter how many times the user clicks).
const shortid = crypto
  .createHash('sha256')
  .update(item.competition_id + ts)
  .digest('hex')
  .slice(0, 8);

// Read existing list, default to empty array on missing file or unparseable
// JSON. ENOENT is treated as "first write" (empty list); any other read
// error throws so a permission issue or filesystem failure surfaces clearly.
let raw = '[]';
try {
  raw = fs.readFileSync(PATH, 'utf8');
} catch (err) {
  if (err.code !== 'ENOENT') throw err;
}

let list;
try {
  list = JSON.parse(raw);
  if (!Array.isArray(list)) list = [];
} catch (err) {
  list = [];
}

// Prune entries older than TTL_DAYS days before append. Keeps the file
// bounded — n8n Code nodes read the whole file on every callback, so
// unbounded growth would slow down each click linearly over time.
const cutoff = Date.now() - TTL_DAYS * 24 * 60 * 60 * 1000;
list = list.filter((e) => {
  try {
    return new Date(e.ts).getTime() >= cutoff;
  } catch (_) {
    return false;
  }
});

const entry = {
  shortid,
  competition_id:   item.slug || item.competition_id,
  competition_url:  item.url || item.competition_url || '',
  competition_name: item.competition_name || '',
  chat_id:          item.action_config?.chat_id || item.chat_id || '',
  message_id:       null,
  email_id:         item.email_id || '',
  ts,
};

list.push(entry);
fs.writeFileSync(PATH, JSON.stringify(list, null, 2));

return [{ json: { ...item, shortid, pending_callback_size: list.length } }];
```

The Code node assumes both `fs` and `crypto` are in `NODE_FUNCTION_ALLOW_BUILTIN` in `docker-compose.yml`. `fs` was enabled in PR #53 (Heartbeat marker writer); `crypto` is enabled in this PR.

## Reader — n8n Code node template (extended `Parse Callback Data`)

The Telegram Callback Handler's `Parse Callback Data` node detects the `<prefix>:<suffix>` shape, looks up `<suffix>` in the stash, and exposes the resolved fields downstream. Backward-compatible with the legacy Phase A `j:<slug>` / `s:<slug>` direct-slug format used by the simulated curl harness in `docs/setup-n8n.md` — the slug fallback fires when the stash lookup misses and the suffix does not look like a hex hash.

```javascript
const fs = require('fs');
const PATH = '/data/state/pending-callbacks.json';

const body = $input.first().json.body;
if (!body || !body.callback_query) {
  throw new Error('Missing callback_query in webhook payload');
}

const cb = body.callback_query;
const rawData = cb.data || '';

// Detect prefix:suffix shape. Prefix is single char j / s / anything else.
const colonIdx = rawData.indexOf(':');
let action = 'unknown';
let suffix = '';
if (colonIdx === 1) {
  const prefix = rawData[0];
  suffix = rawData.slice(2);
  if (prefix === 'j') action = 'join';
  else if (prefix === 's') action = 'skip';
}

// Stash lookup. Returns the resolved entry on hit, null on miss.
let entry = null;
try {
  const list = JSON.parse(fs.readFileSync(PATH, 'utf8'));
  if (Array.isArray(list)) {
    entry = list.find((e) => e.shortid === suffix) || null;
  }
} catch (err) {
  if (err.code !== 'ENOENT') {
    // Swallow: file unreadable or unparseable, fall through to legacy
  }
}

// Backward-compat: when the stash misses and the suffix looks like a
// slug (not a hex hash), use it directly as competition_id. Lets the
// simulated curl test harness keep working without seeding the stash.
const isHexHash = /^[0-9a-f]{6,16}$/.test(suffix);
if (!entry && !isHexHash && suffix) {
  entry = { competition_id: suffix };
}

return [{
  json: {
    action,
    competition_id:    entry?.competition_id    || '',
    competition_url:   entry?.competition_url   || '',
    competition_name:  entry?.competition_name  || '',
    email_id:          entry?.email_id          || '',
    chat_id:           cb.message?.chat?.id     ?? entry?.chat_id ?? '',
    message_id:        cb.message?.message_id   ?? entry?.message_id ?? null,
    callback_query_id: cb.id,
    from_user_id:      cb.from?.id,
    from_first_name:   cb.from?.first_name,
    raw_data:          rawData,
    stash_hit:         !!entry?.shortid,
  },
}];
```

## Validation

`make validate` runs `state/pending-callbacks.json` through `rules/pending-callbacks.schema.json` automatically when the file exists. A fresh clone with no `state/pending-callbacks.json` passes silently.

To exercise the validator manually:

```bash
# Seed a valid file with one entry
cat > state/pending-callbacks.json <<'EOF'
[
  {
    "shortid": "abc12345",
    "competition_id": "titanic",
    "competition_url": "https://www.kaggle.com/competitions/titanic",
    "competition_name": "Titanic - Machine Learning from Disaster",
    "chat_id": 123456789,
    "message_id": null,
    "email_id": "0x18f3e",
    "ts": "2026-04-28T20:30:00Z"
  }
]
EOF
make validate    # passes

# Mutate ts to invalid format
sed -i 's/"2026-04-28T20:30:00Z"/"yesterday at noon"/' state/pending-callbacks.json
make validate    # fails with a clear date-time error

# Clean up
rm state/pending-callbacks.json
```

## Future work

- Atomic write with file locking (`flock`) once concurrent callbacks become possible — currently bounded by n8n's serialised handler.
- Round-trip the live `message_id` back into the stash entry once the original Telegram message has been sent (Send Telegram emits `message_id` in its output) so the writer's null can be replaced for richer downstream debugging.
- Migrate from a JSON file to SQLite once the entry count or write contention warrants it.
- Consumer-specific helpers for #46 (skip — append to watchlist + Gmail mark-as-read) and #28 (accept — repo bootstrap from `competition_url`).
