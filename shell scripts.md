## Shell Script Basics

### What is a shell script?
A `.sh` file is just a list of commands the terminal runs top to bottom, same as if you typed them yourself. The only difference is they run automatically.

### First line — shebang
```bash
#!/bin/bash
```
Tells the OS "use bash to run this file." Always the first line.

---
### Variables
```bash
NAME="Zak"
echo $NAME      # use $ to read a variable
```

---

### Reading user input
```bash
read -p "Enter your name: " NAME
echo "Hello $NAME"
```
`-p` is the prompt text shown to the user.

---

### Default values
```bash
read -p "Interval (default 10): " INTERVAL
INTERVAL=${INTERVAL:-10}   # if user pressed enter without typing, use 10
```

---

### Conditionals
```bash
if [ "$NAME" = "Zak" ]; then
    echo "Hello Zak"
else
    echo "Who are you?"
fi
```

---

### Checking if a command exists
```bash
if ! command -v gcc &>/dev/null; then
    echo "gcc not found"
    exit 1
fi
```
`command -v gcc` returns the path to gcc if it exists. `!` negates it. `&>/dev/null` discards any output.

---

### Exit codes
```bash
exit 0   # success
exit 1   # failure
```
Every command returns an exit code. `0` means success, anything else means failure. `$?` holds the last exit code:
```bash
gcc core/core.c -lsqlite3 -o sysmon
if [ $? -ne 0 ]; then
    echo "Compilation failed"
    exit 1
fi
```

---

### Writing to a file
```bash
cat > /etc/servalert/config.conf << EOF
KEY=VALUE
EOF
```
`<<EOF` means "write everything until you see EOF into the file." Called a heredoc.

---

### Running commands
```bash
systemctl start servalert   # just run it
$(command)                  # capture output into a variable
NAME=$(whoami)              # NAME = current user
```

---

## Your install.sh explained line by line

```bash
#!/bin/bash
# use bash to run this
```

```bash
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi
# EUID is the current user's ID. Root is always 0.
# -ne means "not equal"
# if not root, exit
```

```bash
if ! command -v gcc &>/dev/null; then
  echo "gcc not found"
  exit 1
fi
# check gcc exists before trying to compile
```

```bash
if ! pkg-config --exists sqlite3 2>/dev/null; then
  echo "sqlite3 dev libraries not found"
  exit 1
fi
# pkg-config checks if a library is installed
# 2>/dev/null discards error output
```

```bash
read -p "How often should it monitor usage in seconds? (default 10): " MONITOR_INTERVAL
MONITOR_INTERVAL=${MONITOR_INTERVAL:-10}
# ask user, fall back to 10 if they just press enter
```

```bash
mkdir -p /etc/servalert
cat > /etc/servalert/config.conf << EOF
MONITOR_INTERVAL=$MONITOR_INTERVAL
...
EOF
# create the config directory
# write all collected values into config.conf
```

```bash
systemctl stop servalert 2>/dev/null
# stop old instance if running
# 2>/dev/null — if it wasn't running, discard the error
```

```bash
gcc core/core.c -lsqlite3 -o sysmon
if [ $? -ne 0 ]; then
  echo "Compilation failed."
  exit 1
fi
# compile the C core
# check if it succeeded
```

```bash
cp sysmon /usr/local/bin/sysmon
mkdir -p /usr/local/lib/servalert
cp alert-system/main.py /usr/local/lib/servalert/main.py
cp alert-system/alerts.py /usr/local/lib/servalert/alerts.py
# copy everything to permanent system locations
```

```bash
cat > /etc/systemd/system/servalert.service << 'EOF'
[Unit]
...
EOF
# write the systemd service file
# note 'EOF' with quotes — prevents variable expansion inside
```

```bash
systemctl daemon-reload     # tell systemd to re-read service files
systemctl enable servalert  # start on boot
systemctl start servalert   # start now
```

---

Any part you want me to go deeper on?