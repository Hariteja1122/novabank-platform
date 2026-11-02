#!/usr/bin/env bash
# Continuous delivery: push to "develop" deploys dev, push to "release/*" deploys preprod.
#
# Before running, connect your GitHub account to Cloud Build once:
#   Console > Cloud Build > Triggers > Connect repository > GitHub (Cloud Build GitHub App)
#   and select the five NovaBank service repos.
#
#   GITHUB_USER=your-github-name ./gcp/create-triggers.sh
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh
require_project
: "${GITHUB_USER:?Set GITHUB_USER to the GitHub account that owns the repos}"

for repo in novabank-account-service novabank-auth-service novabank-transaction-service novabank-api-gateway novabank-ui; do
  for pair in "dev:^develop$" "preprod:^release/.*$"; do
    env="${pair%%:*}"; branch="${pair#*:}"
    name="${repo#novabank-}-$env"
    if gcloud builds triggers describe "$name" --region "$REGION" >/dev/null 2>&1; then
      echo "trigger $name exists"; continue
    fi
    gcloud builds triggers create github --name "$name" --region "$REGION" \
      --repo-owner "$GITHUB_USER" --repo-name "$repo" --branch-pattern "$branch" \
      --build-config cloudbuild.yaml --substitutions "_ENV=$env,_REGION=$REGION" \
      --service-account "projects/$PROJECT_ID/serviceAccounts/$DEPLOYER_SA"
  done
done
