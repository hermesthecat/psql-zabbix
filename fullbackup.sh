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

# Log ve Zabbix'e mesaj gönderme
log_message() {
    local message=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp - $message" >> "$LOG_FILE"
    send_to_zabbix "$message" "backup.tar"
}


# PostgreSQL servis kontrolü
check_postgresql() {
    if ! systemctl is-active --quiet postgresql; then
        log_message "HATA: PostgreSQL servisi çalışmıyor!"
        echo "HATA: PostgreSQL servisi çalışmıyor!"
        send_to_zabbix "PostgreSQL servisi çalışmıyor" "backup.postgresql_status"
        return 1
    fi
    
    # PostgreSQL'e bağlanabilme kontrolü
    if ! psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c '\q' >/dev/null 2>&1; then
        log_message "HATA: PostgreSQL'e bağlanılamıyor!"
        echo "HATA: PostgreSQL'e bağlanılamıyor!"
        send_to_zabbix "PostgreSQL'e bağlanılamıyor" "backup.postgresql_status"
        return 1
    fi
    
    return 0
}

echo "----------------------------" >> "$LOG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Backup process started" >> "$LOG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Backup process started"
send_to_zabbix "Backup process started"

run_step() {
    STEP_NAME=$1
    SCRIPT_PATH=$2

    echo "$(date '+%Y-%m-%d %H:%M:%S') - Running $STEP_NAME..." >> "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Running $STEP_NAME..."
    
    OUTPUT=$($SCRIPT_PATH 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -ne 0 ]; then
        ERROR_MSG="$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $STEP_NAME failed! Exit Code: $EXIT_CODE | Error: $OUTPUT"
        echo "$ERROR_MSG"
        echo "$ERROR_MSG" >> "$LOG_FILE"
        send_to_zabbix "$ERROR_MSG"
        exit 1
    fi

    SUCCESS_MSG="$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: $STEP_NAME completed."
    echo "$SUCCESS_MSG"
    echo "$SUCCESS_MSG" >> "$LOG_FILE"
    send_to_zabbix "$SUCCESS_MSG"
}

# PostgreSQL servis kontrolü
if ! check_postgresql; then
    exit 1
fi

# Sırasıyla scriptleri çalıştır
run_step "PostgreSQL Backup" "/root/pgbackup.sh"
run_step "Archiving Backup" "/root/tar.sh"
run_step "Uploading Backup" "/root/upload.sh"
run_step "Verifying Backup" "/root/verify_backup.sh"

FINAL_MSG="$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: Backup process completed!"
echo "$FINAL_MSG"
echo "$FINAL_MSG" >> "$LOG_FILE"
send_to_zabbix "$FINAL_MSG"