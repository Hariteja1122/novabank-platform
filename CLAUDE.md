# CLAUDE.md: novabank-platform

Infrastructure and shared assets for NovaBank (see README.md). No application code lives here.

- `db2/schema/*.sql` is the source of truth for every table. Services use `ddl-auto: none`.
  When a service entity changes, change the SQL here and keep `02-sample-data.sql` loadable.
  Existing databases (dev / preprod VMs) get the same change as a numbered script in `db2/migrations/`.
- `docker-compose.yml` builds the five sibling repos from `../<repo>`; keep ports and env names
  in sync with each service's `application-local.yml`.
- `gcp/config.sh` holds the per environment IPs and names that the Cloud Run YAMLs in every
  service repo (`deploy/environments/*.yaml`) also use. Change both together.
- `api/postman/NovaBank.postman_collection.json` should gain a request for every new endpoint.
- Shell scripts must stay idempotent and pass `bash -n`.
