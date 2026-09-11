#!/usr/bin/env bash
#
# Restore the four production databases from an S3 backup taken by backup-db.sh.
#
# Also used for the initial RDS cutover, by pointing --source at the local
# directory holding the pg_dump output from RDS.
#
# Usage:
#   ./deploy/restore-db.sh --date 2026/09/12                 # from S3
#   ./deploy/restore-db.sh --source /home/ubuntu/db-migration # from local dumps
#   ./deploy/restore-db.sh --date 2026/09/12 --suffix _verify # restore-test copy
#
# --suffix restores into copies (e.g. givingshelf_prod_verify) instead of the
# live databases. Use it for the periodic restore drill: an untested backup is a
# guess, not a backup.
#
# Without --suffix this DESTROYS the current contents of all four databases.
# It prompts once unless FORCE=1.

set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.production.yml}"
DB_CONTAINER="${DB_CONTAINER:-givingshelf-db}"
S3_BUCKET="${DB_BACKUP_BUCKET:-givingshelf-db-backups}"
AWS_REGION="${AWS_REGION:-us-west-2}"
WORK_DIR="${DB_RESTORE_DIR:-/tmp/givingshelf-db-restore}"

DATABASES=(
  givingshelf_prod
  givingshelf_production_cache
  givingshelf_production_queue
  givingshelf_production_cable
)

BACKUP_DATE=""
SOURCE_DIR=""
SUFFIX=""

log() { printf '%s  %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"; }
die() { log "ERROR: $*"; exit 1; }

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-1}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --date)   BACKUP_DATE="${2:-}"; shift 2 ;;
    --source) SOURCE_DIR="${2:-}"; shift 2 ;;
    --suffix) SUFFIX="${2:-}"; shift 2 ;;
    -h|--help) usage 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

[ -n "${BACKUP_DATE}" ] || [ -n "${SOURCE_DIR}" ] || usage 1
[ -z "${BACKUP_DATE}" ] || [ -z "${SOURCE_DIR}" ] || die "pass either --date or --source, not both"

command -v docker >/dev/null 2>&1 || die "docker not found on PATH"

[ -r .env ] || die ".env not readable from $(pwd); run this from the repo root"
POSTGRES_USER="$(grep -E '^POSTGRES_USER=' .env | head -n1 | cut -d= -f2-)"
[ -n "${POSTGRES_USER}" ] || die "POSTGRES_USER not set in .env"

docker ps --format '{{.Names}}' | grep -qx "${DB_CONTAINER}" \
  || die "container ${DB_CONTAINER} is not running"

# Pull from S3 unless we were handed a local directory.
if [ -n "${BACKUP_DATE}" ]; then
  command -v aws >/dev/null 2>&1 || die "aws CLI not found on PATH"
  SOURCE_DIR="${WORK_DIR}/${BACKUP_DATE//\//-}"
  mkdir -p "${SOURCE_DIR}"
  log "Fetching s3://${S3_BUCKET}/${BACKUP_DATE}/ -> ${SOURCE_DIR}"
  aws s3 cp "s3://${S3_BUCKET}/${BACKUP_DATE}/" "${SOURCE_DIR}/" \
    --recursive --region "${AWS_REGION}" --only-show-errors \
    || die "failed to fetch backups for ${BACKUP_DATE}"
fi

[ -d "${SOURCE_DIR}" ] || die "source directory ${SOURCE_DIR} does not exist"

if [ -z "${SUFFIX}" ] && [ "${FORCE:-0}" != "1" ]; then
  printf 'This will OVERWRITE all four live databases from %s.\nType "restore" to continue: ' "${SOURCE_DIR}"
  read -r reply
  [ "${reply}" = "restore" ] || die "aborted"
fi

psql_do() {
  docker exec -i "${DB_CONTAINER}" psql -v ON_ERROR_STOP=1 -U "${POSTGRES_USER}" "$@"
}

for db in "${DATABASES[@]}"; do
  target="${db}${SUFFIX}"

  # Newest matching dump wins, so the caller does not have to know timestamps.
  dump=$(find "${SOURCE_DIR}" -maxdepth 1 -name "${db}-*.dump.gz" -o -maxdepth 1 -name "${db}.dump*" \
         | sort | tail -n1)
  [ -n "${dump}" ] || die "no dump found for ${db} in ${SOURCE_DIR}"

  log "Restoring ${dump##*/} -> ${target}"

  # CREATE DATABASE cannot run inside a transaction block, so this is its own
  # call against the maintenance database.
  psql_do -d postgres -c "SELECT 1 FROM pg_database WHERE datname = '${target}'" \
    | grep -q '1 row' || psql_do -d postgres -c "CREATE DATABASE ${target}"

  # --clean --if-exists drops objects before recreating, which is what makes
  # this safe to run against a database that already has a schema (for example
  # one that db:prepare just created).
  if [ "${dump##*.}" = "gz" ]; then
    gunzip -c "${dump}" | docker exec -i "${DB_CONTAINER}" \
      pg_restore --clean --if-exists --no-owner --no-acl \
        -U "${POSTGRES_USER}" -d "${target}"
  else
    docker exec -i "${DB_CONTAINER}" \
      pg_restore --clean --if-exists --no-owner --no-acl \
        -U "${POSTGRES_USER}" -d "${target}" < "${dump}"
  fi

  log "OK ${target}"
done

log "Restore complete. Verify row counts before trusting it:"
log "  docker exec -it ${DB_CONTAINER} psql -U ${POSTGRES_USER} -d givingshelf_prod${SUFFIX} \\"
log "    -c 'SELECT count(*) FROM users; SELECT count(*) FROM items;'"
