#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root: sudo ./install.sh"
  exit 1
fi

# Check dependencies
if ! command -v gcc &>/dev/null; then
  echo "gcc not found. Install it first."
  exit 1
fi

if ! pkg-config --exists sqlite3 2>/dev/null; then
  echo "sqlite3 dev libraries not found. Install sqlite-devel first."
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo "python3 not found. Install it first."
  exit 1
fi

# User configuration
read -p "How often should it monitor usage in seconds? (default 10): " MONITOR_INTERVAL
MONITOR_INTERVAL=${MONITOR_INTERVAL:-10}

read -p "How often should it check for alerts in seconds? (default 60): " ALERT_INTERVAL
ALERT_INTERVAL=${ALERT_INTERVAL:-60}

read -p "CPU usage alert threshold in percent? (default 80): " CPU_THRESHOLD
CPU_THRESHOLD=${CPU_THRESHOLD:-80}

read -p "Memory usage alert threshold in percent? (default 85): " MEM_THRESHOLD
MEM_THRESHOLD=${MEM_THRESHOLD:-85}

read -p "Network usage alert threshold in Kbps? (default 10000): " NET_THRESHOLD
NET_THRESHOLD=${NET_THRESHOLD:-10000}

read -p "Telegram bot token: " TELEGRAM_TOKEN
if [ -z "$TELEGRAM_TOKEN" ]; then
  echo "Telegram bot token is required."
  exit 1
fi

read -p "Telegram chat ID: " TELEGRAM_CHAT_ID
if [ -z "$TELEGRAM_CHAT_ID" ]; then
  echo "Telegram chat ID is required."
  exit 1
fi

# Write config
mkdir -p /etc/servalert
cat >/etc/servalert/config.conf <<EOF
MONITOR_INTERVAL=$MONITOR_INTERVAL
ALERT_INTERVAL=$ALERT_INTERVAL
CPU_THRESHOLD=$CPU_THRESHOLD
MEM_THRESHOLD=$MEM_THRESHOLD
NET_THRESHOLD=$NET_THRESHOLD
TELEGRAM_TOKEN=$TELEGRAM_TOKEN
TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID
EOF

# Stop services if already running
systemctl stop servalert 2>/dev/null
systemctl stop servalert-alert 2>/dev/null

# 1. Compile the C core
echo "Compiling..."
gcc core/core.c -lsqlite3 -o sysmon
if [ $? -ne 0 ]; then
  echo "Compilation failed."
  exit 1
fi

# 2. Copy binaries and Python files
echo "Installing files..."
cp sysmon /usr/local/bin/sysmon
mkdir -p /usr/local/lib/servalert
cp alert-system/main.py /usr/local/lib/servalert/main.py
cp alert-system/alerts.py /usr/local/lib/servalert/alerts.py

# 3. Install Python dependencies
echo "Installing Python dependencies..."
pip3 install requests -q

# 4. Create data directory
mkdir -p /var/lib/servalert

# 5. Write systemd service for C core
echo "Writing service files..."
cat >/etc/systemd/system/servalert.service <<'EOF'
[Unit]
Description=ServAlert monitoring daemon
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/sysmon
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# 6. Write systemd service for Python alert system
cat >/etc/systemd/system/servalert-alert.service <<'EOF'
[Unit]
Description=ServAlert alert system
After=servalert.service

[Service]
ExecStart=/usr/bin/python3 /usr/local/lib/servalert/main.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# 7. Reload systemd, enable and start both services
echo "Starting services..."
systemctl daemon-reload
systemctl enable servalert
systemctl start servalert
systemctl enable servalert-alert
systemctl start servalert-alert

echo ""
echo "ServAlert installed and running."
echo ""
echo "  C core:  systemctl status servalert"
echo "  Alerts:  systemctl status servalert-alert"
echo "  Logs:    journalctl -u servalert -f"
echo "           journalctl -u servalert-alert -f"
echo "  Stop:    systemctl stop servalert servalert-alert"
