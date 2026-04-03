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
# n8n admin credentials
N8N_USER=admin
N8N_PASSWORD=your-strong-password

# Gmail OAuth2 (from Google Cloud Console)
GMAIL_CLIENT_ID=your-client-id
GMAIL_CLIENT_SECRET=your-client-secret

# Telegram Bot
TELEGRAM_BOT_TOKEN=your-bot-token
TELEGRAM_CHAT_ID=your-chat-id
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

Open the UI at [http://localhost:5678](http://localhost:5678). On first launch, create an owner account with the credentials from `docker/.env`.

## 4. Import Workflows

Two workflows need to be imported:

### Kaggle Email Watcher (main workflow)

1. Click **Add workflow** → menu `⋮` → **Import from file**
2. Select `workflows/kaggle-email-watcher.json`
3. The workflow loads with all nodes pre-configured

### Heartbeat (health check)

1. Click **Add workflow** → menu `⋮` → **Import from file**
2. Select `workflows/heartbeat.json`

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
