# SSL Certificate Setup Guide

This guide walks through setting up SSL certificates for givingshelf.net and booksharecommunity.org (redirects to givingshelf.net) using Let's Encrypt.

## Prerequisites

1. DNS must be configured and propagated:
   - **givingshelf.net** and **www.givingshelf.net** must resolve to your EC2 IP
   - **booksharecommunity.org** and **www.booksharecommunity.org** must resolve to the same EC2 IP (for one cert covering all four)
2. Ports 80 and 443 must be open in your EC2 security group
3. The domains must be accessible via HTTP before requesting certificates

## Step 1: Get EC2 Public IP Address

Run on your EC2 instance:
```bash
curl -s http://169.254.169.254/latest/meta-data/public-ipv4
```

Or check the AWS Console → EC2 → Your Instance → Public IPv4 address

## Step 2: Configure DNS (Namecheap or your provider)

**givingshelf.net:**  
1. Domain List → **Manage** for `givingshelf.net` → **Advanced DNS**  
2. A record `@` → [EC2 IP]  
3. A record `www` → [EC2 IP]  

**booksharecommunity.org** (redirects to givingshelf.net; same cert):  
1. Domain List → **Manage** for `booksharecommunity.org` → **Advanced DNS**  
2. A record `@` → [same EC2 IP]  
3. A record `www` → [same EC2 IP]  

Save changes and wait for propagation (5–30 min).

## Step 3: Verify DNS Propagation

Wait 5–30 minutes, then verify all four resolve to your EC2 IP:

```bash
dig givingshelf.net
dig www.givingshelf.net
dig booksharecommunity.org
dig www.booksharecommunity.org
```

## Fresh EC2 / Re-create from scratch

Nginx uses a single certificate path: `/etc/letsencrypt/live/givingshelf.net/`. On a new instance:

1. **DNS:** Point all four hostnames (givingshelf.net, www, booksharecommunity.org, www) to the new EC2 IP.
2. **Bootstrap:** Create dummy certs in `deploy/nginx/certbot/live/givingshelf.net/` so nginx can start (see deploy steps).
3. **Webroot:** Run `mkdir -p deploy/nginx/www` so the certbot volume mount works.
4. **First cert:** Request the certificate **once** with all four domains and `--cert-name givingshelf.net` (Step 5). The cert is written to `givingshelf.net/` and nginx works without path changes.
5. **Renewal:** `deploy/nginx/renew-certificates.sh` renews all certs; no config change needed.

If you already have a cert in `givingshelf.net-0001/` (e.g. after expanding), see the symlink instructions in Step 5.

## Step 4: Ensure Security Group Allows Ports 80 and 443

In AWS Console:
1. Go to EC2 → Security Groups
2. Select your instance's security group
3. Ensure inbound rules allow:
   - Port 80 (HTTP) from 0.0.0.0/0
   - Port 443 (HTTPS) from 0.0.0.0/0

## Step 5: Obtain SSL Certificate

**Important for fresh EC2 / re-create:** Request **all four domains in one command** and use `--cert-name givingshelf.net` so the certificate is saved at `givingshelf.net/`. Nginx is configured to use that path only.

Ensure the webroot directory exists (Docker mounts it for ACME challenges):

```bash
cd ~/givingshelf
mkdir -p deploy/nginx/www
```

Then run certbot **via Docker** (so it uses the same volume as nginx):

```bash
docker compose -f docker-compose.production.yml --profile certbot run --rm certbot certonly \
  --webroot \
  -w /var/www/certbot \
  --cert-name givingshelf.net \
  -d givingshelf.net \
  -d www.givingshelf.net \
  -d booksharecommunity.org \
  -d www.booksharecommunity.org \
  --email your-email@example.com \
  --agree-tos \
  --non-interactive
```

Replace `your-email@example.com` with your actual email address.

Certificates will be saved to: `deploy/nginx/certbot/live/givingshelf.net/` (inside containers: `/etc/letsencrypt/live/givingshelf.net/`).

### If you already have a certificate in `givingshelf.net-0001/` (e.g. after expanding an existing cert)

Nginx expects the cert at `givingshelf.net/`. Create a symlink **from the project directory** so the path is correct for Docker:

```bash
cd ~/givingshelf/deploy/nginx/certbot/live
# Remove existing givingshelf.net (directory or broken symlink)
rm -rf givingshelf.net
# Symlink must be relative and created in this directory so Docker sees it
ln -s givingshelf.net-0001 givingshelf.net
# Verify: should show givingshelf.net -> givingshelf.net-0001 and fullchain.pem under the target
ls -la
ls -la givingshelf.net-0001/
```

Then reload nginx: `docker compose -f docker-compose.production.yml exec nginx nginx -s reload`

## Step 6: Enable HTTPS in Nginx Configuration

After obtaining certificates, you need to enable the HTTPS server block in nginx:

1. Edit `deploy/nginx/nginx.conf` on your EC2 instance:
   ```bash
   nano ~/givingshelf/deploy/nginx/nginx.conf
   ```

2. **Uncomment the HTTPS server block** (remove `#` from lines 53-102):
   - Find the line `# server {` (around line 53) and change to `server {`
   - Remove all `#` characters from the entire HTTPS server block
   - This enables the HTTPS server with SSL certificates

3. **Enable HTTP to HTTPS redirect** in the HTTP server block (around line 42):
   - Find the location block that has the proxy_pass configuration
   - Comment out or remove the proxy_pass block (lines with proxy_set_header and proxy_pass)
   - Uncomment the redirect line: `return 301 https://$host$request_uri;`

**Quick reference:** The HTTP server should redirect to HTTPS, and the HTTPS server block should be uncommented and active.

**Alternative: Manual editing steps:**

```bash
cd ~/givingshelf

# Create a script to enable HTTPS
cat > enable-https.sh << 'EOF'
#!/bin/bash
sed -i 's/#     listen 443 ssl http2;/    listen 443 ssl http2;/' deploy/nginx/nginx.conf
sed -i 's/#     server_name/    server_name/' deploy/nginx/nginx.conf
sed -i 's/#     # SSL certificates/    # SSL certificates/' deploy/nginx/nginx.conf
sed -i 's/#     ssl_certificate/    ssl_certificate/' deploy/nginx/nginx.conf
sed -i 's/#     ssl_certificate_key/    ssl_certificate_key/' deploy/nginx/nginx.conf
sed -i 's/#     # SSL configuration/    # SSL configuration/' deploy/nginx/nginx.conf
sed -i 's/#     ssl_protocols/    ssl_protocols/' deploy/nginx/nginx.conf
sed -i 's/#     ssl_ciphers/    ssl_ciphers/' deploy/nginx/nginx.conf
sed -i 's/#     ssl_prefer_server_ciphers/    ssl_prefer_server_ciphers/' deploy/nginx/nginx.conf
sed -i 's/#     ssl_session_cache/    ssl_session_cache/' deploy/nginx/nginx.conf
sed -i 's/#     ssl_session_timeout/    ssl_session_timeout/' deploy/nginx/nginx.conf
sed -i 's/#     # Security headers/    # Security headers/' deploy/nginx/nginx.conf
sed -i 's/#     add_header/    add_header/g' deploy/nginx/nginx.conf
sed -i 's/#     # Static assets/    # Static assets/' deploy/nginx/nginx.conf
sed -i 's/#     location ~ \^\/\(assets/    location ~ ^\/(assets/' deploy/nginx/nginx.conf
sed -i 's/#         proxy_set_header/        proxy_set_header/g' deploy/nginx/nginx.conf
sed -i 's/#         proxy_pass/        proxy_pass/g' deploy/nginx/nginx.conf
sed -i 's/#         proxy_http_version/        proxy_http_version/g' deploy/nginx/nginx.conf
sed -i 's/#         proxy_set_header Connection/        proxy_set_header Connection/g' deploy/nginx/nginx.conf
sed -i 's/#         expires/        expires/g' deploy/nginx/nginx.conf
sed -i 's/#         add_header Cache-Control/        add_header Cache-Control/g' deploy/nginx/nginx.conf
sed -i 's/#     # Proxy all requests/    # Proxy all requests/' deploy/nginx/nginx.conf
sed -i 's/#     location \/ {/    location \/ {/' deploy/nginx/nginx.conf
sed -i 's/#         proxy_set_header X-Forwarded-For/        proxy_set_header X-Forwarded-For/g' deploy/nginx/nginx.conf
sed -i 's/#         proxy_set_header Host/        proxy_set_header Host/g' deploy/nginx/nginx.conf
sed -i 's/#         proxy_set_header X-Forwarded-Proto/        proxy_set_header X-Forwarded-Proto/g' deploy/nginx/nginx.conf
sed -i 's/#         proxy_set_header X-Real-IP/        proxy_set_header X-Real-IP/g' deploy/nginx/nginx.conf
sed -i 's/#         proxy_pass http:\/\/web:3000;/        proxy_pass http:\/\/web:3000;/' deploy/nginx/nginx.conf
sed -i 's/#         proxy_http_version 1.1;/        proxy_http_version 1.1;/' deploy/nginx/nginx.conf
sed -i 's/#         proxy_set_header Connection "";/        proxy_set_header Connection "";/' deploy/nginx/nginx.conf
sed -i 's/#         proxy_redirect off;/        proxy_redirect off;/' deploy/nginx/nginx.conf
sed -i 's/#     # healthcheck/    # healthcheck/' deploy/nginx/nginx.conf
sed -i 's/#     location \/healthz/    location \/healthz/' deploy/nginx/nginx.conf
sed -i 's/#         return 200 "ok\\n";/        return 200 "ok\\n";/' deploy/nginx/nginx.conf
sed -i 's/#     }/    }/' deploy/nginx/nginx.conf

# Enable HTTP to HTTPS redirect
sed -i 's/# return 301 https:\/\/\$host\$request_uri;/return 301 https:\/\/$host$request_uri;/' deploy/nginx/nginx.conf
sed -i '/proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;/,/proxy_set_header Connection "";/d' deploy/nginx/nginx.conf
sed -i '/location \/ {/a\            return 301 https://$host$request_uri;' deploy/nginx/nginx.conf
EOF

chmod +x enable-https.sh
./enable-https.sh
```

**Or manually edit the file:**
- Uncomment the entire HTTPS server block (remove `#` from lines 53-102)
- In the HTTP server block, replace the proxy location with: `return 301 https://$host$request_uri;`

## Step 7: Restart Nginx

After enabling HTTPS, restart nginx:

```bash
docker compose -f docker-compose.production.yml restart nginx
```

## Step 7: Verify HTTPS is Working

Test from your local machine:

```bash
curl -I https://givingshelf.net
```

You should see a 200 OK response. Also verify HTTP redirects to HTTPS:

```bash
curl -I http://givingshelf.net
```

Should show a 301 redirect to HTTPS.

## Step 8: Set Up Automatic Certificate Renewal

Certificates expire in 90 days. Set up automatic renewal via cron:

```bash
# Edit crontab
crontab -e

# Add this line to run renewal weekly (every Monday at 3 AM)
0 3 * * 1 cd /home/ubuntu/givingshelf && ./deploy/nginx/renew-certificates.sh >> /var/log/certbot-renewal.log 2>&1
```

Or create a systemd timer (recommended):

Create `/etc/systemd/system/certbot-renewal.service`:
```ini
[Unit]
Description=Renew Let's Encrypt certificates
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
WorkingDirectory=/home/ubuntu/givingshelf
ExecStart=/home/ubuntu/givingshelf/deploy/nginx/renew-certificates.sh
```

Create `/etc/systemd/system/certbot-renewal.timer`:
```ini
[Unit]
Description=Run certbot renewal weekly

[Timer]
OnCalendar=weekly
RandomizedDelaySec=3600

[Install]
WantedBy=timers.target
```

Then enable:
```bash
sudo systemctl enable certbot-renewal.timer
sudo systemctl start certbot-renewal.timer
```

## Step 9: Test Certificate Renewal

Test that renewal works without actually renewing:

```bash
cd ~/givingshelf
docker compose -f docker-compose.production.yml --profile certbot run --rm certbot renew --dry-run
```

## Troubleshooting

### Certificate request fails
- Ensure DNS has propagated (check with `dig givingshelf.net`)
- Verify port 80 is open and accessible
- Check nginx is running and serving the `/.well-known/acme-challenge/` location

### Nginx fails to start after enabling HTTPS
- Check certificate paths are correct in nginx.conf
- Verify certificates exist: `ls -la deploy/nginx/certbot/live/givingshelf.net/`
- Check nginx logs: `docker compose -f docker-compose.production.yml logs nginx`

### Renewal fails
- Ensure the renewal script has execute permissions: `chmod +x deploy/nginx/renew-certificates.sh`
- Check cron/systemd logs for errors
- Manually test renewal: `./deploy/nginx/renew-certificates.sh`

## Additional Resources

- Let's Encrypt Documentation: https://letsencrypt.org/docs/
- Certbot Documentation: https://eff-certbot.readthedocs.io/
- SSL Labs Test: https://www.ssllabs.com/ssltest/analyze.html?d=givingshelf.net

