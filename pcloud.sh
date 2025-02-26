#!/bin/bash

# Yapılandırma
LOG_FILE="/var/log/pcloud_upload.log"
ENV_FILE="/root/.backup_env"

# Kimlik bilgilerini yükle
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "HATA: pCloud kimlik bilgileri dosyası bulunamadı: $ENV_FILE"
    exit 1
fi

# Kimlik bilgilerini kontrol et
if [ -z "$PCLOUD_USERNAME" ] || [ -z "$PCLOUD_PASSWORD" ]; then
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
    local auth_response=$(curl -s "https://eapi.pcloud.com/userinfo?getauth=1&username=$PCLOUD_USERNAME&password=$PCLOUD_PASSWORD")
    
    if echo "$auth_response" | grep -q '"auth":'; then
        local auth_token=$(echo "$auth_response" | grep -o '"auth":"[^"]*"' | cut -d'"' -f4)
        if [ ! -z "$auth_token" ]; then
            echo "$auth_token"
            return 0
        fi
    fi
    
    log_message "HATA: pCloud login başarısız! API Yanıtı: $auth_response"
    echo "HATA: pCloud login başarısız! API Yanıtı: $auth_response"
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
    local folder_id=$2
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
        -F "folderid=$folder_id" \
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
        
        # pCloud'daki dosya boyutunu kontrol et
        local cloud_file_id=$(echo "$response" | grep -o '"fileid":[0-9]*' | cut -d':' -f2)
        if [ ! -z "$cloud_file_id" ]; then
            local check_response=$(curl "https://eapi.pcloud.com/checksumfile?auth=$auth_token&fileid=$cloud_file_id" 2>/dev/null)
            local cloud_size=$(echo "$check_response" | grep -o '"size":[0-9]*' | cut -d':' -f2)
            cloud_size=$((cloud_size / 1024 / 1024)) # Byte'dan MB'a çevir
            
            if [ "$cloud_size" -eq "$file_size" ]; then
                log_message "pCloud dosya boyutu doğrulandı"
                echo "pCloud dosya boyutu doğrulandı"
            else
                log_message "HATA: pCloud dosya boyutu eşleşmiyor! Yerel: ${file_size}MB, pCloud: ${cloud_size}MB"
                echo "HATA: pCloud dosya boyutu eşleşmiyor! Yerel: ${file_size}MB, pCloud: ${cloud_size}MB"
                return 1
            fi
        fi
        
        return 0
    else
        local error_msg="HATA: pCloud yüklemesi başarısız! API Yanıtı: $response"
        log_message "$error_msg"
        echo "HATA: pCloud yüklemesi başarısız! API Yanıtı: $response"
        return 1
    fi
}

# Ana fonksiyon
main() {
    if [ $# -ne 2 ]; then
        log_message "HATA: Eksik parametre! Kullanım: $0 <dosya_yolu> <folder_id>"
        echo "HATA: Eksik parametre! Kullanım: $0 <dosya_yolu> <folder_id>"
        exit 1
    fi
    
    local file_path=$1
    local folder_id=$2
    
    # Dosya kontrolü
    if [ ! -f "$file_path" ]; then
        log_message "HATA: Dosya bulunamadı: $file_path"
        echo "HATA: Dosya bulunamadı: $file_path"
        exit 1
    fi
    
    # pCloud'a yükleme
    if upload_to_pcloud "$file_path" "$folder_id"; then
        log_message "PCloud yükleme işlemi başarıyla tamamlandı"
        echo "PCloud yükleme işlemi başarıyla tamamlandı"
        exit 0
    else
        log_message "PCloud yükleme işlemi başarısız!"
        echo "PCloud yükleme işlemi başarısız!"
        exit 1
    fi
}

# Scripti çalıştır
main "$@"