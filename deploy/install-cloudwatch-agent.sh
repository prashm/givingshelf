#!/bin/bash

# Automated CloudWatch Agent Installation Script
# Run this on your EC2 instance: bash <(curl -s <url>) or copy and run directly

set -e

echo "=========================================="
echo "CloudWatch Agent Installation"
echo "=========================================="
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
  echo "Please run with sudo"
  exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
  VER=$VERSION_ID
else
  echo "Cannot detect OS. Exiting."
  exit 1
fi

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
  ARCH="amd64"
elif [ "$ARCH" = "aarch64" ]; then
  ARCH="arm64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

echo "Detected OS: $OS $VER"
echo "Detected Architecture: $ARCH"
echo ""

# Install CloudWatch Agent
echo "Step 1: Installing CloudWatch Agent..."
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
  DOWNLOAD_URL="https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/${ARCH}/latest/amazon-cloudwatch-agent.deb"
  echo "Downloading from: $DOWNLOAD_URL"
  wget "$DOWNLOAD_URL" -O /tmp/amazon-cloudwatch-agent.deb
  dpkg -i -E /tmp/amazon-cloudwatch-agent.deb
  rm /tmp/amazon-cloudwatch-agent.deb
elif [ "$OS" = "amzn" ] || [ "$OS" = "amazon" ]; then
  DOWNLOAD_URL="https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/${ARCH}/latest/amazon-cloudwatch-agent.rpm"
  echo "Downloading from: $DOWNLOAD_URL"
  wget "$DOWNLOAD_URL" -O /tmp/amazon-cloudwatch-agent.rpm
  rpm -U /tmp/amazon-cloudwatch-agent.rpm
  rm /tmp/amazon-cloudwatch-agent.rpm
else
  echo "Unsupported OS. Please install manually."
  exit 1
fi

echo "✓ CloudWatch Agent installed"
echo ""

# Check for config file in givingshelf directory or standard location
# CloudWatch agent expects JSON format (which it translates to TOML internally)
CONFIG_FILE="/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"
REPO_CONFIG=""

# Check for JSON config (preferred format)
if [ -f "/home/ubuntu/givingshelf/deploy/cloudwatch-config.json" ]; then
  REPO_CONFIG="/home/ubuntu/givingshelf/deploy/cloudwatch-config.json"
elif [ -f "./deploy/cloudwatch-config.json" ]; then
  REPO_CONFIG="./deploy/cloudwatch-config.json"
elif [ -f "$(dirname $0)/cloudwatch-config.json" ]; then
  REPO_CONFIG="$(dirname $0)/cloudwatch-config.json"
fi

# Step 2: Copy config file
echo "Step 2: Setting up configuration file..."
if [ -f "$CONFIG_FILE" ]; then
  echo "✓ Configuration file already exists at $CONFIG_FILE"
  echo "  (To update it, run: sudo bash deploy/update-cloudwatch-config.sh)"
elif [ -n "$REPO_CONFIG" ] && [ -f "$REPO_CONFIG" ]; then
  echo "Copying config from $REPO_CONFIG to $CONFIG_FILE"
  mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
  cp "$REPO_CONFIG" "$CONFIG_FILE"
  chown root:root "$CONFIG_FILE"
  chmod 644 "$CONFIG_FILE"
  echo "✓ Configuration file copied"
  
  # Fix permissions for cwagent user
  echo "Fixing permissions for cwagent user..."
  usermod -a -G adm cwagent 2>/dev/null || true
  usermod -a -G ubuntu cwagent 2>/dev/null || true
  echo "✓ Added cwagent to adm and ubuntu groups"
else
  echo "⚠ WARNING: Configuration file not found"
  echo "Please copy deploy/cloudwatch-config.json to $CONFIG_FILE"
  echo "Or create it manually based on the guide in deploy/cloudwatch-setup.md"
  echo ""
fi

# Get instance ID
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "unknown")
echo "Instance ID: $INSTANCE_ID"
echo ""

# Check IAM role
echo "Step 3: Checking IAM role..."
IAM_ROLE=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/ 2>/dev/null | head -n 1 || echo "")
if [ -z "$IAM_ROLE" ]; then
  echo "⚠ WARNING: No IAM role attached to this instance."
  echo "Please attach an IAM role with CloudWatchAgentServerPolicy"
  echo ""
else
  echo "✓ IAM role found: $IAM_ROLE"
  echo ""
fi

# Start agent (if config exists)
if [ -f "$CONFIG_FILE" ]; then
  echo "Step 4: Starting CloudWatch Agent..."
  # Use the agent's config command to load JSON config
  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:"$CONFIG_FILE" \
    -s
  
  echo ""
  echo "Step 5: Checking agent status..."
  sleep 2
  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status
  echo ""
  echo "✓ CloudWatch Agent is running!"
else
  echo "Step 4: Skipping agent start (config file not found)"
  echo ""
  echo "Next steps:"
  echo "1. Copy deploy/cloudwatch-config.json to $CONFIG_FILE"
  echo "2. Run: sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:$CONFIG_FILE -s"
fi

echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Verify metrics in CloudWatch Console → Metrics → CWAgent"
echo "2. Create alarms using: ./deploy/create-cloudwatch-alarms.sh $INSTANCE_ID [sns-topic-arn]"
echo "3. See deploy/cloudwatch-setup.md for detailed instructions"
echo ""

