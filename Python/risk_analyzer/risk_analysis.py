# Importera rätt bibliotek för att hantera filerna
import json
import csv

# Läs JSON-fil
with open("events.json") as f:
  events = json.load(f)["events"]

# Läs CSV-fil (lite oklart vad den gör)
users = {} # Skapar en tom dictionary
with open("users.csv") as f:
  reader = csv.DictReader(f)
  for row in reader:
    users[row["username"]] = {
      "status": row["status"],
      "fails": 0
    }

# Räkna antalet fails
for event in events: # Loopar igenom alla events i json-filen
  if event["event"] == "failed_login": # Kollar om något event heter "failed_login"
    user = event["user"] # Sätter variabeln users till namnet på användaren som hade en "failed_login"
    if user in users:
      users[user]["fails"] += 1 # Hittar användaren ovan i CSV-filen och ökar värdet "fails" med 1

# Klassificera risker
def classify(userinfo): # Definierar funktionen classify
  fails = userinfo["fails"] # Hitta värdet för "fails"
  status = userinfo["status"] # Hitta värdet för "status"

  if status == "disabled" and fails > 0: # Logik som skriver ut felmeddelande baserat på
    return "CRITICAL"                    # hur högt värdet av "fails" är
  if fails >= 3:
    return "HIGH"
  if fails >= 1:
    return "MEDIUM"
  return "LOW"

# Loggning
with open("risk_report.txt", "w") as report: # Öppnar risk_report.txt med write som variabeln report
  for username, info in users.items():
    risk = classify(info)
    report.write(f"{username}: {risk} (fails: {info['fails']}, status: {info['status']})\n")

  print("Analysen är klar. Se risk_report.txt.") # Skriver meddelande till terminalen