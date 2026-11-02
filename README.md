# NovaBank platform

NovaBank is a retail banking application: customers sign up, hold checking and savings
accounts, move money and see their history; operations staff manage customers, freeze
accounts, record branch deposits and monitor transactions.

This repo holds everything that is not a service: the IBM Db2 schema and sample data, the
one command local environment, the GCP environment setup, the Postman / Hoppscotch
collection and the IDE guide.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/YOUR_GITHUB_USER/novabank-platform)

## The six repos

| Repo | What | Port |
|---|---|---|
| `novabank-ui` | Angular 22: user module (`/app`) and admin module (`/admin`) | 4200 |
| `novabank-api-gateway` | Spring Cloud Gateway: routing, JWT check, CORS, correlation IDs | 8080 |
| `novabank-auth-service` | Login, registration, profiles, customer admin. Db2 schema `NB_AUTH` | 8081 |
| `novabank-account-service` | Accounts and balances, the only writer of money. Schema `NB_ACCT` | 8082 |
| `novabank-transaction-service` | Transfers, deposits, history, monitoring. Schema `NB_TXN` | 8083 |
| `novabank-platform` | This repo | |

```
 Browser ──> novabank-ui (nginx) ──/api──> api-gateway ──┬──> auth-service ─────────┐
                                                          ├──> account-service ──────┤──> IBM Db2 (NOVABANK)
                                                          └──> transaction-service ──┘    NB_AUTH, NB_ACCT, NB_TXN
                         auth ──/internal──> account <──/internal── transaction
```

* Java 21, Spring Boot 3.5, Spring Security resource server (HS256 JWT), Spring Data JPA on Db2,
  Spring Cloud Gateway, springdoc OpenAPI, virtual threads.
* Each service owns one Db2 schema and never reads another's tables. Service to service calls go
  through `/internal/**` endpoints guarded by a shared key and never routed by the gateway.
* Transfers are idempotent (`Idempotency-Key` header + unique index), lock both account rows in a
  fixed order, and are guarded by `@Version` and a Db2 `CHECK (BALANCE >= 0)`.

## Run it on your laptop (one command)

Needs only Docker Desktop (6 GB+ memory). No JDK, Maven or Node required for this path.

```bash
# all six repo folders side by side in one parent folder, then:
cd novabank-platform
./dev.sh up          # Windows: double-click dev.cmd, or .\dev.ps1 up
```

First start builds the images and initializes Db2 (3 to 6 minutes). Then:

| | |
|---|---|
| UI | http://localhost:4200 |
| Customer | `john.carter@example.com` / `Password@123` |
| Admin | `admin@novabank.dev` / `Admin@123` |
| Gateway | http://localhost:8080 |
| Swagger | http://localhost:8081/swagger-ui.html, :8082, :8083 |
| Db2 | `localhost:50000`, database `NOVABANK`, user `db2inst1`, password in `.env` |

Other commands: `./dev.sh db` (Db2 only, for IDE work), `status`, `logs <service>`, `down`, `reset`.

## Run it in the cloud, anytime, from any machine (one click)

The Codespaces badge above opens a cloud dev machine (4 cores, 16 GB) with Java 21, Maven,
Node 22, Docker and the Claude Code CLI. It clones the five other repos and runs `./dev.sh up`
by itself; the UI opens in your browser when it is ready. Stop the Codespace when you are done
(GitHub's free monthly hours cover casual use). You can also connect to it from IntelliJ through
JetBrains Gateway.

Requires the repos to be on GitHub under your account: run
`./novabank-platform/scripts/create-github-repos.sh` once from the parent folder. It creates the
six repos, pushes `main` and `develop`, and fills your username into the badge and dev container.

## Sample database

`db2/schema/01-schema.sql` creates the three schemas, tables, indexes, check constraints and the
`V_DAILY_VOLUME` view. `02-sample-data.sql` loads 8 users (2 admins, 6 customers, one of them
locked), 10 accounts (one frozen) and 72 transactions with timestamps relative to load time, so
the dashboards always show recent activity. Balances equal the sum of the loaded transactions.

Loading into your own Db2 instead of Docker:

```bash
db2 create database NOVABANK
db2 connect to NOVABANK
db2 -tvf db2/schema/01-schema.sql
db2 -tvf db2/schema/02-sample-data.sql
```

## Environments

| | local | dev | preprod |
|---|---|---|---|
| Runs on | Docker Compose / IntelliJ | Cloud Run + Db2 VM | Cloud Run + Db2 VM |
| Spring profile | `local` | `dev` | `preprod` |
| Config | `application-local.yml` | `application-dev.yml` + `deploy/environments/dev.yaml` | `application-preprod.yml` + `deploy/environments/preprod.yaml` |
| Secrets | `.env` (throwaway values) | Secret Manager `novabank-dev-*` | Secret Manager `novabank-preprod-*` |
| Swagger UI | on | on | off |
| Logging | DEBUG | DEBUG | INFO |
| Db2 | container | VM `novabank-db2-dev`, 10.10.0.10 | VM `novabank-db2-preprod`, 10.20.0.10 |
| Scale | 1 | 0 to 2 per service | 0 to 4 per service |
| Deployed by | `./dev.sh up` | push to `develop` | push to `release/*` |

Every service repo carries its own Cloud Run definitions in `deploy/environments/dev.yaml` and
`preprod.yaml`, and a `cloudbuild.yaml` that tests, builds, pushes and deploys them.

## Deploy to GCP

You need the gcloud CLI, a project with billing enabled, and Owner or Editor on it.

```bash
export PROJECT_ID=your-project-id REGION=us-central1
gcloud auth login

./gcp/bootstrap.sh dev        # APIs, Artifact Registry, VPC, secrets, IAM, Db2 VM. Safe to re-run.
./gcp/deploy-all.sh dev       # Cloud Build: test, build, deploy all five services

./gcp/bootstrap.sh preprod
./gcp/deploy-all.sh preprod
```

The Db2 VM needs about 10 minutes on first boot. Check it with
`gcloud compute ssh novabank-db2-dev --zone us-central1-a --tunnel-through-iap -- sudo docker logs -f novabank-db2`.

Continuous delivery: connect GitHub to Cloud Build once in the console (Cloud Build > Triggers >
Connect repository), then `GITHUB_USER=<you> ./gcp/create-triggers.sh`.

**How it fits together on GCP**: Cloud Run services reach Db2 on the VM's private IP through
Direct VPC egress (no connector to pay for). Db2 has no public port: the firewall only allows
50000 from the environment's own subnet. The UI's nginx proxies `/api` to the gateway, so the
browser makes same-origin calls only.

**Cost**: Cloud Run scales to zero, so idle services cost nothing. Each Db2 VM (e2-standard-2)
is the main cost while running; stop it when idle:
`./gcp/env-control.sh stop preprod` and `start preprod` later.

**Hardening ideas** (left out to keep setup simple): make the backend services
`ingress: internal` and route the gateway through the VPC; use Cloud Armor in front of the UI;
move Db2 to a managed IBM Db2 offering; replace the shared JWT secret with RS256 keys.

## API testing

`api/postman/` has the collection (33 requests with tests) and environments for local, dev and
preprod. It imports into Hoppscotch too. Details in `docs/intellij-and-claude-code.md`.

## IDE and Claude Code

See [docs/intellij-and-claude-code.md](docs/intellij-and-claude-code.md): opening all repos in
IntelliJ, run configurations, Db2 in the Database tool window, and Claude Code with your Pro
plan through the JetBrains plugin.

## Known gaps worth building next

* A reconciliation job for transfers left `PENDING` when account-service was unreachable.
* Testcontainers integration tests against Db2 (unit tests cover the money logic today).
* Beneficiaries (saved payees) and scheduled transfers.
* Audit trail table for admin actions.
