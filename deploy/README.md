# Deployment Scripts

This directory contains scripts for setting up and deploying the Bookshare application on EC2.

## Initial EC2 Setup

When setting up a **new EC2 instance**, run the comprehensive setup script:

```bash
cd /home/ubuntu/bookshare
sudo bash deploy/setup-ec2.sh
```

This script will:
1. Install and configure CloudWatch Agent
2. Setup Docker log tailing for CloudWatch
3. Configure all monitoring

## Individual Setup Scripts

### CloudWatch Agent Setup

```bash
sudo bash deploy/install-cloudwatch-agent.sh
```

Installs the CloudWatch agent and configures it to monitor:
- CPU, Memory, Disk usage
- System logs
- Docker container logs (Rails web, Rails worker, Nginx)

### Docker Log Tailing Setup

```bash
sudo bash deploy/setup-docker-logs.sh
```

Sets up a systemd service that tails Docker container logs to files on the host, which CloudWatch can then monitor.

### Update CloudWatch Config

```bash
sudo bash deploy/update-cloudwatch-config.sh
```

Updates the CloudWatch agent configuration from the repo (uses JSON format) and restarts the agent. This script:
- Stops the agent to prevent config conflicts
- Cleans up any temp files in the `.d` directory
- Copies the JSON config file
- Sets proper permissions (adds cwagent to adm and ubuntu groups)
- Ensures Docker log directory exists
- Restarts the agent using the config command

## CloudWatch Log Groups

After setup, you'll see these log groups in CloudWatch:

- `/aws/ec2/bookshare/syslog` - System logs
- `/aws/ec2/bookshare/rails/web` - Rails web server logs
- `/aws/ec2/bookshare/rails/worker` - Rails background job logs
- `/aws/ec2/bookshare/nginx` - Nginx access/error logs

## CloudWatch Metrics

Metrics are published under the `CWAgent` namespace:
- `disk_used_percent` - Disk usage (critical for preventing deployment failures)
- `mem_used_percent` - Memory usage
- `CPU_USAGE_IDLE` - CPU usage
- And more...

## Creating Alarms

Use the provided script to create CloudWatch alarms:

```bash
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
./deploy/create-cloudwatch-alarms.sh $INSTANCE_ID [sns-topic-arn]
```

## Troubleshooting

### Check CloudWatch Agent Status
```bash
sudo systemctl status amazon-cloudwatch-agent
sudo tail -f /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
```

### Check Docker Log Tailing
```bash
sudo systemctl status tail-docker-logs
ls -lh /home/ubuntu/bookshare/logs/docker/
```

### Verify Logs are Being Sent
```bash
# Check agent logs for any errors
sudo tail -50 /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log | grep -i error

# Check if log files exist and have content
tail -20 /home/ubuntu/bookshare/logs/docker/rails-web.log
```

## Deployment Integration

The deployment workflow (`.github/workflows/deploy.yml`) automatically:
- Sets up Docker log tailing if not already configured
- Ensures all monitoring is in place

No manual intervention needed after initial setup!

