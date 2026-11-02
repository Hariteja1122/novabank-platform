#!/bin/bash
# Compute Engine startup script for the NovaBank Db2 VM (Debian 12). Runs on every boot;
# installs Docker once, builds the NovaBank Db2 image from the bucket, keeps it running.
set -euo pipefail
md() { curl -fs -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/$1"; }
ENV=$(md novabank-env)
BUCKET=$(md novabank-bucket)
WORK=/opt/novabank

if ! command -v docker >/dev/null; then
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io
fi

mkdir -p "$WORK" /var/lib/novabank-db2
gcloud storage rsync -r "$BUCKET/db2" "$WORK/db2"
DB_PASSWORD=$(gcloud secrets versions access latest --secret "novabank-$ENV-db-password")

docker build -t novabank-db2:latest "$WORK/db2"

if [ -z "$(docker ps -aq -f name=^novabank-db2$)" ]; then
  docker run -d --name novabank-db2 --restart unless-stopped --privileged -p 50000:50000 \
    -v /var/lib/novabank-db2:/database \
    -e LICENSE=accept -e DB2INSTANCE=db2inst1 -e DB2INST1_PASSWORD="$DB_PASSWORD" -e DBNAME=NOVABANK \
    -e BLU=false -e ENABLE_ORACLE_COMPATIBILITY=false -e UPDATEAVAIL=NO -e TO_CREATE_SAMPLEDB=false \
    -e REPODB=false -e IS_OSXFS=false -e PERSISTENT_HOME=true -e HADR_ENABLED=false -e AUTOCONFIG=true \
    novabank-db2:latest
else
  docker start novabank-db2 >/dev/null || true
fi
echo "[novabank] Db2 container for $ENV is running. Watch: docker logs -f novabank-db2"
