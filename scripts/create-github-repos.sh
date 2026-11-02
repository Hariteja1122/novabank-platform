#!/usr/bin/env bash
# Creates the six NovaBank repos on GitHub and pushes them (needs the GitHub CLI: gh auth login).
# Run from the folder that contains all six repo folders' parent, i.e.:
#   cd novabank && ./novabank-platform/scripts/create-github-repos.sh            (private repos)
#   VISIBILITY=public ./novabank-platform/scripts/create-github-repos.sh
set -euo pipefail
VISIBILITY="${VISIBILITY:-private}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
command -v gh >/dev/null || { echo "Install the GitHub CLI first: https://cli.github.com" >&2; exit 1; }
OWNER=$(gh api user --jq .login)

# Point the Codespaces config at your account so the dev container can clone the other repos.
sed -i.bak "s/YOUR_GITHUB_USER/$OWNER/g" "$ROOT/novabank-platform/.devcontainer/devcontainer.json"
rm -f "$ROOT/novabank-platform/.devcontainer/devcontainer.json.bak"
sed -i.bak "s/YOUR_GITHUB_USER/$OWNER/g" "$ROOT/novabank-platform/README.md" && rm -f "$ROOT/novabank-platform/README.md.bak"

for repo in novabank-platform novabank-auth-service novabank-account-service novabank-transaction-service novabank-api-gateway novabank-ui; do
  cd "$ROOT/$repo"
  [ -d .git ] || git init -b main
  git add -A
  git diff --cached --quiet || git commit -m "Configure repository for $OWNER" >/dev/null
  if gh repo view "$OWNER/$repo" >/dev/null 2>&1; then
    echo "$OWNER/$repo already exists, pushing"
    git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/$OWNER/$repo.git"
    git push -u origin main
  else
    gh repo create "$OWNER/$repo" --"$VISIBILITY" --source . --remote origin --push
  fi
  git checkout -q -B develop && git push -q -u origin develop && git checkout -q main
done
echo "Done. Repos: https://github.com/$OWNER?tab=repositories&q=novabank"
