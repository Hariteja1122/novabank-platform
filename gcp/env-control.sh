#!/usr/bin/env bash
# Save money: stop an environment's Db2 VM when you are not using it, start it again later.
# Cloud Run services already scale to zero on their own.
#   ./gcp/env-control.sh stop preprod
#   ./gcp/env-control.sh start preprod
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh
ACTION="${1:?usage: env-control.sh start|stop dev|preprod}"
ENV="${2:?usage: env-control.sh start|stop dev|preprod}"
env_settings "$ENV"
require_project
gcloud compute instances "$ACTION" "$DB2_VM" --zone "$ZONE"
