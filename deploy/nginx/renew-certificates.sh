#!/bin/bash
# Certificate renewal script for Let's Encrypt
# This script should be run via cron weekly

set -e

cd "$(dirname "$0")/../.."

# Renew certificates
docker compose -f docker-compose.production.yml --profile certbot run --rm certbot renew

# Reload nginx to pick up new certificates
docker compose -f docker-compose.production.yml exec nginx nginx -s reload

echo "Certificate renewal completed successfully at $(date)"

