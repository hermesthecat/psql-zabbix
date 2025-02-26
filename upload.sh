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

# Yedek dosyasını oluştur
cp /home/zipbackup/DB-Backup_All.tar.gz /home/zipbackup/DB-Backup_All.$(date +%y)$(date +%m)$(date +%d).tar.gz

# PCloud'a yükle
./pcloud.sh /home/zipbackup/DB-Backup_All.$(date +%y)$(date +%m)$(date +%d).tar.gz 11111111111

# Yedek dosyasını temizle
rm -rf /home/zipbackup/DB-Backup_All.*

