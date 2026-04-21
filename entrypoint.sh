#!/bin/bash
set -euo pipefail

# --- 1. Materialize git-crypt key from env var -----------------------------
if [ -n "${GIT_CRYPT_KEY_BASE64:-}" ]; then
  mkdir -p /data/.secrets
  echo "$GIT_CRYPT_KEY_BASE64" | base64 -d > /data/.secrets/git-crypt-key
  chmod 600 /data/.secrets/git-crypt-key
  echo "[entrypoint] git-crypt key materialized at /data/.secrets/git-crypt-key"
fi

# --- 2. Configure git identity & credentials -------------------------------
if [ -n "${GIT_AUTHOR_NAME:-}" ]; then
  git config --global user.name "$GIT_AUTHOR_NAME"
fi
if [ -n "${GIT_AUTHOR_EMAIL:-}" ]; then
  git config --global user.email "$GIT_AUTHOR_EMAIL"
fi
if [ -n "${GITHUB_TOKEN:-}" ]; then
  git config --global credential.helper store
  echo "https://x-access-token:${GITHUB_TOKEN}@github.com" > ~/.git-credentials
  chmod 600 ~/.git-credentials
  echo "[entrypoint] GitHub credentials configured"
fi

# --- 3. Pre-clone AlphaClaw workspace repo (if configured) -----------------
# This lets us restore state from GitHub on fresh volumes,
# avoiding the welcome wizard on each redeploy/restart with wiped disk.
if [ -n "${GITHUB_WORKSPACE_REPO:-}" ] && [ ! -d /data/.openclaw/.git ]; then
  echo "[entrypoint] pre-cloning workspace repo $GITHUB_WORKSPACE_REPO"
  rm -rf /data/.openclaw
  if git clone "https://github.com/${GITHUB_WORKSPACE_REPO}.git" /data/.openclaw; then
    if [ -f /data/.secrets/git-crypt-key ] && [ -f /data/.openclaw/.git-crypt-enabled ]; then
      cd /data/.openclaw
      git-crypt unlock /data/.secrets/git-crypt-key || echo "[entrypoint] WARN: git-crypt unlock failed on workspace repo"
      cd /app
      echo "[entrypoint] workspace repo unlocked"
    fi
    echo "[entrypoint] workspace repo ready at /data/.openclaw"
  else
    echo "[entrypoint] workspace repo clone failed or repo empty - AlphaClaw will init fresh"
    rm -rf /data/.openclaw
  fi
fi

# --- 4. Pre-clone brain repo (for gbrain later) ---------------------------
if [ -n "${BRAIN_REPO_URL:-}" ] && [ ! -d /data/brain-repo/.git ]; then
  echo "[entrypoint] cloning brain repo from $BRAIN_REPO_URL"
  if git clone "$BRAIN_REPO_URL" /data/brain-repo; then
    if [ -f /data/.secrets/git-crypt-key ]; then
      cd /data/brain-repo
      git-crypt unlock /data/.secrets/git-crypt-key || echo "[entrypoint] WARN: brain repo git-crypt unlock failed"
      cd /app
      echo "[entrypoint] brain repo unlocked"
    fi
  fi
fi

exec "$@"
