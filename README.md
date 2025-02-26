# PostgreSQL Backup and Verification System

A comprehensive backup solution for PostgreSQL databases with automatic compression, encryption, cloud storage, and extensive verification capabilities.

## Features

### Core Functionality
- Automated PostgreSQL database backups
- AES-256 encryption with secure key management
- LZMA2 compression for optimal storage
- pCloud integration for secure cloud storage
- Multi-layer backup verification system
- Zabbix monitoring integration
- Detailed logging and error tracking

### Backup Management
- Daily, weekly, and monthly backup cycles
- Automated backup rotation
- Configurable retention policies
- Backup size optimization
- Progress tracking and reporting

### Security Features
- AES-256 encryption for all backups
- Secure key management system
- Encrypted headers for enhanced security
- Permission-based access control
- Secure credential handling

### Verification System
- Archive integrity checking
- Dual checksum verification (MD5, SHA256)
- Test database restoration
- Data consistency validation
- Size and content verification

### Cloud Integration
- Automated pCloud uploads
- Transfer verification
- Progress monitoring
- Performance metrics
- Retry mechanisms

### Monitoring
- Zabbix integration
- Real-time status updates
- Performance metrics
- Error notifications
- Resource usage tracking

## System Requirements

### Operating System
- Linux (Debian/Ubuntu or RHEL/CentOS)
- Proper file permissions
- Sudo access for installation

### Dependencies
- PostgreSQL (9.6 or higher)
- p7zip-full package
- Zabbix agent
- curl
- bc

### Storage
- Sufficient disk space for local backups
- pCloud account for cloud storage
- Backup retention management

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/psql-zabbix.git
cd psql-zabbix
```

2. Configure environment variables:
```bash
cp .backup_env.example .backup_env
nano .backup_env
```

3. Set required permissions:
```bash
chmod 700 *.sh
chmod 600 .backup_env
```

4. Configure pCloud credentials:
```bash
# Edit .backup_env with your pCloud credentials
PCLOUD_USERNAME="your_username"
PCLOUD_PASSWORD="your_password"
PCLOUD_FOLDER_ID="your_folder_id"
```

5. Set up Zabbix monitoring:
```bash
# Configure Zabbix agent with provided templates
# Edit zabbix_agentd.conf to include custom parameters
```

## Configuration

### Environment Variables
- `PGPASSWORD`: PostgreSQL password
- `BACKUP_DIR`: Backup storage directory
- `ENCRYPTION_KEY_FILE`: Path to encryption key
- `TEST_DB_NAME`: Database name for restore tests
- `CHECKSUM_DIR`: Directory for checksum files
- `ZABBIX_SERVER`: Zabbix server address

### Backup Schedule
Configure cron jobs for automated backups:
```bash
# Example cron configuration
0 1 * * * /root/fullbackup.sh # Daily backup at 1 AM
0 2 * * 0 /root/weekly_backup.sh # Weekly backup at 2 AM on Sundays
0 3 1 * * /root/monthly_backup.sh # Monthly backup at 3 AM on first day
```

## Usage

### Manual Backup
```bash
./fullbackup.sh
```

### Verify Latest Backup
```bash
./verify_backup.sh
```

### Monitor Status
```bash
# Check Zabbix dashboard or log files
tail -f /var/log/backup_runner.log
tail -f /var/log/backup_verify.log
tail -f /var/log/backup_tar.log
tail -f /var/log/pcloud_upload.log
```

## System Architecture

### Components
1. **Backup Module** (pgbackup.sh)
   - PostgreSQL dump operations
   - Backup management
   - Rotation handling

2. **Security Module** (tar.sh)
   - LZMA2 compression
   - AES-256 encryption
   - Header protection

3. **Cloud Module** (upload.sh)
   - pCloud API integration
   - Transfer management
   - Verification

4. **Verification Module** (verify_backup.sh)
   - Integrity checking
   - Checksum validation
   - Test restoration

5. **Coordinator** (fullbackup.sh)
   - Process orchestration
   - Error handling
   - Status reporting

### File Structure
```
/
├── root/
│   ├── fullbackup.sh     # Main coordinator
│   ├── pgbackup.sh       # PostgreSQL operations
│   ├── tar.sh            # Compression/encryption
│   ├── upload.sh         # pCloud integration
│   └── verify_backup.sh  # Backup verification
├── home/pg_backup/backup/
│   ├── daily/           # Daily backups
│   ├── weekly/          # Weekly backups
│   ├── monthly/         # Monthly backups
│   └── checksums/       # Verification digests
└── var/log/
    ├── backup_runner.log    # Main logs
    ├── backup_verify.log   # Verification logs
    ├── backup_tar.log     # Compression logs
    └── pcloud_upload.log  # Upload logs
```

## Monitoring and Logging

### Zabbix Integration
- Backup status monitoring
- Performance metrics tracking
- Error notifications
- Resource usage monitoring

### Log Files
- Detailed operation logs
- Error tracking
- Performance metrics
- Status updates

## Error Handling

### Automatic Recovery
- Retry mechanisms for failures
- Cleanup of incomplete operations
- Status notifications
- Error reporting

### Manual Intervention
- Clear error messages
- Detailed logs
- Recovery procedures
- Troubleshooting guides

## Future Development

### Planned Enhancements
1. Parallel processing implementation
2. Web management interface
3. Multi-server support
4. Advanced analytics
5. Additional cloud providers
6. Enhanced monitoring capabilities

### Contributing
Contributions are welcome! Please read our contributing guidelines and submit pull requests.

## Support

### Documentation
- [System Architecture](docs/architecture.md)
- [Configuration Guide](docs/configuration.md)
- [Troubleshooting](docs/troubleshooting.md)

### Contact
For support and questions, please:
- Open an issue in the repository
- Contact the system administrator
- Check the documentation

## License
This project is licensed under the MIT License - see the LICENSE file for details.
