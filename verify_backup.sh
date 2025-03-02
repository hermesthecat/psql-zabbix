#!/bin/bash

LOG_FILE="/var/log/backup_verify.log"
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

# Zabbix'e bildirim gönderme fonksiyonu
send_to_zabbix() {
    MESSAGE=$1
    zabbix_sender -z "$ZABBIX_SERVER" -s "$HOSTNAME" -k "backup.verify" -o "$MESSAGE" >/dev/null 2>&1
}

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    send_to_zabbix "$1"
}

# En son yedek dosyasını bulma
find_latest_backup() {
    local latest_backup=$(find $ZIP_DIR -type f -name "backup_*.7z" | sort -r | head -n 1)
    echo "$latest_backup"
}

# Yedek dosyasının bütünlüğünü kontrol etme
verify_backup_integrity() {
    local backup_file=$1
    local password=$(cat "$ENCRYPTION_KEY_FILE")
    
    # 7zip bütünlük kontrolü
    7z t -p"$password" "$backup_file" >/dev/null 2>&1
    return $?
}

# Yedek içeriğini test etme
test_backup_restore() {
    local backup_file=$1
    local temp_dir=$(mktemp -d)
    local password=$(cat "$ENCRYPTION_KEY_FILE")
    local success=0
    
    log_message "Test restore başlatılıyor: $backup_file"
    echo "Test restore başlatılıyor: $backup_file"
    
    # 7zip arşivini geçici dizine aç
    7z x -p"$password" -o"$temp_dir" "$backup_file" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        log_message "HATA: Yedek dosyası açılamadı"
        echo "HATA: Yedek dosyası açılamadı"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # SQL dosyasını bul
    local sql_file=$(find "$temp_dir" -type f -name "*.sql" | head -n 1)
    if [ -z "$sql_file" ]; then
        log_message "HATA: SQL dosyası bulunamadı"
        echo "HATA: SQL dosyası bulunamadı"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Test veritabanı oluşturma
    PGPASSWORD=$PGPASSWORD psql -h localhost -U postgres -c "DROP DATABASE IF EXISTS $TEST_DB_NAME;" >/dev/null 2>&1
    PGPASSWORD=$PGPASSWORD psql -h localhost -U postgres -c "CREATE DATABASE $TEST_DB_NAME;" >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        # Yedeği test veritabanına yükleme
        PGPASSWORD=$PGPASSWORD psql -h localhost -U postgres -d "$TEST_DB_NAME" -f "$sql_file" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            # Veritabanı boyutunu ve tablo sayısını kontrol etme
            local db_size=$(PGPASSWORD=$PGPASSWORD psql -h localhost -U postgres -d "$TEST_DB_NAME" -t -c "SELECT pg_size_pretty(pg_database_size('$TEST_DB_NAME'));")
            local table_count=$(PGPASSWORD=$PGPASSWORD psql -h localhost -U postgres -d "$TEST_DB_NAME" -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';")
            
            log_message "Test restore başarılı! DB Boyutu: $db_size, Tablo Sayısı: $table_count"
            echo "Test restore başarılı! DB Boyutu: $db_size, Tablo Sayısı: $table_count"
            success=1
        else
            log_message "HATA: Test restore başarısız - SQL yükleme hatası"
            echo "HATA: Test restore başarısız - SQL yükleme hatası"
        fi
    else
        log_message "HATA: Test restore başarısız - Test DB oluşturulamadı"
        echo "HATA: Test restore başarısız - Test DB oluşturulamadı"
    fi
    
    # Temizlik
    PGPASSWORD=$PGPASSWORD psql -h localhost -U postgres -c "DROP DATABASE IF EXISTS $TEST_DB_NAME;" >/dev/null 2>&1
    rm -rf "$temp_dir"
    
    return $success
}

# Checksum dizinini oluştur
create_checksum_dir() {
    if [ ! -d "$CHECKSUM_DIR" ]; then
        mkdir -p "$CHECKSUM_DIR"
        log_message "Checksum dizini oluşturuldu: $CHECKSUM_DIR"
        echo "Checksum dizini oluşturuldu: $CHECKSUM_DIR"
    fi
}

# Checksum oluşturma ve kaydetme
generate_checksums() {
    local backup_file=$1
    local backup_filename=$(basename "$backup_file")
    local checksum_file="${CHECKSUM_DIR}/${backup_filename}.checksum"
    
    # MD5 ve SHA256 checksumları oluştur
    local md5sum=$(md5sum "$backup_file" | awk '{print $1}')
    local sha256sum=$(sha256sum "$backup_file" | awk '{print $1}')
    
    # Checksum dosyasını oluştur
    echo "Dosya: $backup_filename" > "$checksum_file"
    echo "Tarih: $(date '+%Y-%m-%d %H:%M:%S')" >> "$checksum_file"
    echo "MD5: $md5sum" >> "$checksum_file"
    echo "SHA256: $sha256sum" >> "$checksum_file"
    echo "Boyut: $(du -h "$backup_file" | cut -f1)" >> "$checksum_file"
    
    log_message "Checksumlar oluşturuldu: $checksum_file"
    echo "Checksumlar oluşturuldu: $checksum_file"

    # Checksum değerlerini döndür
    echo "$md5sum:$sha256sum"
}

# Checksum doğrulama
verify_checksums() {
    local backup_file=$1
    local backup_filename=$(basename "$backup_file")
    local checksum_file="${CHECKSUM_DIR}/${backup_filename}.checksum"
    
    # Eğer checksum dosyası yoksa, yeni oluştur
    if [ ! -f "$checksum_file" ]; then
        log_message "Checksum dosyası bulunamadı, yeni oluşturuluyor..."
        echo "Checksum dosyası bulunamadı, yeni oluşturuluyor..."
        generate_checksums "$backup_file"
        return 0
    fi
    
    # Mevcut checksumları oku
    local stored_md5=$(grep "MD5:" "$checksum_file" | cut -d' ' -f2)
    local stored_sha256=$(grep "SHA256:" "$checksum_file" | cut -d' ' -f2)
    
    # Yeni checksumları hesapla
    local current_md5=$(md5sum "$backup_file" | awk '{print $1}')
    local current_sha256=$(sha256sum "$backup_file" | awk '{print $1}')
    
    # Karşılaştır
    if [ "$stored_md5" != "$current_md5" ]; then
        log_message "HATA: MD5 checksum eşleşmiyor!"
        echo "HATA: MD5 checksum eşleşmiyor!"
        log_message "Beklenen: $stored_md5"
        echo "Beklenen: $stored_md5"
        log_message "Hesaplanan: $current_md5"
        echo "Hesaplanan: $current_md5"
        return 1
    fi
    
    if [ "$stored_sha256" != "$current_sha256" ]; then
        log_message "HATA: SHA256 checksum eşleşmiyor!"
        echo "HATA: SHA256 checksum eşleşmiyor!"
        log_message "Beklenen: $stored_sha256"
        echo "Beklenen: $stored_sha256"
        log_message "Hesaplanan: $current_sha256"
        echo "Hesaplanan: $current_sha256"
        return 1
    fi
    
    log_message "Checksum doğrulaması başarılı"
    echo "Checksum doğrulaması başarılı"
    return 0
}

# Ana doğrulama süreci
main() {
    log_message "Yedek doğrulama süreci başlatıldı"
    echo "Yedek doğrulama süreci başlatıldı"
    
    # Checksum dizinini oluştur
    create_checksum_dir
    
    local backup_file=$(find_latest_backup)
    if [ -z "$backup_file" ]; then
        log_message "HATA: Yedek dosyası bulunamadı!"
        echo "HATA: Yedek dosyası bulunamadı!"
        exit 1
    fi
    
    log_message "En son yedek dosyası: $backup_file"
    
    # Dosya bütünlüğü kontrolü
    if ! verify_backup_integrity "$backup_file"; then
        log_message "HATA: Yedek dosyası bütünlük kontrolünden geçemedi!"
        echo "HATA: Yedek dosyası bütünlük kontrolünden geçemedi!"
        exit 1
    fi
    log_message "Dosya bütünlük kontrolü başarılı"
    echo "Dosya bütünlük kontrolü başarılı"
    
    # Checksum kontrolü
    if ! verify_checksums "$backup_file"; then
        log_message "HATA: Checksum doğrulaması başarısız!"
        echo "HATA: Checksum doğrulaması başarısız!"
        exit 1
    fi
    
    # Test restore işlemi
    if ! test_backup_restore "$backup_file"; then
        log_message "HATA: Test restore işlemi başarısız!"
        echo "HATA: Test restore işlemi başarısız!"
        exit 1
    fi
    
    # Yeni checksum oluştur
    generate_checksums "$backup_file"
    
    log_message "Yedek doğrulama süreci başarıyla tamamlandı"
    echo "Yedek doğrulama süreci başarıyla tamamlandı"

    rm -rf "$ZIP_DIR"/*
    rm -rf "$CHECKSUM_DIR"/*
}

# Script'i çalıştır
main 