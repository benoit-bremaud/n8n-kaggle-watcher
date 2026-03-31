# Gmail OAuth2 Setup

This guide walks you through creating Gmail API credentials for n8n.

## 1. Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click **Select a project** → **New Project**
3. Name it `n8n-kaggle-watcher` → **Create**

## 2. Enable Gmail API

1. Go to **APIs & Services** → **Library**
2. Search for **Gmail API**
3. Click **Enable**

## 3. Configure OAuth Consent Screen

1. Go to **APIs & Services** → **OAuth consent screen**
2. Choose **External** → **Create**
3. Fill in:
   - App name: `n8n-kaggle-watcher`
   - User support email: your email
   - Developer contact: your email
4. Click **Save and Continue**
5. **Scopes**: Add `https://www.googleapis.com/auth/gmail.readonly`
6. **Test users**: Add your Gmail address
7. Click **Save and Continue**

## 4. Create OAuth2 Credentials

1. Go to **APIs & Services** → **Credentials**
2. Click **+ Create Credentials** → **OAuth client ID**
3. Application type: **Web application**
4. Name: `n8n`
5. Authorized redirect URIs: `http://localhost:5678/rest/oauth2-credential/callback`
6. Click **Create**
7. Copy the **Client ID** and **Client Secret**

## 5. Configure in n8n

1. Open n8n at `http://localhost:5678`
2. Go to **Settings** → **Credentials** → **Add Credential**
3. Search for **Gmail OAuth2**
4. Paste your **Client ID** and **Client Secret**
5. Click **Sign in with Google** and authorize
6. Save the credential

## Troubleshooting

- **Error 403: access_denied**: Make sure your email is added as a test user in the OAuth consent screen
- **Redirect URI mismatch**: Verify the redirect URI matches exactly (`http://localhost:5678/rest/oauth2-credential/callback`)
- **Token expired**: Re-authenticate in n8n credentials settings
