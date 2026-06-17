#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root: sudo ./uninstall.sh"
  exit 1
fi

systemctl stop servalert
systemctl disable servalert
rm -f /etc/systemd/system/servalert.service
rm -f /usr/local/bin/sysmon
systemctl daemon-reload

echo "ServAlert removed."
