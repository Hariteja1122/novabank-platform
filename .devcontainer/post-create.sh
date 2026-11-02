#!/usr/bin/env bash
# Runs once when the Codespace is created: clones the five sibling repos next to this
# one so docker compose can build them, then installs the Claude Code CLI.
set -euo pipefail
OWNER=$(git -C "$(dirname "$0")/.." remote get-url origin | sed -E 's#.*[:/]([^/]+)/[^/]+(\.git)?$#\1#')
cd "$(dirname "$0")/../.."
for r in novabank-auth-service novabank-account-service novabank-transaction-service novabank-api-gateway novabank-ui; do
  [ -d "$r" ] || gh repo clone "$OWNER/$r" "$r" || git clone "https://github.com/$OWNER/$r.git" "$r"
done
cp -n novabank-platform/.env.example novabank-platform/.env || true
curl -fsSL https://claude.ai/install.sh | bash || echo "Claude Code install skipped (run it later: curl -fsSL https://claude.ai/install.sh | bash)"
echo "Workspace ready. NovaBank starts automatically; run 'bash dev.sh status' to check."
