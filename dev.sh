#!/usr/bin/env bash
# NovaBank one-command developer environment.
#
#   ./dev.sh up        build and start everything (Db2, services, gateway, UI)
#   ./dev.sh db        start only Db2 (run the services from IntelliJ)
#   ./dev.sh status    show containers and health
#   ./dev.sh logs [s]  follow logs (all or one service, e.g. logs transaction-service)
#   ./dev.sh down      stop everything, keep data
#   ./dev.sh reset     stop everything and wipe Db2 (sample data reloads next start)
#   ./dev.sh clone     clone the sibling repos from GitHub (needs GITHUB_USER)
set -euo pipefail
cd "$(dirname "$0")"

REPOS=(novabank-auth-service novabank-account-service novabank-transaction-service novabank-api-gateway novabank-ui)
c_green='\033[0;32m'; c_yellow='\033[0;33m'; c_red='\033[0;31m'; c_off='\033[0m'
say()  { printf "${c_green}==>${c_off} %s\n" "$*"; }
warn() { printf "${c_yellow}==>${c_off} %s\n" "$*"; }
die()  { printf "${c_red}==>${c_off} %s\n" "$*" >&2; exit 1; }

compose() { docker compose "$@"; }

preflight() {
  command -v docker >/dev/null || die "Docker is not installed. Install Docker Desktop first."
  docker info >/dev/null 2>&1 || die "Docker is not running. Start Docker Desktop and try again."
  [ -f .env ] || { cp .env.example .env; say "Created .env from .env.example"; }
}

check_repos() {
  local missing=()
  for r in "${REPOS[@]}"; do [ -d "../$r" ] || missing+=("$r"); done
  if [ ${#missing[@]} -gt 0 ]; then
    die "Missing sibling repos: ${missing[*]}. Put all six repos in one folder, or run: GITHUB_USER=<you> ./dev.sh clone"
  fi
}

wait_healthy() {
  local svc=$1 timeout=${2:-900} waited=0
  printf "    waiting for %s " "$svc"
  while true; do
    local state
    state=$(docker inspect -f '{{.State.Health.Status}}' "$(compose ps -q "$svc")" 2>/dev/null || echo starting)
    [ "$state" = "healthy" ] && { printf " ready\n"; return 0; }
    [ $waited -ge "$timeout" ] && { printf "\n"; die "$svc did not become healthy. Check: ./dev.sh logs $svc"; }
    printf "."; sleep 5; waited=$((waited + 5))
  done
}

banner() {
  cat <<TXT

  NovaBank is running
  -------------------------------------------------------------
  UI               http://localhost:4200
  API gateway      http://localhost:8080
  Swagger          http://localhost:8081/swagger-ui.html  (auth)
                   http://localhost:8082/swagger-ui.html  (account)
                   http://localhost:8083/swagger-ui.html  (transaction)
  Db2              localhost:50000  db NOVABANK  user db2inst1  password in .env

  Customer login   john.carter@example.com / Password@123
  Admin login      admin@novabank.dev / Admin@123
  -------------------------------------------------------------
TXT
}

cmd=${1:-up}
case "$cmd" in
  up)
    preflight; check_repos
    say "Building images and starting NovaBank (first Db2 start takes 3 to 6 minutes)"
    compose up -d --build
    wait_healthy db2 900
    for s in account-service auth-service transaction-service api-gateway; do wait_healthy "$s" 300; done
    banner
    ;;
  db)
    preflight
    say "Starting Db2 only"
    compose up -d --build db2
    wait_healthy db2 900
    say "Db2 is ready on localhost:50000. Start the services from IntelliJ with the 'local' profile."
    ;;
  status) compose ps ;;
  logs)   shift; compose logs -f --tail=200 "$@" ;;
  down)   compose down; say "Stopped. Data kept in the db2data volume." ;;
  reset)
    read -r -p "This deletes all Db2 data. Type yes to continue: " ok
    [ "$ok" = "yes" ] || die "Cancelled."
    compose down -v; say "Wiped. The sample data loads again on the next ./dev.sh up."
    ;;
  clone)
    [ -n "${GITHUB_USER:-}" ] || die "Set GITHUB_USER, e.g. GITHUB_USER=your-name ./dev.sh clone"
    for r in "${REPOS[@]}"; do
      if [ -d "../$r" ]; then warn "$r already present"; else git clone "https://github.com/$GITHUB_USER/$r.git" "../$r"; fi
    done
    ;;
  *) sed -n '2,12p' "$0"; exit 1 ;;
esac
