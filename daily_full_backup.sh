#!/bin/bash

# Daily Full Backup Script
# Günde 2 kez çalıştırılacak: 06:00 ve 18:00

LOG_FILE="/var/log/daily_full_backup.log"
ENV_FILE="/root/.backup_env"

# Env dosyasını kontrol et ve yükle
if [ ! -f "$ENV_FILE" ]; then
    echo "HATA: Env dosyası bulunamadı: $ENV_FILE"
    exit 1
fi

source "$ENV_FILE"

# Zabbix'e bildirim gönderme fonksiyonu
send_to_zabbix() {
    MESSAGE=$1
    KEY=${2:-"backup.daily_full"}
    zabbix_sender -z "$ZABBIX_SERVER" -s "$HOSTNAME" -k "$KEY" -o "$MESSAGE" >/dev/null 2>&1
}

# Log mesajı
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# WAL checkpoint oluştur (clean backup point için)
create_checkpoint() {
    log_message "CHECKPOINT: WAL checkpoint oluşturuluyor..."
    
    # PostgreSQL'de checkpoint oluştur
    PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -U $PG_USERNAME -d postgres -c "CHECKPOINT;" >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        log_message "CHECKPOINT: Başarılı"
        return 0
    else
        log_message "CHECKPOINT: HATA - Başarısız"
        return 1
    fi
}

# Full backup alma
run_full_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_type=""
    
    # Saat kontrolü ile backup türü belirle
    local current_hour=$(date +%H)
    if [ "$current_hour" = "06" ]; then
        backup_type="morning"
    elif [ "$current_hour" = "18" ]; then
        backup_type="evening"
    else
        backup_type="manual"
    fi
    
    log_message "FULL: $backup_type full backup başlıyor..."
    
    # Checkpoint oluştur
    if ! create_checkpoint; then
        log_message "FULL: HATA - Checkpoint oluşturulamadı"
        send_to_zabbix "0" "backup.full.checkpoint"
        return 1
    fi
    
    send_to_zabbix "1" "backup.full.checkpoint"
    
    # Mevcut fullbackup.sh'yi çalıştır
    log_message "FULL: Ana backup script çalıştırılıyor..."
    
    if ./fullbackup.sh; then
        log_message "FULL: $backup_type backup başarılı"
        send_to_zabbix "1" "backup.full.${backup_type}"
        
        # Başarılı full backup sonrası eski WAL arşivlerini temizle
        cleanup_old_incremental_after_full
        
        return 0
    else
        log_message "FULL: HATA - $backup_type backup başarısız"
        send_to_zabbix "0" "backup.full.${backup_type}"
        return 1
    fi
}

# Full backup sonrası eski incremental dosyalarını temizle
cleanup_old_incremental_after_full() {
    local wal_archive_dir="${ZIP_DIR}/wal_archives"
    
    if [ -d "$wal_archive_dir" ]; then
        # Son 6 saatlik WAL arşivlerini koru, geri kalanını sil
        local old_files=$(find "$wal_archive_dir" -name "wal_incremental_*.7z" -mmin +360)
        local count=0
        
        for file in $old_files; do
            if [ -f "$file" ]; then
                rm -f "$file"
                ((count++))
            fi
        done
        
        if [ $count -gt 0 ]; then
            log_message "CLEANUP: $count eski incremental arşiv temizlendi"
        fi
    fi
    
    # WAL dizinindeki eski dosyaları da temizle
    local wal_dir="${BACKUP_DIR}/wal"
    if [ -d "$wal_dir" ]; then
        local old_wal=$(find "$wal_dir" -type f -mmin +360)
        local wal_count=0
        
        for file in $old_wal; do
            if [ -f "$file" ]; then
                rm -f "$file"
                ((wal_count++))
            fi
        done
        
        if [ $wal_count -gt 0 ]; then
            log_message "CLEANUP: $wal_count eski WAL dosyası temizlendi"
        fi
    fi
}

# Ana işlem
main() {
    log_message "=== Daily Full Backup Başlıyor ==="
    
    # Full backup çalıştır
    if run_full_backup; then
        log_message "=== Daily Full Backup Başarılı ==="
        exit 0
    else
        log_message "=== Daily Full Backup BAŞARISIZ ==="
        exit 1
    fi
}

# Script'i çalıştır
main 