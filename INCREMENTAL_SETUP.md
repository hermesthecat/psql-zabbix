# Incremental Backup Kurulum Rehberi

## 🚀 Kurulum Adımları

### 1. Script İzinleri

```bash
chmod +x wal_archive.sh
chmod +x incremental_backup.sh
chmod +x daily_full_backup.sh
```

### 2. PostgreSQL Konfigürasyonu

```bash
# postgresql.conf dosyasını düzenle
sudo nano /etc/postgresql/13/main/postgresql.conf

# Bu satırları ekle/düzenle:
wal_level = replica
archive_mode = on
archive_command = '/path/to/psql-zabbix/wal_archive.sh %p %f'
max_wal_size = 1GB
min_wal_size = 80MB
wal_keep_segments = 32
checkpoint_completion_target = 0.7
checkpoint_timeout = 5min

# PostgreSQL'i restart et
sudo systemctl restart postgresql
```

### 3. Cron Job'ları Ekle

```bash
# Crontab'ı düzenle
crontab -e

# Bu satırları ekle:

# Full backup - sabah 06:00
0 6 * * * /path/to/psql-zabbix/daily_full_backup.sh >/dev/null 2>&1

# Full backup - akşam 18:00  
0 18 * * * /path/to/psql-zabbix/daily_full_backup.sh >/dev/null 2>&1

# Incremental backup - her saat başı (full backup saatleri hariç)
0 0,1,2,3,4,5,7,8,9,10,11,12,13,14,15,16,17,19,20,21,22,23 * * * /path/to/psql-zabbix/incremental_backup.sh >/dev/null 2>&1
```

### 4. Test Et

```bash
# WAL archiving testi
sudo -u postgres psql -c "SELECT pg_switch_wal();"

# İncrementalbackup testi  
./incremental_backup.sh

# Full backup testi
./daily_full_backup.sh
```

## 📊 Backup Stratejisi

```
┌─────────────┬─────────────────┬─────────────────┬─────────────────┐
│    Saat     │   Backup Türü   │      Boyut      │      İçerik     │
├─────────────┼─────────────────┼─────────────────┼─────────────────┤
│   06:00     │   Full Backup   │     2-5GB       │  Tam veritabanı │
│   07:00     │  Incremental    │    10-50MB      │   WAL dosyaları │
│   08:00     │  Incremental    │    10-50MB      │   WAL dosyaları │
│    ...      │      ...        │      ...        │       ...       │
│   17:00     │  Incremental    │    10-50MB      │   WAL dosyaları │
│   18:00     │   Full Backup   │     2-5GB       │  Tam veritabanı │
│   19:00     │  Incremental    │    10-50MB      │   WAL dosyaları │
│    ...      │      ...        │      ...        │       ...       │
└─────────────┴─────────────────┴─────────────────┴─────────────────┘
```

## 🔍 Monitoring

### Yeni Zabbix Metrikleri

```bash
# /etc/zabbix/zabbix_agentd.d/incremental_backup.conf
UserParameter=backup.wal.archive,cat /var/log/wal_archive.log | grep -c "WAL arşivlendi" 
UserParameter=backup.incremental.status,cat /var/log/incremental_backup.log | grep -c "başarılı"
UserParameter=backup.full.morning,cat /var/log/daily_full_backup.log | grep -c "morning backup başarılı"
UserParameter=backup.full.evening,cat /var/log/daily_full_backup.log | grep -c "evening backup başarılı"
```

## 📁 Dosya Yapısı

```
psql-zabbix/
├── pgbackup.sh              # Mevcut - değişmeyecek
├── fullbackup.sh             # Mevcut - değişmeyecek  
├── tar.sh                    # Mevcut - değişmeyecek
├── verify_backup.sh          # Mevcut - değişmeyecek
├── upload.sh                 # Mevcut - değişmeyecek
├── pcloud.sh                 # Mevcut - değişmeyecek
├── wal_archive.sh            # YENİ - WAL arşivleme
├── incremental_backup.sh     # YENİ - Saatlik incremental
├── daily_full_backup.sh      # YENİ - Günlük full backup
└── INCREMENTAL_SETUP.md      # YENİ - Kurulum rehberi
```

## 🎯 Faydalar

### 💾 Disk Kullanımı

- **Öncesi**: Her gün 1x tam yedek = ~5GB/gün  
- **Sonrası**: Günde 2x tam + 22x incremental = ~10GB + ~500MB = ~10.5GB/gün
- **Net**: ~2x artış ama çok daha detaylı koruma

### ⚡ Recovery Zamanı  

- **Öncesi**: 24 saate kadar veri kaybı riski
- **Sonrası**: Maksimum 1 saat veri kaybı riski
- **PITR**: Herhangi bir zaman noktasına dönebilme

### 🔒 Güvenlik

- Tüm WAL dosyaları şifrelenmiş
- Checksum doğrulama
- Otomatik temizlik mekanizması

## 🚨 Önemli Notlar

1. **İlk kurulumdan sonra** PostgreSQL restart gerekli
2. **WAL dizini** otomatik oluşturulacak
3. **pCloud klasörü** WAL arşivleri için ayrı olacak  
4. **Log dosyaları** /var/log/ altında oluşturulacak
5. **Disk alanı** WAL için ekstra ~500MB-1GB gerekli
