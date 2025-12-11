#!/bin/bash

# Skapa variabel
logfile="security_log.txt"

# Deklarera funktionen log
# Echo skriver ut datumet (en inbyggd method?) och $1 innehåller värdet 
# från antingen $file_input eller $user_input beroende på i vilken funktion
# log används.
# Den vänstra halvan pipe:as till tee
# tee skapar en fil om den inte finns, annars lägger den till värdet till $logfile
# $logfile är som bekant security_log.txt
log() {
  echo "$(date) - $1" | tee -a $logfile
}

check_file() {
  local file=$1
  if [ -f "$file" ]; then
      log "Filen '$file' finns."
      ls -l "$file" | tee -a $logfile
  else
      log "VARNING: Filen '$file' saknas."
  fi
}

check_user() {
  local user=$1
  if id "$user" &>/dev/null; then
      log "Användaren '$user' finns."
  else
      log "VARNING: Användaren '$user' saknas."
  fi
}

read -p "Ange fil att kontrollera: " file_input
check_file "$file_input"

read -p "Ange användarnamn att kontrollera: " user_input
check_user "$user_input"

log "Kontroller slutförda."