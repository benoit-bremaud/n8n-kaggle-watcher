# n8n Setup Guide

## First Run

```bash
# Copy environment template
cp docker/.env.example docker/.env

# Edit credentials
nano docker/.env

# Start n8n
make up

# Open the UI
open http://localhost:5678
```

On first launch, n8n will ask you to create an owner account.

## Import Workflow

1. Open n8n at `http://localhost:5678`
2. Click **Add workflow** (or use the menu)
3. Click the **...** menu → **Import from file**
4. Select `workflows/kaggle-email-watcher.json`
5. The workflow will appear with all nodes pre-configured

## Configure Credentials

### Gmail OAuth2

See [setup-gmail-oauth.md](setup-gmail-oauth.md) for detailed instructions.

### Telegram

1. Create a bot via [@BotFather](https://t.me/BotFather) on Telegram:
   - Send `/newbot`
   - Choose a name (e.g., `Kaggle Watcher`)
   - Choose a username (e.g., `kaggle_watcher_bot`)
   - Copy the **bot token**

2. Get your **chat ID**:
   - Send a message to your bot
   - Visit `https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates`
   - Find your `chat.id` in the response

3. In n8n:
   - Go to **Settings** → **Credentials** → **Add Credential**
   - Search for **Telegram**
   - Paste your **bot token**
   - Save

4. Update `rules/actions.json` with your `chat_id`

## Activate the Workflow

1. Open the imported workflow
2. Click the **Active** toggle (top right) to enable it
3. The workflow will now poll Gmail every 5 minutes

## Useful Commands

```bash
make up         # Start n8n
make down       # Stop n8n
make logs       # Follow n8n logs
make validate   # Validate JSON files
```
