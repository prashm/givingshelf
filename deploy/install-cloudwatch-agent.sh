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

echo "Detected OS: $OS $VER"
echo ""

# Install CloudWatch Agent
echo "Step 1: Installing CloudWatch Agent..."
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
  wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -O /tmp/amazon-cloudwatch-agent.deb
  dpkg -i -E /tmp/amazon-cloudwatch-agent.deb
  rm /tmp/amazon-cloudwatch-agent.deb
elif [ "$OS" = "amzn" ] || [ "$OS" = "amazon" ]; then
  wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm -O /tmp/amazon-cloudwatch-agent.rpm
  rpm -U /tmp/amazon-cloudwatch-agent.rpm
  rm /tmp/amazon-cloudwatch-agent.rpm
else
  echo "Unsupported OS. Please install manually."
  exit 1
fi

echo "✓ CloudWatch Agent installed"
echo ""

# Check if config file exists
CONFIG_FILE="/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Step 2: Creating configuration file..."
  echo "Please copy deploy/cloudwatch-config.json to $CONFIG_FILE"
  echo "Or create it manually based on the guide in deploy/cloudwatch-setup.md"
  echo ""
else
  echo "Step 2: Configuration file found at $CONFIG_FILE"
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
  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:$CONFIG_FILE \
    -s
  
  echo ""
  echo "Step 5: Checking agent status..."
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

