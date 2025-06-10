#!/bin/bash

# Incremental Backup Script
# Her saat başı çalıştırılacak

LOG_FILE="/var/log/incremental_backup.log"
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
    KEY=${2:-"backup.incremental"}
    zabbix_sender -z "$ZABBIX_SERVER" -s "$HOSTNAME" -k "$KEY" -o "$MESSAGE" >/dev/null 2>&1
}

# Log mesajı
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# WAL dosyalarını sıkıştır ve arşivle
compress_wal_files() {
    local wal_dir="${BACKUP_DIR}/wal"
    local archive_dir="${ZIP_DIR}/wal_archives"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    # Dizinleri oluştur
    mkdir -p "$archive_dir"
    
    # WAL dosyalarını kontrol et
    local wal_files=$(find "$wal_dir" -name "*.wal" -o -name "*[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]" 2>/dev/null)
    
    if [ -z "$wal_files" ]; then
        log_message "WAL: Arşivlenecek WAL dosyası bulunamadı"
        return 0
    fi
    
    local file_count=$(echo "$wal_files" | wc -l)
    log_message "WAL: $file_count WAL dosyası bulundu"
    
    # WAL dosyalarını geçici dizine kopyala
    local temp_dir=$(mktemp -d)
    cp -r "$wal_dir"/* "$temp_dir/" 2>/dev/null
    
    # Sıkıştırma
    local archive_file="${archive_dir}/wal_incremental_${timestamp}.7z"
    local password=$(cat "$ENCRYPTION_KEY_FILE")
    
    log_message "WAL: Sıkıştırma başlıyor..."
    
    if 7z a -t7z -m0=lzma2 -mx=3 -mhe=on -p"$password" "$archive_file" "$temp_dir"/* >/dev/null 2>&1; then
        local archive_size=$(du -h "$archive_file" | cut -f1)
        log_message "WAL: Sıkıştırma başarılı - Boyut: $archive_size"
        
        # Eski WAL dosyalarını temizle (sadece arşivlenenleri)
        rm -f $wal_files
        log_message "WAL: $file_count WAL dosyası temizlendi"
        
        # pCloud'a yükle
        if [ -f "./pcloud.sh" ]; then
            log_message "WAL: pCloud'a yükleme başlıyor..."
            ./pcloud.sh "$archive_file" "$PCLOUD_FOLDER_ID"
            log_message "WAL: pCloud'a yüklendi"
        fi
        
        send_to_zabbix "1" "backup.wal.incremental"
        send_to_zabbix "$file_count" "backup.wal.files_count"
        
        # Temizlik
        rm -rf "$temp_dir"
        
        return 0
    else
        log_message "WAL: HATA - Sıkıştırma başarısız"
        rm -rf "$temp_dir"
        send_to_zabbix "0" "backup.wal.incremental"
        return 1
    fi
}

# WAL temizleme (48 saatten eski dosyalar)
cleanup_old_wal() {
    local archive_dir="${ZIP_DIR}/wal_archives"
    
    if [ -d "$archive_dir" ]; then
        local old_files=$(find "$archive_dir" -name "wal_incremental_*.7z" -mtime +2)
        local count=0
        
        for file in $old_files; do
            if [ -f "$file" ]; then
                rm -f "$file"
                ((count++))
            fi
        done
        
        if [ $count -gt 0 ]; then
            log_message "WAL: $count eski WAL arşivi temizlendi"
        fi
    fi
}

# Ana işlem
main() {
    log_message "=== Incremental Backup Başlıyor ==="
    
    # WAL dosyalarını işle
    if compress_wal_files; then
        log_message "Incremental backup başarılı"
    else
        log_message "HATA: Incremental backup başarısız"
        exit 1
    fi
    
    # Eski dosyaları temizle
    cleanup_old_wal
    
    log_message "=== Incremental Backup Tamamlandı ==="
}

# Script'i çalıştır
main 