# PostgreSQL Yedekleme ve Doğrulama Sistemi

Bu proje, PostgreSQL veritabanlarının otomatik yedeklenmesi, sıkıştırılması, yüklenmesi ve doğrulanması için geliştirilmiş bir script koleksiyonudur. Zabbix monitoring sistemi ile entegre çalışır.

## Özellikler

- Otomatik PostgreSQL yedekleme
- Günlük, haftalık ve aylık yedek rotasyonu
- 7zip ile gelişmiş sıkıştırma (LZMA2)
- AES-256 şifreleme ile güvenli yedekleme
- pCloud entegrasyonu ile otomatik bulut yedekleme
- Kapsamlı yedek doğrulama sistemi:
  - 7zip bütünlük kontrolü
  - Şifreleme doğrulama testi
  - Test veritabanında restore denemesi
- Zabbix entegrasyonu ile detaylı monitoring
- Merkezi yapılandırma yönetimi
- Detaylı loglama sistemi
- Performans metrikleri ve raporlama

## Yedek Dosya Formatı

Sistem aşağıdaki formatta yedek dosyaları oluşturur:

1. **Dizin Yapısı**:
   ```
   /home/pg_backup/backup/
   ├── daily/
   │   ├── backup_YYYYMMDD/         # PostgreSQL dump dizini
   │   └── backup_YYYYMMDD.7z       # Şifrelenmiş ve sıkıştırılmış yedek
   ├── weekly/
   │   └── backup_YYYYMMDD.7z
   └── monthly/
       └── backup_YYYYMMDD.7z
   ```

2. **Dosya İsimlendirme**:
   - Yedek dizini: `backup_YYYYMMDD`
   - Sıkıştırılmış yedek: `backup_YYYYMMDD.7z`
   - Örnek: `backup_20240226.7z`

3. **Sıkıştırma ve Şifreleme**:
   - Format: 7zip (.7z)
   - Sıkıştırma: LZMA2
   - Şifreleme: AES-256
   - Başlık şifreleme: Aktif

## Sistem Mimarisi

### Script Yapısı
- **fullbackup.sh**: Ana koordinatör script
- **pgbackup.sh**: PostgreSQL yedekleme işlemleri
- **tar.sh**: 7zip ile sıkıştırma ve şifreleme işlemleri
- **upload.sh**: pCloud'a otomatik yükleme işlemleri
- **verify_backup.sh**: Yedek doğrulama işlemleri

### Yapılandırma Dosyaları
- **/.backup_env**: Merkezi yapılandırma dosyası
- **/.pgpass**: PostgreSQL kimlik bilgileri
- **/.backup_encryption_key**: 7zip şifreleme anahtarı (otomatik oluşturulur)

### Log Dosyaları
- **/var/log/backup_runner.log**: Ana yedekleme logları
- **/var/log/backup_verify.log**: Doğrulama logları
- **/var/log/backup_tar.log**: Sıkıştırma ve şifreleme logları
- **/var/log/pcloud_upload.log**: pCloud yükleme logları

## Kurulum

1. Gerekli paketleri yükleyin:
```bash
# Debian/Ubuntu
apt-get update
apt-get install p7zip-full postgresql-client zabbix-agent

# RHEL/CentOS
yum install p7zip p7zip-plugins postgresql zabbix-agent
```

2. Scriptleri kopyalayın:
```bash
cp *.sh /root/
chmod +x /root/*.sh
```

3. Dizinleri oluşturun:
```bash
mkdir -p /home/pg_backup/backup/{daily,weekly,monthly,checksums}
mkdir -p /var/log
touch /var/log/backup_{runner,verify,tar,pcloud_upload}.log
chmod 640 /var/log/backup_*.log
```

4. Merkezi yapılandırma dosyasını oluşturun:
```bash
cat > /root/.backup_env << 'EOF'
# pCloud Yapılandırması
PCLOUD_USERNAME="your_username"
PCLOUD_PASSWORD="your_password"
PCLOUD_FOLDER_ID="your_folder_id"

# Zabbix Yapılandırması
ZABBIX_SERVER="10.10.10.10"
HOSTNAME="Database-Master"

# Yedekleme Yapılandırması
BACKUP_DIR="/home/pg_backup/backup"
TEST_DB_NAME="verify_test_db"
CHECKSUM_DIR="${BACKUP_DIR}/checksums"

# Şifreleme Yapılandırması
ENCRYPTION_KEY_FILE="/root/.backup_encryption_key"
EOF

chmod 600 /root/.backup_env
```

5. PostgreSQL bağlantı dosyasını oluşturun:
```bash
echo "localhost:5432:*:postgres:your_password" > ~/.pgpass
chmod 600 ~/.pgpass
```

## pCloud Yükleme Özellikleri

Sistem, yedekleri otomatik olarak pCloud'a yükler ve aşağıdaki özellikleri sunar:

1. **Otomatik Yedek Tespiti**:
   - En son oluşturulan 7zip yedek dosyasını bulma
   - Dosya boyutu ve tarih kontrolü
   - Yükleme öncesi doğrulama

2. **Performans İzleme**:
   - Yükleme hızı (MB/s)
   - İşlem süresi
   - Dosya boyutu takibi

3. **Hata Yönetimi**:
   - Bağlantı hataları tespiti
   - Yükleme başarısızlıkları
   - Otomatik yeniden deneme (opsiyonel)

4. **Zabbix Monitoring**:
   - Yükleme durumu
   - Performans metrikleri
   - Hata bildirimleri

## Monitoring Metrikleri

### Yedekleme Metrikleri (backup.tar.*)
- `original_size`: Orijinal yedek boyutu (MB)
- `encrypted_size`: Şifrelenmiş yedek boyutu (MB)
- `compression_ratio`: Sıkıştırma oranı (%)
- `speed`: Sıkıştırma hızı (MB/s)
- `duration`: İşlem süresi (saniye)
- `verify`: Doğrulama durumu (0/1)
- `status`: Genel işlem durumu (0/1)

### pCloud Yükleme Metrikleri (pcloud.upload.*)
- `size`: Yüklenen dosya boyutu (MB)
- `speed`: Yükleme hızı (MB/s)
- `duration`: Yükleme süresi (saniye)
- `status`: Yükleme durumu (0/1)

## Kullanım

### Manuel Çalıştırma
```bash
# Tam yedekleme döngüsü
/root/fullbackup.sh

# Sadece doğrulama
/root/verify_backup.sh

# Sadece pCloud'a yükleme
/root/upload.sh
```

### Otomatik Çalıştırma (Cron)
```bash
# Günlük yedekleme (her gece 01:00'de)
0 1 * * * /root/fullbackup.sh

# Haftalık doğrulama (her Pazar 03:00'de)
0 3 * * 0 /root/verify_backup.sh

# Günlük pCloud yükleme (her gece 02:00'de)
0 2 * * * /root/upload.sh
```

## Güvenlik Önlemleri

1. **Dosya İzinleri**:
   - Tüm yapılandırma dosyaları: `chmod 600`
   - Script dosyaları: `chmod 700`
   - Log dosyaları: `chmod 640`

2. **Kimlik Bilgileri**:
   - pCloud kimlik bilgileri şifreli saklanır
   - Tüm hassas bilgiler `.backup_env` içinde tutulur
   - Dosya izinleri kısıtlıdır

3. **Yedek Güvenliği**:
   - AES-256 şifreleme
   - 7zip başlık şifreleme
   - Şifreli transfer (pCloud API)

## Yazar

A. Kerem Gök

## Lisans

Bu proje GNU General Public License v3.0 altında lisanslanmıştır. 
## Yedekleri Çözme

Şifrelenmiş yedekleri çözmek için aşağıdaki adımları izleyin:

1. Şifre çözme ve açma:
```bash
# Şifreyi dosyadan okuyarak
7z x -p"$(cat /root/.backup_encryption_key)" backup_YYYYMMDD.7z

# veya şifreyi manuel girerek
7z x backup_YYYYMMDD.7z
```

**Önemli Notlar**:
- Şifreleme anahtarını (`/root/.backup_encryption_key`) kaybederseniz, yedekleri çözemezsiniz
- Anahtarı güvenli bir ortamda yedekleyin
- Yedek sunucularına anahtarı da taşımayı unutmayın
- Şifreleme nedeniyle yedekleme süresi ve dosya boyutu bir miktar artacaktır 
