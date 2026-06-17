import requests

token = "8446598462:AAGqoltbb8FoY_SQfXfHAlv4YA5uQI7isI8"
chat_id = "1740904658"

url = f"https://api.telegram.org/bot{token}/sendMessage"
response = requests.post(url, json={
    "chat_id": chat_id,
    "text": "Test message from ServAlert"
})

print(response.json())
