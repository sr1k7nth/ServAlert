#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root: sudo ./uninstall.sh"
  exit 1
fi

systemctl stop servalert servalert-alert 2>/dev/null
systemctl disable servalert servalert-alert 2>/dev/null
rm -f /etc/systemd/system/servalert.service
rm -f /etc/systemd/system/servalert-alert.service
rm -f /usr/local/bin/sysmon
rm -rf /usr/local/lib/servalert
rm -rf /var/lib/servalert
rm -rf /etc/servalert
systemctl daemon-reload

echo "ServAlert removed."
