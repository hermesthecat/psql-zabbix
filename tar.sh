#!/bin/sh
tar --exclude='/home/zipbackup' --exclude='/home/database' -zvcf /home/zipbackup/DB-Backup_All.tar.gz /home/
