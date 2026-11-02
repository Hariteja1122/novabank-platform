# Shared settings for every gcp/*.sh script. Edit PROJECT_ID (or export it) before running.
PROJECT_ID="${PROJECT_ID:-your-gcp-project-id}"
REGION="${REGION:-us-central1}"
ZONE="${ZONE:-${REGION}-a}"
AR_REPO="novabank"
VPC="novabank-vpc"
DEPLOYER_SA="novabank-deployer@${PROJECT_ID}.iam.gserviceaccount.com"
DB2_BUCKET="gs://${PROJECT_ID}-novabank-db2"

# Per environment network and Db2 VM settings. Cloud Run YAMLs in each repo use the same IPs.
env_settings() {
  case "$1" in
    dev)     SUBNET_RANGE="10.10.0.0/24"; DB2_IP="10.10.0.10"; DB2_MACHINE="e2-standard-2" ;;
    preprod) SUBNET_RANGE="10.20.0.0/24"; DB2_IP="10.20.0.10"; DB2_MACHINE="e2-standard-2" ;;
    *) echo "Unknown environment '$1'. Use dev or preprod." >&2; exit 1 ;;
  esac
  SUBNET="novabank-$1-subnet"
  DB2_VM="novabank-db2-$1"
  RUN_SA="novabank-run-$1@${PROJECT_ID}.iam.gserviceaccount.com"
}

require_project() {
  if [ "$PROJECT_ID" = "your-gcp-project-id" ]; then
    echo "Set PROJECT_ID first, e.g.  export PROJECT_ID=novabank-demo-12345" >&2
    exit 1
  fi
  gcloud config set project "$PROJECT_ID" >/dev/null
}
