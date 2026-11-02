#!/usr/bin/env bash
# Build and deploy every NovaBank service to one environment with Cloud Build.
#   ./gcp/deploy-all.sh dev
#   ./gcp/deploy-all.sh preprod
# Each repo's cloudbuild.yaml does the work, using deploy/environments/<env>.yaml.
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh
ENV="${1:?usage: deploy-all.sh dev|preprod}"
env_settings "$ENV"
require_project

# Order matters a little: account-service first, since auth and transaction call it.
for repo in novabank-account-service novabank-auth-service novabank-transaction-service novabank-api-gateway novabank-ui; do
  dir="../../$repo"
  [ -d "$dir" ] || { echo "Missing $dir" >&2; exit 1; }
  printf '\n\033[0;32m==> %s -> %s\033[0m\n' "$repo" "$ENV"
  gcloud builds submit "$dir" --config "$dir/cloudbuild.yaml" --region "$REGION" \
    --service-account "projects/$PROJECT_ID/serviceAccounts/$DEPLOYER_SA" \
    --substitutions "_ENV=$ENV,_REGION=$REGION"
done

NUM=$(gcloud projects describe "$PROJECT_ID" --format 'value(projectNumber)')
cat <<TXT

Deployed NovaBank to $ENV.
  UI       https://novabank-ui-$ENV-$NUM.$REGION.run.app
  Gateway  https://novabank-gateway-$ENV-$NUM.$REGION.run.app
Set baseUrl in api/postman/NovaBank-$ENV.postman_environment.json to the gateway URL.
TXT
