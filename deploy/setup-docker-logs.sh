#!/bin/bash

# Setup script to tail Docker container logs to files for CloudWatch monitoring
# This is run as part of the deployment process

set -e

if [ "$EUID" -ne 0 ]; then 
  echo "Please run with sudo"
  exit 1
fi

LOG_DIR="/home/ubuntu/bookshare/logs/docker"
SCRIPT_PATH="/usr/local/bin/tail-docker-logs.sh"
SERVICE_NAME="tail-docker-logs.service"

echo "Setting up Docker log tailing for CloudWatch..."

# Create log directory
mkdir -p "$LOG_DIR"
chown ubuntu:ubuntu "$LOG_DIR"

# Create the tail script
cat > "$SCRIPT_PATH" << 'SCRIPT_EOF'
#!/bin/bash
# Tail Docker container logs to files for CloudWatch monitoring

LOG_DIR="/home/ubuntu/bookshare/logs/docker"

# Function to tail a container's logs
tail_container() {
  local container_name=$1
  local log_file=$2
  
  while true; do
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
      docker logs -f --tail 0 "${container_name}" >> "${log_file}" 2>&1
    else
      echo "$(date): Container ${container_name} not running, waiting..." >> "${log_file}"
      sleep 10
    fi
  done
}

# Start tailing each container in background
tail_container bookshare-web "${LOG_DIR}/rails-web.log" &
tail_container bookshare-worker "${LOG_DIR}/rails-worker.log" &
tail_container bookshare-nginx "${LOG_DIR}/nginx.log" &

# Wait for all background processes
wait
SCRIPT_EOF

chmod +x "$SCRIPT_PATH"

# Create systemd service
cat > "/etc/systemd/system/${SERVICE_NAME}" << 'SERVICE_EOF'
[Unit]
Description=Tail Docker container logs to files for CloudWatch
After=docker.service
Requires=docker.service

[Service]
Type=simple
ExecStart=/usr/local/bin/tail-docker-logs.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Reload systemd and enable/start the service
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"

# Start the service (or restart if already running)
if systemctl is-active --quiet "${SERVICE_NAME}"; then
  echo "Restarting ${SERVICE_NAME}..."
  systemctl restart "${SERVICE_NAME}"
else
  echo "Starting ${SERVICE_NAME}..."
  systemctl start "${SERVICE_NAME}"
fi

# Wait a moment for service to start
sleep 2

# Verify service is running
if systemctl is-active --quiet "${SERVICE_NAME}"; then
  echo "✓ Docker log tailing service is running"
  echo "  Log files will be created in: ${LOG_DIR}"
else
  echo "⚠ Warning: Service may not have started properly"
  systemctl status "${SERVICE_NAME}" --no-pager -l | head -20
  exit 1
fi

echo ""
echo "Setup complete! Log files:"
ls -lh "${LOG_DIR}" 2>/dev/null || echo "  (Log files will appear once containers start writing)"

