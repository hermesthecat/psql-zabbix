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
  - Otomatik retry mekanizması
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
  - Retry limit: 3
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
PGHOST="localhost"
PGPORT="5432"
PGUSER="postgres"
PGPASSWORD="your_password"
BACKUP_DIR="/backup/postgresql"
ENCRYPTION_KEY="your_secure_key"
PCLOUD_USERNAME="pcloud_user"
PCLOUD_PASSWORD="pcloud_pass"
```

### 3. İzinler
```bash
# Script izinleri
chmod 700 *.sh
chmod 600 .backup_env
chown postgres:postgres *.sh
```

### 4. Zabbix Konfigürasyonu
```bash
# /etc/zabbix/zabbix_agentd.d/postgresql.conf
UserParameter=pgsql.backup.status,cat /var/log/backup_status.log
UserParameter=pgsql.backup.size,stat -f -c %s /backup/latest.tar.xz
```

## 📋 Kullanım

### Manuel Yedek Alma
```bash
./fullbackup.sh -d database_name -t full
```

### Yedek Doğrulama
```bash
./verify_backup.sh -f backup_file.tar.xz -c checksum_file
```

### Log İzleme
```bash
tail -f /var/log/backup_runner.log
```

## 🔍 Hata Ayıklama

### Log Dosyaları
- **/var/log/backup_runner.log**: Ana işlem logları
- **/var/log/backup_verify.log**: Doğrulama logları
- **/var/log/backup_tar.log**: Sıkıştırma logları
- **/var/log/pcloud_upload.log**: Upload logları

### Yaygın Hatalar
1. **Disk Alan Yetersizliği**
   - Çözüm: Eski yedekleri temizle
   - Minimum gerekli alan: DB boyutu * 3

2. **pCloud Bağlantı Hataları**
   - Retry mekanizması devrede
   - Token yenileme kontrolü
   - Network timeout kontrolü

3. **PostgreSQL Erişim Hataları**
   - pg_hba.conf kontrolü
   - Kullanıcı izinleri
   - SSL bağlantı kontrolü

## 📊 Monitoring Detayları

### Zabbix Metrikleri
1. **Yedekleme Durumu**
   - backup.status: 0=Hata, 1=Başarılı
   - backup.duration: Saniye cinsinden süre
   - backup.size: Byte cinsinden boyut

2. **Performans**
   - backup.cpu_usage: CPU kullanımı %
   - backup.mem_usage: RAM kullanımı MB
   - backup.io_wait: I/O bekleme süresi

3. **pCloud**
   - upload.speed: MB/s
   - upload.status: 0=Hata, 1=Başarılı
   - upload.retry_count: Deneme sayısı

## 🔒 Güvenlik

### Şifreleme Detayları
- **Algoritma**: AES-256-CBC
- **Key Derivation**: PBKDF2 (100,000 iterasyon)
- **Salt**: 16 byte random
- **IV**: 16 byte random per file
- **MAC**: HMAC-SHA256

## 📝 Lisans
Bu proje MIT lisansı altında lisanslanmıştır. Detaylar için LICENSE dosyasına bakınız.

## 👥 İletişim
- **Geliştirici**: A. Kerem Gök
- **E-posta**: kerem@example.com
- **GitHub**: github.com/username
