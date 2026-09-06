#!/usr/bin/env bash
set -o pipefail
umask 077

#Funciont: Backup website and mysql database
#Author: licess
#LNMP Backup Script

#IMPORTANT!!!Please Setting the following Values!

Backup_Home="/home/backup/"
MySQL_Dump="/usr/local/mysql/bin/mysqldump"
######~Set Directory you want to backup~######
Backup_Dir=("/home/wwwroot/example.com" "/home/wwwroot/site2.com")

######~Set MySQL Database you want to backup~######
Backup_Database=("database1" "database2")

######~Set MySQL UserName and password~######
MYSQL_UserName='root'
MYSQL_PassWord='yourrootpassword'

######~Enable Ftp Backup~######
Enable_FTP=0
# 0: enable; 1: disable
######~Set FTP Information~######
FTP_Host='1.2.3.4'
FTP_Username='your_ftp_username'
FTP_Password='yourftppassword'
FTP_Dir="backup"

#Values Setting END!

if [ "${MYSQL_UserName}" = "root" ] && [ "${MYSQL_PassWord}" = "yourrootpassword" ]; then
    echo "Error: configure a real MySQL password before running the backup script." >&2
    exit 1
fi
if [ "${Enable_FTP}" != "0" ] && [ "${Enable_FTP}" != "1" ]; then
    echo "Error: Enable_FTP must be 0 or 1." >&2
    exit 1
fi
if [ "${Enable_FTP}" = "0" ] && { [ "${FTP_Host}" = "1.2.3.4" ] || [ "${FTP_Username}" = "your_ftp_username" ] || [ "${FTP_Password}" = "yourftppassword" ]; }; then
    echo "Error: configure real FTP credentials or set Enable_FTP=1." >&2
    exit 1
fi

if [ -z "${Backup_Home}" ] || [ "${Backup_Home}" = "/" ]; then
    echo "Error: Backup_Home must be a dedicated backup directory." >&2
    exit 1
fi
Backup_Home="${Backup_Home%/}/"

Mysql_Options_File=$(mktemp "${TMPDIR:-/tmp}/lnmp-mysqldump.XXXXXX") || exit 1
cleanup()
{
    rm -f -- "${Mysql_Options_File}"
}
trap cleanup EXIT

Mysql_Password_Escaped="${MYSQL_PassWord//\\/\\\\}"
Mysql_Password_Escaped="${Mysql_Password_Escaped//\"/\\\"}"
printf '[client]\nuser=%s\npassword="%s"\n' "${MYSQL_UserName}" "${Mysql_Password_Escaped}" >"${Mysql_Options_File}" || exit 1
chmod 600 "${Mysql_Options_File}" || exit 1

TodayWWWBackup=www-*-$(date +"%Y%m%d").tar.gz
TodayDBBackup=db-*-$(date +"%Y%m%d").sql
OldWWWBackup=www-*-$(date -d -3day +"%Y%m%d").tar.gz
OldDBBackup=db-*-$(date -d -3day +"%Y%m%d").sql

Backup_Dir()
{
    local backup_path="$1"
    local dir_name="${backup_path##*/}"
    local parent_dir="${backup_path%/*}"

    [ -d "${backup_path}" ] || {
        echo "Backup directory not found: ${backup_path}" >&2
        return 1
    }
    [ "${parent_dir}" != "${backup_path}" ] || parent_dir="/"
    tar --create --gzip --file "${Backup_Home}www-${dir_name}-$(date +"%Y%m%d").tar.gz" --directory "${parent_dir}" -- "${dir_name}"
}
Backup_Sql()
{
    local database="$1"
    "${MySQL_Dump}" "--defaults-extra-file=${Mysql_Options_File}" "${database}" >"${Backup_Home}db-${database}-$(date +"%Y%m%d").sql"
}

if [ ! -f "${MySQL_Dump}" ]; then
    echo "mysqldump command not found.please check your setting."
    exit 1
fi

if [ ! -d "${Backup_Home}" ]; then
    mkdir -p -- "${Backup_Home}" || exit 1
fi

if [ "${Enable_FTP}" = 0 ]; then
    type lftp >/dev/null 2>&1 || {
        echo >&2 "lftp command not found. Install: centos:yum install lftp,debian/ubuntu:apt-get install lftp."
        exit 1
    }
fi

echo "Backup website files..."
for dd in "${Backup_Dir[@]}"; do
    Backup_Dir "${dd}" || exit 1
done

echo "Backup Databases..."
for db in "${Backup_Database[@]}"; do
    Backup_Sql "${db}" || exit 1
done

echo "Delete old backup files..."
find "${Backup_Home}" -maxdepth 1 -type f -name "${OldWWWBackup}" -delete
find "${Backup_Home}" -maxdepth 1 -type f -name "${OldDBBackup}" -delete

if [ "${Enable_FTP}" = 0 ]; then
    echo "Uploading backup files to ftp..."
    cd "${Backup_Home}" || exit 1
    LFTP_PASSWORD="${FTP_Password}" lftp "${FTP_Host}" -u "${FTP_Username}" << EOF
cd ${FTP_Dir}
mrm ${OldWWWBackup}
mrm ${OldDBBackup}
mput ${TodayWWWBackup}
mput ${TodayDBBackup}
bye
EOF

echo "complete."
fi
