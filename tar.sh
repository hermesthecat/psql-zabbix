#!/bin/bash

# Yapılandırma
LOG_FILE="/var/log/backup_tar.log"
ENV_FILE="/root/.backup_env"

# Env dosyasını kontrol et
if [ ! -f "$ENV_FILE" ]; then
    echo "HATA: Env dosyası bulunamadı: $ENV_FILE"
    exit 1
fi

# Env dosyasını yükle
source "$ENV_FILE"

# Kritik bağımlılıkları kontrol et
command -v 7z >/dev/null 2>&1 || { echo "HATA: 7zip yüklü değil"; exit 1; }

# Kritik değişkenleri kontrol et
for var in BACKUP_DIR ZIP_DIR ZABBIX_SERVER ENCRYPTION_KEY_FILE; do
    if [ -z "${!var}" ]; then
        echo "HATA: $var değişkeni tanımlanmamış"
        exit 1
    fi
done

# Dizinlerin varlığını kontrol et
for dir in "$BACKUP_DIR" "$ZIP_DIR"; do
    if [ ! -d "$dir" ]; then
        echo "HATA: $dir dizini mevcut değil"
        exit 1
    fi
done

# Şifreleme anahtarını kontrol et
if [ ! -f "$ENCRYPTION_KEY_FILE" ]; then
    # Rastgele 32 karakterlik şifre oluştur
    tr -dc 'A-Za-z0-9!@#$%^&*()' < /dev/urandom | head -c 32 > "$ENCRYPTION_KEY_FILE"
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
    local compression_speed=${3:-"ultra"}  # Varsayılan: fast
    local password=$(cat "$ENCRYPTION_KEY_FILE")
    local start_time=$(date +%s)
    
    # Kaynak dizin boyutunu al
    local original_size=$(du -sm "$source_dir" | cut -f1)
    log_message "Sıkıştırma ve şifreleme başlıyor: $source_dir (Boyut: ${original_size}MB, Mod: $compression_speed)"
    echo "Sıkıştırma ve şifreleme başlıyor: $source_dir (Boyut: ${original_size}MB, Mod: $compression_speed)"
    send_to_zabbix "$original_size" "backup.tar.original_size"
    
    # Sıkıştırma parametrelerini ayarla
    local compression_params
    case "$compression_speed" in
        "ultra")
            compression_params="-t7z -m0=lz4 -mx=1 -mfb=16 -md=8m -ms=off -mhe=on"
            ;;
        "fast")
            compression_params="-t7z -m0=lzma2 -mx=3 -mfb=32 -md=16m -ms=off -mhe=on"
            ;;
        "max")
            compression_params="-t7z -m0=lzma2 -mx=9 -mfb=64 -md=32m -ms=on -mhe=on"
            ;;
        *)
            compression_params="-t7z -m0=lzma2 -mx=3 -mfb=32 -md=16m -ms=off -mhe=on"
            ;;
    esac
    
    # 7zip ile sıkıştır ve şifrele
    7z a $compression_params -p"$password" "$target_file" "$source_dir" >/dev/null 2>&1
    local zip_status=$?
    
    if [ $zip_status -eq 0 ]; then
        # Bitiş zamanı ve süre hesaplama
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        # Şifrelenmiş dosya boyutu
        local encrypted_size=$(get_file_size "$target_file")
        local compression_ratio=$(calculate_compression_ratio $original_size $encrypted_size)
        local speed=$(echo "scale=2; $original_size / $duration" | bc)
        
        local success_msg="Sıkıştırma ve şifreleme başarılı: ${encrypted_size}MB (Oran: %${compression_ratio}, Hız: ${speed}MB/s, Süre: ${duration}s)"
        log_message "$success_msg"
        echo "$success_msg"
        
        # Metrikleri Zabbix'e gönder
        send_to_zabbix "$encrypted_size" "backup.tar.encrypted_size"
        send_to_zabbix "$compression_ratio" "backup.tar.compression_ratio"
        send_to_zabbix "$speed" "backup.tar.speed"
        send_to_zabbix "$duration" "backup.tar.duration"
        
        # Şifreleme doğruluğunu test et
        7z t -p"$password" "$target_file" >/dev/null 2>&1
        local verify_status=$?
        
        if [ $verify_status -eq 0 ]; then
            log_message "Yedek doğrulama başarılı: $target_file"
            echo "Yedek doğrulama başarılı: $target_file"
            send_to_zabbix "1" "backup.tar.verify"
            return 0
        else
            log_message "HATA: Yedek doğrulama başarısız: $target_file"
            echo "HATA: Yedek doğrulama başarısız: $target_file"
            send_to_zabbix "0" "backup.tar.verify"
            return 1
        fi
    else
        log_message "HATA: Sıkıştırma ve şifreleme başarısız: $source_dir"
        echo "HATA: Sıkıştırma ve şifreleme başarısız: $source_dir"
        send_to_zabbix "0" "backup.tar.status"
        return 1
    fi
}

# Ana fonksiyon
main() {
    # Sıkıştırma hızını kontrol et (env dosyasından veya varsayılan)
    local compression_speed=${COMPRESSION_SPEED:-"ultra"}
    
    # Geçerli bir sıkıştırma hızı mı kontrol et
    case "$compression_speed" in
        "ultra"|"fast"|"max") ;;
        *)
            log_message "UYARI: Geçersiz sıkıştırma hızı '$compression_speed'. Varsayılan 'ultra' kullanılıyor."
            compression_speed="ultra"
            ;;
    esac
    
    # BACKUP_DIR içeriğini kontrol et ve logla
    if [ ! -d "$BACKUP_DIR" ]; then
        log_message "HATA: $BACKUP_DIR dizini mevcut değil!"
        echo "HATA: $BACKUP_DIR dizini mevcut değil!"
        exit 1
    fi

    echo "Yedek dizini içeriği:" >> "$LOG_FILE"
    ls -la "$BACKUP_DIR" >> "$LOG_FILE"

    # Tüm SQL dosyalarını bul
    echo "SQL dosyaları aranıyor: $BACKUP_DIR/*.sql" >> "$LOG_FILE"
    local sql_files=$(find "$BACKUP_DIR" -maxdepth 4 -type f -name "*.sql" -mmin -1440 -printf '%T@ %p\n' | sort -nr)
    
    if [ -z "$sql_files" ]; then
        log_message "HATA: Hiç SQL yedek dosyası bulunamadı!"
        echo "HATA: Hiç SQL yedek dosyası bulunamadı!"
        echo "Dizin içeriği:"
        ls -la "$BACKUP_DIR"
        exit 1
    fi

    local success_count=0
    local total_count=0

    # Her SQL dosyası için ayrı işlem yap
    echo "$sql_files" | while read timestamp filepath; do
        if [ -n "$filepath" ]; then
            ((total_count++))
            
            # SQL dosyasının boyutunu kontrol et
            local file_size=$(du -sm "$filepath" | cut -f1)
            local available_space=$(df -m "$ZIP_DIR" | tail -1 | awk '{print $4}')
            
            if [ $available_space -lt $file_size ]; then
                log_message "HATA: $filepath için yeterli alan yok. Gerekli: ${file_size}MB, Mevcut: ${available_space}MB"
                echo "HATA: $filepath için yeterli alan yok. Gerekli: ${file_size}MB, Mevcut: ${available_space}MB"
                continue
            fi
            
            # Dosya adından veritabanı adını çıkar
            local db_name=$(basename "$filepath" .sql)
            local datetime=$(date +%Y%m%d_%H%M%S)
            local target_file="$ZIP_DIR/backup_${db_name}_${datetime}.7z"
            
            log_message "İşleniyor: $filepath (Sıkıştırma Modu: $compression_speed)"
            echo "İşleniyor: $filepath (Sıkıştırma Modu: $compression_speed)"
            
            # Geçici bir dizin oluştur
            local temp_dir="${BACKUP_DIR}/temp_${db_name}_${datetime}"
            mkdir -p "$temp_dir"
            cp "$filepath" "$temp_dir/"
            
            # Sıkıştırma ve şifreleme işlemini başlat
            if compress_and_encrypt_backup "$temp_dir" "$target_file" "$compression_speed"; then
                ((success_count++))
                log_message "$filepath başarıyla sıkıştırıldı: $target_file"
                echo "$filepath başarıyla sıkıştırıldı: $target_file"
            else
                log_message "HATA: $filepath sıkıştırma başarısız!"
                echo "HATA: $filepath sıkıştırma başarısız!"
            fi
            
            # Geçici dizini temizle
            rm -rf "$temp_dir"
        fi
    done

    # Sonuç raporu
    local summary="Toplam: $total_count dosya, Başarılı: $success_count, Başarısız: $((total_count - success_count))"
    log_message "$summary"
    echo "$summary"
    
    if [ $success_count -eq 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Scripti çalıştır
main
