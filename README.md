# PostgreSQL Yedekleme ve Doğrulama Sistemi

Bu proje, PostgreSQL veritabanlarının otomatik yedeklenmesi, sıkıştırılması, yüklenmesi ve doğrulanması için geliştirilmiş bir script koleksiyonudur. Zabbix monitoring sistemi ile entegre çalışır.

## Özellikler

- Otomatik PostgreSQL yedekleme
- Günlük, haftalık ve aylık yedek rotasyonu
- Yedeklerin sıkıştırılması (bzip2/gzip)
- AES-256-CBC şifreleme ile güvenli yedekleme
- Uzak sunucuya yedek yükleme
- pCloud entegrasyonu
- Kapsamlı yedek doğrulama sistemi:
  - MD5 ve SHA256 checksum kontrolü
  - Arşiv bütünlüğü testi
  - Şifreleme doğrulama testi
  - Test veritabanında restore denemesi
- Zabbix entegrasyonu ile monitoring
- Merkezi yapılandırma yönetimi
- Detaylı loglama sistemi

## Sistem Mimarisi

### Script Yapısı
- **fullbackup.sh**: Ana koordinatör script
- **pgbackup.sh**: PostgreSQL yedekleme işlemleri
- **tar.sh**: Yedek sıkıştırma işlemleri
- **upload.sh**: Uzak sunucuya yükleme işlemleri
- **pcloud.sh**: pCloud'a yükleme işlemleri
- **verify_backup.sh**: Yedek doğrulama işlemleri

### Yapılandırma Dosyaları
- **/.backup_env**: Merkezi yapılandırma dosyası
- **/.pgpass**: PostgreSQL kimlik bilgileri
- **/.pcloud_credentials**: pCloud kimlik bilgileri (opsiyonel)
- **/.backup_encryption_key**: AES şifreleme anahtarı (otomatik oluşturulur)

### Log Dosyaları
- **/var/log/backup_runner.log**: Ana yedekleme logları
- **/var/log/backup_verify.log**: Doğrulama logları
- **/var/log/backup_tar.log**: Sıkıştırma logları
- **/var/log/pcloud_upload.log**: pCloud yükleme logları

## Kurulum

1. Scriptleri kopyalayın:
```bash
cp *.sh /root/
chmod +x /root/*.sh
```

2. Dizinleri oluşturun:
```bash
mkdir -p /home/pg_backup/backup/{daily,weekly,monthly,checksums}
mkdir -p /var/log
touch /var/log/backup_{runner,verify,tar}.log
touch /var/log/pcloud_upload.log
chmod 640 /var/log/backup_*.log
```

3. Merkezi yapılandırma dosyasını oluşturun:
```bash
cat > /root/.backup_env << 'EOF'
PCLOUD_USERNAME="your_username"
PCLOUD_PASSWORD="your_password"

ZABBIX_SERVER="10.10.10.10"
HOSTNAME="Database-Master"

BACKUP_DIR="/home/pg_backup/backup"

TEST_DB_NAME="verify_test_db"

CHECKSUM_DIR="${BACKUP_DIR}/checksums"
EOF

chmod 600 /root/.backup_env
```

4. PostgreSQL bağlantı dosyasını oluşturun:
```bash
echo "localhost:5432:*:postgres:your_password" > ~/.pgpass
chmod 600 ~/.pgpass
```

5. Şifreleme anahtarı otomatik olarak oluşturulacaktır:
   - İlk çalıştırmada `/root/.backup_encryption_key` dosyası oluşturulur
   - 32 byte'lık rastgele AES-256 anahtarı üretilir
   - Dosya izinleri 600 olarak ayarlanır (sadece root okuyabilir)
   - **ÖNEMLİ**: Bu anahtarı güvenli bir yerde yedeklemeyi unutmayın!

## Kullanım

### Manuel Çalıştırma
```bash
# Tam yedekleme döngüsü
/root/fullbackup.sh

# Sadece doğrulama
/root/verify_backup.sh

# Sadece pCloud'a yükleme
/root/pcloud.sh /yol/dosya.tar.gz folder_id
```

### Otomatik Çalıştırma
```bash
# Crontab yapılandırması
0 1 * * * /root/fullbackup.sh  # Her gece 01:00'de yedekleme
0 7 * * * /root/verify_backup.sh  # Her sabah 07:00'de doğrulama
```

## Zabbix Monitoring

### Metrik Grupları

1. **Yedekleme Durumu** (backup.status):
   - Genel yedekleme durumu
   - Adım adım ilerleme
   - Hata bildirimleri

2. **Doğrulama Metrikleri** (backup.verify):
   - Checksum kontrolleri
   - Restore testleri
   - Bütünlük doğrulaması

3. **Sıkıştırma Metrikleri** (backup.tar):
   - Orijinal boyut (MB)
   - Şifrelenmiş boyut (MB)
   - Sıkıştırma oranı (%)
   - İşlem hızı (MB/s)
   - İşlem süresi (s)
   - Şifreleme durumu

4. **pCloud Metrikleri** (pcloud.upload):
   - Yükleme boyutu (MB)
   - Transfer hızı (MB/s)
   - İşlem süresi (s)
   - Hata durumları

### Önerilen Triggerlar ve Alarmlar

1. **Yedekleme Durumu Alarmları**:
```
# Yedekleme hatası
Name: Backup Error on {HOST.NAME}
Expression: {HOST.NAME:backup.status.str("ERROR")}=1
Priority: High
Description: Yedekleme işlemi sırasında hata oluştu. Lütfen /var/log/backup_runner.log dosyasını kontrol edin.

# Yedekleme uzun sürüyor
Name: Backup Taking Too Long on {HOST.NAME}
Expression: {HOST.NAME:backup.status.str("started")}>0 and {HOST.NAME:backup.status.nodata(3600)}=1
Priority: Warning
Description: Yedekleme işlemi 1 saatten uzun süredir devam ediyor veya takılmış olabilir.

# Yedekleme başlamadı
Name: Backup Not Started on {HOST.NAME}
Expression: {HOST.NAME:backup.status.nodata(86400)}=1
Priority: High
Description: Son 24 saat içinde yedekleme işlemi başlatılmadı.
```

2. **Doğrulama Alarmları**:
```
# Doğrulama hatası
Name: Backup Verification Failed on {HOST.NAME}
Expression: {HOST.NAME:backup.verify.str("HATA")}=1
Priority: High
Description: Yedek doğrulama işlemi başarısız. Detaylar için /var/log/backup_verify.log dosyasını kontrol edin.

# Checksum hatası
Name: Backup Checksum Mismatch on {HOST.NAME}
Expression: {HOST.NAME:backup.verify.str("checksum eşleşmiyor")}=1
Priority: High
Description: Yedek dosyasının checksum değerleri eşleşmiyor. Dosya bozulmuş olabilir.

# Restore testi başarısız
Name: Backup Restore Test Failed on {HOST.NAME}
Expression: {HOST.NAME:backup.verify.str("restore başarısız")}=1
Priority: High
Description: Test veritabanına restore işlemi başarısız oldu.
```

3. **Sıkıştırma ve Şifreleme Performans Alarmları**:
```
# Düşük sıkıştırma oranı
Name: Low Compression Ratio on {HOST.NAME}
Expression: {HOST.NAME:backup.tar.compression_ratio.last()}<30
Priority: Warning
Description: Sıkıştırma oranı %30'un altında. Yedek dosyaları beklenenden büyük olabilir.

# Düşük işlem hızı
Name: Slow Encryption Speed on {HOST.NAME}
Expression: {HOST.NAME:backup.tar.speed.last()}<5
Priority: Warning
Description: Şifreleme ve sıkıştırma hızı 5MB/s'nin altında. Sistem performans sorunu olabilir.

# Uzun işlem süresi
Name: Encryption Taking Too Long on {HOST.NAME}
Expression: {HOST.NAME:backup.tar.duration.last()}>1800
Priority: Warning
Description: Şifreleme ve sıkıştırma işlemi 30 dakikadan uzun sürdü.

# Şifreleme hatası
Name: Encryption Error on {HOST.NAME}
Expression: {HOST.NAME:backup.tar.str("HATA")}=1
Priority: High
Description: Şifreleme işlemi sırasında hata oluştu.

# Şifreleme doğrulama hatası
Name: Encryption Verification Failed on {HOST.NAME}
Expression: {HOST.NAME:backup.tar.str("şifreleme doğrulama")}=1
Priority: High
Description: Şifreleme doğrulama testi başarısız oldu.
```

4. **pCloud Yükleme Alarmları**:
```
# Düşük yükleme hızı
Name: Slow pCloud Upload Speed on {HOST.NAME}
Expression: {HOST.NAME:pcloud.upload.speed.last()}<0.5
Priority: Warning
Description: pCloud yükleme hızı 0.5MB/s'nin altında. İnternet bağlantısını kontrol edin.

# Uzun yükleme süresi
Name: pCloud Upload Taking Too Long on {HOST.NAME}
Expression: {HOST.NAME:pcloud.upload.duration.last()}>7200
Priority: Warning
Description: pCloud yüklemesi 2 saatten uzun süredir devam ediyor.

# Yükleme hatası
Name: pCloud Upload Error on {HOST.NAME}
Expression: {HOST.NAME:pcloud.upload.str("HATA")}=1
Priority: High
Description: pCloud yükleme işlemi başarısız oldu.

# Boyut eşleşmeme hatası
Name: pCloud File Size Mismatch on {HOST.NAME}
Expression: {HOST.NAME:pcloud.upload.str("boyutu eşleşmiyor")}=1
Priority: High
Description: Yüklenen dosyanın boyutu pCloud'daki dosya boyutu ile eşleşmiyor.
```

5. **Disk Alan Kullanımı Alarmları**:
```
# Yedek dizini dolmak üzere
Name: Backup Directory Running Out of Space on {HOST.NAME}
Expression: {HOST.NAME:vfs.fs.size[/home/pg_backup/backup,pfree].last()}<10
Priority: High
Description: Yedekleme dizininde %10'dan az boş alan kaldı.

# Log dizini dolmak üzere
Name: Log Directory Running Out of Space on {HOST.NAME}
Expression: {HOST.NAME:vfs.fs.size[/var/log,pfree].last()}<10
Priority: Warning
Description: Log dizininde %10'dan az boş alan kaldı.
```

Her trigger için önerilen eylemler:

1. **High Priority Alarmlar**:
   - SMS/Telefon bildirimi
   - E-posta bildirimi
   - Ticket oluşturma
   - Yedekleme işlemini durdurma (opsiyonel)

2. **Warning Priority Alarmlar**:
   - E-posta bildirimi
   - Slack/Teams bildirimi
   - Günlük raporda gösterme

3. **Information Priority Alarmlar**:
   - Günlük raporda gösterme
   - Dashboard'da gösterme

## Güvenlik Önlemleri

1. **Dosya İzinleri**:
   - Tüm yapılandırma dosyaları: `chmod 600`
   - Script dosyaları: `chmod 700`
   - Log dosyaları: `chmod 640`

2. **Dizin İzinleri**:
   - Yedekleme dizini: `chmod 750`
   - Log dizini: `chmod 755`

3. **Kimlik Bilgileri Yönetimi**:
   - Tüm kimlik bilgileri `.backup_env` dosyasında merkezi olarak saklanır
   - Dosya izinleri kısıtlıdır
   - Hassas bilgiler şifrelenir (opsiyonel)

## Bakım

1. **Log Rotasyonu**:
```
/etc/logrotate.d/backup_logs:
/var/log/backup_*.log {
    weekly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 640 root root
}
```

2. **Eski Yedeklerin Temizlenmesi**:
```bash
# Günlük yedekler (30 gün)
find /home/pg_backup/backup/daily -type f -mtime +30 -delete

# Haftalık yedekler (12 hafta)
find /home/pg_backup/backup/weekly -type f -mtime +84 -delete

# Aylık yedekler (6 ay)
find /home/pg_backup/backup/monthly -type f -mtime +180 -delete

# Checksum dosyaları (90 gün)
find /home/pg_backup/backup/checksums -type f -mtime +90 -delete
```

## Yazar

A. Kerem Gök

## Lisans

Bu proje GNU General Public License v3.0 altında lisanslanmıştır. 

## Yedekleri Çözme

Şifrelenmiş yedekleri çözmek için aşağıdaki adımları izleyin:

1. Şifre çözme:
```bash
openssl enc -d -aes-256-cbc -in backup_TARIH.tar.gz.enc -out backup_TARIH.tar.gz -pass file:/root/.backup_encryption_key
```

2. Arşivi açma:
```bash
tar -xzf backup_TARIH.tar.gz
```

**Önemli Notlar**:
- Şifreleme anahtarını (`/root/.backup_encryption_key`) kaybederseniz, yedekleri çözemezsiniz
- Anahtarı güvenli bir ortamda yedekleyin
- Yedek sunucularına anahtarı da taşımayı unutmayın
- Şifreleme nedeniyle yedekleme süresi ve dosya boyutu bir miktar artacaktır 