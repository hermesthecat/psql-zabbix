#!/bin/bash

# Yapılandırma
LOG_FILE="/var/log/pcloud.log"
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

# pCloud kimlik doğrulama
strAuth=$(curl -s --location --request GET "https://eapi.pcloud.com/userinfo?getauth=1&username=$PCLOUD_USERNAME&password=$PCLOUD_PASSWORD" | jq -r ".auth")
echo $strAuth

# pCloud kimlik doğrulama başarısızsa
if [ -z "$strAuth" ] || [ "$strAuth" == "null" ]; then
    echo "HATA: pCloud kimlik doğrulama başarısız oldu!"
    exit 1
fi

# pCloud'a dosya yükle
curl --location --request POST "https://eapi.pcloud.com/uploadfile?auth=$strAuth" \
--form "folderid=$2" \
--form "file=@$1"

# Dosya yükleme sonrası log dosyasına yaz
echo "Dosya yüklendi: $1" >> "$LOG_FILE"