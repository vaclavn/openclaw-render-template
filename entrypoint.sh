#!/bin/bash
set -euo pipefail

# Materialize git-crypt key from env var if provided
if [ -n "${GIT_CRYPT_KEY_BASE64:-}" ]; then
  mkdir -p /data/.secrets
  echo "$GIT_CRYPT_KEY_BASE64" | base64 -d > /data/.secrets/git-crypt-key
  chmod 600 /data/.secrets/git-crypt-key
  echo "[entrypoint] git-crypt key materialized at /data/.secrets/git-crypt-key"
fi

# Configure git identity for commits from the container
if [ -n "${GIT_AUTHOR_NAME:-}" ]; then
  git config --global user.name "$GIT_AUTHOR_NAME"
fi
if [ -n "${GIT_AUTHOR_EMAIL:-}" ]; then
  git config --global user.email "$GIT_AUTHOR_EMAIL"
fi

# Configure GitHub credentials for push/pull if provided
if [ -n "${GITHUB_TOKEN:-}" ]; then
  git config --global credential.helper store
  echo "https://x-access-token:${GITHUB_TOKEN}@github.com" > ~/.git-credentials
  chmod 600 ~/.git-credentials
  echo "[entrypoint] GitHub credentials configured"
fi

# Auto-clone and unlock brain repo on first boot
if [ -n "${BRAIN_REPO_URL:-}" ] && [ ! -d /data/brain-repo/.git ]; then
  echo "[entrypoint] cloning brain repo from $BRAIN_REPO_URL"
  git clone "$BRAIN_REPO_URL" /data/brain-repo
  if [ -f /data/.secrets/git-crypt-key ]; then
    cd /data/brain-repo
    git-crypt unlock /data/.secrets/git-crypt-key
    echo "[entrypoint] brain repo unlocked"
    cd /app
  fi
fi

exec "$@"
