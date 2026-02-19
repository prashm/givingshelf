---
name: AWS Production Deployment
overview: Migrate the Givingshelf Rails app from single-EC2 Docker deployment to a scalable AWS architecture with RDS PostgreSQL, separate web/worker containers, and Redis—optimized for free tier with clear scaling paths.
todos: []
isProject: false
---

# AWS Production Deployment Plan

## Current State

Your app is a **Rails 8** application with:

- **PostgreSQL** (4 databases: primary, cache, queue, cable via Solid Cache/Queue/Cable)
- **Redis** (Action Cable + presence features)
- **Solid Queue** for background jobs (runs via `bin/jobs`)
- **Docker Compose** deployment to a single EC2 (34.208.25.211) with Postgres and Redis in containers

## Target Architecture

```mermaid
flowchart TB
    subgraph internet [Internet]
        Users
    end

    subgraph aws [AWS]
        subgraph ec2 [EC2 t3.micro - Free Tier]
            subgraph containers [Docker Containers]
                Web[Web - Puma]
                Worker[Worker - Solid Queue]
                Redis[Redis]
                Nginx[Nginx + Certbot]
            end
        end

        subgraph rds [RDS db.t3.micro - Free Tier]
            PG[(PostgreSQL)]
        end

        S3[S3 - Active Storage]
    end

    Users --> Nginx
    Nginx --> Web
    Web --> PG
    Web --> Redis
    Worker --> PG
    Worker --> Redis
    Web --> S3
```



**Free tier fit:** 1 EC2 (750 hrs) + 1 RDS (750 hrs) + S3 (5GB) stays within limits. Redis runs in Docker on EC2 to avoid ElastiCache costs.

---

## Phase 1: RDS PostgreSQL Setup (Step-by-Step)

### Step 1.1: Open RDS Console

1. Log in to [AWS Console](https://console.aws.amazon.com/)
2. Set region to **us-west-2** (Oregon) to match your S3 bucket
3. Go to **Services** → **Database** → **RDS**
4. Click **Create database**

### Step 1.2: Choose Database Creation Method

1. Select **Standard create** (not Easy create)
2. **Engine type:** PostgreSQL
3. **Engine version:** PostgreSQL 17.x (e.g. 17.6 - latest 17.x patch)
4. **Templates:** Select **Free tier**
5. Click **Next**

### Step 1.3: Settings

1. **DB instance identifier:** `givingshelf-prod`
2. **Master username:** `gs_admin`
3. **Master password:** Generate a strong password and store it securely (you will need it for `DATABASE_URL`)
4. **Confirm password:** Re-enter the password
5. Click **Next**

### Step 1.4: Instance Configuration

1. **DB instance class:** **Burstable classes** → `db.t3.micro` (or `db.t4g.micro` for ARM)
2. **Storage:**
  - **Storage type:** General Purpose SSD (gp2)
  - **Allocated storage:** 20 (free tier max)
  - **Storage autoscaling:** Uncheck (stay within free tier)
3. Click **Next**

### Step 1.5: Connectivity

1. **Compute resource:** Don't connect to an EC2 compute resource (we'll use security groups)
2. **Virtual private cloud (VPC):** Select the **same VPC** as your EC2 instance
  - To find EC2's VPC: EC2 Console → Instances → select your instance → look at "VPC ID" under Networking
3. **DB subnet group:** default (or the one for your VPC)
4. **Public access:** **No** (keep database private)
5. **VPC security group:** **Create new** → name it `givingshelf-rds-sg`
  - Or select existing and add inbound rule in next step
6. **Availability Zone:** No preference (or same AZ as EC2 for lower latency)
7. **Database authentication:** Password authentication
8. Click **Next**

### Step 1.6: Additional Configuration

1. **Initial database name:** `givingshelf_prod` (primary database)
2. **DB parameter group:** default.postgres17
3. **Backup:**
  - **Retention:** 7 days (or 1 to save space)
  - **Window:** Choose a low-traffic time
4. **Encryption:** Enable (recommended; no extra cost for storage encryption)
5. **Performance Insights:** Disable (not in free tier)
6. **Monitoring:** Disable Enhanced Monitoring (optional, costs extra)
7. Expand **Maintenance** → **Auto minor version upgrade:** Enable (recommended)
8. Click **Create database**

### Step 1.7: Configure RDS Security Group (Allow EC2 Access)

1. In RDS Console, click your new DB instance
2. Under **Connectivity & security**, click the **VPC security group** link
3. In the Security Group, go to **Inbound rules** → **Edit inbound rules**
4. **Add rule:**
  - **Type:** PostgreSQL
  - **Port:** 5432
  - **Source:** Custom → select the **security group of your EC2 instance**
  - **Description:** Allow EC2 app server
5. Click **Save rules**

### Step 1.8: Get RDS Endpoint

1. In RDS Console → **Databases** → click `givingshelf-prod`
2. Copy **Endpoint** (e.g. `givingshelf-prod.xxxxx.us-west-2.rds.amazonaws.com`)
3. Note the **Port** (5432)

### Step 1.9: Create Additional Databases (Cache, Queue, Cable)

RDS creates `givingshelf_prod` at launch. Create the other three databases (Rails expects these names in database.yml):

**Option A: Using psql from EC2**

1. SSH into your EC2 instance
2. Install PostgreSQL client if needed: `sudo apt install postgresql-client -y`
3. Connect (replace endpoint and password):

```bash
PGPASSWORD='YOUR_PASSWORD' psql -h givingshelf-prod.xxxxx.us-west-2.rds.amazonaws.com -U gs_admin -d givingshelf_prod
```

1. Run:

```sql
CREATE DATABASE givingshelf_production_cache;
CREATE DATABASE givingshelf_production_queue;
CREATE DATABASE givingshelf_production_cable;
\q
```

**Option B: Using Docker on EC2**

Use separate `-c` flags so each `CREATE DATABASE` runs outside a transaction block:

```bash
docker run --rm -e PGPASSWORD='YOUR_PASSWORD' postgres:17 psql -h givingshelf-prod.xxxxx.us-west-2.rds.amazonaws.com -U gs_admin -d givingshelf_prod -c "CREATE DATABASE givingshelf_production_cache;" -c "CREATE DATABASE givingshelf_production_queue;" -c "CREATE DATABASE givingshelf_production_cable;"
```

### Step 1.10: Build DATABASE_URL

Format:

```
postgresql://givingshelf_admin:YOUR_PASSWORD@givingshelf-production.xxxxx.us-west-2.rds.amazonaws.com:5432/givingshelf_production
```

URL-encode the password if it contains special characters (e.g. `@` → `%40`, `#` → `%23`).

---

## Phase 2: EC2 Setup (Step-by-Step)

*If you already have an EC2 instance (e.g. 34.208.25.211), skip to Step 2.6 to verify/update security groups and networking.*

### Step 2.1: Open EC2 Console

1. AWS Console → **Services** → **Compute** → **EC2**
2. Set region to **us-west-2** (same as RDS)
3. Click **Launch instance**

### Step 2.2: Name and Tags

1. **Name:** `givingshelf-app-server`
2. Click **Next**

### Step 2.3: Application and OS Images (AMI)

1. **Quick Start:** Ubuntu
2. **AMI:** Ubuntu Server 22.04 LTS
3. **Architecture:** 64-bit (x86) or 64-bit (Arm) for t4g
4. Click **Next**

### Step 2.4: Instance Type

1. Select **t3.micro** (or **t4g.micro** for ARM)
2. Free tier eligible
3. Click **Next**

### Step 2.5: Key Pair (Login)

1. **Key pair name:** Create new or select existing
2. If creating new: **Create new key pair** → name `givingshelf-key` → download `.pem` and store securely
3. Click **Next**

### Step 2.6: Network Settings

1. **VPC:** Same VPC as RDS (critical for connectivity)
2. **Subnet:** Any private or public subnet in that VPC
3. **Auto-assign public IP:** Enable (if no NAT; needed for SSH and inbound HTTP/HTTPS)
4. **Firewall (security group):** Create new or select existing
  - **Create new** → name `givingshelf-app-sg`
  - **Inbound rules:**
    - SSH (22): Your IP only (or 0.0.0.0/0 for testing only)
    - HTTP (80): 0.0.0.0/0
    - HTTPS (443): 0.0.0.0/0
5. Click **Next**

### Step 2.7: Configure Storage

1. **Volume:** 8–30 GB gp3 (free tier: 30 GB)
2. Click **Next**

### Step 2.8: Advanced Details (Optional)

1. **IAM instance profile:** Create/attach a role if you need S3, Secrets Manager, etc.
2. **User data:** Optional bootstrap script to install Docker on Ubuntu. If you skip this, install Docker manually via Step 2.10 after launch.
  Paste the entire script below into the **User data** field. **Reading the script:** Each line is one command. When a line contains `&&`, it runs two commands in sequence on that same line. Blank lines are ignored.

```bash
   #!/bin/bash
   apt-get update && apt-get install -y ca-certificates curl gnupg
   install -m 0755 -d /etc/apt/keyrings
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
   chmod a+r /etc/apt/keyrings/docker.gpg
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
   apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
   systemctl start docker && systemctl enable docker
   usermod -aG docker ubuntu
   

```

   **Line-by-line:** Line 2 = one command (update + install). Line 3 = one command. Lines 4–5 = two commands. Line 6 = one command. Line 7 = one command. Lines 8–9 = two commands.

1. Click **Launch instance**

### Step 2.9: Connect to EC2

1. EC2 Console → **Instances** → select your instance
2. Click **Connect** → **SSH client**
3. Use the shown command, e.g.:

```bash
ssh -i "givingshelf-key.pem" ec2-user@34.208.25.211
```

(Use `ubuntu@...` if you chose Ubuntu AMI.)

### Step 2.10: Install Docker on Ubuntu (if not in User Data)

Run these commands on your Ubuntu EC2. **Each block is one command** (run them in order):

Command 1 — Install prerequisites:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
```

Command 2 — Create keyrings directory:

```bash
sudo install -m 0755 -d /etc/apt/keyrings
```

Command 3 — Add Docker GPG key:

```bash
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

Command 4 — Add Docker repository:

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

Command 5 — Install Docker:

```bash
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Command 6 — Start Docker and add your user:

```bash
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu
```

Log out and SSH back in (or run `newgrp docker`), then verify: `docker run hello-world` and `docker compose version`.

### Step 2.11: GitHub Access for Initial Clone

Set up GitHub access so you can clone the repo on EC2. The deploy workflow later uses `git fetch` and `git reset`, so the repo must exist. Choose one method:

**Option A: SSH deploy key (recommended, read-only)**

1. On EC2, generate an SSH key for the ubuntu user:

```bash
ssh-keygen -t ed25519 -C "givingshelf-ec2" -f ~/.ssh/givingshelf_deploy -N ""
```

1. Display the public key and copy it:

```bash
cat ~/.ssh/givingshelf_deploy.pub
```

1. In GitHub: Repo → **Settings** → **Deploy keys** → **Add deploy key**
  - **Title:** `givingshelf-ec2` (or any name)
  - **Key:** Paste the public key
  - **Allow write access:** Uncheck (read-only is sufficient)
  - Click **Add key**
2. Configure SSH to use this key for GitHub and clone:

```bash
mkdir -p ~/.ssh
echo -e "Host github.com\n  HostName github.com\n  User git\n  IdentityFile ~/.ssh/givingshelf_deploy\n  IdentitiesOnly yes" >> ~/.ssh/config
chmod 600 ~/.ssh/config
ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts
git clone git@github.com:YOUR_ORG/givingshelf.git /home/ubuntu/givingshelf
```

Replace `YOUR_ORG` with your GitHub org or username.

**Option B: HTTPS with Personal Access Token (PAT)**

1. In GitHub: **Settings** → **Developer settings** → **Personal access tokens** → Generate a token with `repo` scope.
2. Clone (replace YOUR_TOKEN and YOUR_ORG):

```bash
git clone https://YOUR_TOKEN@github.com/YOUR_ORG/givingshelf.git /home/ubuntu/givingshelf
```

1. To avoid storing the token in the URL for future pulls, configure the credential helper or use `git config credential.helper store` after the first pull.

### Step 2.12: Deploy Application

1. `cd /home/ubuntu/givingshelf` (repo should already be cloned from Step 2.11)
2. Configure secrets (e.g. `/etc/givingshelf/.env.production` with `DATABASE_URL`, `REDIS_URL`, etc.)
3. Run `docker compose -f docker-compose.production.yml up -d`

### Step 2.13: Verify RDS Connectivity from EC2

```bash
# From EC2, test RDS connection
nc -zv givingshelf-production.xxxxx.us-west-2.rds.amazonaws.com 5432
# Or with psql
PGPASSWORD='xxx' psql -h givingshelf-production.xxxxx.us-west-2.rds.amazonaws.com -U givingshelf_admin -d givingshelf_production -c "SELECT 1;"
```

### Step 2.14: systemd Service (Auto-start on Reboot)

Ensure `docker compose up` runs on EC2 reboot. The unit file is in [deploy/givingshelf.service](deploy/givingshelf.service).

**Install and enable:**

```bash
# From EC2, after cloning repo to /home/ubuntu/givingshelf
sudo cp /home/ubuntu/givingshelf/deploy/givingshelf.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable givingshelf.service
sudo systemctl start givingshelf.service   # Starts containers now
```

**Verify:** `sudo systemctl status givingshelf.service`

The service runs `docker compose -f docker-compose.production.yml up -d` at boot (after Docker is ready). The deploy workflow uses `sudo systemctl restart givingshelf.service` after each deploy.

---

## Phase 2.5: HTTPS Setup on EC2 (Let's Encrypt)

Enable HTTPS using Let's Encrypt certificates. Nginx is already configured for SSL; you need to obtain certs and ensure renewal is scheduled. See [deploy/nginx/SSL_SETUP.md](deploy/nginx/SSL_SETUP.md) for full details.

### Step 2.5.1: Prerequisites

- DNS: `givingshelf.net` and `www.givingshelf.net` must resolve to your EC2 public IP
- Security group: Ports 80 and 443 open (Step 2.6)
- App running: Containers (including nginx) must be up

### Step 2.5.2: Point DNS to EC2

1. Get EC2 public IP: `curl -s http://169.254.169.254/latest/meta-data/public-ipv4` (from EC2) or AWS Console
2. In your DNS provider (e.g. Namecheap): Add A records `@` and `www` → EC2 IP
3. Wait 5–30 min for propagation. Verify: `dig givingshelf.net`

### Step 2.5.3: Create Dummy Certificates (Bootstrap)

Nginx needs certificate files to start on 443. Create self-signed placeholders first:

```bash
cd /home/ubuntu/givingshelf
sudo mkdir -p deploy/nginx/certbot/live/givingshelf.net
sudo openssl req -x509 -nodes -days 1 -newkey rsa:2048 \
  -keyout deploy/nginx/certbot/live/givingshelf.net/privkey.pem \
  -out deploy/nginx/certbot/live/givingshelf.net/fullchain.pem \
  -subj "/CN=givingshelf.net"
```

### Step 2.5.4: Start Containers (if not already running)

```bash
cd /home/ubuntu/givingshelf
docker compose -f docker-compose.production.yml up -d
```

### Step 2.5.5: Obtain Let's Encrypt Certificates

```bash
cd /home/ubuntu/givingshelf
docker compose -f docker-compose.production.yml --profile certbot run --rm certbot certonly \
  --webroot \
  -w /var/www/certbot \
  -d givingshelf.net \
  -d www.givingshelf.net \
  --email your-email@example.com \
  --agree-tos \
  --non-interactive
```

Replace `your-email@example.com` with your email. Certificates overwrite the dummy certs.

### Step 2.5.6: Reload Nginx

```bash
docker compose -f docker-compose.production.yml exec nginx nginx -s reload
```

### Step 2.5.7: Verify HTTPS

```bash
curl -I https://givingshelf.net
curl -I http://givingshelf.net   # Should 301 redirect to HTTPS
```

### Step 2.5.8: Set Up Automatic Certificate Renewal

Certificates expire in 90 days. Add a weekly renewal:

**Option A: Cron**
```bash
crontab -e
# Add:
0 3 * * 1 cd /home/ubuntu/givingshelf && ./deploy/nginx/renew-certificates.sh >> /var/log/certbot-renewal.log 2>&1
```

**Option B: systemd timer** (see [deploy/nginx/SSL_SETUP.md](deploy/nginx/SSL_SETUP.md) Step 8)

### Step 2.5.9: Test Renewal (Dry Run)

```bash
cd /home/ubuntu/givingshelf
docker compose -f docker-compose.production.yml --profile certbot run --rm certbot renew --dry-run
```

---

## Phase 3: Application Configuration Changes

### 2.1 Database SSL

RDS expects SSL. Update [config/database.yml](config/database.yml) production primary:

```yaml
# Change from:
sslmode: disable
# To:
sslmode: require
```

RDS uses AWS-managed certs; `require` is enough without custom CA.

### 2.2 Docker Compose

Modify [docker-compose.production.yml](docker-compose.production.yml):

- **Remove** the `db` service
- **Remove** `depends_on: db` from `web` and `worker`; they will use RDS via `DATABASE_URL`
- **Keep** `redis` (stays on EC2 for free tier)
- Ensure `DATABASE_URL` is passed via `.env` (from your secrets script)

**PostgreSQL 17 consistency:** If you use a separate `docker-compose` for local development with a Postgres service, update the image from `postgres:15` to `postgres:17` so dev and production match.

### 2.3 Environment Variables

Add to `.env.production` (or your secrets store):


| Variable       | Source                                                            |
| -------------- | ----------------------------------------------------------------- |
| `DATABASE_URL` | `postgresql://user:pass@rds-endpoint:5432/givingshelf_production` |
| `REDIS_URL`    | `redis://redis:6379/0` (unchanged)                                |


Remove or ignore `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` for production (they were for the Docker Postgres container).

### 2.4 Database Bootstrap

Before first deploy with RDS:

1. Run `rails db:create` (or create DBs manually in RDS as above)
2. Run `rails db:prepare` (creates schema, runs migrations for all 4 DBs)

---

## Phase 4: EC2 and Deployment Updates

### 3.1 EC2 Setup

- **Instance:** `t3.micro` (2 vCPU, 1GB RAM) or `t4g.micro` (ARM)
- **Region:** Same as RDS (e.g. `us-west-2` for S3)
- **Security group:** Allow 80, 443 from 0.0.0.0/0; SSH from your IP

### 3.2 Update Deploy Workflow

In [.github/workflows/deploy.yml](.github/workflows/deploy.yml):

- Remove or skip the "wait for database" step that checks `givingshelf-postgres` (Docker health)
- Replace with a simple readiness check: `curl` the app or run `rails db:migrate:status` to verify RDS connectivity
- Keep `db:prepare` (idempotent; safe for RDS)

### 3.3 Secrets Script

Update `fetch-givingshelf-secrets.sh` to include `DATABASE_URL` (or components) from AWS Secrets Manager or Parameter Store.

---

## Phase 5: Scaling Path (When Leaving Free Tier)

### Horizontal Scaling

```mermaid
flowchart TB
    subgraph scale [Scaled Architecture]
        ALB[Application Load Balancer]
        EC2A[EC2 Web 1]
        EC2B[EC2 Web 2]
        EC2Worker[EC2 Worker]
        ElastiCache[ElastiCache Redis]
        RDS[(RDS)]
    end

    Users --> ALB
    ALB --> EC2A
    ALB --> EC2B
    EC2A --> RDS
    EC2B --> RDS
    EC2Worker --> RDS
    EC2A --> ElastiCache
    EC2B --> ElastiCache
    EC2Worker --> ElastiCache
```



- **Web:** Put 2+ EC2 instances behind an ALB
- **Worker:** Run `bin/jobs` on a dedicated EC2 (or same as web initially)
- **Redis:** Move to ElastiCache when you need shared Redis across instances
- **Database:** RDS supports vertical scaling (instance size) and storage scaling

### Vertical Scaling

- **EC2:** t3.micro → t3.small → t3.medium
- **RDS:** db.t3.micro → db.t3.small
- **Worker concurrency:** `JOB_CONCURRENCY=3` in [config/deploy.yml](config/deploy.yml) (already commented)

---

## File Change Summary


| File                                                           | Changes                                                     |
| -------------------------------------------------------------- | ----------------------------------------------------------- |
| [config/database.yml](config/database.yml)                     | `sslmode: require` for production primary                   |
| [docker-compose.production.yml](docker-compose.production.yml) | Remove `db` service; remove db `depends_on` from web/worker |
| Local dev docker-compose (if used)                             | Update Postgres image from `postgres:15` to `postgres:17`   |
| [.github/workflows/deploy.yml](.github/workflows/deploy.yml)   | Replace Docker DB health check with RDS connectivity check  |
| [deploy/givingshelf.service](deploy/givingshelf.service)       | systemd unit for auto-starting Docker Compose on reboot     |
| [deploy/nginx/SSL_SETUP.md](deploy/nginx/SSL_SETUP.md)         | Detailed HTTPS/Let's Encrypt setup (referenced in Phase 2.5) |
| New: `deploy/rds-setup.sql`                                    | SQL to create cache/queue/cable databases (optional)        |
| Secrets / `.env`                                               | Add `DATABASE_URL`; remove Postgres vars for prod           |


---

## Pre-Deployment Checklist

1. [ ] Create RDS instance in same region/VPC as EC2
2. [ ] Create 4 databases in RDS (or use `db:create` if RDS user has `CREATEDB`)
3. [ ] Add deploy key to GitHub repo and clone repo on EC2 (Step 2.11)
4. [ ] Add `DATABASE_URL` to secrets
5. [ ] Update `fetch-givingshelf-secrets.sh` to include `DATABASE_URL`
6. [ ] Run migrations against RDS from local or a one-off container before switching traffic
7. [ ] Migrate existing data from Docker Postgres to RDS (if any) via `pg_dump` / `pg_restore`
8. [ ] Deploy code changes and verify health
9. [ ] Complete HTTPS setup: DNS, dummy certs, Certbot, renewal (Phase 2.5)

---

## Cost Estimate (Free Tier)


| Service         | Free Tier        | Expected Cost          |
| --------------- | ---------------- | ---------------------- |
| EC2 t3.micro    | 750 hrs/mo       | $0                     |
| RDS db.t3.micro | 750 hrs/mo, 20GB | $0                     |
| S3              | 5GB              | $0                     |
| Data transfer   | 15GB out/mo      | $0                     |
| **Total**       |                  | **$0** (within limits) |


**Note:** Free tier is typically 12 months from account creation. Monitor usage in the AWS Billing console.