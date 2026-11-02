#!/usr/bin/env bash
# One-time setup of a NovaBank environment in GCP. Safe to re-run.
#
#   export PROJECT_ID=your-project REGION=us-central1
#   ./gcp/bootstrap.sh dev
#   ./gcp/bootstrap.sh preprod
#
# Creates: APIs, Artifact Registry repo, VPC + subnet, firewall rules, secrets,
# service accounts and IAM, and a Compute Engine VM running Db2 with the sample data.
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh
ENV="${1:?usage: bootstrap.sh dev|preprod}"
env_settings "$ENV"
require_project
step() { printf '\n\033[0;32m==> %s\033[0m\n' "$*"; }
exists() { "$@" >/dev/null 2>&1; }

step "Enabling APIs"
gcloud services enable run.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com \
  secretmanager.googleapis.com compute.googleapis.com iam.googleapis.com

step "Artifact Registry repository '$AR_REPO'"
exists gcloud artifacts repositories describe "$AR_REPO" --location "$REGION" ||
  gcloud artifacts repositories create "$AR_REPO" --repository-format docker --location "$REGION" \
    --description "NovaBank container images"

step "Network: $VPC / $SUBNET ($SUBNET_RANGE)"
exists gcloud compute networks describe "$VPC" || gcloud compute networks create "$VPC" --subnet-mode custom
exists gcloud compute networks subnets describe "$SUBNET" --region "$REGION" ||
  gcloud compute networks subnets create "$SUBNET" --network "$VPC" --region "$REGION" --range "$SUBNET_RANGE"
exists gcloud compute firewall-rules describe "novabank-$ENV-allow-db2" ||
  gcloud compute firewall-rules create "novabank-$ENV-allow-db2" --network "$VPC" --direction INGRESS \
    --allow tcp:50000 --source-ranges "$SUBNET_RANGE" --target-tags "db2-$ENV"
exists gcloud compute firewall-rules describe "novabank-allow-iap-ssh" ||
  gcloud compute firewall-rules create "novabank-allow-iap-ssh" --network "$VPC" --direction INGRESS \
    --allow tcp:22 --source-ranges 35.235.240.0/20

step "Secrets for $ENV"
make_secret() {
  local name="novabank-$ENV-$1" value="$2"
  if exists gcloud secrets describe "$name"; then echo "  $name exists"; else
    printf '%s' "$value" | gcloud secrets create "$name" --data-file=- --replication-policy automatic
  fi
}
make_secret db-password "Nb$(openssl rand -hex 12)"
make_secret jwt-secret "$(openssl rand -base64 48 | tr -d '\n')"
make_secret internal-api-key "$(openssl rand -hex 24)"

step "Service accounts and IAM"
for sa in "novabank-run-$ENV:NovaBank Cloud Run ($ENV)" "novabank-db2-$ENV:NovaBank Db2 VM ($ENV)" "novabank-deployer:NovaBank Cloud Build deployer"; do
  id="${sa%%:*}"; name="${sa#*:}"
  exists gcloud iam service-accounts describe "$id@$PROJECT_ID.iam.gserviceaccount.com" ||
    gcloud iam service-accounts create "$id" --display-name "$name"
done
for s in db-password jwt-secret internal-api-key; do
  gcloud secrets add-iam-policy-binding "novabank-$ENV-$s" --quiet \
    --member "serviceAccount:$RUN_SA" --role roles/secretmanager.secretAccessor >/dev/null
done
gcloud secrets add-iam-policy-binding "novabank-$ENV-db-password" --quiet \
  --member "serviceAccount:novabank-db2-$ENV@$PROJECT_ID.iam.gserviceaccount.com" \
  --role roles/secretmanager.secretAccessor >/dev/null
for role in roles/run.admin roles/artifactregistry.writer roles/logging.logWriter roles/storage.objectViewer; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" --quiet --condition=None \
    --member "serviceAccount:$DEPLOYER_SA" --role "$role" >/dev/null
done
gcloud iam service-accounts add-iam-policy-binding "$RUN_SA" --quiet \
  --member "serviceAccount:$DEPLOYER_SA" --role roles/iam.serviceAccountUser >/dev/null

step "Uploading Db2 image definition and SQL to $DB2_BUCKET"
exists gcloud storage buckets describe "$DB2_BUCKET" ||
  gcloud storage buckets create "$DB2_BUCKET" --location "$REGION" --uniform-bucket-level-access
gcloud storage rsync -r ../db2 "$DB2_BUCKET/db2" --delete-unmatched-destination-objects
gcloud storage buckets add-iam-policy-binding "$DB2_BUCKET" --quiet \
  --member "serviceAccount:novabank-db2-$ENV@$PROJECT_ID.iam.gserviceaccount.com" \
  --role roles/storage.objectViewer >/dev/null

step "Db2 VM $DB2_VM ($DB2_MACHINE, private IP $DB2_IP)"
if exists gcloud compute instances describe "$DB2_VM" --zone "$ZONE"; then
  echo "  $DB2_VM exists"
else
  gcloud compute instances create "$DB2_VM" --zone "$ZONE" --machine-type "$DB2_MACHINE" \
    --subnet "$SUBNET" --private-network-ip "$DB2_IP" --tags "db2-$ENV" \
    --image-family debian-12 --image-project debian-cloud --boot-disk-size 40GB --boot-disk-type pd-balanced \
    --service-account "novabank-db2-$ENV@$PROJECT_ID.iam.gserviceaccount.com" --scopes cloud-platform \
    --metadata "novabank-env=$ENV,novabank-bucket=$DB2_BUCKET" \
    --metadata-from-file startup-script=./db2-vm/startup-script.sh \
    --labels "app=novabank,env=$ENV"
fi

cat <<TXT

Environment '$ENV' is ready.
  Db2 is installing on $DB2_VM. First boot takes about 10 minutes. Follow it with:
    gcloud compute ssh $DB2_VM --zone $ZONE --tunnel-through-iap -- sudo journalctl -u google-startup-scripts -f
  Then deploy the services:
    ./gcp/deploy-all.sh $ENV
TXT
