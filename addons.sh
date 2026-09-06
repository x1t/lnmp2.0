#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script"
    exit 1
fi

cur_dir=$(pwd)
action=$1
action2=$2

. lnmp.conf
. include/main.sh
. include/init.sh
. include/version.sh
. include/redis.sh
. include/php_exif.sh
. include/php_fileinfo.sh
. include/php_ldap.sh
. include/php_bz2.sh

Display_Addons_Menu()
{
    echo "##### cache #####"
    echo "  1: Redis"
    echo "##### PHP Modules/Extensions #####"
    echo "  2: Ldap"
    echo "  3: Bz2"
    echo "  4: Exif"
    echo "  5: Fileinfo"
    echo "#################################################"
    echo " exit: Exit current script"
    echo "#################################################"
    read -p "Enter your choice (1, 2, 3, 4, 5, 6, 7, 8... or exit): " action2
}

Restart_PHP()
{
    if [ -s /usr/local/apache/bin/httpd ] && [ -s /usr/local/apache/conf/httpd.conf ] && [ -s /etc/init.d/httpd ]; then
        echo "Restarting Apache......"
        /etc/init.d/httpd restart
    else
        echo "Restarting php-fpm......"
        ${PHPFPM_Initd} restart
    fi
}

clear
echo "+-----------------------------------------------------------------------+"
echo "|            Addons script for LNMP V2.0, Written by Licess             |"
echo "+-----------------------------------------------------------------------+"
echo "|    A tool to Install cache,optimizer,accelerator...addons for LNMP    |"
echo "+-----------------------------------------------------------------------+"
echo "|         LNMP Addons Installation Script by Licess                |"
echo "+-----------------------------------------------------------------------+"

Select_PHP()
{
    if [ "${action2}" == "exit" ]; then
        exit 1
    fi
    if [[ ! -s /usr/local/php5.2/sbin/php-fpm && ! -s /usr/local/nginx/conf/enable-php5.2.conf ]] && [[ ! -s /usr/local/php5.3/sbin/php-fpm && ! -s /usr/local/nginx/conf/enable-php5.3.conf ]] && [[ ! -s /usr/local/php5.4/sbin/php-fpm && ! -s /usr/local/nginx/conf/enable-php5.4.conf ]] && [[ ! -s /usr/local/php5.5/sbin/php-fpm && ! -s /usr/local/nginx/conf/enable-php5.5.conf ]] && [[ ! -s /usr/local/php5.6/sbin/php-fpm && ! -s /usr/local/nginx/conf/enable-php5.6.conf ]] && [[ ! -s /usr/local/php7.0/sbin/php-fpm && ! -s /usr/local/nginx/conf/enable-php7.0.conf ]] && [[ ! -s /usr/local/php7.1/sbin/php-fpm && ! -s /usr/local/nginx/conf/enable-php7.1.conf ]] && [[ ! -s /usr/local/php7.2/sbin/php-fpm && ! -s /usr/local/nginx/conf/enable-php7.2.conf ]] && [[ ! -s /usr/local/php7.3/sbin/php-fpm && ! -s /usr/local/nginx/conf/enable-php7.3.conf ]] && [[ ! -s /usr/local/php7.4/sbin/php-fpm && ! -s /usr/local/nginx/conf/enable-php7.4.conf ]] && [[ ! -s /usr/local/php8.0/sbin/php-fpm && ! -s /usr/local/nginx/conf/enable-php8.0.conf ]] && [[ ! -s /usr/local/php8.1/sbin/php-fpm && ! -s /usr/local/nginx/conf/enable-php8.1.conf ]] && [[ ! -s /usr/local/php8.2/sbin/php-fpm && ! -s /usr/local/nginx/conf/enable-php8.2.conf ]]; then
        PHP_Path='/usr/local/php'
        PHPFPM_Initd='/etc/init.d/php-fpm'
    else
        echo "Multiple PHP version found, Please select the PHP version."
        Cur_PHP_Version="`/usr/local/php/bin/php-config --version`"
        Echo_Green "1: Default Main PHP ${Cur_PHP_Version}"
        if [[ -s /usr/local/php5.2/sbin/php-fpm && -s /usr/local/nginx/conf/enable-php5.2.conf && -s /etc/init.d/php-fpm5.2 ]]; then
            Echo_Green "2: PHP 5.2 [found]"
        fi
        if [[ -s /usr/local/php5.3/sbin/php-fpm && -s /usr/local/nginx/conf/enable-php5.3.conf && -s /etc/init.d/php-fpm5.3 ]]; then
            Echo_Green "3: PHP 5.3 [found]"
        fi
        if [[ -s /usr/local/php5.4/sbin/php-fpm && -s /usr/local/nginx/conf/enable-php5.4.conf && -s /etc/init.d/php-fpm5.4 ]]; then
            Echo_Green "4: PHP 5.4 [found]"
        fi
        if [[ -s /usr/local/php5.5/sbin/php-fpm && -s /usr/local/nginx/conf/enable-php5.5.conf && -s /etc/init.d/php-fpm5.5 ]]; then
            Echo_Green "5: PHP 5.5 [found]"
        fi
        if [[ -s /usr/local/php5.6/sbin/php-fpm && -s /usr/local/nginx/conf/enable-php5.6.conf && -s /etc/init.d/php-fpm5.6 ]]; then
            Echo_Green "6: PHP 5.6 [found]"
        fi
        if [[ -s /usr/local/php7.0/sbin/php-fpm && -s /usr/local/nginx/conf/enable-php7.0.conf && -s /etc/init.d/php-fpm7.0 ]]; then
            Echo_Green "7: PHP 7.0 [found]"
        fi
        if [[ -s /usr/local/php7.1/sbin/php-fpm && -s /usr/local/nginx/conf/enable-php7.1.conf && -s /etc/init.d/php-fpm7.1 ]]; then
            Echo_Green "8: PHP 7.1 [found]"
        fi
        if [[ -s /usr/local/php7.2/sbin/php-fpm && -s /usr/local/nginx/conf/enable-php7.2.conf && -s /etc/init.d/php-fpm7.2 ]]; then
            Echo_Green "9: PHP 7.2 [found]"
        fi
        if [[ -s /usr/local/php7.3/sbin/php-fpm && -s /usr/local/nginx/conf/enable-php7.3.conf && -s /etc/init.d/php-fpm7.3 ]]; then
            Echo_Green "10: PHP 7.3 [found]"
        fi
        if [[ -s /usr/local/php7.4/sbin/php-fpm && -s /usr/local/nginx/conf/enable-php7.4.conf && -s /etc/init.d/php-fpm7.4 ]]; then
            Echo_Green "11: PHP 7.4 [found]"
        fi
        if [[ -s /usr/local/php8.0/sbin/php-fpm && -s /usr/local/nginx/conf/enable-php8.0.conf && -s /etc/init.d/php-fpm8.0 ]]; then
            Echo_Green "12: PHP 8.0 [found]"
        fi
        if [[ -s /usr/local/php8.1/sbin/php-fpm && -s /usr/local/nginx/conf/enable-php8.1.conf && -s /etc/init.d/php-fpm8.1 ]]; then
            Echo_Green "13: PHP 8.1 [found]"
        fi
        if [[ -s /usr/local/php8.2/sbin/php-fpm && -s /usr/local/nginx/conf/enable-php8.2.conf && -s /etc/init.d/php-fpm8.2 ]]; then
            Echo_Green "14: PHP 8.2 [found]"
        fi
        Echo_Yellow "Enter your choice (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 or 14): "
        read php_select
        case "${php_select}" in
            1)
                echo "Current selection: PHP ${Cur_PHP_Version}"
                PHP_Path='/usr/local/php'
                PHPFPM_Initd='/etc/init.d/php-fpm'
                ;;
            2)
                echo "Current selection: PHP `/usr/local/php5.2/bin/php-config --version`"
                PHP_Path='/usr/local/php5.2'
                PHPFPM_Initd='/etc/init.d/php-fpm5.2'
                ;;
            3)
                echo "Current selection: PHP `/usr/local/php5.3/bin/php-config --version`"
                PHP_Path='/usr/local/php5.3'
                PHPFPM_Initd='/etc/init.d/php-fpm5.3'
                ;;
            4)
                echo "Current selection: PHP `/usr/local/php5.4/bin/php-config --version`"
                PHP_Path='/usr/local/php5.4'
                PHPFPM_Initd='/etc/init.d/php-fpm5.4'
                ;;
            5)
                echo "Current selection: PHP `/usr/local/php5.5/bin/php-config --version`"
                PHP_Path='/usr/local/php5.5'
                PHPFPM_Initd='/etc/init.d/php-fpm5.5'
                ;;
            6)
                echo "Current selection: PHP `/usr/local/php5.6/bin/php-config --version`"
                PHP_Path='/usr/local/php5.6'
                PHPFPM_Initd='/etc/init.d/php-fpm5.6'
                ;;
            7)
                echo "Current selection: PHP `/usr/local/php7.0/bin/php-config --version`"
                PHP_Path='/usr/local/php7.0'
                PHPFPM_Initd='/etc/init.d/php-fpm7.0'
                ;;
            8)
                echo "Current selection: PHP `/usr/local/php7.1/bin/php-config --version`"
                PHP_Path='/usr/local/php7.1'
                PHPFPM_Initd='/etc/init.d/php-fpm7.1'
                ;;
            9)
                echo "Current selection: PHP `/usr/local/php7.2/bin/php-config --version`"
                PHP_Path='/usr/local/php7.2'
                PHPFPM_Initd='/etc/init.d/php-fpm7.2'
                ;;
            10)
                echo "Current selection: PHP `/usr/local/php7.3/bin/php-config --version`"
                PHP_Path='/usr/local/php7.3'
                PHPFPM_Initd='/etc/init.d/php-fpm7.3'
                ;;
            11)
                echo "Current selection: PHP `/usr/local/php7.4/bin/php-config --version`"
                PHP_Path='/usr/local/php7.4'
                PHPFPM_Initd='/etc/init.d/php-fpm7.4'
                ;;
            12)
                echo "Current selection: PHP `/usr/local/php8.0/bin/php-config --version`"
                PHP_Path='/usr/local/php8.0'
                PHPFPM_Initd='/etc/init.d/php-fpm8.0'
                ;;
            13)
                echo "Current selection: PHP `/usr/local/php8.1/bin/php-config --version`"
                PHP_Path='/usr/local/php8.1'
                PHPFPM_Initd='/etc/init.d/php-fpm8.1'
                ;;
            14)
                echo "Current selection: PHP `/usr/local/php8.2/bin/php-config --version`"
                PHP_Path='/usr/local/php8.2'
                PHPFPM_Initd='/etc/init.d/php-fpm8.2'
                ;;
            *)
                echo "Default,Current selection: PHP ${Cur_PHP_Version}"
                php_select="1"
                PHP_Path='/usr/local/php'
                PHPFPM_Initd='/etc/init.d/php-fpm'
                ;;
        esac
    fi
}

Addons_Get_PHP_Ext_Dir()
{
    Cur_PHP_Version="`${PHP_Path}/bin/php-config --version`"
    zend_ext_dir="`${PHP_Path}/bin/php-config --extension-dir`/"
}

Download_PHP_Src()
{
    Get_Country
    if ! Download_Files "https://www.php.net/distributions/php-${Cur_PHP_Version}.tar.bz2" "php-${Cur_PHP_Version}.tar.bz2"; then
        Download_Files "https://museum.php.net/php5/php-${Cur_PHP_Version}.tar.bz2" "php-${Cur_PHP_Version}.tar.bz2" || return 1
    fi
}

if [[ "${action}" == "" || "${action2}" == "" ]]; then
    action='install'
    Display_Addons_Menu
fi
Get_Dist_Name
Select_PHP

    case "${action}" in
    install)
        case "${action2}" in
            1|[rR]edis)
                Install_Redis
                ;;
            2|[lL]dap)
                Install_PHP_Ldap
                ;;
            3|[bB]z2)
                Install_PHP_Bz2
                ;;
            4|[eE]xif)
                Install_PHP_Exif
                ;;
            5|[fF]ileinfo)
                Install_PHP_Fileinfo
                ;;
            [eE][xX][iI][tT])
                exit 1
                ;;
            *)
                echo "Usage: ./addons.sh install {redis|ldap|bz2|exif|fileinfo}"
                ;;
        esac
        ;;
    uninstall)
        case "${action2}" in
            [rR]edis)
                Uninstall_Redis
                ;;
            [lL]dap)
                Uninstall_PHP_Ldap
                ;;
            [bB]z2)
                Uninstall_PHP_Bz2
                ;;
            [eE]xif)
                Uninstall_PHP_Exif
                ;;
            [fF]ileinfo)
                Uninstall_PHP_Fileinfo
                ;;
            *)
                echo "Usage: ./addons.sh uninstall {redis|ldap|bz2|exif|fileinfo}"
                ;;
        esac
        ;;
    [eE][xX][iI][tT])
        exit 1
        ;;
    *)
        echo "Usage: ./addons.sh {install|uninstall} {redis|ldap|bz2|exif|fileinfo}"
        exit 1
        ;;
    esac
