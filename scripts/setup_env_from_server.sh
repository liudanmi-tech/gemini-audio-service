#!/bin/bash
# 从服务端拉取 .env 中的 GEMINI_API_KEY 到本地 .env
# 用法: ./scripts/setup_env_from_server.sh user@host

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

SERVER="${1:-$DEPLOY_SERVER}"
REMOTE_DIR="${DEPLOY_REMOTE_DIR:-$HOME/gemini-audio-service}"

if [ -z "$SERVER" ]; then
  echo "Usage: $0 user@host"
  echo "Or set DEPLOY_SERVER in .deploy.env"
  exit 1
fi

echo "Fetching GEMINI_API_KEY from $SERVER..."
# 使用单引号确保 ~ 在远程展开
KEY=$(ssh "$SERVER" 'grep ^GEMINI_API_KEY= ~/gemini-audio-service/.env 2>/dev/null | cut -d= -f2-' || true)
if [ -z "$KEY" ]; then
  echo "ERROR: GEMINI_API_KEY not found on server"
  exit 1
fi

if [ ! -f .env ]; then
  cp .env.example .env
fi
grep -v '^GEMINI_API_KEY=' .env > .env.tmp 2>/dev/null || true
printf 'GEMINI_API_KEY=%s\n' "$KEY" >> .env.tmp
mv .env.tmp .env
echo "OK: Updated GEMINI_API_KEY in local .env"
