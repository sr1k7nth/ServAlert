# ServAlert
A lightweight, self-hosted server monitoring daemon written in C and Python. Provides alert system through different chat applications (currently supports only Discord and Telegram)

## Architecture
The C core runs as a daemon, reading /proc/meminfo and /proc/stat every N seconds 
and writing metrics to a SQLite database. C is used here for near-zero overhead.

The Python alert layer reads the database every N seconds, checks thresholds, 
and sends notifications. Python is used here for its HTTP libraries and simplicity.

Both run as separate systemd services.
## Features
1. Takes roughly around **20-25MB** of memory.
2. Custom thresholds for CPU, Memory and Network usage
3. Custom stats read time.
4. Discord and Telegram support.
   Get notifications on your Telegram (via bot_token and chat_id) and Discord (webhooks).
## Requirements
1. gcc compiler
2. python
3. sqlite3
## Installation
1. Clone:
   ```
   git clone https://github.com/sr1k7nth/ServAlert.git
   ```
2. In same folder:
   ```
   sudo ./install.sh
   ```
## Configuration
All the thresholds, Telegram and Discord goes into the `.conf` file in `/etc/servalert/config.conf`

```
MONITOR_INTERVAL=
ALERT_INTERVAL=
CPU_THRESHOLD=
MEM_THRESHOLD=
NET_THRESHOLD=
TELEGRAM=1/0
TELEGRAM_TOKEN=you_token
TELEGRAM_CHAT_ID=your_chat_id
DISCORD=1/0
DISCORD_WEBHOOK=""
```

## Usage
```
Start:   systemctl start servalert servalert-alert
Stop:    systemctl stop servalert servalert-alert
Status:  systemctl status servalert
         systemctl status servalert-alert
Logs:    journalctl -u servalert -f
         journalctl -u servalert-alert -f
```

## Uninstall
```
sudo ./uninstall.sh
```
## Memory Usage
```
C core (servalert):        ~1.2M
Python alerts:             ~19.4M
Total:                     ~20.6M
```
## Future features:
- Network usage
- Web dashboard
- Email alert
