# SSL Certificate Setup Guide

This guide walks through setting up SSL certificates for booksharecommunity.org using Let's Encrypt.

## Prerequisites

1. DNS must be configured and propagated (booksharecommunity.org must resolve to your EC2 IP)
2. Ports 80 and 443 must be open in your EC2 security group
3. The domain must be accessible via HTTP before requesting certificates

## Step 1: Get EC2 Public IP Address

Run on your EC2 instance:
```bash
curl -s http://169.254.169.254/latest/meta-data/public-ipv4
```

Or check the AWS Console → EC2 → Your Instance → Public IPv4 address

## Step 2: Configure DNS in Namecheap

1. Log into your Namecheap account
2. Go to **Domain List** → Click **Manage** for `booksharecommunity.org`
3. Navigate to **Advanced DNS** tab
4. Add/Update A Record:
   - **Type**: A Record
   - **Host**: `@` (or leave blank for root domain)
   - **Value**: [Your EC2 Public IP]
   - **TTL**: Automatic (or 30 min)
5. (Optional) Add A Record for www subdomain:
   - **Type**: A Record
   - **Host**: `www`
   - **Value**: [Your EC2 Public IP]
   - **TTL**: Automatic
6. Save changes

## Step 3: Verify DNS Propagation

Wait 5-30 minutes for DNS to propagate, then verify:

```bash
# On your local machine or EC2
dig booksharecommunity.org
# or
nslookup booksharecommunity.org
```

Verify it resolves to your EC2 IP address before proceeding.

## Step 4: Ensure Security Group Allows Ports 80 and 443

In AWS Console:
1. Go to EC2 → Security Groups
2. Select your instance's security group
3. Ensure inbound rules allow:
   - Port 80 (HTTP) from 0.0.0.0/0
   - Port 443 (HTTPS) from 0.0.0.0/0

## Step 5: Obtain SSL Certificate

On your EC2 instance, navigate to the project directory and run:

```bash
cd ~/bookshare

# Request certificate for both root domain and www subdomain
docker compose -f docker-compose.production.yml --profile certbot run --rm certbot certonly \
  --webroot \
  -w /var/www/certbot \
  -d booksharecommunity.org \
  -d www.booksharecommunity.org \
  --email your-email@example.com \
  --agree-tos \
  --non-interactive
```

Replace `your-email@example.com` with your actual email address.

Certificates will be saved to: `/etc/letsencrypt/live/booksharecommunity.org/`

## Step 6: Enable HTTPS in Nginx Configuration

After obtaining certificates, you need to enable the HTTPS server block in nginx:

1. Edit `deploy/nginx/nginx.conf` on your EC2 instance:
   ```bash
   nano ~/bookshare/deploy/nginx/nginx.conf
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
cd ~/bookshare

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
curl -I https://booksharecommunity.org
```

You should see a 200 OK response. Also verify HTTP redirects to HTTPS:

```bash
curl -I http://booksharecommunity.org
```

Should show a 301 redirect to HTTPS.

## Step 8: Set Up Automatic Certificate Renewal

Certificates expire in 90 days. Set up automatic renewal via cron:

```bash
# Edit crontab
crontab -e

# Add this line to run renewal weekly (every Monday at 3 AM)
0 3 * * 1 cd /home/ubuntu/bookshare && ./deploy/nginx/renew-certificates.sh >> /var/log/certbot-renewal.log 2>&1
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
WorkingDirectory=/home/ubuntu/bookshare
ExecStart=/home/ubuntu/bookshare/deploy/nginx/renew-certificates.sh
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
cd ~/bookshare
docker compose -f docker-compose.production.yml --profile certbot run --rm certbot renew --dry-run
```

## Troubleshooting

### Certificate request fails
- Ensure DNS has propagated (check with `dig booksharecommunity.org`)
- Verify port 80 is open and accessible
- Check nginx is running and serving the `/.well-known/acme-challenge/` location

### Nginx fails to start after enabling HTTPS
- Check certificate paths are correct in nginx.conf
- Verify certificates exist: `ls -la deploy/nginx/certbot/live/booksharecommunity.org/`
- Check nginx logs: `docker compose -f docker-compose.production.yml logs nginx`

### Renewal fails
- Ensure the renewal script has execute permissions: `chmod +x deploy/nginx/renew-certificates.sh`
- Check cron/systemd logs for errors
- Manually test renewal: `./deploy/nginx/renew-certificates.sh`

## Additional Resources

- Let's Encrypt Documentation: https://letsencrypt.org/docs/
- Certbot Documentation: https://eff-certbot.readthedocs.io/
- SSL Labs Test: https://www.ssllabs.com/ssltest/analyze.html?d=booksharecommunity.org

