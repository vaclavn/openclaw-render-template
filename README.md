# vn-gbrain-deploy

Deployable container image for a 24/7 personal AI agent: **AlphaClaw** (runtime
+ UI) with **git-crypt** available for encrypted brain repos. Platform-agnostic
Dockerfile; deploy to Northflank, Fly, Render, or any container host.

## What the image adds on top of AlphaClaw

1. Installs `git-crypt` and `tini` alongside git/curl/python/build tools
2. On container start, `entrypoint.sh`:
   - Decodes `GIT_CRYPT_KEY_BASE64` env var → `/data/.secrets/git-crypt-key` (mode 600)
   - Configures git identity (`GIT_AUTHOR_NAME` / `GIT_AUTHOR_EMAIL`)
   - Configures GitHub credentials from `GITHUB_TOKEN` for push access
3. Hands off to `alphaclaw start`

After boot, the agent (or gbrain install routine) clones the encrypted brain
repo and runs `git-crypt unlock /data/.secrets/git-crypt-key`. From that point
on, all commits/pushes auto-encrypt via the filter.

## Required env vars

| Variable | Purpose |
|----------|---------|
| `SETUP_PASSWORD` | Password for the AlphaClaw welcome wizard |
| `ANTHROPIC_API_KEY` | Claude API key for the agent |
| `DATABASE_URL` | Supabase Postgres connection string (pgvector required) |
| `GIT_CRYPT_KEY_BASE64` | `base64` of `git-crypt export-key` output |
| `GITHUB_TOKEN` | PAT with `repo` scope — enables agent pushes |
| `GIT_AUTHOR_EMAIL` | Email used on agent commits |

Optional:

| Variable | Purpose |
|----------|---------|
| `OPENCLAW_GATEWAY_TOKEN` | Gateway auth (auto-generated if empty) |
| `GIT_AUTHOR_NAME` | Commit author (default via welcome wizard) |
| `TELEGRAM_BOT_TOKEN` | Telegram channel |
| `OPENAI_API_KEY` | Alternative LLM provider |
| `PORT` | HTTP port (default `3000`) |

## Deploy to Northflank

1. **Create project** in Northflank — region `eu-west-1` (closest EU to Supabase Frankfurt).
2. **Create Deployment service:**
   - Source: GitHub → `vaclavn/openclaw-render-template` (this repo)
   - Build: **Dockerfile** (auto-detected)
   - Branch: `main`
3. **Resource plan:** `nf-compute-200` (4 vCPU, 8 GB RAM) — ~$52/month
4. **Ports:** `3000` HTTP, public, auto-TLS
5. **Persistent volume:** mount at `/data`, size 20 GB
6. **Secret group:** create `vn-gbrain-secrets` with all env vars above.
   Attach to the service.
7. **Health check:** HTTP path `/health` on port `3000`
8. **Deploy.**

After first deploy:

- Open the public URL
- Enter `SETUP_PASSWORD`
- Complete the AlphaClaw welcome wizard (model, provider auth, GitHub, channels)
- In the chat, paste: `Set up gbrain` → agent installs gbrain, 25 skills, cron jobs
- When gbrain asks for the brain repo: give `https://github.com/vaclavn/notes-brain.git`
- When prompted to unlock: the key is already at `/data/.secrets/git-crypt-key`

## Local dev

```bash
cp .env.example .env
# fill in API keys, DATABASE_URL, GIT_CRYPT_KEY_BASE64
docker compose up --build
```

UI at http://127.0.0.1:3000/

## Git-crypt key management

The value in `GIT_CRYPT_KEY_BASE64` is the symmetric git-crypt key exported
from the brain repo and base64-encoded:

```bash
cd /path/to/notes-brain
git-crypt export-key /tmp/key
base64 < /tmp/key   # paste output into Northflank secret
shred -u /tmp/key   # delete local copy
```

**Always keep a copy in 1Password.** If the key is lost, content on GitHub
is unrecoverable.

## Origin

Fork of [chrysb/openclaw-render-template](https://github.com/chrysb/openclaw-render-template)
— added git-crypt support, simplified for Northflank.
