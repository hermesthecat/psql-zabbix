# PostgreSQL Yedekleme ve Doğrulama Sistemi

Bu proje, PostgreSQL veritabanlarının otomatik yedeklenmesi, sıkıştırılması, yüklenmesi ve doğrulanması için geliştirilmiş bir script koleksiyonudur. Zabbix monitoring sistemi ile entegre çalışır.

## Özellikler

- Otomatik PostgreSQL yedekleme
- Günlük, haftalık ve aylık yedek rotasyonu
- Yedeklerin sıkıştırılması (bzip2/gzip)
- Uzak sunucuya yedek yükleme
- Kapsamlı yedek doğrulama sistemi:
  - MD5 ve SHA256 checksum kontrolü
  - Arşiv bütünlüğü testi
  - Test veritabanında restore denemesi
- Zabbix entegrasyonu ile monitoring
- Detaylı loglama sistemi

## Kurulum

1. Scriptleri uygun dizine kopyalayın:
```bash
cp *.sh /root/
chmod +x /root/*.sh
```

2. Gerekli dizinleri oluşturun:
```bash
mkdir -p /home/pg_backup/backup/{daily,weekly,monthly,checksums}
mkdir -p /var/log
touch /var/log/backup_runner.log
touch /var/log/backup_verify.log
```

3. PostgreSQL bağlantı bilgilerini ayarlayın:
```bash
echo "localhost:5432:*:postgres:SIFRENIZ" > ~/.pgpass
chmod 600 ~/.pgpass
```

4. Zabbix sunucu bilgilerini güncelleyin:
   - `fullbackup.sh` ve `verify_backup.sh` dosyalarında:
     * `ZABBIX_SERVER` değişkenini kendi Zabbix sunucunuzun IP'si ile güncelleyin
     * `HOSTNAME` değişkenini Zabbix'te kayıtlı host adınızla güncelleyin

## Kullanım

### Manuel Çalıştırma

Tam yedekleme işlemi için:
```bash
/root/fullbackup.sh
```

Sadece yedek doğrulama için:
```bash
/root/verify_backup.sh
```

### Otomatik Çalıştırma

Crontab'a eklemek için:
```bash
# Günlük yedekleme (her gece 01:00'de)
0 1 * * * /root/fullbackup.sh

# Yedek doğrulama (her sabah 07:00'de)
0 7 * * * /root/verify_backup.sh
```

## Script Açıklamaları

- **fullbackup.sh**: Ana yedekleme koordinatörü
- **pgbackup.sh**: PostgreSQL yedekleme işlemleri
- **tar.sh**: Yedek sıkıştırma işlemleri
- **upload.sh**: Uzak sunucuya yükleme işlemleri
- **verify_backup.sh**: Yedek doğrulama işlemleri

## Zabbix Entegrasyonu

Zabbix'te aşağıdaki itemları oluşturun:

1. Yedekleme Durumu:
   - Key: backup.status
   - Type: Zabbix trapper
   - Value type: Text

2. Doğrulama Durumu:
   - Key: backup.verify
   - Type: Zabbix trapper
   - Value type: Text

## Log Dosyaları

- **/var/log/backup_runner.log**: Yedekleme işlem logları
- **/var/log/backup_verify.log**: Doğrulama işlem logları

## Checksum Sistemi

Yedek dosyaları için oluşturulan checksum bilgileri `/home/pg_backup/backup/checksums` dizininde saklanır. Her yedek dosyası için:
- MD5 checksum
- SHA256 checksum
- Dosya boyutu
- Oluşturma tarihi

bilgileri kaydedilir.

## Güvenlik Önerileri

1. `.pgpass` dosyasının izinlerinin doğru ayarlandığından emin olun (chmod 600)
2. Yedekleme scriptlerini root dışında kullanıcıların erişemeyeceği bir dizinde saklayın
3. Log dosyalarının izinlerini kısıtlayın
4. Checksum dizinini düzenli olarak yedekleyin

## Bakım

1. Eski yedeklerin temizlenmesi:
```bash
# 30 günden eski günlük yedekleri temizle
find /home/pg_backup/backup/daily -type f -mtime +30 -delete

# 90 günden eski checksum dosyalarını temizle
find /home/pg_backup/backup/checksums -type f -mtime +90 -delete
```

2. Log rotasyonu için logrotate yapılandırması:
```
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

## Yazar

A. Kerem Gök

## Lisans

Bu proje GNU General Public License v3.0 altında lisanslanmıştır. 