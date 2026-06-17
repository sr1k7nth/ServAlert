import requests
from datetime import datetime


def get_timestamp():
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def send_telegram(message, config):
    url = f"https://api.telegram.org/bot{config['TELEGRAM_TOKEN']}/sendMessage"

    formatted_message = f"[{get_timestamp()}]\n{message}"

    requests.post(url, json={
        "chat_id": config["TELEGRAM_CHAT_ID"],
        "text": formatted_message
    })

def send_discord(message, config):
    requests.post(config["DISCORD_WEBHOOK"], json={
        "content": message
    })

def send_alert(message, config):
    if config["TELEGRAM"] == "1":
        send_telegram(message, config)
    if config["DISCORD"] == "1":
        send_discord(message, config)

def send_cpu_alert(avg_cpu, config):
    send_alert(f"CPU Usage Alert!\nUsage: {avg_cpu:.2f}%", config)

def send_mem_alert(avg_mem, config):
    send_alert(f"Memory Usage Alert!\nUsage: {avg_mem:.2f}%", config)
