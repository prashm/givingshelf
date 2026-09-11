#!/usr/bin/env bash
#
# Nightly logical backup of all four production databases to S3.
#
# Replaces RDS automated backups after the move to a containerized Postgres.
# Recovery point is nightly, not point-in-time -- see deploy/POSTGRES_ON_EC2.md.
#
# Usage (from the repo root on EC2):
#   ./deploy/backup-db.sh
#
# Cron:
#   0 3 * * * cd /home/ubuntu/givingshelf && ./deploy/backup-db.sh >> /var/log/db-backup.log 2>&1
#
# Exits non-zero on any failure so cron surfaces it. A silent backup failure is
# the main way this architecture bites you, so also alarm on object freshness.

set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.production.yml}"
DB_CONTAINER="${DB_CONTAINER:-givingshelf-db}"
S3_BUCKET="${DB_BACKUP_BUCKET:-givingshelf-db-backups}"
AWS_REGION="${AWS_REGION:-us-west-2}"
LOCAL_DIR="${DB_BACKUP_DIR:-/tmp/givingshelf-db-backup}"
# Keep dumps on disk briefly so a failed upload is still recoverable by hand.
LOCAL_RETENTION_DAYS="${DB_BACKUP_LOCAL_RETENTION_DAYS:-2}"

DATABASES=(
  givingshelf_prod
  givingshelf_production_cache
  givingshelf_production_queue
  givingshelf_production_cable
)

log() { printf '%s  %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"; }
die() { log "ERROR: $*"; exit 1; }

command -v aws >/dev/null 2>&1 || die "aws CLI not found on PATH"
command -v docker >/dev/null 2>&1 || die "docker not found on PATH"

# Read POSTGRES_USER from the same .env the containers use, so the credentials
# never appear in this script, in cron, or in the process list.
[ -r .env ] || die ".env not readable from $(pwd); run this from the repo root"
# shellcheck disable=SC1091
POSTGRES_USER="$(grep -E '^POSTGRES_USER=' .env | head -n1 | cut -d= -f2-)"
[ -n "${POSTGRES_USER}" ] || die "POSTGRES_USER not set in .env"

docker ps --format '{{.Names}}' | grep -qx "${DB_CONTAINER}" \
  || die "container ${DB_CONTAINER} is not running; nothing to back up"

STAMP="$(date -u '+%Y-%m-%dT%H%M%SZ')"
S3_PREFIX="$(date -u '+%Y/%m/%d')"
mkdir -p "${LOCAL_DIR}"

log "Starting backup ${STAMP} -> s3://${S3_BUCKET}/${S3_PREFIX}/"

failed=0
for db in "${DATABASES[@]}"; do
  dump="${LOCAL_DIR}/${db}-${STAMP}.dump.gz"

  # -Fc is the custom format: compressed, and restorable selectively via
  # pg_restore. Piped straight out of the container so no dump ever lands
  # inside it.
  if ! docker exec "${DB_CONTAINER}" \
        pg_dump -Fc -U "${POSTGRES_USER}" -d "${db}" 2>/dev/null | gzip -c > "${dump}"; then
    log "FAILED to dump ${db}"
    rm -f "${dump}"
    failed=1
    continue
  fi

  # A pg_dump that produced nothing useful is worse than an obvious failure.
  size=$(wc -c < "${dump}")
  if [ "${size}" -lt 1024 ]; then
    log "FAILED: dump of ${db} is only ${size} bytes, refusing to upload"
    rm -f "${dump}"
    failed=1
    continue
  fi

  if ! aws s3 cp "${dump}" "s3://${S3_BUCKET}/${S3_PREFIX}/${db}-${STAMP}.dump.gz" \
        --region "${AWS_REGION}" --only-show-errors; then
    log "FAILED to upload ${db} (dump kept at ${dump})"
    failed=1
    continue
  fi

  log "OK ${db} (${size} bytes)"
done

find "${LOCAL_DIR}" -name '*.dump.gz' -mtime "+${LOCAL_RETENTION_DAYS}" -delete 2>/dev/null || true

[ "${failed}" -eq 0 ] || die "one or more databases failed to back up"

log "Backup ${STAMP} complete"
