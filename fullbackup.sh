#!/bin/bash

LOG_FILE="/var/log/backup_runner.log"
ENV_FILE="/root/.backup_env"

# Env dosyasını kontrol et
if [ ! -f "$ENV_FILE" ]; then
    echo "HATA: Env dosyası bulunamadı: $ENV_FILE"
    exit 1
fi

# Env dosyasını yükle
source "$ENV_FILE"

send_to_zabbix() {
    MESSAGE=$1
    zabbix_sender -z "$ZABBIX_SERVER" -s "$HOSTNAME" -k "backup.status" -o "$MESSAGE" >/dev/null 2>&1
}

echo "----------------------------" >> "$LOG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Backup process started" >> "$LOG_FILE"
send_to_zabbix "Backup process started"

run_step() {
    STEP_NAME=$1
    SCRIPT_PATH=$2

    echo "$(date '+%Y-%m-%d %H:%M:%S') - Running $STEP_NAME..." >> "$LOG_FILE"

    OUTPUT=$($SCRIPT_PATH 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -ne 0 ]; then
        ERROR_MSG="$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $STEP_NAME failed! Exit Code: $EXIT_CODE | Error: $OUTPUT"
        echo "$ERROR_MSG" >> "$LOG_FILE"
        send_to_zabbix "$ERROR_MSG"
        exit 1
    fi

    SUCCESS_MSG="$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: $STEP_NAME completed."
    echo "$SUCCESS_MSG" >> "$LOG_FILE"
    send_to_zabbix "$SUCCESS_MSG"
}

# Sırasıyla scriptleri çalıştır
run_step "PostgreSQL Backup" "/root/pgbackup.sh"
run_step "Archiving Backup" "/root/tar.sh"
run_step "Uploading Backup" "/root/upload.sh"
run_step "Verifying Backup" "/root/verify_backup.sh"

FINAL_MSG="$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: Backup process completed!"
echo "$FINAL_MSG" >> "$LOG_FILE"
send_to_zabbix "$FINAL_MSG"