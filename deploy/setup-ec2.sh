#!/bin/bash

# Comprehensive EC2 setup script for new instances
# This script sets up CloudWatch agent and Docker log tailing
# Run this once when setting up a new EC2 instance

set -e

if [ "$EUID" -ne 0 ]; then 
  echo "Please run with sudo"
  exit 1
fi

# Get the script directory (where this script is located)
if [ -L "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$(readlink "${BASH_SOURCE[0]}")")" && pwd)"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
GIVINGSHELF_DIR="/home/ubuntu/givingshelf"

echo "=========================================="
echo "EC2 Setup Script"
echo "=========================================="
echo ""
echo "This script will:"
echo "  1. Install and configure CloudWatch Agent"
echo "  2. Setup Docker log tailing for CloudWatch"
echo "  3. Configure all monitoring"
echo ""

# Check if we're in the givingshelf directory
if [ ! -f "${GIVINGSHELF_DIR}/docker-compose.production.yml" ]; then
  echo "Error: Could not find givingshelf directory at ${GIVINGSHELF_DIR}"
  echo "Please ensure you're running this from the givingshelf directory"
  exit 1
fi

cd "${GIVINGSHELF_DIR}"

# Step 1: Install CloudWatch Agent
echo "Step 1: Installing CloudWatch Agent..."
if [ -f "${SCRIPT_DIR}/install-cloudwatch-agent.sh" ]; then
  bash "${SCRIPT_DIR}/install-cloudwatch-agent.sh"
else
  echo "Warning: install-cloudwatch-agent.sh not found, skipping CloudWatch setup"
fi

# Step 2: Setup Docker log tailing
echo ""
echo "Step 2: Setting up Docker log tailing..."
if [ -f "${SCRIPT_DIR}/setup-docker-logs.sh" ]; then
  bash "${SCRIPT_DIR}/setup-docker-logs.sh"
else
  echo "Warning: setup-docker-logs.sh not found, skipping Docker log setup"
fi

# Step 3: Update CloudWatch config to include Docker logs
echo ""
echo "Step 3: Updating CloudWatch config for Docker logs..."
if [ -f "${SCRIPT_DIR}/cloudwatch-config.json" ]; then
  # Check if Docker logs are already in the config
  if ! grep -q "rails-web.log" /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json 2>/dev/null; then
    echo "Updating CloudWatch config to include Docker logs..."
    bash "${SCRIPT_DIR}/update-cloudwatch-config.sh"
  else
    echo "✓ CloudWatch config already includes Docker logs"
  fi
else
  echo "Warning: cloudwatch-config.json not found"
fi

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Verify CloudWatch agent is running:"
echo "   sudo systemctl status amazon-cloudwatch-agent"
echo ""
echo "2. Verify Docker log tailing is running:"
echo "   sudo systemctl status tail-docker-logs"
echo ""
echo "3. Check log files are being created:"
echo "   ls -lh /home/ubuntu/givingshelf/logs/docker/"
echo ""
echo "4. View logs in CloudWatch Console:"
echo "   - /aws/ec2/givingshelf/rails/web"
echo "   - /aws/ec2/givingshelf/rails/worker"
echo "   - /aws/ec2/givingshelf/nginx"
echo ""

