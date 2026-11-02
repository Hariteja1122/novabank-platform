#!/bin/bash
# Runs inside the icr.io/db2_community/db2 container after the instance and the
# NOVABANK database are created (the image runs every script in /var/custom).
# It is idempotent: the marker file lives on the persisted /database volume, so
# the schema and sample data load only once per volume.

MARKER=/database/config/.novabank_seeded
SQL_DIR=/novabank-sql
INSTANCE="${DB2INSTANCE:-db2inst1}"
DB="${DBNAME:-NOVABANK}"

if [ -f "$MARKER" ]; then
  echo "[novabank] Sample database already loaded, skipping."
  exit 0
fi

echo "[novabank] Loading NovaBank schema and sample data into ${DB}..."
# db2 CLP return codes: 0 ok, 1 no rows, 2 warning, 4 error, 8 system error.
su - "$INSTANCE" -c "
  db2 connect to ${DB} || exit 8
  db2 -tvf ${SQL_DIR}/01-schema.sql;      rc1=\$?
  db2 -tvf ${SQL_DIR}/02-sample-data.sql; rc2=\$?
  db2 terminate
  if [ \$rc1 -ge 4 ] || [ \$rc2 -ge 4 ]; then exit 4; fi
"
if [ $? -ne 0 ]; then
  echo "[novabank] ERROR: loading SQL failed. Check the output above."
  exit 1
fi

touch "$MARKER"
echo "[novabank] Done. Demo admin: admin@novabank.dev / Admin@123"
