# Watchlist — Decision log for Kaggle Launch notifications

The watchlist is the append-only journal of Yes/No decisions taken on
Kaggle competition Launch notifications. Both branches of the
interactive flow write here:

- **Accept** (#28) — appends an entry with `decision: "accept"`,
  populated later with `repo_url` once the GitHub repo has been
  scaffolded.
- **Decline** (#46) — appends an entry with `decision: "decline"`.

The `/status` Telegram command (#32) reads this file to summarize the
current backlog and recent decisions.

## File layout

| Path | Tracking | Mode |
|---|---|---|
| `rules/watchlist.schema.json` | committed | n/a (config) |
| `state/watchlist.json.example` | committed | n/a (bootstrap) |
| `state/watchlist.json` | **gitignored** | rw at runtime |

The schema lives under `rules/` because it is part of the project's
config contract. The runtime data lives under `state/` because:

- `state/` is bind-mounted **read-write** in `docker-compose.yml`
  (`../state:/data/state`), so n8n Code nodes can append to it.
- `rules/` is bind-mounted **read-only** (`../rules:/data/rules:ro`)
  to prevent accidental writes to `actions.json` or
  `telegram-config.json` from any node.

Inside the n8n container, the path is `/data/state/watchlist.json`.

## Schema

See [`rules/watchlist.schema.json`](../rules/watchlist.schema.json) for
the canonical definition. Required fields per entry:

- `competition_id` (string) — Kaggle slug or numeric id used in URLs
- `decision` (`"accept"` or `"decline"`)
- `timestamp` (ISO 8601 date-time)
- `source_email_id` (string) — Gmail message id, used for dedup

Optional: `competition_name`, `competition_url`, `repo_url`.

## Bootstrap

On a fresh install, copy the empty example file:

```bash
cp state/watchlist.json.example state/watchlist.json
```

The watchdog and `/status` reader tolerate the file being absent
(treated as empty).

## Writer — n8n Code node template

Use this snippet in a Code node placed at the end of the accept and
decline branches. It performs an atomic read-append-write so two
parallel decisions on the same email cannot lose entries — but in
practice the inbound flow is serialized by the Schedule Trigger, so
the simple non-locking version below is sufficient.

```javascript
const fs = require('fs');
const PATH = '/data/state/watchlist.json';

// Read existing list, default to empty array if missing or unparseable.
let list = [];
try {
  const raw = fs.readFileSync(PATH, 'utf8');
  list = JSON.parse(raw);
  if (!Array.isArray(list)) list = [];
} catch (err) {
  if (err.code !== 'ENOENT') throw err;
}

// Build the new entry from the previous node's output.
const item = $input.first().json;
const entry = {
  competition_id:   item.competition_id,
  competition_name: item.competition_name,
  competition_url:  item.competition_url,
  decision:         item.decision,                  // 'accept' or 'decline'
  timestamp:        new Date().toISOString(),
  source_email_id:  item.source_email_id,
};
if (item.repo_url) entry.repo_url = item.repo_url;

// Dedup by source_email_id — guard against duplicate webhook callbacks.
if (list.some(e => e.source_email_id === entry.source_email_id)) {
  return [{ json: { ...item, watchlist_status: 'already-recorded' } }];
}

list.push(entry);
fs.writeFileSync(PATH, JSON.stringify(list, null, 2));

return [{ json: { ...item, watchlist_status: 'recorded', watchlist_size: list.length } }];
```

The Code node assumes `NODE_FUNCTION_ALLOW_BUILTIN=fs` is set in
`docker-compose.yml` (it already is, courtesy of the Heartbeat marker
writer added in PR #53).

## Validation

`make validate` runs `state/watchlist.json` through
`rules/watchlist.schema.json` automatically when the file exists. A
fresh clone with no `state/watchlist.json` passes silently. To
exercise the validator manually:

```bash
# Seed a valid file with one accept + one decline
cat > state/watchlist.json <<'EOF'
[
  {
    "competition_id": "titanic",
    "competition_name": "Titanic - Machine Learning from Disaster",
    "competition_url": "https://www.kaggle.com/competitions/titanic",
    "decision": "accept",
    "timestamp": "2026-04-26T14:00:00Z",
    "source_email_id": "<msg-id-1@mail.gmail.com>"
  },
  {
    "competition_id": "house-prices-advanced-regression-techniques",
    "decision": "decline",
    "timestamp": "2026-04-26T14:05:00Z",
    "source_email_id": "<msg-id-2@mail.gmail.com>"
  }
]
EOF
make validate    # passes

# Mutate decision to an invalid value
sed -i 's/"accept"/"maybe"/' state/watchlist.json
make validate    # fails with a clear error pointing at the bad enum value

# Clean up
rm state/watchlist.json
```

## Future work

- Atomic write with file locking (`flock`) once concurrent decisions
  become possible — currently bounded by n8n's single-threaded
  scheduler.
- Periodic compaction or rotation if the file grows past a few MB.
- Read-side helper for `/status` (#32).
