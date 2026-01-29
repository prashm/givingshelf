#!/bin/bash

# Script to update CloudWatch Agent JSON configuration
# Run this on your EC2 instance: sudo bash deploy/update-cloudwatch-config.sh

set -e

if [ "$EUID" -ne 0 ]; then 
  echo "Please run with sudo"
  exit 1
fi

CONFIG_FILE="/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"
REPO_CONFIG=""

# Find the JSON config file in the repo (prefer JSON, fallback to TOML)
if [ -f "/home/ubuntu/givingshelf/deploy/cloudwatch-config.json" ]; then
  REPO_CONFIG="/home/ubuntu/givingshelf/deploy/cloudwatch-config.json"
elif [ -f "./deploy/cloudwatch-config.json" ]; then
  REPO_CONFIG="./deploy/cloudwatch-config.json"
elif [ -f "$(dirname $0)/cloudwatch-config.json" ]; then
  REPO_CONFIG="$(dirname $0)/cloudwatch-config.json"
fi

if [ -z "$REPO_CONFIG" ] || [ ! -f "$REPO_CONFIG" ]; then
  echo "Error: Could not find cloudwatch-config.json in the repo"
  echo "Please ensure the file exists in deploy/cloudwatch-config.json"
  exit 1
fi

echo "Updating CloudWatch Agent configuration..."
echo "Source: $REPO_CONFIG"
echo "Destination: $CONFIG_FILE"
echo ""

# Stop the agent first to prevent config conflicts
echo "Stopping CloudWatch Agent..."
systemctl stop amazon-cloudwatch-agent || true

# Clean up any temp files or TOML files in .d directory that might cause issues
echo "Cleaning up config directory..."
rm -f /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/*.tmp
rm -f /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/*.toml

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
echo "Fixing permissions..."
usermod -a -G adm cwagent 2>/dev/null || echo "Note: cwagent user may already be in adm group"
usermod -a -G ubuntu cwagent 2>/dev/null || echo "Note: cwagent user may already be in ubuntu group"
echo "✓ Added cwagent to adm and ubuntu groups"

# Ensure Docker log directory exists and has proper permissions
echo ""
echo "Ensuring Docker log directory exists..."
mkdir -p /home/ubuntu/givingshelf/logs/docker
chown ubuntu:ubuntu /home/ubuntu/givingshelf/logs/docker
chmod 755 /home/ubuntu/givingshelf/logs/docker

# Ensure log files are readable by cwagent
for log_file in rails-web.log rails-worker.log nginx.log; do
  log_path="/home/ubuntu/givingshelf/logs/docker/${log_file}"
  if [ -f "$log_path" ]; then
    chmod 644 "$log_path"
    chown ubuntu:ubuntu "$log_path"
  fi
done
echo "✓ Docker log directory and files ready"

# Use the agent's config command to load the JSON config
echo ""
echo "Loading CloudWatch Agent configuration..."
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:"$CONFIG_FILE" \
  -s

# Wait a moment for agent to start
sleep 3

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
echo "  - Syslog permissions fixed"
echo "  - Docker container logs (Rails web, Rails worker, Nginx)"
echo "  - cwagent user added to adm and ubuntu groups for file access"
echo ""
echo "Check agent logs:"
echo "  sudo tail -f /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log"
echo ""

