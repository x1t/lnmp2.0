#!/usr/bin/env bash
umask 077
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1
cd -- "${SCRIPT_DIR}" || exit 1

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script"
    exit 1
fi

cur_dir="${SCRIPT_DIR}"
action=$1
shopt -s extglob
Upgrade_Date=$(date +"%Y%m%d%H%M%S")

. lnmp.conf
. include/version.sh
. include/main.sh
. include/init.sh
. include/php.sh
. include/nginx.sh
. include/mysql.sh
. include/mariadb.sh
. include/upgrade_nginx.sh
. include/upgrade_php.sh
. include/upgrade_mysql.sh
. include/upgrade_mariadb.sh
. include/upgrade_mysql2mariadb.sh
. include/upgrade_phpmyadmin.sh
. include/upgrade_mphp.sh

Get_Dist_Name
Get_Dist_Version
MemTotal=$(awk '/MemTotal/ {printf( "%d\n", $2 / 1024 )}' /proc/meminfo)

Display_Upgrade_Menu()
{
    echo "1: Upgrade Nginx"
    echo "2: Upgrade MySQL"
    echo "3: Upgrade MariaDB"
    echo "4: Upgrade PHP for LNMP"
    echo "5: Upgrade PHP for LNMPA or LAMP"
    echo "6: Upgrade MySQL to MariaDB"
    echo "7: Upgrade phpMyAdmin"
    echo "8: Upgrade Multiple PHP"
    echo "exit: Exit current script"
    echo "###################################################"
    read -p "Enter your choice (1, 2, 3, 4, 5, 6, 7 or exit): " action
}

Run_Upgrade()
{
    local log_file="$1"
    shift
    "$@" 2>&1 | tee "${log_file}"
    return "${PIPESTATUS[0]}"
}

clear
echo "+-----------------------------------------------------------------------+"
echo "|            Upgrade script for LNMP V2.0, Written by Licess            |"
echo "+-----------------------------------------------------------------------+"
echo "|     A tool to upgrade Nginx,MySQL/Mariadb,PHP for LNMP/LNMPA/LAMP     |"
echo "+-----------------------------------------------------------------------+"
echo "|         LNMP Upgrade Script by Licess                            |"
echo "+-----------------------------------------------------------------------+"

if [ "${action}" == "" ]; then
    Display_Upgrade_Menu
fi

upgrade_status=1
    case "${action}" in
    1|[nN][gG][iI][nN][xX])
        Run_Upgrade "/root/upgrade_nginx${Upgrade_Date}.log" Upgrade_Nginx
        upgrade_status=$?
        ;;
    2|[mM][yY][sS][qQ][lL])
        Run_Upgrade "/root/upgrade_mysq${Upgrade_Date}.log" Upgrade_MySQL
        upgrade_status=$?
        ;;
    3|[mM][aA][rR][iI][aA][dD][bB])
        Run_Upgrade "/root/upgrade_mariadb${Upgrade_Date}.log" Upgrade_MariaDB
        upgrade_status=$?
        ;;
    4|[pP][hP][pP])
        Stack="lnmp"
        Run_Upgrade "/root/upgrade_lnmp_php${Upgrade_Date}.log" Upgrade_PHP
        upgrade_status=$?
        ;;
    5|[pP][hP][pP][aA])
        Run_Upgrade "/root/upgrade_a_php${Upgrade_Date}.log" Upgrade_PHP
        upgrade_status=$?
        ;;
    6|[mM]2[mY])
        Run_Upgrade "/root/upgrade_mysql2mariadb${Upgrade_Date}.log" Upgrade_MySQL2MariaDB
        upgrade_status=$?
        ;;
    7|[pP][hH][pP][mM][yY][aA][dD][mM][iI][nN])
        Run_Upgrade "/root/upgrade_phpmyadmin${Upgrade_Date}.log" Upgrade_phpMyAdmin
        upgrade_status=$?
        ;;
    8|[mM][pP][hH][pP])
        Run_Upgrade "/root/upgrade_mphp${Upgrade_Date}.log" Upgrade_Multiplephp
        upgrade_status=$?
        ;;
    [eE][xX][iI][tT])
        exit 1
        ;;
    *)
        echo "Usage: ./upgrade.sh {nginx|mysql|mariadb|m2m|php|phpa|phpmyadmin}"
        exit 1
    ;;
    esac

exit "${upgrade_status}"
