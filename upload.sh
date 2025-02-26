#!/bin/bash

# Yapılandırma
LOG_FILE="/var/log/pcloud_upload.log"
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

# Kimlik bilgilerini kontrol et
if [ -z "$PCLOUD_USERNAME" ] || [ -z "$PCLOUD_PASSWORD" ] || [ -z "$PCLOUD_FOLDER_ID" ]; then
    echo "HATA: pCloud kimlik bilgileri eksik! Lütfen $ENV_FILE dosyasını kontrol edin."
    exit 1
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
    send_to_zabbix "$message" "pcloud.upload"
}

# pCloud'a login olma
get_auth_token() {
    echo "DEBUG: pCloud login denemesi başlıyor..." >> "$LOG_FILE"
    echo "DEBUG: Kullanılan endpoint: https://eapi.pcloud.com/userinfo" >> "$LOG_FILE"
    echo "DEBUG: Kullanıcı adı uzunluğu: ${#PCLOUD_USERNAME}" >> "$LOG_FILE"
    echo "DEBUG: Şifre uzunluğu: ${#PCLOUD_PASSWORD}" >> "$LOG_FILE"
    
    # Curl isteğini verbose modda yapalım ve logları saklayalım
    local auth_response=$(curl -v \
        "https://eapi.pcloud.com/userinfo?getauth=1&username=$PCLOUD_USERNAME&password=$PCLOUD_PASSWORD" \
        2>> "$LOG_FILE")
    
    echo "DEBUG: API Yanıtı: $auth_response" >> "$LOG_FILE"
    
    if echo "$auth_response" | grep -q '"auth":'; then
        local auth_token=$(echo "$auth_response" | grep -o '"auth":"[^"]*"' | cut -d'"' -f4)
        if [ ! -z "$auth_token" ]; then
            echo "DEBUG: Auth token başarıyla alındı" >> "$LOG_FILE"
            echo "$auth_token"
            return 0
        fi
    fi
    
    # Hata detaylarını ayıklayalım
    local error_code=$(echo "$auth_response" | grep -o '"result":[0-9]*' | cut -d':' -f2)
    local error_msg=$(echo "$auth_response" | grep -o '"error":"[^"]*"' | cut -d'"' -f4)
    
    echo "DEBUG: Hata kodu: $error_code" >> "$LOG_FILE"
    echo "DEBUG: Hata mesajı: $error_msg" >> "$LOG_FILE"
    
    log_message "HATA: pCloud login başarısız! Hata Kodu: $error_code, Mesaj: $error_msg"
    return 1
}

# Dosya boyutunu alma (MB cinsinden)
get_file_size() {
    local file=$1
    local size=$(du -m "$file" | cut -f1)
    echo "$size"
}

# pCloud'a yükleme fonksiyonu
upload_to_pcloud() {
    local file_path=$1
    local file_name=$(basename "$file_path")
    local file_size=$(get_file_size "$file_path")
    
    # pCloud'a login ol
    local auth_token=$(get_auth_token)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Yükleme başlangıç zamanı
    local start_time=$(date +%s)
    
    log_message "pCloud yüklemesi başlıyor: $file_name (Boyut: ${file_size}MB)"
    echo "pCloud yüklemesi başlıyor: $file_name (Boyut: ${file_size}MB)"
    send_to_zabbix "$file_size" "pcloud.upload.size"
    
    # pCloud API çağrısı
    local response=$(curl -X POST \
        -F "auth=$auth_token" \
        -F "folderid=$PCLOUD_FOLDER_ID" \
        -F "filename=@$file_path" \
        "https://eapi.pcloud.com/uploadfile" 2>/dev/null)
    
    # Yükleme bitiş zamanı
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Transfer hızını hesapla (MB/s)
    local speed=$(echo "scale=2; $file_size / $duration" | bc)
    
    # API yanıtını kontrol et
    if echo "$response" | grep -q '"result":0'; then
        local success_msg="pCloud yüklemesi başarılı: $file_name (${file_size}MB, ${speed}MB/s, ${duration}s)"
        log_message "$success_msg"
        echo "$success_msg"

        # Metrikleri Zabbix'e gönder
        send_to_zabbix "$speed" "pcloud.upload.speed"
        send_to_zabbix "$duration" "pcloud.upload.duration"
        send_to_zabbix "1" "pcloud.upload.status"
        
        # pCloud'daki dosya boyutunu kontrol et
        local cloud_file_id=$(echo "$response" | grep -o '"fileid":[0-9]*' | cut -d':' -f2)
        if [ ! -z "$cloud_file_id" ]; then
            local check_response=$(curl "https://eapi.pcloud.com/checksumfile?auth=$auth_token&fileid=$cloud_file_id" 2>/dev/null)
            local cloud_size=$(echo "$check_response" | grep -o '"size":[0-9]*' | cut -d':' -f2)
            cloud_size=$((cloud_size / 1024 / 1024)) # Byte'dan MB'a çevir
            
            if [ "$cloud_size" -eq "$file_size" ]; then
                log_message "pCloud dosya boyutu doğrulandı"
                echo "pCloud dosya boyutu doğrulandı"
                return 0
            else
                log_message "HATA: pCloud dosya boyutu eşleşmiyor! Yerel: ${file_size}MB, pCloud: ${cloud_size}MB"
                echo "HATA: pCloud dosya boyutu eşleşmiyor! Yerel: ${file_size}MB, pCloud: ${cloud_size}MB"
                send_to_zabbix "0" "pcloud.upload.status"
                return 1
            fi
        fi
    else
        # Hata detaylarını ayıklayalım
        local error_code=$(echo "$response" | grep -o '"result":[0-9]*' | cut -d':' -f2)
        local error_msg=$(echo "$response" | grep -o '"error":"[^"]*"' | cut -d'"' -f4)
        
        echo "DEBUG: Upload API Yanıtı: $response" >> "$LOG_FILE"
        echo "DEBUG: Upload Hata Kodu: $error_code" >> "$LOG_FILE"
        echo "DEBUG: Upload Hata Mesajı: $error_msg" >> "$LOG_FILE"
        
        local error_msg="HATA: pCloud yüklemesi başarısız! Hata Kodu: $error_code, Mesaj: $error_msg"
        log_message "$error_msg"
        echo "$error_msg"
        send_to_zabbix "0" "pcloud.upload.status"
        return 1
    fi
}

# Ana fonksiyon
main() {
    # Son çalışmadan bu yana oluşturulan yedekleri bul (24 saat içinde)
    echo "Yeni yedekler aranıyor..." >> "$LOG_FILE"
    local new_backups=$(find "$ZIP_DIR" -type f -name "backup_*.7z" -mmin -1440 -printf '%T@ %p\n' | sort -n)
    
    if [ -z "$new_backups" ]; then
        log_message "HATA: Yüklenecek yeni yedek dosyası bulunamadı!"
        echo "HATA: Yüklenecek yeni yedek dosyası bulunamadı!"
        exit 1
    fi

    local success_count=0
    local total_count=0

    # Her yedek dosyası için ayrı işlem yap
    echo "$new_backups" | while read timestamp filepath; do
        if [ -n "$filepath" ]; then
            ((total_count++))
            
            log_message "pCloud'a yükleniyor: $filepath"
            echo "pCloud'a yükleniyor: $filepath"
            
            # pCloud'a yükleme işlemini başlat
            if upload_to_pcloud "$filepath"; then
                ((success_count++))
                log_message "$filepath başarıyla yüklendi"
                echo "$filepath başarıyla yüklendi"
                
                # Başarılı yüklemeyi Zabbix'e bildir
                send_to_zabbix "1" "backup.upload.status"
                
                # Dosya boyutunu Zabbix'e gönder
                local file_size=$(du -m "$filepath" | cut -f1)
                send_to_zabbix "$file_size" "backup.upload.size"
            else
                log_message "HATA: $filepath yükleme başarısız!"
                echo "HATA: $filepath yükleme başarısız!"
                send_to_zabbix "0" "backup.upload.status"
            fi
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

