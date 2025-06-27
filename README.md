# PostgreSQL Yedekleme ve Doğrulama Sistemi

Bu sistem, PostgreSQL veritabanları için gelişmiş bir yedekleme çözümüdür. Otomatik sıkıştırma, şifreleme, bulut depolama ve kapsamlı doğrulama özellikleri sunar.

## 🌟 Özellikler

### 💾 Temel İşlevsellik

- **PostgreSQL Yedekleme**
  - pg_dump ve pg_dumpall desteği
  - Özel yedekleme stratejileri
  - Paralel yedekleme desteği
  - Sıcak yedekleme (Hot Backup) özelliği
  - WAL arşivleme desteği

- **Gelişmiş Sıkıştırma**
  - LZMA2 (xz) sıkıştırma [Sıkıştırma oranı: ~80-85%]
  - LZ4 hızlı sıkıştırma seçeneği [Hız odaklı, ~50-60% sıkıştırma]
  - GZIP alternatifi [~60-70% sıkıştırma]
  - 7z arşivleme desteği
  - Çoklu sıkıştırma seviyesi (0-9)

- **Güvenlik**
  - AES-256-CBC şifreleme
  - Güvenli anahtar yönetimi
  - SHA-256 ve MD5 sağlama
  - Şifrelenmiş başlık bilgileri
  - PBKDF2 anahtar türetme (100,000 iterasyon)

### 🔄 Yedekleme Döngüsü

- **Günlük Yedekler**
  - Tam veritabanı yedeği
  - Saat: 01:00
  - 7 gün saklama
  - Ortalama boyut: 500MB-1GB (sıkıştırılmış)

- **Haftalık Yedekler**
  - Kümülatif yedek
  - Her Pazar 02:00
  - 4 hafta saklama
  - Ortalama boyut: 2-3GB (sıkıştırılmış)

- **Aylık Yedekler**
  - Arşiv yedeği
  - Ayın 1'i saat 03:00
  - 12 ay saklama
  - Ortalama boyut: 4-5GB (sıkıştırılmış)

### ☁️ Bulut Entegrasyonu (pCloud)

- **Upload Özellikleri**
  - Çoklu parça yükleme (multipart)
  - Otomatik retry mekanizması (5 deneme)
  - Bant genişliği kontrolü
  - Checksum doğrulama
  - Dosya bütünlük kontrolü

- **Depolama Yönetimi**
  - Otomatik eski yedek temizleme
  - Depolama alanı optimizasyonu
  - Klasör yapısı organizasyonu
  - Yedek rotasyonu

### 📊 Zabbix Monitoring

- **Metrikler**
  - Yedek boyutu ve süresi
  - Sıkıştırma oranı
  - Başarı/Hata durumu
  - Disk kullanımı
  - CPU/RAM kullanımı

- **Alertler**
  - Kritik hatalar
  - Yedek gecikmeleri
  - Disk alan uyarıları
  - Performans düşüşleri
  - Güvenlik ihlalleri

## 🛠️ Sistem Gereksinimleri

### 💻 Donanım

- **CPU**: En az 2 çekirdek (önerilen: 4+ çekirdek)
- **RAM**: Minimum 4GB (önerilen: 8GB+)
- **Disk**: SSD tercih edilir
  - Yedek alanı: DB boyutunun 3 katı
  - Temp alan: DB boyutunun 1.5 katı

### 📦 Yazılım Bağımlılıkları

- **PostgreSQL**: 9.6+ (önerilen: 13+)

  ```bash
  postgresql-client-common
  postgresql-client-13
  ```

- **Sıkıştırma Araçları**

  ```bash
  p7zip-full
  xz-utils
  lz4
  ```

- **Monitoring**

  ```bash
  zabbix-agent2
  zabbix-sender
  ```

- **Diğer**

  ```bash
  curl
  jq
  bc
  openssl
  ```

## 📈 Performans Metrikleri

### 🚀 Yedekleme Performansı

- **Sıkıştırma Hızı**
  - LZMA2: ~20-30 MB/s
  - LZ4: ~100-150 MB/s
  - GZIP: ~40-50 MB/s

- **Şifreleme Hızı**
  - AES-256: ~50-60 MB/s
  - Paralel işlem: ~150-200 MB/s

- **Upload Hızı**
  - pCloud: ~10-20 MB/s
  - Retry limit: 5
  - Timeout: 300s

### 📊 Kaynak Kullanımı

- **CPU Kullanımı**
  - Yedekleme: 50-70%
  - Sıkıştırma: 80-90%
  - Şifreleme: 60-70%

- **RAM Kullanımı**
  - Base: ~500MB
  - Peak: ~2GB
  - Buffer: 1GB

- **Disk I/O**
  - Read: ~100MB/s
  - Write: ~50MB/s
  - IOPS: 1000+

## 📁 Proje Yapısı ve Bileşenler

```bash
psql-zabbix
├── pgbackup.sh      # PostgreSQL yedekleme ana script
├── fullbackup.sh    # Tam yedekleme işlemi başlatıcı ve orkestrasyon
├── tar.sh           # Sıkıştırma ve şifreleme işlemleri
├── verify_backup.sh # Yedek doğrulama ve test
├── upload.sh        # pCloud'a yedek yükleme işlemleri
├── pcloud.sh        # pCloud API entegrasyonu
└── .backup_env      # Çevresel değişkenler
```

### 🔄 Bileşen Detayları

#### 1. fullbackup.sh

Tüm yedekleme sürecini orkestre eden ana script. Diğer tüm scriptleri sırasıyla çalıştırır ve süreç durumunu Zabbix'e bildirir.

**İşlevler:**

- PostgreSQL yedekleme sürecini başlatır
- Yedekleri sıkıştırır ve şifreler
- pCloud'a yükleme işlemini gerçekleştirir
- Yedeklerin doğruluğunu kontrol eder
- Eski SQL ve ZIP dosyalarını temizler
- Tüm süreç adımlarını loglar ve Zabbix'e bildirir

**Kullanım:**

```bash
./fullbackup.sh
```

#### 2. pgbackup.sh

PostgreSQL veritabanlarının yedeğini alan ana script.

**İşlevler:**

- Tüm veritabanlarını veya belirli veritabanlarını yedekler
- pg_dump ve pg_dumpall komutlarını kullanır
- Paralel yedekleme desteği sunar
- Yedekleme sürecini loglar

**Kullanım:**

```bash
./pgbackup.sh [-d database_name] [-t backup_type]
```

#### 3. tar.sh

Yedekleri sıkıştıran ve şifreleyen script.

**İşlevler:**

- 7zip kullanarak yedekleri sıkıştırır
- AES-256 şifreleme uygular
- Üç farklı sıkıştırma modu sunar: ultra (LZ4), fast (LZMA2-3), max (LZMA2-9)
- Sıkıştırma oranı ve hızını hesaplar
- Yedek bütünlüğünü doğrular
- Disk alanı kontrolü yapar
- Geçici dosyaları temizler

**Kullanım:**

```bash
./tar.sh
```

#### 4. verify_backup.sh

Yedeklerin bütünlüğünü ve kullanılabilirliğini doğrulayan script.

**İşlevler:**

- 7zip arşiv bütünlüğünü kontrol eder
- MD5 ve SHA256 checksum doğrulaması yapar
- Test veritabanına restore ederek yedekleri doğrular
- Checksum dosyalarını oluşturur ve pCloud'a yükler
- Doğrulama sonuçlarını loglar ve Zabbix'e bildirir

**Kullanım:**

```bash
./verify_backup.sh [-f backup_file] [-c checksum_file]
```

#### 5. upload.sh

Yedekleri pCloud'a yükleyen script.

**İşlevler:**

- ZIP_DIR içindeki tüm 7z dosyalarını pCloud'a yükler
- pcloud.sh scriptini kullanarak her dosyayı ayrı ayrı yükler
- Yükleme işlemlerini loglar

**Kullanım:**

```bash
./upload.sh
```

#### 6. pcloud.sh

pCloud API ile etkileşim kuran script.

**İşlevler:**

- pCloud kimlik doğrulama işlemini gerçekleştirir
- Başarısız kimlik doğrulama durumunda 5 kez tekrar dener
- Dosyaları pCloud'a yükler
- Yükleme işlemlerini loglar

**Kullanım:**

```bash
./pcloud.sh <dosya_yolu> <pcloud_folder_id>
```

## 🔧 Kurulum

### 1. Repo Klonlama

```bash
git clone https://github.com/hermesthecat/psql-zabbix.git
cd psql-zabbix
```

### 2. Çevresel Değişkenler

```bash
# .backup_env dosyasını düzenleyin
cp .backup_env.example .backup_env
nano .backup_env

# Gerekli değişkenler:
PCLOUD_USERNAME="your_username"        # pCloud kullanıcı adı
PCLOUD_PASSWORD="your_password"        # pCloud şifresi
PCLOUD_FOLDER_ID="your_folder_id"      # pCloud klasör ID'si

ZABBIX_SERVER="10.10.10.10"            # Zabbix sunucu IP adresi
HOSTNAME="Database-Master"             # Sunucu host adı

BACKUP_DIR="/home/pg_backup/backup"    # Yedeklerin saklanacağı ana dizin
ZIP_DIR="/home/zipbackup"              # Sıkıştırılmış yedeklerin saklanacağı dizin
CHECKSUM_DIR="${BACKUP_DIR}/checksums" # Checksum dosyalarının saklanacağı dizin

ENCRYPTION_KEY_FILE="/root/.backup_encryption_key" # Şifreleme anahtarı dosyası

PG_USERNAME="postgres"                 # PostgreSQL kullanıcı adı
PG_PASSWORD="postgres"                 # PostgreSQL şifresi
PG_HOST="localhost"                    # PostgreSQL sunucu adresi

TEST_DB_NAME="verify_test_db"          # Test için kullanılacak veritabanı adı
```

### 3. Dizinleri Oluşturma

```bash
# Gerekli dizinleri oluştur
mkdir -p "$BACKUP_DIR"
mkdir -p "$ZIP_DIR"
mkdir -p "$CHECKSUM_DIR"
```

### 4. İzinler

```bash
# Script izinleri
chmod 700 *.sh
chmod 600 .backup_env
chown postgres:postgres *.sh
```

### 5. Zabbix Konfigürasyonu

```bash
# /etc/zabbix/zabbix_agentd.d/postgresql.conf
UserParameter=backup.status,cat /var/log/backup_runner.log | grep -i "status" | tail -1
UserParameter=backup.verify,cat /var/log/backup_verify.log | grep -i "verify" | tail -1
UserParameter=backup.size,stat -f -c %s /backup/latest.tar.xz
UserParameter=backup.tar.status,cat /var/log/backup_tar.log | grep -i "status" | tail -1
UserParameter=backup.tar.verify,cat /var/log/backup_tar.log | grep -i "verify" | tail -1
UserParameter=backup.tar.compression_ratio,cat /var/log/backup_tar.log | grep -i "compression_ratio" | tail -1
UserParameter=backup.tar.speed,cat /var/log/backup_tar.log | grep -i "speed" | tail -1
UserParameter=backup.tar.duration,cat /var/log/backup_tar.log | grep -i "duration" | tail -1
```

### 6. Cron Yapılandırması

```bash
# Günlük yedekleme (her gün 01:00'de)
0 1 * * * /path/to/psql-zabbix/fullbackup.sh > /dev/null 2>&1

# Haftalık yedekleme (her Pazar 02:00'de)
0 2 * * 0 /path/to/psql-zabbix/fullbackup.sh -t weekly > /dev/null 2>&1

# Aylık yedekleme (her ayın 1'i 03:00'de)
0 3 1 * * /path/to/psql-zabbix/fullbackup.sh -t monthly > /dev/null 2>&1

# Yedek doğrulama (her gün 04:00'de)
0 4 * * * /path/to/psql-zabbix/verify_backup.sh > /dev/null 2>&1
```

## 📋 Kullanım

### Manuel Yedek Alma

```bash
# Tüm veritabanlarının tam yedeğini al
./fullbackup.sh

# Belirli bir veritabanının yedeğini al
./fullbackup.sh -d database_name -t full
```

### Yedek Doğrulama

```bash
# En son yedeği doğrula
./verify_backup.sh

# Belirli bir yedek dosyasını doğrula
./verify_backup.sh -f backup_file.7z -c checksum_file
```

### Sıkıştırma ve Şifreleme

```bash
# Varsayılan ayarlarla sıkıştır (fast modu)
./tar.sh

# Ultra hızlı sıkıştırma (LZ4)
COMPRESSION_SPEED=ultra ./tar.sh

# Maksimum sıkıştırma (LZMA2-9)
COMPRESSION_SPEED=max ./tar.sh
```

### pCloud'a Manuel Yükleme

```bash
# Tüm yedekleri yükle
./upload.sh

# Belirli bir dosyayı yükle
./pcloud.sh /path/to/file.7z your_folder_id
```

### Log İzleme

```bash
# Ana yedekleme süreci logları
tail -f /var/log/backup_runner.log

# Doğrulama logları
tail -f /var/log/backup_verify.log

# Sıkıştırma ve şifreleme logları
tail -f /var/log/backup_tar.log

# pCloud upload logları
tail -f /var/log/pcloud.log
```

## 🔍 Hata Ayıklama

### Log Dosyaları

- **/var/log/backup_runner.log**: Ana işlem logları
- **/var/log/backup_verify.log**: Doğrulama logları
- **/var/log/backup_tar.log**: Sıkıştırma logları
- **/var/log/pcloud.log**: pCloud upload logları

### Yaygın Hatalar ve Çözümleri

#### 1. Disk Alan Yetersizliği

- **Belirtiler**: `HATA: /path/to/file için yeterli alan yok. Gerekli: XXX MB, Mevcut: YYY MB`
- **Çözüm**:
  - Eski yedekleri temizle: `find $BACKUP_DIR -name "*.sql" -mtime +7 -delete`
  - Eski ZIP dosyalarını temizle: `find $ZIP_DIR -name "*.7z" -mtime +30 -delete`
  - Disk alanını genişlet
- **Önlem**: Minimum gerekli alan: DB boyutu * 3

#### 2. pCloud Bağlantı Hataları

- **Belirtiler**: `HATA: pCloud kimlik doğrulama başarısız oldu!`
- **Çözüm**:
  - pCloud kimlik bilgilerini kontrol et
  - İnternet bağlantısını kontrol et
  - pCloud API durumunu kontrol et
- **Özellikler**:
  - Retry mekanizması devrede (5 deneme)
  - Token yenileme kontrolü
  - Network timeout kontrolü

#### 3. PostgreSQL Erişim Hataları

- **Belirtiler**: `HATA: PostgreSQL bağlantısı kurulamadı`
- **Çözüm**:
  - pg_hba.conf dosyasını kontrol et
  - PostgreSQL servisinin çalıştığını doğrula: `systemctl status postgresql`
  - Kullanıcı izinlerini kontrol et: `psql -U $PG_USERNAME -h $PG_HOST -c "\du"`
  - SSL bağlantı ayarlarını kontrol et

#### 4. Şifreleme Hataları

- **Belirtiler**: `HATA: Yedek doğrulama başarısız`
- **Çözüm**:
  - Şifreleme anahtarı dosyasını kontrol et
  - 7zip kurulumunu kontrol et: `7z --help`
  - Dosya izinlerini kontrol et

## 📊 Monitoring Detayları

### Zabbix Metrikleri

#### 1. Yedekleme Durumu

- **backup.status**: 0=Hata, 1=Başarılı
- **backup.verify**: 0=Hata, 1=Başarılı
- **backup.duration**: Saniye cinsinden süre
- **backup.size**: Byte cinsinden boyut

#### 2. Sıkıştırma Metrikleri

- **backup.tar.status**: 0=Hata, 1=Başarılı
- **backup.tar.verify**: 0=Hata, 1=Başarılı
- **backup.tar.original_size**: Orijinal boyut (MB)
- **backup.tar.encrypted_size**: Şifrelenmiş boyut (MB)
- **backup.tar.compression_ratio**: Sıkıştırma oranı (%)
- **backup.tar.speed**: Sıkıştırma hızı (MB/s)
- **backup.tar.duration**: Sıkıştırma süresi (s)

#### 3. Performans

- **backup.cpu_usage**: CPU kullanımı (%)
- **backup.mem_usage**: RAM kullanımı (MB)
- **backup.io_wait**: I/O bekleme süresi (s)

#### 4. pCloud

- **upload.speed**: Upload hızı (MB/s)
- **upload.status**: 0=Hata, 1=Başarılı
- **upload.retry_count**: Deneme sayısı

### Zabbix Trigger Örnekleri

```bash
# Yedekleme hatası
{HOST.NAME:backup.status.last()}=0

# Doğrulama hatası
{HOST.NAME:backup.verify.last()}=0

# Sıkıştırma oranı düşük
{HOST.NAME:backup.tar.compression_ratio.last()}<50

# Yedekleme süresi uzun
{HOST.NAME:backup.duration.last()}>7200
```

## 🔒 Güvenlik

### Şifreleme Detayları

- **Algoritma**: AES-256-CBC
- **Key Derivation**: PBKDF2 (100,000 iterasyon)
- **Salt**: 16 byte random
- **IV**: 16 byte random per file
- **MAC**: HMAC-SHA256

### Güvenlik Önlemleri

- Şifreleme anahtarı dosyası için sıkı izinler (600)
- Script dosyaları için sıkı izinler (700)
- Çevresel değişkenler dosyası için sıkı izinler (600)
- Şifrelenmiş yedekler için bütünlük kontrolü
- Checksum doğrulaması (MD5 ve SHA256)
- Test veritabanına restore ederek yedeklerin kullanılabilirliğini doğrulama

## 👥 İletişim

- **Geliştirici**: A. Kerem Gök
- **GitHub**: github.com/hermesthecat
