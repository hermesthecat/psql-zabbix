cp /home/zipbackup/DB-Backup_All.tar.gz /home/zipbackup/DB-Backup_All.$(date +%y)$(date +%m)$(date +%d).tar.gz
./pcloud.sh /home/zipbackup/DB-Backup_All.$(date +%y)$(date +%m)$(date +%d).tar.gz 11111111111
rm -rf /home/zipbackup/DB-Backup_All.*
