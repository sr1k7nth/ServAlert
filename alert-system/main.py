import sqlite3
import time
from alerts import send_alert, send_cpu_alert, send_mem_alert

DB_PATH = "/var/lib/servalert/metrics.db"

last_alert_sent = {
    "cpu": 0,
    "mem": 0,
    "core": 0
}

COOLDOWN = 600  # 10 minutes in seconds

def read_config():
    config = {}
    with open("/etc/servalert/config.conf") as f:
        for line in f:
            line = line.strip()
            if "=" in line:
                key, value = line.split("=", 1)
                config[key] = value
    return config

def get_recent_metrics(n=6):
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute(
        "SELECT * FROM metrics ORDER BY id DESC LIMIT ?", (n,)
    )

    rows = cursor.fetchall()
    conn.close()
    return rows


def check_metrics(config):
    
    rows = get_recent_metrics()

    if not rows:
        return

    if len(rows) < 6:
        return
    
    now = time.time()
    last_timestamp = rows[0]["timestamp"]
    if time.time() - last_timestamp > 90:
        if now - last_alert_sent["core"] > COOLDOWN:
            send_alert("SerAlert core stopped: daemon may have crashed", config)
            last_alert_sent["core"] = int(now)
            return

    avg_cpu = sum(row["cpu_percent"] for row in rows) / len(rows)
    if avg_cpu > float(config["CPU_THRESHOLD"]):
        if now - last_alert_sent["cpu"] > COOLDOWN:
            send_cpu_alert(avg_cpu,config)
            last_alert_sent["cpu"] = int(now)

    avg_mem_available = sum(row["mem_available"] for row in rows) / len(rows)
    mem_used_percent = 100 - (avg_mem_available / rows[0]["mem_total"] * 100)

    if mem_used_percent > float(config["MEM_THRESHOLD"]):
        if now - last_alert_sent["mem"] > COOLDOWN:
            send_mem_alert(mem_used_percent, config)
            last_alert_sent["mem"] = int(now)



if __name__ == "__main__":
    config = read_config()
    while True:
        check_metrics(config)
        time.sleep(int(config["ALERT_INTERVAL"]))
