#!/bin/bash

# Script to update CloudWatch Agent TOML configuration
# Run this on your EC2 instance: sudo bash deploy/update-cloudwatch-config.sh

set -e

if [ "$EUID" -ne 0 ]; then 
  echo "Please run with sudo"
  exit 1
fi

CONFIG_FILE="/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.toml"
REPO_CONFIG=""

# Find the config file in the repo
if [ -f "/home/ubuntu/bookshare/deploy/cloudwatch-config.toml" ]; then
  REPO_CONFIG="/home/ubuntu/bookshare/deploy/cloudwatch-config.toml"
elif [ -f "./deploy/cloudwatch-config.toml" ]; then
  REPO_CONFIG="./deploy/cloudwatch-config.toml"
elif [ -f "$(dirname $0)/cloudwatch-config.toml" ]; then
  REPO_CONFIG="$(dirname $0)/cloudwatch-config.toml"
fi

if [ -z "$REPO_CONFIG" ] || [ ! -f "$REPO_CONFIG" ]; then
  echo "Error: Could not find cloudwatch-config.toml in the repo"
  echo "Please ensure the file exists in deploy/cloudwatch-config.toml"
  exit 1
fi

echo "Updating CloudWatch Agent configuration..."
echo "Source: $REPO_CONFIG"
echo "Destination: $CONFIG_FILE"
echo ""

# Backup existing config
if [ -f "$CONFIG_FILE" ]; then
  BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
  cp "$CONFIG_FILE" "$BACKUP_FILE"
  echo "✓ Backed up existing config to: $BACKUP_FILE"
fi

# Copy new config
cp "$REPO_CONFIG" "$CONFIG_FILE"
chown root:root "$CONFIG_FILE"
chmod 644 "$CONFIG_FILE"
echo "✓ Configuration file updated"

# Fix syslog permissions
echo ""
echo "Fixing syslog permissions..."
usermod -a -G adm cwagent 2>/dev/null || echo "Note: cwagent user may already be in adm group"
echo "✓ Added cwagent to adm group for syslog access"

# Ensure Docker log directory exists
echo ""
echo "Ensuring Docker log directory exists..."
mkdir -p /home/ubuntu/bookshare/logs/docker
chown ubuntu:ubuntu /home/ubuntu/bookshare/logs/docker
echo "✓ Docker log directory ready"

# Restart agent
echo ""
echo "Restarting CloudWatch Agent..."
systemctl restart amazon-cloudwatch-agent

# Wait a moment for restart
sleep 2

# Check status
echo ""
echo "Agent status:"
systemctl status amazon-cloudwatch-agent --no-pager -l | head -20

echo ""
echo "=========================================="
echo "Configuration updated successfully!"
echo "=========================================="
echo ""
echo "The config now includes:"
echo "  - Namespace: CWAgent (for metrics)"
echo "  - Disk monitoring: Only root filesystem (/)"
echo "  - Docker overlay filesystems ignored"
echo "  - Syslog permissions fixed"
echo "  - Docker container logs (Rails web, Rails worker, Nginx)"
echo ""
echo "Check agent logs:"
echo "  sudo tail -f /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log"
echo ""

