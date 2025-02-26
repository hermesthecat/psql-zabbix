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
    local password=$(cat "$ENCRYPTION_KEY_FILE")
    local start_time=$(date +%s)
    
    # Kaynak dizin boyutunu al
    local original_size=$(du -sm "$source_dir" | cut -f1)
    log_message "Sıkıştırma ve şifreleme başlıyor: $source_dir (Boyut: ${original_size}MB)"
    echo "Sıkıştırma ve şifreleme başlıyor: $source_dir (Boyut: ${original_size}MB)"
    send_to_zabbix "$original_size" "backup.tar.original_size"
    
    # 7zip ile sıkıştır ve şifrele
    7z a -t7z -m0=lzma2 -mx=9 -mfb=64 -md=32m -ms=on -mhe=on -p"$password" "$target_file" "$source_dir" >/dev/null 2>&1
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
    # En son yedek dizinini bul
    local latest_backup=$(find $BACKUP_DIR/ -type d -name "backup_*" | sort -r | head -n 1)
    
    if [ -z "$latest_backup" ]; then
        log_message "HATA: Sıkıştırılacak yedek dizini bulunamadı!"
        echo "HATA: Sıkıştırılacak yedek dizini bulunamadı!"
        exit 1
    fi
    
    # Yedek dizininin yaşını kontrol et (24 saatten eski olmamalı)
    local backup_age=$(find "$latest_backup" -maxdepth 0 -mtime +1)
    if [ ! -z "$backup_age" ]; then
        log_message "UYARI: En son yedek 24 saatten daha eski!"
        echo "UYARI: En son yedek 24 saatten daha eski!"
    fi
    
    # Hedef dizinde yeterli alan var mı kontrol et
    local required_space=$(du -sm "$latest_backup" | cut -f1)
    local available_space=$(df -m "$ZIP_DIR" | tail -1 | awk '{print $4}')
    if [ $available_space -lt $required_space ]; then
        log_message "HATA: Hedef dizinde yeterli alan yok. Gerekli: ${required_space}MB, Mevcut: ${available_space}MB"
        echo "HATA: Hedef dizinde yeterli alan yok. Gerekli: ${required_space}MB, Mevcut: ${available_space}MB"
        exit 1
    fi
    
    # Hedef dosya adını oluştur
    local datetime=$(date +%Y%m%d_%H%M%S)
    local backup_name=$(basename "$latest_backup" | cut -d'/' -f2)
    local target_file="$ZIP_DIR/backup_${backup_name}_${datetime}.7z"
    
    log_message "Yedek sıkıştırma ve şifreleme işlemi başlatılıyor..."
    echo "Yedek sıkıştırma ve şifreleme işlemi başlatılıyor..."
    
    # Sıkıştırma ve şifreleme işlemini başlat
    if compress_and_encrypt_backup "$latest_backup" "$target_file"; then
        log_message "Yedek sıkıştırma ve şifreleme işlemi başarıyla tamamlandı"
        echo "Yedek sıkıştırma ve şifreleme işlemi başarıyla tamamlandı"
        exit 0
    else
        log_message "Yedek sıkıştırma ve şifreleme işlemi başarısız!"
        echo "Yedek sıkıştırma ve şifreleme işlemi başarısız!"
        exit 1
    fi
}

# Scripti çalıştır
main
