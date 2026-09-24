# PostgreSQL on EC2 (containerized)

Production Postgres runs as the `db` service in
[docker-compose.production.yml](../docker-compose.production.yml), replacing the
RDS `db.t4g.micro` instance. Jira: GS-1.

Data lives on a **dedicated EBS volume bind-mounted at `/mnt/pgdata`**, not in a
Docker named volume. That matters for two reasons: the volume survives instance
termination, and no `docker volume` command can reach it.

Four databases:

| Database | Purpose |
| --- | --- |
| `givingshelf_prod` | Primary (created by the container from `POSTGRES_DB`) |
| `givingshelf_production_cache` | Solid Cache |
| `givingshelf_production_queue` | Solid Queue |
| `givingshelf_production_cable` | Solid Cable |

---

## 1. Host setup (one time, before cutover)

### 1.1 Dedicated EBS volume

Highest-value step here. It isolates the database from Docker's disk churn and
is what turns instance recovery from hours into minutes.

In the AWS console: **EC2 -> Volumes -> Create volume**

- 10 GiB, gp3
- **Same Availability Zone as the instance** (volumes cannot attach across AZs)
- **Encryption enabled** -- this can only be set at creation; retrofitting needs
  a snapshot-and-copy cycle
- Tags: `Name=givingshelf-pgdata`, `Backup=daily`

Attach it to the instance as `/dev/sdf`, then confirm **DeleteOnTermination is
false** on the attachment. Volumes attached after launch default to false, which
is what you want, but verify it -- this is the property that survives an
accidental instance termination.

On the instance:

```bash
lsblk                                  # confirm the device, likely nvme1n1
sudo mkfs.ext4 /dev/nvme1n1
sudo mkdir -p /mnt/pgdata
sudo blkid /dev/nvme1n1                # copy the UUID

# Mount by UUID, never by device name: NVMe names can shift across reboots.
# nofail so a missing volume never blocks boot.
echo 'UUID=<uuid>  /mnt/pgdata  ext4  defaults,nofail  0  2' | sudo tee -a /etc/fstab
sudo mount -a
findmnt /mnt/pgdata                    # must show the volume

# 999:999 is the postgres user inside the official image.
sudo mkdir -p /mnt/pgdata/pgdata
sudo chown -R 999:999 /mnt/pgdata/pgdata
sudo chmod 700 /mnt/pgdata/pgdata
```

**Reboot once now** and re-run `findmnt /mnt/pgdata`. Finding a broken fstab
entry before the database is live is much cheaper than after.

### 1.2 Swap

`t4g.small` has 2 GB, now shared between Puma, Solid Queue, Redis, nginx and
Postgres. Put swap on the root volume, not the data volume.

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
free -h
```

### 1.3 Backup bucket

**S3 -> Create bucket**

- Name `givingshelf-db-backups`, region `us-west-2`
- Block all public access: ON (the default)
- Default encryption: SSE-S3
- Lifecycle rule: expire current versions after 30 days; abort incomplete
  multipart uploads after 7 days

### 1.4 IAM

[config/storage.yml](../config/storage.yml) `amazon_production` sets no
credentials, so the instance already uses its IAM role for S3. Find that role
under **EC2 -> your instance -> Security -> IAM Role** and attach this inline
policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GivingshelfDbBackups",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::givingshelf-db-backups",
        "arn:aws:s3:::givingshelf-db-backups/*"
      ]
    }
  ]
}
```

### 1.5 EBS snapshots

A machine-level restore point that still works if the `pg_dump` cron has
silently broken. Snapshots are incremental, so ongoing cost is small.

**EC2 -> Lifecycle Manager -> Create snapshot lifecycle policy**

- Target volumes by tag `Backup=daily` -- daily schedule, retain 7
- Tag the root volume `Backup=weekly` and add a second policy -- weekly, retain
  4. The root is mostly static Docker images, so daily buys little.
- Enable "Copy tags from source"

Caveat worth internalizing: an EBS snapshot of a running database is equivalent
to pulling the power cord. Postgres recovers via WAL replay on start, which is
reliable, but it is a weaker guarantee than the `pg_dump` output. That is why
both exist.

### 1.6 Secrets

In Secrets Manager, secret `givingshelf/prod/env`:

| Key | Value |
| --- | --- |
| `DATABASE_URL` | `postgresql://gs_user:<password>@db:5432/givingshelf_prod` |
| `DATABASE_SSLMODE` | `disable` |
| `POSTGRES_USER` | `gs_user` |
| `POSTGRES_PASSWORD` | `<password>` |
| `POSTGRES_DB` | `givingshelf_prod` |

`POSTGRES_*` are read by the postgres image **only on first initialization of an
empty data directory**. Changing them later does nothing, so get the password
right the first time.

`DATABASE_SSLMODE=disable` is required because the container serves no TLS.
[config/database.yml](../config/database.yml) defaults to `require` when the
variable is unset, so a managed endpoint is never silently downgraded.

The old `POSTGRES_*`-free, RDS-era entries can be removed once cutover is done.

---

## 2. Cutover from RDS

Sequenced so the data migration happens under direct observation rather than
inside an auto-triggered deploy. The deploy workflow fires on CI success against
`main`, so the branch merge is **last**, after the data is already in place.

```bash
cd /home/ubuntu/givingshelf
RDS_HOST=givingshelf-prod.xxxxx.us-west-2.rds.amazonaws.com
mkdir -p /home/ubuntu/db-migration
```

**1. Dump RDS while it is still healthy.** App still running.

```bash
for db in givingshelf_prod givingshelf_production_cache \
          givingshelf_production_queue givingshelf_production_cable; do
  docker run --rm -e PGPASSWORD="$RDS_PW" -v /home/ubuntu/db-migration:/dumps \
    postgres:17.6 pg_dump -Fc -h "$RDS_HOST" -U gs_admin -d "$db" -f "/dumps/$db.dump"
done

# Verify every dump is readable BEFORE going further.
for f in /home/ubuntu/db-migration/*.dump; do
  docker run --rm -v /home/ubuntu/db-migration:/dumps postgres:17.6 \
    pg_restore --list "/dumps/$(basename "$f")" > /dev/null && echo "OK $f"
done

aws s3 cp /home/ubuntu/db-migration/ s3://givingshelf-db-backups/rds-cutover/ --recursive
```

Also record the row counts you will check against later, and the collation:

```bash
docker run --rm -e PGPASSWORD="$RDS_PW" postgres:17.6 \
  psql -h "$RDS_HOST" -U gs_admin -d givingshelf_prod -c \
  "SELECT 'users' t, count(*) FROM users
   UNION ALL SELECT 'items', count(*) FROM items
   UNION ALL SELECT 'item_requests', count(*) FROM item_requests
   UNION ALL SELECT 'community_groups', count(*) FROM community_groups
   UNION ALL SELECT 'messages', count(*) FROM messages;"

docker run --rm -e PGPASSWORD="$RDS_PW" postgres:17.6 \
  psql -h "$RDS_HOST" -U gs_admin -d givingshelf_prod -c \
  "SELECT datcollate, datctype FROM pg_database WHERE datname = current_database();"
```

**2. Check out the branch on EC2.** Do this before maintenance mode — the flag
file path, `maintenance.html`, and nginx `if (-f)` logic only exist on this
branch. Matches how the deploy script already manipulates the working tree.

```bash
git fetch origin && git checkout feat/gs-1-postgres-in-docker

# Recreate nginx so it picks up the updated conf and maintenance volume mount.
docker compose -f docker-compose.production.yml up -d nginx
```

**3. Maintenance on.**

```bash
touch deploy/nginx/maintenance/on
curl -sI https://givingshelf.net | head -n1          # expect 503
curl -s  https://givingshelf.net/healthz             # expect ok
```

**4. Stop writers**, then re-dump the primary to catch anything written since
step 1.

```bash
docker compose -f docker-compose.production.yml stop web worker

docker run --rm -e PGPASSWORD="$RDS_PW" -v /home/ubuntu/db-migration:/dumps \
  postgres:17.6 pg_dump -Fc -h "$RDS_HOST" -U gs_admin -d givingshelf_prod \
  -f /dumps/givingshelf_prod.dump
```

**5. Save the secrets** from 1.6, then materialize them.

```bash
sudo /usr/local/bin/fetch-givingshelf-secrets.sh
rm -f .env && ln -s /etc/givingshelf/.env.production .env
# fetch script leaves the file mode 600 (root only). Compose runs as ubuntu
# and must read it — same chmod the deploy workflow applies.
sudo chmod 644 /etc/givingshelf/.env.production
```

**6. Confirm the volume is mounted and ready.**

```bash
findmnt /mnt/pgdata                    # must show the volume
ls -la /mnt/pgdata/pgdata              # empty, owned by 999:999
```

If Postgres initializes against an unmounted path it silently writes to the root
volume instead, and you will not notice until the disk fills.

**7. Start Postgres alone**, wait for health, create the three extra databases.

```bash
docker compose -f docker-compose.production.yml up -d db
docker inspect --format '{{.State.Health.Status}}' givingshelf-db   # healthy
docker exec -i givingshelf-db psql -v ON_ERROR_STOP=1 -U gs_user \
  -d givingshelf_prod < deploy/rds-setup.sql
```

**8. Compare collation before trusting the restore.** Postgres 15+ removed
`SHOW lc_collate` / `SHOW lc_ctype`; read them from `pg_database` instead.

```bash
docker exec givingshelf-db psql -U gs_user -d givingshelf_prod -c \
  "SELECT datcollate, datctype FROM pg_database WHERE datname = current_database();"
```

If these differ from what RDS reported in step 1, text indexes will sort
differently and you get subtle wrong-result bugs rather than a clean error.
Resolve it now: wipe `/mnt/pgdata/pgdata` and recreate with matching
`POSTGRES_INITDB_ARGS="--lc-collate=<value> --lc-ctype=<value>"` before the
first init (only works on an empty data directory).

**9. Restore all four.**

```bash
./deploy/restore-db.sh --source /home/ubuntu/db-migration
```

**10. Spot-check** the same five row counts from step 1.

**11. Rebuild the app image and bring the stack up.** Checking out the branch
only updates files on the host; `config/database.yml` (and the rest of the app)
are baked into `givingshelf-web` at build time. Without a rebuild, Rails still
runs the pre-migration image (`sslmode: require`, no local-db changes).

```bash
docker compose -f docker-compose.production.yml build web
docker compose -f docker-compose.production.yml up -d
# Nginx resolves `web` to an IP at start and caches it. Recreate nginx after
# web gets a new container IP, or you get 502 Connection refused to the old one.
docker compose -f docker-compose.production.yml up -d --force-recreate nginx
docker compose -f docker-compose.production.yml exec web \
  bundle exec rails db:migrate:status
```

`db:migrate:status` is the pre-flight check while the public site can stay on
the maintenance page. Browser smoke testing needs the next step.

**12. Maintenance off**, then smoke-test in the browser. Nginx checks the flag
file on every request — no reload needed. The site is public again here; if
something is wrong, `touch deploy/nginx/maintenance/on` to put the page back.

```bash
rm deploy/nginx/maintenance/on
curl -sI https://givingshelf.net | head -n1   # expect 200, not 503
```

Create a test item, confirm a background job runs, confirm Action Cable chat
connects.

**13. Merge to `main`.** The auto-deploy reapplies the same code, re-fetches
secrets, rebuilds, runs a no-op `db:prepare`, and restarts. Data persists on the
mounted volume. This is the real test that the pipeline matches the new topology.

**14. Reboot deliberately.** Confirm the volume remounts from fstab,
`givingshelf.service` brings the stack back, and Postgres starts cleanly against
the existing data directory.

---

## 3. Backups

```bash
./deploy/backup-db.sh                                    # run once by hand
crontab -e
# 0 3 * * * cd /home/ubuntu/givingshelf && ./deploy/backup-db.sh >> /var/log/db-backup.log 2>&1
```

**Then test the restore, the same day.** An untested backup is a guess:

```bash
./deploy/restore-db.sh --date "$(date -u +%Y/%m/%d)" --suffix _verify
docker exec -it givingshelf-db psql -U gs_user -d givingshelf_prod_verify \
  -c 'SELECT count(*) FROM users;'
# then drop the copies
```

Repeat this drill quarterly. Silent backup failure is the main way this
architecture bites you, so alarm on object freshness in
`s3://givingshelf-db-backups/` rather than trusting cron.

---

## 4. Recovery runbook

**Postgres will not start.** Check `docker logs givingshelf-db` first. Most
likely causes, in order: `/mnt/pgdata` not mounted (`findmnt`), wrong ownership
on `pgdata` (must be `999:999`), or an image tag that moved to a new major
version (must stay `postgres:17.6`).

**Data directory corrupt.** Restore from the most recent S3 dump:

```bash
docker compose -f docker-compose.production.yml stop web worker
./deploy/restore-db.sh --date YYYY/MM/DD
docker compose -f docker-compose.production.yml up -d
```

**Instance lost entirely.** This is the path the dedicated volume exists for:

1. Launch a replacement `t4g.small` in the same AZ, Ubuntu 22.04, same security
   group and IAM role. See
   [aws_prod_deploy_setup_steps.md](aws_prod_deploy_setup_steps.md) phase 2.
2. Install Docker, clone the repo to `/home/ubuntu/givingshelf`.
3. **Attach the existing `givingshelf-pgdata` volume** -- or, if it was lost too,
   restore its latest DLM snapshot to a new volume and attach that. Mount at
   `/mnt/pgdata` per section 1.1. Do not reformat it.
4. Add swap (1.2), fetch secrets, symlink `.env`.
5. `docker compose -f docker-compose.production.yml up -d`
6. Reattach the Elastic IP or update DNS; reissue certs if needed.

Expected recovery: minutes if the volume survived, closer to an hour if
restoring from snapshot, and up to a day of lost writes only if you fall all the
way back to an S3 dump.

---

## 5. Operational notes

- **Never** run `docker compose down -v` or `docker system prune --volumes`.
  The bind mount protects the database, but `redis_data` and `rails_storage` are
  still named volumes. The `--volumes` flag was removed from the deploy
  workflow's disk-pressure cleanup for this reason.
- Minor version upgrades are now ours to schedule. Bump the pinned tag in the
  compose file and restart; within a major version the on-disk format is
  compatible. A **major** upgrade needs `pg_upgrade` or a dump/restore, and the
  container will refuse to start otherwise.
- Watch `mem_used_percent` and `disk_used_percent` for `/mnt/pgdata` in
  CloudWatch. `web` and `worker` carry `mem_limit` so a Rails leak makes Rails
  the OOM victim rather than Postgres; a killed Postgres backend restarts every
  backend and drops all connections.
- Recovery point is **nightly, not point-in-time**. RDS offered any-second
  recovery. Closing that gap means WAL archiving to S3 with pgBackRest or wal-g
  -- worth doing once real users depend on the data.

---

## 6. Decommissioning RDS

Leave RDS running and untouched for about a week as the rollback path. Rolling
back is reverting `DATABASE_URL` to the RDS endpoint and setting
`DATABASE_SSLMODE=require`.

Once satisfied:

1. **RDS -> `givingshelf-prod` -> Actions -> Delete**, taking a final snapshot
   named `givingshelf-prod-final-<date>`
2. Delete that snapshot after a few weeks (snapshot storage bills at about
   $0.095/GB of actual data)
3. Delete the now-unused `givingshelf-rds-sg` security group
4. Confirm the Relational Database Service line is gone from the next invoice

Do **not** just stop the instance. A stopped RDS instance still bills for all
40 GiB of storage and auto-restarts after 7 days.
