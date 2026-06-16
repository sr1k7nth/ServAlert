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

# 1. compile the C core
echo "Compiling..."
gcc core/core.c -lsqlite3 -o sysmon
if [ $? -ne 0 ]; then
  echo "Compilation failed."
  exit 1
fi

# 2. copy binary to system path
echo "Installing binary..."
cp sysmon /usr/local/bin/sysmon

# 3. write the systemd service file
echo "Writing service file..."
cat >/etc/systemd/system/servalert.service <<'EOF'
[Unit]
Description=ServAlert monitoring daemon
After=network.target

[Service]
ExecStart=/usr/local/bin/sysmon
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

mkdir -p /var/lib/servalert

# 4. reload systemd, enable and start
echo "Starting service..."
systemctl daemon-reload
systemctl enable servalert
systemctl start servalert

echo ""
echo "ServAlert installed and running."
echo "  Status:  systemctl status servalert"
echo "  Logs:    journalctl -u servalert -f"
echo "  Stop:    systemctl stop servalert"
