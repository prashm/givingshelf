#!/bin/bash

# Script to create CloudWatch alarms for EC2 instance monitoring
# Usage: ./create-cloudwatch-alarms.sh <instance-id> <sns-topic-arn>

set -e

INSTANCE_ID="${1:-}"
SNS_TOPIC_ARN="${2:-}"

if [ -z "$INSTANCE_ID" ]; then
  echo "Usage: $0 <instance-id> [sns-topic-arn]"
  echo "Example: $0 i-1234567890abcdef0 arn:aws:sns:us-west-2:123456789012:alerts"
  exit 1
fi

REGION=$(aws configure get region || echo "us-west-2")
ALARM_PREFIX="bookshare-ec2"

echo "Creating CloudWatch alarms for instance: $INSTANCE_ID"
echo "Region: $REGION"
echo ""

# Function to create alarm
create_alarm() {
  local alarm_name=$1
  local metric_name=$2
  local threshold=$3
  local comparison=$4
  local description=$5
  local evaluation_periods=${6:-2}
  local datapoints=${7:-2}

  echo "Creating alarm: $alarm_name"

  local alarm_args=(
    --alarm-name "$alarm_name"
    --alarm-description "$description"
    --metric-name "$metric_name"
    --namespace "CWAgent"
    --statistic "Average"
    --period 300
    --threshold "$threshold"
    --comparison-operator "$comparison"
    --evaluation-periods "$evaluation_periods"
    --datapoints-to-alarm "$datapoints"
    --dimensions "Name=InstanceId,Value=$INSTANCE_ID"
    --treat-missing-data "notBreaching"
  )

  if [ -n "$SNS_TOPIC_ARN" ]; then
    alarm_args+=(--alarm-actions "$SNS_TOPIC_ARN")
  fi

  aws cloudwatch put-metric-alarm "${alarm_args[@]}" --region "$REGION" || {
    echo "Warning: Failed to create alarm $alarm_name (may already exist)"
  }
}

# Disk Space Alarms (Critical - these prevent deployments)
create_alarm \
  "${ALARM_PREFIX}-disk-space-critical" \
  "disk_used_percent" \
  90 \
  "GreaterThanThreshold" \
  "Critical: Disk usage is above 90%. Deployment may fail." \
  1 \
  1

create_alarm \
  "${ALARM_PREFIX}-disk-space-warning" \
  "disk_used_percent" \
  80 \
  "GreaterThanThreshold" \
  "Warning: Disk usage is above 80%. Consider cleaning up." \
  2 \
  2

# Memory Alarms
create_alarm \
  "${ALARM_PREFIX}-memory-high" \
  "MEM_USED_PERCENT" \
  90 \
  "GreaterThanThreshold" \
  "Warning: Memory usage is above 90%." \
  2 \
  2

# CPU Alarms
create_alarm \
  "${ALARM_PREFIX}-cpu-high" \
  "CPU_USAGE_IDLE" \
  10 \
  "LessThanThreshold" \
  "Warning: CPU idle is below 10% (CPU usage is above 90%)." \
  2 \
  2

echo ""
echo "Alarms created successfully!"
echo ""
echo "To view alarms:"
echo "  aws cloudwatch describe-alarms --alarm-name-prefix $ALARM_PREFIX --region $REGION"
echo ""
echo "To delete alarms:"
echo "  aws cloudwatch delete-alarms --alarm-names ${ALARM_PREFIX}-disk-space-critical ${ALARM_PREFIX}-disk-space-warning ${ALARM_PREFIX}-memory-high ${ALARM_PREFIX}-cpu-high --region $REGION"

