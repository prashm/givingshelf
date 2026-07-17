#!/bin/bash
# Certificate renewal script for Let's Encrypt
# This script should be run via cron weekly
#
# NOTE: Wildcard certificates (*.givingshelf.net) require DNS-01.
# `certbot renew` only works unattended if the original cert was issued with an
# automated DNS plugin (e.g. certbot-dns-cloudflare / certbot-dns-route53).
# Manual DNS-01 certs must be re-issued interactively before expiry — see SSL_SETUP.md.

set -e

cd "$(dirname "$0")/../.."

# Renew certificates
docker compose -f docker-compose.production.yml --profile certbot run --rm certbot renew

# Reload nginx to pick up new certificates
docker compose -f docker-compose.production.yml exec nginx nginx -s reload

echo "Certificate renewal completed successfully at $(date)"
