# YouTube Data API v3 Setup Guide

This walks you through the one-time OAuth setup lazy-tube needs to upload
videos on your behalf.

## 1. Create a Google Cloud project

1. Go to https://console.cloud.google.com
2. Create a new project (or select an existing one).
3. Open **APIs & Services -> Library**, search for **YouTube Data API v3**,
   and click **Enable**.

## 2. Configure the OAuth consent screen

1. Open **APIs & Services -> OAuth consent screen**.
2. Choose **External** (unless you have a Google Workspace org).
3. Fill in the required app fields (name, support email).
4. Under **Test users**, add the Google account(s) you will upload from.
   Skipping this step causes `access_denied` errors.

## 3. Create OAuth credentials

1. Open **APIs & Services -> Credentials -> Create Credentials -> OAuth client ID**.
2. Application type: **Desktop app** (NOT Web application - a Web app
   requires a manually configured redirect URI and will fail with
   `redirect_uri_mismatch`).
3. Download the resulting JSON file.
4. Save it as `data/client_secrets.json` in this project.

## 4. Required scopes

lazy-tube requests these scopes (already configured in `youtube_client.py`):

- `https://www.googleapis.com/auth/youtube.upload`
- `https://www.googleapis.com/auth/youtube.force-ssl`
- `https://www.googleapis.com/auth/youtube.readonly`

## 5. First run

The first upload opens a browser window for you to sign in and grant
access. A `youtube_token.pickle` file is then saved to `data/` so you
will not be prompted again until the token expires or is revoked.

## 6. Quota

The default YouTube API quota is 10,000 units/day. A single video
upload costs ~1,600 units, so you get roughly 6 uploads/day by default.
Request a higher quota under **APIs & Services -> Quotas** if you need more.