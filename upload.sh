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

cp /home/zipbackup/DB-Backup_All.tar.gz /home/zipbackup/DB-Backup_All.$(date +%y)$(date +%m)$(date +%d).tar.gz
./pcloud.sh /home/zipbackup/DB-Backup_All.$(date +%y)$(date +%m)$(date +%d).tar.gz $PCLOUD_FOLDER_ID
rm -rf /home/zipbackup/DB-Backup_All.*
