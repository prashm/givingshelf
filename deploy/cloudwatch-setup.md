# CloudWatch Setup Guide

This guide will help you set up CloudWatch monitoring for your EC2 instance, including disk space alerts to prevent deployment failures.

## Prerequisites

- AWS CLI installed and configured on your local machine
- IAM permissions to install CloudWatch agent and create alarms
- SSH access to your EC2 instance

## Step 1: Install CloudWatch Agent on EC2

### Option A: Automated Installation (Recommended)

SSH into your EC2 instance and run:

```bash
# Copy the installation script to your EC2 instance, then:
sudo bash /home/ubuntu/bookshare/deploy/install-cloudwatch-agent.sh
```

### Option B: Manual Installation

```bash
# Download and install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i -E ./amazon-cloudwatch-agent.deb

# Verify installation
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -v
```

## Step 2: Create IAM Role for CloudWatch Agent

1. Go to AWS Console → IAM → Roles
2. Create a new role:
   - Trust entity: EC2
   - Attach policy: `CloudWatchAgentServerPolicy`
   - Name: `CloudWatchAgentServerRole`

3. Attach the role to your EC2 instance:
   - EC2 Console → Select instance → Actions → Security → Modify IAM role
   - Select `CloudWatchAgentServerRole`

## Step 3: Configure CloudWatch Agent

Copy the configuration file to your EC2 instance:

```bash
# On your local machine, copy the config file
scp deploy/cloudwatch-config.json ubuntu@44.250.51.11:/tmp/

# On EC2 instance, move it to the correct location
sudo mv /tmp/cloudwatch-config.json /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
sudo chown root:root /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
```

Or manually create it using the configuration provided in `deploy/cloudwatch-config.json`.

## Step 4: Start CloudWatch Agent

```bash
# Start the agent with the configuration
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

# Check status
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status
```

## Step 5: Create CloudWatch Alarms

### Option A: Using AWS Console

1. Go to CloudWatch → Alarms → Create alarm
2. Select metric: `CWAgent` → `disk_used_percent` → `InstanceId` → `device` = `/`
3. Set threshold: `>= 80` for warning, `>= 90` for critical
4. Configure SNS topic for notifications

### Option B: Using AWS CLI (Recommended)

First, get your instance ID and optionally create an SNS topic for notifications:

```bash
# Get instance ID (run on EC2)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

# Create SNS topic (optional, for email notifications)
SNS_TOPIC_ARN=$(aws sns create-topic --name bookshare-alerts --query 'TopicArn' --output text)
aws sns subscribe --topic-arn $SNS_TOPIC_ARN --protocol email --notification-endpoint your-email@example.com

# Create alarms
./deploy/create-cloudwatch-alarms.sh $INSTANCE_ID $SNS_TOPIC_ARN
```

## Step 6: Verify Metrics

1. Go to CloudWatch → Metrics → CWAgent
2. You should see metrics like:
   - `disk_used_percent`
   - `mem_used_percent`
   - `cpu_usage_idle`
   - `diskio_reads`, `diskio_writes`

## Monitoring Disk Space

The most important metric for preventing deployment failures is disk space. Set up alarms for:
- **Warning**: Disk usage > 80%
- **Critical**: Disk usage > 90%

You'll receive notifications before disk space becomes critical.

## Troubleshooting

### Check agent logs
```bash
sudo tail -f /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
```

### Restart agent
```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a stop
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a start
```

### Verify metrics are being sent
```bash
# Check if agent is running
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status
```

