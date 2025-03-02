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

# ZIP_DIR'deki tüm 7z dosyalarını tek tek pCloud'a yükle
for file in $ZIP_DIR/*; do
    echo "Yükleniyor: $file"
    ./pcloud.sh "$file" "$PCLOUD_FOLDER_ID"
    echo "Yüklendi: $file"
done
rm -rf /home/zipbackup/*

# CHECKSUM_DIR'deki tüm checksum dosyalarını tek tek pCloud'a yükle
for file in $CHECKSUM_DIR/*; do
    echo "Yükleniyor: $file"
    ./pcloud.sh "$file" "$PCLOUD_FOLDER_ID"
    echo "Yüklendi: $file"
done
rm -rf /home/checksums/*






