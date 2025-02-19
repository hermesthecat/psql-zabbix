#!/bin/bash

# Yapılandırma
LOG_FILE="/var/log/backup_tar.log"
ENV_FILE="/root/.backup_env"
ENCRYPTION_KEY_FILE="/root/.backup_encryption_key"

# Env dosyasını kontrol et
if [ ! -f "$ENV_FILE" ]; then
    echo "HATA: Env dosyası bulunamadı: $ENV_FILE"
    exit 1
fi

# Env dosyasını yükle
source "$ENV_FILE"

# Şifreleme anahtarını kontrol et
if [ ! -f "$ENCRYPTION_KEY_FILE" ]; then
    # Rastgele 32 byte'lık anahtar oluştur (AES-256 için)
    openssl rand -base64 32 > "$ENCRYPTION_KEY_FILE"
    chmod 600 "$ENCRYPTION_KEY_FILE"
fi

# Zabbix'e bildirim gönderme fonksiyonu
send_to_zabbix() {
    MESSAGE=$1
    KEY=$2
    zabbix_sender -z "$ZABBIX_SERVER" -s "$HOSTNAME" -k "$KEY" -o "$MESSAGE" >/dev/null 2>&1
}

# Log ve Zabbix'e mesaj gönderme
log_message() {
    local message=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp - $message" >> "$LOG_FILE"
    send_to_zabbix "$message" "backup.tar"
}

# Dosya boyutunu alma (MB cinsinden)
get_file_size() {
    local file=$1
    local size=$(du -m "$file" | cut -f1)
    echo "$size"
}

# Sıkıştırma oranını hesaplama
calculate_compression_ratio() {
    local original_size=$1
    local compressed_size=$2
    local ratio=$(echo "scale=2; ($original_size - $compressed_size) * 100 / $original_size" | bc)
    echo "$ratio"
}

# Sıkıştırma ve şifreleme işlemi
compress_and_encrypt_backup() {
    local source_dir=$1
    local target_file=$2
    local temp_tar="/tmp/temp_backup_$$.tar.gz"
    local start_time=$(date +%s)
    
    # Kaynak dizin boyutunu al
    local original_size=$(du -sm "$source_dir" | cut -f1)
    log_message "Sıkıştırma ve şifreleme başlıyor: $source_dir (Boyut: ${original_size}MB)"
    send_to_zabbix "$original_size" "backup.tar.original_size"
    
    # Önce tar.gz oluştur
    tar -czf "$temp_tar" -C "$(dirname "$source_dir")" "$(basename "$source_dir")" 2>/dev/null
    local tar_status=$?
    
    if [ $tar_status -eq 0 ]; then
        # tar.gz dosyasını AES ile şifrele
        openssl enc -aes-256-cbc -salt -in "$temp_tar" -out "$target_file" -pass file:"$ENCRYPTION_KEY_FILE" 2>/dev/null
        local encrypt_status=$?
        rm -f "$temp_tar"  # Geçici dosyayı sil
        
        # Bitiş zamanı ve süre hesaplama
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [ $encrypt_status -eq 0 ]; then
            # Şifrelenmiş dosya boyutu
            local encrypted_size=$(get_file_size "$target_file")
            local compression_ratio=$(calculate_compression_ratio $original_size $encrypted_size)
            local speed=$(echo "scale=2; $original_size / $duration" | bc)
            
            local success_msg="Sıkıştırma ve şifreleme başarılı: ${encrypted_size}MB (Oran: %${compression_ratio}, Hız: ${speed}MB/s, Süre: ${duration}s)"
            log_message "$success_msg"
            
            # Metrikleri Zabbix'e gönder
            send_to_zabbix "$encrypted_size" "backup.tar.encrypted_size"
            send_to_zabbix "$compression_ratio" "backup.tar.compression_ratio"
            send_to_zabbix "$speed" "backup.tar.speed"
            send_to_zabbix "$duration" "backup.tar.duration"
            
            # Şifreleme doğruluğunu test et
            local test_decrypt="/tmp/test_decrypt_$$.tar.gz"
            openssl enc -d -aes-256-cbc -in "$target_file" -out "$test_decrypt" -pass file:"$ENCRYPTION_KEY_FILE" 2>/dev/null
            if [ $? -eq 0 ]; then
                tar -tzf "$test_decrypt" >/dev/null 2>&1
                local verify_status=$?
                rm -f "$test_decrypt"
                
                if [ $verify_status -eq 0 ]; then
                    log_message "Şifreleme ve arşiv bütünlük kontrolü başarılı"
                    return 0
                else
                    log_message "HATA: Arşiv bütünlük kontrolü başarısız!"
                    return 1
                fi
            else
                log_message "HATA: Şifreleme doğrulama testi başarısız!"
                return 1
            fi
        else
            log_message "HATA: Şifreleme işlemi başarısız! (Çıkış kodu: $encrypt_status)"
            return 1
        fi
    else
        log_message "HATA: Sıkıştırma işlemi başarısız! (Çıkış kodu: $tar_status)"
        return 1
    fi
}

# Ana fonksiyon
main() {
    # En son yedek dizinini bul
    local latest_backup=$(find $BACKUP_DIR/daily -type d -name "backup_*" | sort -r | head -n 1)
    
    if [ -z "$latest_backup" ]; then
        log_message "HATA: Sıkıştırılacak yedek dizini bulunamadı!"
        exit 1
    fi
    
    # Hedef dosya adını oluştur
    local backup_date=$(basename "$latest_backup" | cut -d'_' -f2)
    local target_file="$BACKUP_DIR/daily/backup_${backup_date}.tar.gz.enc"
    
    log_message "Yedek sıkıştırma ve şifreleme işlemi başlatılıyor..."
    
    # Sıkıştırma ve şifreleme işlemini başlat
    if compress_and_encrypt_backup "$latest_backup" "$target_file"; then
        log_message "Yedek sıkıştırma ve şifreleme işlemi başarıyla tamamlandı"
        exit 0
    else
        log_message "Yedek sıkıştırma ve şifreleme işlemi başarısız!"
        exit 1
    fi
}

# Scripti çalıştır
main
