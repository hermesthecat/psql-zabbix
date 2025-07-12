#!/bin/bash

# WAL Archive Script for Incremental Backup
# Bu script PostgreSQL tarafından otomatik çağrılır

WAL_FILE=$1      # %p - WAL dosyasının tam yolu
WAL_NAME=$2      # %f - WAL dosyasının adı

# Yapılandırma
ENV_FILE="/root/.backup_env"
LOG_FILE="/var/log/wal_archive.log"

# Env dosyasını yükle
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "HATA: Env dosyası bulunamadı: $ENV_FILE" >> "$LOG_FILE"
    exit 1
fi

# WAL dizini yoksa oluştur
WAL_ARCHIVE_DIR="${BACKUP_DIR}/wal"
mkdir -p "$WAL_ARCHIVE_DIR"

# WAL dosyasını arşiv dizinine kopyala
ARCHIVE_PATH="${WAL_ARCHIVE_DIR}/${WAL_NAME}"

# Dosyayı güvenli şekilde kopyala
if cp "$WAL_FILE" "$ARCHIVE_PATH"; then
    # Checksum oluştur
    md5sum "$ARCHIVE_PATH" > "${ARCHIVE_PATH}.md5"
    
    # Log
    echo "$(date '+%Y-%m-%d %H:%M:%S') - WAL arşivlendi: $WAL_NAME" >> "$LOG_FILE"
    
    # Zabbix'e bildir (isteğe bağlı)
    if command -v zabbix_sender >/dev/null 2>&1; then
        zabbix_sender -z "$ZABBIX_SERVER" -s "$HOSTNAME" -k "backup.wal.archive" -o "1" >/dev/null 2>&1
    fi
    
    exit 0
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - HATA: WAL arşivleme başarısız: $WAL_NAME" >> "$LOG_FILE"
    
    # Zabbix'e hata bildir
    if command -v zabbix_sender >/dev/null 2>&1; then
        zabbix_sender -z "$ZABBIX_SERVER" -s "$HOSTNAME" -k "backup.wal.archive" -o "0" >/dev/null 2>&1
    fi
    
    exit 1
fi 