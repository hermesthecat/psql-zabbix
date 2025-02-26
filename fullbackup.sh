#!/bin/bash

LOG_FILE="/var/log/backup_runner.log"
ENV_FILE="/root/.backup_env"

# Env dosyasını kontrol et
if [ ! -f "$ENV_FILE" ]; then
    echo "HATA: Env dosyası bulunamadı: $ENV_FILE"
    exit 1
fi

# Log dosyasını temizle
rm -f "$LOG_FILE"

# Env dosyasını yükle
source "$ENV_FILE"

send_to_zabbix() {
    MESSAGE=$1
    zabbix_sender -z "$ZABBIX_SERVER" -s "$HOSTNAME" -k "backup.status" -o "$MESSAGE" >/dev/null 2>&1
}

# SQL dosyalarını temizleme fonksiyonu
cleanup_sql_files() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - SQL dosyaları temizleniyor..." >> "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - SQL dosyaları temizleniyor..."
    
    local sql_files=$(find "$BACKUP_DIR" -maxdepth 4 -type f -name "*.sql" -mmin -1440)
    local count=0
    
    for file in $sql_files; do
        if [ -f "$file" ]; then
            rm -f "$file"
            if [ $? -eq 0 ]; then
                ((count++))
                echo "$(date '+%Y-%m-%d %H:%M:%S') - Silindi: $file" >> "$LOG_FILE"
            else
                echo "$(date '+%Y-%m-%d %H:%M:%S') - HATA: $file silinemedi!" >> "$LOG_FILE"
            fi
        fi
    done
    
    local msg="$(date '+%Y-%m-%d %H:%M:%S') - $count SQL dosyası temizlendi"
    echo "$msg" >> "$LOG_FILE"
    echo "$msg"
}

# ZIP dosyalarını temizleme fonksiyonu
cleanup_zip_files() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ZIP dosyaları temizleniyor..." >> "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ZIP dosyaları temizleniyor..."
    
    local zip_files=$(find "$ZIP_DIR" -maxdepth 4 -type f -name "*.7z" -mmin -1440)
        local count=0
    
    for file in $zip_files; do
        if [ -f "$file" ]; then
            rm -f "$file"
            if [ $? -eq 0 ]; then
                ((count++))
                echo "$(date '+%Y-%m-%d %H:%M:%S') - Silindi: $file" >> "$LOG_FILE"
            else
                echo "$(date '+%Y-%m-%d %H:%M:%S') - HATA: $file silinemedi!" >> "$LOG_FILE"
            fi
        fi
    done    

    local msg="$(date '+%Y-%m-%d %H:%M:%S') - $count ZIP dosyası temizlendi"
    echo "$msg" >> "$LOG_FILE"
    echo "$msg"
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

# Sırasıyla scriptleri çalıştır
run_step "PostgreSQL Backup" "./pgbackup.sh"
run_step "Archiving Backup" "./tar.sh"
run_step "Uploading Backup" "./upload.sh"
run_step "Verifying Backup" "./verify_backup.sh"

# Tüm işlemler başarılı olduysa SQL ve ZIP dosyalarını temizle
#cleanup_sql_files
cleanup_zip_files

FINAL_MSG="$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: Backup process completed!"
echo "$FINAL_MSG"
echo "$FINAL_MSG" >> "$LOG_FILE"
send_to_zabbix "$FINAL_MSG"