#!/usr/bin/env bash

Set_Timezone()
{
    Echo_Blue "Setting timezone..."
    rm -rf /etc/localtime
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
}

CentOS_InstallNTP()
{
    if [ "${CheckMirror}" != "n" ]; then
        if command -v ntpdate >/dev/null 2>&1; then
            ntpdate -u pool.ntp.org
        elif command -v chronyd >/dev/null 2>&1; then
            chronyd -d -q "server pool.ntp.org iburst"
        else
            yum info ntpdate && check_ntp="y"
            if [ "${check_ntp}" = "y" ]; then
                Echo_Blue "[+] Installing ntp..."
                yum install -y ntpdate
                ntpdate -u pool.ntp.org
            else
                Echo_Blue "[+] Installing chrony..."
                yum install chrony -y
                chronyd -d -q "server pool.ntp.org iburst"
            fi
        fi
    fi
    date
    start_time=$(date +%s)
}

Deb_InstallNTP()
{
    if [ "${CheckMirror}" != "n" ]; then
        if ! apt-get update; then
            apt-get update --allow-releaseinfo-change || return 1
        fi
        if ! command -v ntpdate >/dev/null 2>&1 && apt-cache show ntpsec-ntpdate >/dev/null 2>&1; then
            Echo_Blue "[+] Installing ntpsec-ntpdate..."
            apt-get install -y ntpsec-ntpdate || return 1
        fi
        if command -v ntpdate >/dev/null 2>&1; then
            ntpdate -u pool.ntp.org >/dev/null 2>&1 || true
        fi
    fi
    date
    start_time=$(date +%s)
}

CentOS_RemoveAMP()
{
    Echo_Blue "[-] Yum remove packages..."
    rpm -qa|grep httpd
    rpm -e httpd httpd-tools --nodeps
    if [[ "${DBSelect}" != "0" ]]; then
        yum -y remove mysql-server mysql mysql-libs mariadb-server mariadb mariadb-libs
        rpm -qa|grep mysql
        if [ $? -ne 0 ]; then
            rpm -e mysql mysql-libs --nodeps
            rpm -e mariadb mariadb-libs --nodeps
        fi
    fi
    rpm -qa|grep php
    rpm -e php-mysql php-cli php-gd php-common php --nodeps

    Remove_Error_Libcurl

    yum -y remove httpd*
    yum -y remove php*
    yum clean all
}

Deb_RemoveAMP()
{
    Echo_Blue "[-] apt-get remove packages..."
    if ! apt-get update; then
        apt-get update --allow-releaseinfo-change || return 1
    fi
    local package
    local installed_packages=()
    local remove_packages=(apache2 apache2-doc apache2-utils apache2-bin apache2-data apache2.2-common apache2.2-bin apache2-mpm-prefork apache2-mpm-worker php5 php5-common php5-cgi php5-cli php5-mysql php5-curl php5-gd php-cli php-fpm php-common php-curl php-gd php-mysql)
    for package in "${remove_packages[@]}"; do
        if dpkg-query -W -f='${Status}' "${package}" 2>/dev/null | grep -q 'install ok installed'; then
            installed_packages+=("${package}")
        fi
    done
    if [ "${#installed_packages[@]}" -gt 0 ]; then
        apt-get purge -y "${installed_packages[@]}" || return 1
    fi
    if [[ "${DBSelect}" != "0" ]]; then
        installed_packages=()
        local database_packages=(mysql-client mysql-server mysql-common mysql-server-core-5.5 mysql-client-5.5 mysql-server-core-8.0 mysql-client-core-8.0 mariadb-client mariadb-server mariadb-common mariadb-server-core libmariadbd-dev)
        for package in "${database_packages[@]}"; do
            if dpkg-query -W -f='${Status}' "${package}" 2>/dev/null | grep -q 'install ok installed'; then
                installed_packages+=("${package}")
            fi
        done
        if [ "${#installed_packages[@]}" -gt 0 ]; then
            apt-get purge -y "${installed_packages[@]}" || return 1
        fi
    fi
    if [ -x /etc/init.d/apache2 ]; then
        /etc/init.d/apache2 stop >/dev/null 2>&1 || true
    fi
    if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet apache2.service; then
        systemctl stop apache2.service || return 1
    fi
    apt-get clean || return 1
}

Disable_Selinux()
{
    if [ -s /etc/selinux/config ]; then
        setenforce 0
        sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
    fi
}

Xen_Hwcap_Setting()
{
    if [ -s /etc/ld.so.conf.d/libc6-xen.conf ]; then
        sed -i 's/hwcap 1 nosegneg/hwcap 0 nosegneg/g' /etc/ld.so.conf.d/libc6-xen.conf
    fi
}

Check_Hosts()
{
    if grep -Eqi '^127.0.0.1[[:space:]]*localhost' /etc/hosts; then
        echo "Hosts: ok."
    else
        echo "127.0.0.1 localhost.localdomain localhost" >> /etc/hosts
    fi
    if [ "${CheckMirror}" != "n" ]; then
        if getent hosts mirror.math.princeton.edu >/dev/null 2>&1; then
            echo "DNS...ok"
        else
            Echo_Red "DNS resolution failed for the configured public source mirror."
            Echo_Red "Fix /etc/resolv.conf before continuing; the installer will not overwrite it."
            return 1
        fi
    fi
}

RHEL_Modify_Source()
{
    Get_RHEL_Version
    if [ "${RHELRepo}" = "local" ]; then
        echo "DO NOT change RHEL repository, use the repository you set."
    else
        local repo_file="/etc/yum.repos.d/Centos-${RHEL_Ver}.repo"
        echo "RHEL ${RHEL_Ver} will use the bundled HTTPS university mirror configuration..."
        case "${RHEL_Ver}" in
            6)
                cp -f -- "${cur_dir}/conf/CentOS6-Base-Vault.repo" "${repo_file}" || return 1
                ;;
            7)
                cat >"${repo_file}" <<'EOF'
[base]
name=CentOS-7.9.2009 - Base - mirror.lt.ucsc.edu
baseurl=https://mirror.lt.ucsc.edu/centos/7.9.2009/os/$basearch/
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://www.centos.org/keys/RPM-GPG-KEY-CentOS-7
enabled=1

[updates]
name=CentOS-7.9.2009 - Updates - mirror.lt.ucsc.edu
baseurl=https://mirror.lt.ucsc.edu/centos/7.9.2009/updates/$basearch/
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://www.centos.org/keys/RPM-GPG-KEY-CentOS-7
enabled=1

[extras]
name=CentOS-7.9.2009 - Extras - mirror.lt.ucsc.edu
baseurl=https://mirror.lt.ucsc.edu/centos/7.9.2009/extras/$basearch/
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://www.centos.org/keys/RPM-GPG-KEY-CentOS-7
enabled=1

[centosplus]
name=CentOS-7.9.2009 - Plus - mirror.lt.ucsc.edu
baseurl=https://mirror.lt.ucsc.edu/centos/7.9.2009/centosplus/$basearch/
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://www.centos.org/keys/RPM-GPG-KEY-CentOS-7
enabled=0

[contrib]
name=CentOS-7.9.2009 - Contrib - mirror.lt.ucsc.edu
baseurl=https://mirror.lt.ucsc.edu/centos/7.9.2009/contrib/$basearch/
gpgcheck=1
gpgkey=https://www.centos.org/keys/RPM-GPG-KEY-CentOS-7
enabled=0
EOF
                ;;
            8)
                cp -f -- "${cur_dir}/conf/CentOS8-vault.repo" "${repo_file}" || return 1
                ;;
            9)
                cp -f -- "${cur_dir}/conf/rhel-9.repo" "${repo_file}" || return 1
                ;;
            *)
                Echo_Red "No bundled verified RHEL repository configuration for RHEL ${RHEL_Ver}."
                Echo_Red "Set RHELRepo=local and configure a trusted repository before continuing."
                return 1
                ;;
        esac
        yum clean all || return 1
        yum makecache || return 1
    fi
    if [ -f /etc/yum/pluginconf.d/subscription-manager.conf ]; then
        sed -i "s/^enabled[ ]*=[ ]*1/enabled=0/" /etc/yum/pluginconf.d/subscription-manager.conf || return 1
    fi
}

Ubuntu_Modify_Source()
{
    OldReleasesURL='https://old-releases.ubuntu.com/ubuntu/'
    CodeName=''
    if grep -Eqi "10.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^10.10'; then
        CodeName='maverick'
    elif grep -Eqi "11.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^11.04'; then
        CodeName='natty'
    elif  grep -Eqi "11.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^11.10'; then
        CodeName='oneiric'
    elif grep -Eqi "12.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^12.10'; then
        CodeName='quantal'
    elif grep -Eqi "13.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^13.04'; then
        CodeName='raring'
    elif grep -Eqi "13.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^13.10'; then
        CodeName='saucy'
    elif grep -Eqi "10.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^10.04'; then
        CodeName='lucid'
    elif grep -Eqi "14.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^14.10'; then
        CodeName='utopic'
    elif grep -Eqi "15.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^15.04'; then
        CodeName='vivid'
    elif grep -Eqi "12.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^12.04'; then
        CodeName='precise'
    elif grep -Eqi "15.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^15.10'; then
        CodeName='wily'
    elif grep -Eqi "16.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^16.10'; then
        CodeName='yakkety'
    elif grep -Eqi "14.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^14.04'; then
        Ubuntu_Deadline trusty
    elif grep -Eqi "17.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^17.04'; then
        CodeName='zesty'
    elif grep -Eqi "17.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^17.10'; then
        CodeName='artful'
    elif grep -Eqi "16.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^16.04'; then
        Ubuntu_Deadline xenial
    elif grep -Eqi "16.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^16.10'; then
        CodeName='yakkety'
    elif grep -Eqi "18.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^18.04'; then
        Ubuntu_Deadline bionic
    elif grep -Eqi "18.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^18.10'; then
        CodeName='cosmic'
    elif grep -Eqi "19.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^19.04'; then
        CodeName='disco'
    elif grep -Eqi "19.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^19.10'; then
        CodeName='eoan'
    elif grep -Eqi "20.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^20.10'; then
        CodeName='groovy'
    elif grep -Eqi "21.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^21.04'; then
        CodeName='hirsute'
    elif grep -Eqi "21.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^21.10'; then
        CodeName='impish'
    fi
    if [ "${CodeName}" != "" ]; then
        \cp /etc/apt/sources.list /etc/apt/sources.list.$(date +"%Y%m%d")
        cat > /etc/apt/sources.list<<EOF
deb ${OldReleasesURL} ${CodeName} main restricted universe multiverse
deb ${OldReleasesURL} ${CodeName}-security main restricted universe multiverse
deb ${OldReleasesURL} ${CodeName}-updates main restricted universe multiverse
deb ${OldReleasesURL} ${CodeName}-proposed main restricted universe multiverse
deb ${OldReleasesURL} ${CodeName}-backports main restricted universe multiverse
deb-src ${OldReleasesURL} ${CodeName} main restricted universe multiverse
deb-src ${OldReleasesURL} ${CodeName}-security main restricted universe multiverse
deb-src ${OldReleasesURL} ${CodeName}-updates main restricted universe multiverse
deb-src ${OldReleasesURL} ${CodeName}-proposed main restricted universe multiverse
deb-src ${OldReleasesURL} ${CodeName}-backports main restricted universe multiverse
EOF
    fi
}

Check_Old_Releases_URL()
{
    OR_Status=`wget --spider --server-response ${OldReleasesURL}/dists/$1/Release 2>&1 | awk '/^  HTTP/{print $2}'`
    if [ "${OR_Status}" = "200" ]; then
        echo "Ubuntu old-releases status: ${OR_Status}";
        CodeName="$1"
    fi
}

Ubuntu_Deadline()
{
    trusty_deadline=`date -d "2024-4-30 00:00:00" +%s`
    xenial_deadline=`date -d "2026-4-30 00:00:00" +%s`
    kinetic_deadline=`date -d "2023-7-30 00:00:00" +%s`
    bionic_deadline=`date -d "2028-7-30 00:00:00" +%s`
    cur_time=`date  +%s`
    case "$1" in
        trusty)
            if [ ${cur_time} -gt ${trusty_deadline} ]; then
                echo "${cur_time} > ${trusty_deadline}"
                Check_Old_Releases_URL trusty
            fi
            ;;
        xenial)
            if [ ${cur_time} -gt ${xenial_deadline} ]; then
                echo "${cur_time} > ${xenial_deadline}"
                Check_Old_Releases_URL xenial
            fi
            ;;
        eoan)
            if [ ${cur_time} -gt ${eoan_deadline} ]; then
                echo "${cur_time} > ${eoan_deadline}"
                Check_Old_Releases_URL eoan
            fi
            ;;
        bionic)
            if [ ${cur_time} -gt ${bionic_deadline} ]; then
                echo "${cur_time} > ${bionic_deadline}"
                Check_Old_Releases_URL bionic
            fi
            ;;
    esac
}

CentOS6_Modify_Source()
{
    if echo "${CentOS_Version}" | grep -Eqi "^6"; then
        Echo_Yellow "CentOS 6 is now end of life, use vault repository."
        mkdir /etc/yum.repos.d/backup
        mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup/
        \cp ${cur_dir}/conf/CentOS6-Base-Vault.repo /etc/yum.repos.d/CentOS-Base.repo
    fi
}

CentOS8_Modify_Source()
{
    if echo "${CentOS_Version}" | grep -Eqi "^8" && [ "${isCentosStream}" != "y" ]; then
        Echo_Yellow "CentOS 8 is now end of life, use vault repository."
        if [ ! -s /etc/yum.repos.d/CentOS8-vault.repo ]; then
            mkdir /etc/yum.repos.d/backup
            mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup/
            \cp ${cur_dir}/conf/CentOS8-vault.repo /etc/yum.repos.d/CentOS8-vault.repo
        fi
    fi
}

Modify_Source()
{
    if [ "${DISTRO}" = "RHEL" ]; then
        if subscription-manager status; then
            Echo_Blue "RHEL subscription exists on the system, skip setting up third-party sources."
            Get_RHEL_Version
            if echo "${RHEL_Version}" | grep -Eqi "^[89]"; then
                subscription-manager repos --enable codeready-builder-for-rhel-${RHEL_Version}-${DB_ARCH}-rpms
            fi
        else
            RHEL_Modify_Source
        fi
    elif [ "${DISTRO}" = "Ubuntu" ]; then
        Ubuntu_Modify_Source
    elif [ "${DISTRO}" = "CentOS" ]; then
        CentOS6_Modify_Source
        CentOS8_Modify_Source
    fi
}

Check_PowerTools()
{
    if ! yum -v repolist all|grep "PowerTools"; then
        Echo_Red "PowerTools repository not found!"
    fi
    repo_id=$(yum repolist all|grep -Ei "PowerTools"|head -n 1|awk '{print $1}')
}

Check_Codeready()
{
    repo_id=$(yum repolist all|grep -E "CodeReady"|head -n 1|awk '{print $1}')
    [ -z "${repo_id}" ] && repo_id="ol8_codeready_builder"
}

CentOS_Dependent()
{
    if [ -s /etc/yum.conf ]; then
        \cp /etc/yum.conf /etc/yum.conf.lnmp
        sed -i 's:exclude=.*:exclude=:g' /etc/yum.conf
    fi

    Echo_Blue "[+] Yum installing dependent packages..."
    for packages in make cmake gcc gcc-c++ gcc-g77 kernel-headers glibc-headers flex bison file libtool libtool-libs autoconf patch wget crontabs libjpeg libjpeg-devel libjpeg-turbo-devel libpng libpng-devel libpng10 libpng10-devel gd gd-devel libxml2 libxml2-devel zlib zlib-devel glib2 glib2-devel unzip tar bzip2 bzip2-devel libzip-devel libevent libevent-devel ncurses ncurses-devel curl curl-devel libcurl libcurl-devel e2fsprogs e2fsprogs-devel krb5 krb5-devel libidn libidn-devel openssl openssl-devel pcre-devel gettext gettext-devel ncurses-devel gmp-devel pspell-devel unzip libcap diffutils ca-certificates net-tools psmisc libXpm-devel git-core c-ares-devel libicu-devel libxslt libxslt-devel xz expat-devel libaio-devel rpcgen libtirpc-devel perl cyrus-sasl-devel sqlite-devel oniguruma-devel lsof re2c pkg-config libarchive hostname ncurses-libs numactl-devel libxcrypt libwebp-devel gnutls-devel initscripts iproute libxcrypt-compat pcre2-devel automake libtool-ltdl-devel;
    do yum -y install $packages; done

    yum -y update nss

    if echo "${CentOS_Version}" | grep -Eqi "^8" || echo "${RHEL_Version}" | grep -Eqi "^8" || echo "${Rocky_Version}" | grep -Eqi "^8" || echo "${Alma_Version}" | grep -Eqi "^8" || echo "${Anolis_Version}" | grep -Eqi "^8" || echo "${OpenCloudOS_Version}" | grep -Eqi "^8"; then
        Check_PowerTools
        if [ "${repo_id}" != "" ]; then
            echo "Installing packages in PowerTools repository..."
            for c8packages in rpcgen re2c oniguruma-devel;
            do dnf --enablerepo=${repo_id} install ${c8packages} -y; done
        fi
        dnf install libarchive -y

        dnf install gcc-toolset-10 -y
    fi

    if echo "${CentOS_Version}" | grep -Eqi "^9" || echo "${Alma_Version}" | grep -Eqi "^9" || echo "${Rocky_Version}" | grep -Eqi "^9"; then
        for cs9packages in oniguruma-devel libzip-devel libtirpc-devel libxcrypt-compat;
        do dnf --enablerepo=crb install ${cs9packages} -y; done
        if [[ "${Bin}" != "y" ]] && Is_Modern_MySQL_DB; then
            dnf install gcc-toolset-12-gcc gcc-toolset-12-gcc-c++ gcc-toolset-12-binutils gcc-toolset-12-annobin-annocheck gcc-toolset-12-annobin-plugin-gcc -y
        fi
    fi

    if [ "${DISTRO}" = "Oracle" ] && echo "${Oracle_Version}" | grep -Eqi "^8"; then
        Check_Codeready
        for o8packages in rpcgen re2c oniguruma-devel;
        do dnf --enablerepo=${repo_id} install ${o8packages} -y; done
        dnf install libarchive -y
    fi

    if [ "${DISTRO}" = "Oracle" ] && echo "${Oracle_Version}" | grep -Eqi "^9"; then
        Check_Codeready
        dnf --enablerepo=${repo_id} install libtirpc-devel -y
        if [[ "${Bin}" != "y" ]] && Is_Modern_MySQL_DB; then
            dnf install gcc-toolset-12-gcc gcc-toolset-12-gcc-c++ gcc-toolset-12-binutils gcc-toolset-12-annobin-annocheck gcc-toolset-12-annobin-plugin-gcc -y
        fi
    fi

    if echo "${CentOS_Version}" | grep -Eqi "^7" || echo "${RHEL_Version}" | grep -Eqi "^7"  || echo "${Aliyun_Version}" | grep -Eqi "^2" || echo "${Alibaba_Version}" | grep -Eqi "^2" || echo "${Oracle_Version}" | grep -Eqi "^7" || echo "${Anolis_Version}" | grep -Eqi "^7"; then
        if [ "${DISTRO}" = "Oracle" ]; then
            yum -y install oracle-epel-release
            yum -y --enablerepo=*EPEL* install oniguruma-devel
        else
            yum -y install epel-release
            if [ "${country}" = "CN" ]; then
                sed -e 's!^metalink=!#metalink=!g' \
                    -e 's!^#baseurl=!baseurl=!g' \
                    -i /etc/yum.repos.d/epel*.repo
            fi
        fi
        yum -y install oniguruma oniguruma-devel
        if [ "${CheckMirror}" = "n" ]; then
            rpm -ivh ${cur_dir}/src/oniguruma-6.8.2-1.el7.x86_64.rpm ${cur_dir}/src/oniguruma-devel-6.8.2-1.el7.x86_64.rpm
        fi
    fi

    if [ "${DISTRO}" = "Fedora" ] || echo "${CentOS_Version}" | grep -Eqi "^9" || echo "${Alma_Version}" | grep -Eqi "^9" || echo "${Rocky_Version}" | grep -Eqi "^9" || echo "${Amazon_Version}" | grep -Eqi "^202[3-9]" || echo "${OpenCloudOS_Version}" | grep -Eqi "^9"; then
        dnf install chkconfig -y
    fi

    if [ "${DISTRO}" = "UOS" ]; then
        Check_PowerTools
        if [ "${repo_id}" != "" ]; then
            echo "Installing packages in PowerTools repository..."
            for uospackages in rpcgen re2c oniguruma-devel;
            do dnf --enablerepo=${repo_id} install ${uospackages} -y; done
        fi
    fi

    if [ -s /etc/yum.conf.lnmp ]; then
        mv -f /etc/yum.conf.lnmp /etc/yum.conf
    fi
}

Deb_Dependent()
{
    Echo_Blue "[+] Apt-get installing dependent packages..."
    if ! apt-get update; then
        apt-get update --allow-releaseinfo-change || return 1
    fi
    apt-get -fy install || return 1
    export DEBIAN_FRONTEND=noninteractive
    local package tool
    local available_packages=()
    local runtime_packages=()
    if [ "${DISTRO}" = "Debian" ] && echo "${Debian_Version}" | grep -Eqi "^13"; then
        echo "Detected Debian 13 Trixie, adjusting package names..."
        runtime_packages=(libaio1t64 libncurses-dev libtinfo6)
    else
        runtime_packages=(libaio1 libaio-dev libncurses5 libncurses5-dev libtinfo-dev)
    fi
    local packages=(debian-keyring debian-archive-keyring build-essential gcc g++ make cmake autoconf automake re2c wget cron bzip2 libzip-dev libc6-dev bison file flex m4 gawk less cpp binutils diffutils unzip tar libbz2-dev libtool libevent-dev openssl libssl-dev libsasl2-dev zlib1g zlib1g-dev libbz2-1.0 libglib2.0-0 libglib2.0-dev libjpeg-dev libpng-dev libkrb5-dev curl libcurl4-openssl-dev libpcre3-dev libpq-dev libpq5 gettext libxml2-dev libcap-dev ca-certificates psmisc patch git libc-ares-dev libicu-dev e2fsprogs libxslt1.1 libxslt1-dev xz-utils libexpat1-dev libtirpc-dev libsqlite3-dev libonig-dev lsof pkg-config libnuma-dev libwebp-dev gnutls-dev iproute2 gzip libpcre2-dev libtool-bin libreadline-dev libfcgi-dev libfreetype6-dev libgd-dev libpspell-dev "${runtime_packages[@]}")
    for package in "${packages[@]}"; do
        if LC_ALL=C apt-cache policy "${package}" 2>/dev/null | awk '$1 == "Candidate:" { found = ($2 != "(none)" && $2 != "") } END { exit(found ? 0 : 1) }'; then
            available_packages+=("${package}")
        else
            case "${package}" in
                build-essential|gcc|g++|make|libc6-dev|pkg-config)
                    Echo_Red "Required build dependency has no installation candidate: ${package}. Check your APT repositories."
                    return 1
                    ;;
                *)
                    echo "Skipping unavailable distribution package: ${package}"
                    ;;
            esac
        fi
    done
    if [ "${#available_packages[@]}" -eq 0 ]; then
        Echo_Red "No dependency packages are available. Check your APT repositories."
        return 1
    fi
    apt-get --no-install-recommends install -y "${available_packages[@]}" || return 1
    for tool in gcc g++ make pkg-config; do
        if ! command -v "${tool}" >/dev/null 2>&1; then
            Echo_Red "Required build tool is still missing after dependency installation: ${tool}"
            return 1
        fi
    done
    return 0
}

Check_Download()
{
    Echo_Blue "[+] Downloading files..."
    cd "${cur_dir}/src" || return 1
    Download_Files "${Download_Mirror}/libiconv/${Libiconv_Ver}.tar.gz" "${Libiconv_Ver}.tar.gz" || return 1
    if [[ "${PHPSelect}" =~ ^[1-5]$ ]]; then
        Download_Files "${Download_Mirror}/libmcrypt/${LibMcrypt_Ver}.tar.bz2" "${LibMcrypt_Ver}.tar.bz2" || return 1
        Download_Files "${Download_Mirror}/mcrypt/${Mcypt_Ver}.tar.gz" "${Mcypt_Ver}.tar.gz" || return 1
        Download_Files "${Download_Mirror}/mhash/${Mhash_Ver}.tar.bz2" "${Mhash_Ver}.tar.bz2" || return 1
    fi
    if [ "${SelectMalloc}" = "2" ]; then
        Download_Files "https://github.com/jemalloc/jemalloc/releases/download/${Jemalloc_Ver##*-}/${Jemalloc_Ver}.tar.bz2" "${Jemalloc_Ver}.tar.bz2" || return 1
    elif [ "${SelectMalloc}" = "3" ]; then
        Download_Files "https://github.com/gperftools/gperftools/releases/download/gperftools-${TCMalloc_Ver##*-}/${TCMalloc_Ver}.tar.gz" "${TCMalloc_Ver}.tar.gz" || return 1
        Download_Files "https://download.savannah.nongnu.org/releases/libunwind/${Libunwind_Ver}.tar.gz" "${Libunwind_Ver}.tar.gz" || return 1
    fi
    if [ "${Stack}" != "lamp" ]; then
        if ! Download_Files "${University_Mirror}/macports/distfiles/nginx/${Nginx_Ver}.tar.gz" "${Nginx_Ver}.tar.gz"; then
            Download_Files "https://nginx.org/download/${Nginx_Ver}.tar.gz" "${Nginx_Ver}.tar.gz" || return 1
        fi
    fi
    if Is_MySQL_DB; then
        if [[ "${Bin}" = "y" && "${DBSelect}" =~ ^[2-4]$ ]]; then
            Mysql_Ver_Short=$(echo ${Mysql_Ver} | sed 's/mysql-//' | cut -d. -f1-2)
            if ! Download_Files "https://cdn.mysql.com/Downloads/MySQL-${Mysql_Ver_Short}/${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}.tar.gz" "${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}.tar.gz"; then
                Download_Files "https://cdn.mysql.com/archives/mysql-${Mysql_Ver_Short}/${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}.tar.gz" "${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}.tar.gz" || return 1
            fi
        elif [[ "${Bin}" = "y" ]] && Is_Modern_MySQL_DB; then
            mysql8_file=$(Get_MySQL_Binary_File "${Mysql_Ver}" "${DB_ARCH}") || return 1
            Mysql_Ver_Short=$(echo ${Mysql_Ver} | sed 's/mysql-//' | cut -d. -f1-2)
            if ! Download_Files "https://cdn.mysql.com/Downloads/MySQL-${Mysql_Ver_Short}/${mysql8_file}" "${mysql8_file}"; then
                Download_Files "https://cdn.mysql.com/archives/mysql-${Mysql_Ver_Short}/${mysql8_file}" "${mysql8_file}" || return 1
            fi
        else
            Mysql_Ver_Short=$(echo ${Mysql_Ver} | sed 's/mysql-//' | cut -d. -f1-2)
            Download_Files "https://cdn.mysql.com/Downloads/MySQL-${Mysql_Ver_Short}/${Mysql_Ver}.tar.gz" "${Mysql_Ver}.tar.gz" || return 1
        fi
    elif Is_MariaDB_DB; then
        Mariadb_Version=$(echo ${Mariadb_Ver} | cut -d- -f2)
        if [ "${Bin}" = "y" ]; then
            MariaDB_FileName="${Mariadb_Ver}-linux-systemd-${DB_ARCH}"
        else
            MariaDB_FileName="${Mariadb_Ver}"
        fi
        Download_Files "https://downloads.mariadb.org/rest-api/mariadb/${Mariadb_Version}/${MariaDB_FileName}.tar.gz" "${MariaDB_FileName}.tar.gz" || return 1
    fi
    Download_Files "https://www.php.net/distributions/${Php_Ver}.tar.bz2" "${Php_Ver}.tar.bz2" || return 1
    # Note: PHP-FPM patch no longer needed for PHP 7+
    PhpMyAdmin_Version="${PhpMyAdmin_Ver#phpMyAdmin-}"
    PhpMyAdmin_Version="${PhpMyAdmin_Version%%-*}"
    if ! Download_Files "https://files.phpmyadmin.net/phpMyAdmin/${PhpMyAdmin_Version}/${PhpMyAdmin_Ver}.tar.xz" "${PhpMyAdmin_Ver}.tar.xz"; then
        Download_Files "https://github.com/phpmyadmin/phpmyadmin/releases/download/RELEASE_${PhpMyAdmin_Version//./_}/${PhpMyAdmin_Ver}.tar.xz" "${PhpMyAdmin_Ver}.tar.xz" || return 1
    fi
    # Skip probe file download for security
    echo "Note: Probe file download skipped for security reasons"
    if [ "${Stack}" != "lnmp" ]; then
        # Use official Apache download
        Download_Files "https://archive.apache.org/dist/httpd/${Apache_Ver}.tar.bz2" "${Apache_Ver}.tar.bz2" || return 1
        Download_Files "https://archive.apache.org/dist/apr/${APR_Ver}.tar.bz2" "${APR_Ver}.tar.bz2" || return 1
        Download_Files "https://archive.apache.org/dist/apr/${APR_Util_Ver}.tar.bz2" "${APR_Util_Ver}.tar.bz2" || return 1
    fi
}

Make_Install()
{
    local jobs
    jobs=$(grep -c '^processor' /proc/cpuinfo)
    [ "${jobs}" -gt 0 ] || jobs=1
    if ! make -j "${jobs}"; then
        make || return 1
    fi
    make install
}

PHP_Make_Install()
{
    local jobs
    jobs=$(grep -c '^processor' /proc/cpuinfo)
    [ "${jobs}" -gt 0 ] || jobs=1
    if ! make ZEND_EXTRA_LIBS='-liconv' -j "${jobs}"; then
        make ZEND_EXTRA_LIBS='-liconv' || return 1
    fi
    make install
}

Install_Autoconf()
{
    Echo_Blue "[+] Installing ${Autoconf_Ver}"
    cd "${cur_dir}/src" || return 1
    Download_Files "${University_Mirror}/gnu/autoconf/${Autoconf_Ver}.tar.gz" "${Autoconf_Ver}.tar.gz" || return 1
    Tar_Cd "${Autoconf_Ver}.tar.gz" "${Autoconf_Ver}" || return 1
    ./configure --prefix=/usr/local/autoconf-2.13 || return 1
    Make_Install || return 1
    cd "${cur_dir}/src/" || return 1
    rm -rf -- "${cur_dir}/src/${Autoconf_Ver}"
}

Install_Libiconv()
{
    Echo_Blue "[+] Installing ${Libiconv_Ver}"
    Tar_Cd "${Libiconv_Ver}.tar.gz" "${Libiconv_Ver}" || return 1
    ./configure --disable-shared --enable-static || return 1
    Make_Install || return 1
    cd "${cur_dir}/src/" || return 1
    rm -rf -- "${cur_dir}/src/${Libiconv_Ver}"
}

Install_Libmcrypt()
{
    Echo_Blue "[+] Installing ${LibMcrypt_Ver}"
    Tar_Cd "${LibMcrypt_Ver}.tar.bz2" "${LibMcrypt_Ver}" || return 1
    ./configure || return 1
    Make_Install || return 1
    /sbin/ldconfig || return 1
    cd libltdl/ || return 1
    ./configure --enable-ltdl-install || return 1
    Make_Install || return 1
    ln -sf /usr/local/lib/libmcrypt.la /usr/lib/libmcrypt.la
    ln -sf /usr/local/lib/libmcrypt.so /usr/lib/libmcrypt.so
    ln -sf /usr/local/lib/libmcrypt.so.4 /usr/lib/libmcrypt.so.4
    ln -sf /usr/local/lib/libmcrypt.so.4.4.8 /usr/lib/libmcrypt.so.4.4.8
    ldconfig || return 1
    cd "${cur_dir}/src/" || return 1
    rm -rf -- "${cur_dir}/src/${LibMcrypt_Ver}"
}

Install_Mcrypt()
{
    Echo_Blue "[+] Installing ${Mcypt_Ver}"
    Tar_Cd "${Mcypt_Ver}.tar.gz" "${Mcypt_Ver}" || return 1
    ./configure || return 1
    Make_Install || return 1
    cd "${cur_dir}/src/" || return 1
    rm -rf -- "${cur_dir}/src/${Mcypt_Ver}"
}

Install_Mhash()
{
    Echo_Blue "[+] Installing ${Mhash_Ver}"
    Tar_Cd "${Mhash_Ver}.tar.bz2" "${Mhash_Ver}" || return 1
    ./configure || return 1
    Make_Install || return 1
    ln -sf /usr/local/lib/libmhash.a /usr/lib/libmhash.a
    ln -sf /usr/local/lib/libmhash.la /usr/lib/libmhash.la
    ln -sf /usr/local/lib/libmhash.so /usr/lib/libmhash.so
    ln -sf /usr/local/lib/libmhash.so.2 /usr/lib/libmhash.so.2
    ln -sf /usr/local/lib/libmhash.so.2.0.1 /usr/lib/libmhash.so.2.0.1
    ldconfig || return 1
    cd "${cur_dir}/src/" || return 1
    rm -rf -- "${cur_dir}/src/${Mhash_Ver}"
}

Install_Freetype()
{
    if echo "${Ubuntu_Version}" | grep -Eqi "^1[89]\.|2[0-9]\." || echo "${Mint_Version}" | grep -Eqi "^19|2[0-9]" || echo "${Deepin_Version}" | grep -Eqi "^15\.[7-9]|15.1[0-9]|1[6-9]|2[0-9]" || echo "${Debian_Version}" | grep -Eqi "^9|1[0-9]" || echo "${Raspbian_Version}" | grep -Eqi "^9|1[0-9]" || echo "${Kali_Version}" | grep -Eqi "^202[0-9]" || echo "${UOS_Version}" | grep -Eqi "^2[0-9]" || echo "${CentOS_Version}" | grep -Eqi "^8|9" || echo "${RHEL_Version}" | grep -Eqi "^8|9" || echo "${Oracle_Version}" | grep -Eqi "^8|9" || echo "${Fedora_Version}" | grep -Eqi "^3[0-9]|29" || echo "${Rocky_Version}" | grep -Eqi "^8|9" || echo "${Alma_Version}" | grep -Eqi "^8|9" || echo "${openEuler_Version}" | grep -Eqi "^2[0-9]" || echo "${Anolis_Version}" | grep -Eqi "^8|9" || echo "${Kylin_Version}" | grep -Eqi "^V1[0-9]" || echo "${Amazon_Version}" | grep -Eqi "^202[3-9]" || echo "${OpenCloudOS_Version}" | grep -Eqi "^8|9|23"; then
        if ! Download_Files "${Download_Mirror}/freetype/${Freetype_New_Ver}.tar.xz" "${Freetype_New_Ver}.tar.xz"; then
            Download_Files "https://sourceforge.net/projects/freetype/files/freetype2/${Freetype_New_Ver##*-}/${Freetype_New_Ver}.tar.xz/download" "${Freetype_New_Ver}.tar.xz" || return 1
        fi
        Echo_Blue "[+] Installing ${Freetype_New_Ver}"
        Tar_Cd "${Freetype_New_Ver}.tar.xz" "${Freetype_New_Ver}" || return 1
        ./configure --prefix=/usr/local/freetype --enable-freetype-config || return 1
    else
        Download_Files "https://sourceforge.net/projects/freetype/files/freetype2/${Freetype_Ver##*-}/${Freetype_Ver}.tar.bz2/download" "${Freetype_Ver}.tar.bz2" || return 1
        Echo_Blue "[+] Installing ${Freetype_Ver}"
        Tar_Cd "${Freetype_Ver}.tar.bz2" "${Freetype_Ver}" || return 1
        ./configure --prefix=/usr/local/freetype || return 1
    fi
    Make_Install || return 1

    [[ -d /usr/lib/pkgconfig ]] && \cp /usr/local/freetype/lib/pkgconfig/freetype2.pc /usr/lib/pkgconfig/
    cat > /etc/ld.so.conf.d/freetype.conf<<EOF
/usr/local/freetype/lib
EOF
    ldconfig
    ln -sf /usr/local/freetype/include/freetype2/* /usr/include/
    cd "${cur_dir}/src/" || return 1
    rm -rf -- "${cur_dir}/src/${Freetype_Ver}" "${cur_dir}/src/${Freetype_New_Ver}"
}

Install_Curl()
{
    if [[ ! -s /usr/local/curl/bin/curl || ! -s /usr/local/curl/lib/libcurl.so || ! -s /usr/local/curl/include/curl/curl.h ]]; then
        Echo_Blue "[+] Installing ${Curl_Ver}"
        cd "${cur_dir}/src" || return 1
        Download_Files "https://curl.se/download/${Curl_Ver}.tar.bz2" "${Curl_Ver}.tar.bz2" || return 1
        Tar_Cd "${Curl_Ver}.tar.bz2" "${Curl_Ver}" || return 1
        if [ -s /usr/local/openssl/bin/openssl ] || /usr/local/openssl/bin/openssl version | grep -Eqi 'OpenSSL 1.0.2'; then
            ./configure --prefix=/usr/local/curl --enable-ares --without-nss --with-zlib --with-ssl=/usr/local/openssl || return 1
        else
            ./configure --prefix=/usr/local/curl --enable-ares --without-nss --with-zlib --with-ssl || return 1
        fi
        Make_Install || return 1
        cd "${cur_dir}/src/" || return 1
        rm -rf -- "${cur_dir}/src/${Curl_Ver}"
        ldconfig || return 1
    fi
    Remove_Error_Libcurl
}

Install_Pcre()
{
    if ! command -v pcre-config >/dev/null 2>&1 || pcre-config --version | grep -vEqi '^8.'; then
        Echo_Blue "[+] Installing ${Pcre_Ver}"
        cd ${cur_dir}/src
        # Use the verified university mirror for PCRE.
        Download_Files "${Download_Mirror}/pcre/${Pcre_Ver}.tar.bz2" "${Pcre_Ver}.tar.bz2" || return 1
        if [ ! -s "${Pcre_Ver}.tar.bz2" ]; then
            return 1
        fi
        Tar_Cd "${Pcre_Ver}.tar.bz2" "${Pcre_Ver}" || return 1
        ./configure --disable-shared --enable-utf8 --enable-unicode-properties --enable-jit || return 1
        make || return 1
        cd ${cur_dir}/src
        Nginx_With_Pcre="--with-pcre=${cur_dir}/src/${Pcre_Ver} --with-pcre-jit"
    fi
}

Install_Jemalloc()
{
    Echo_Blue "[+] Installing ${Jemalloc_Ver}"
    cd "${cur_dir}/src" || return 1
    Tar_Cd "${Jemalloc_Ver}.tar.bz2" "${Jemalloc_Ver}" || return 1
    ./configure || return 1
    Make_Install || return 1
    ldconfig || return 1
    cd "${cur_dir}/src/" || return 1
    rm -rf -- "${cur_dir}/src/${Jemalloc_Ver}"
    ln -sf /usr/local/lib/libjemalloc* /usr/lib/
}

Install_TCMalloc()
{
    Echo_Blue "[+] Installing ${TCMalloc_Ver}"
    if [ "${Is_64bit}" = "y" ]; then
        Tar_Cd "${Libunwind_Ver}.tar.gz" "${Libunwind_Ver}" || return 1
        CFLAGS=-fPIC ./configure || return 1
        make CFLAGS=-fPIC || return 1
        make CFLAGS=-fPIC install || return 1
        rm -rf -- "${cur_dir}/src/${Libunwind_Ver}"
    fi
    Tar_Cd "${TCMalloc_Ver}.tar.gz" "${TCMalloc_Ver}" || return 1
    if [ "${Is_64bit}" = "y" ]; then
        ./configure || return 1
    else
        ./configure --enable-frame-pointers || return 1
    fi
    Make_Install || return 1
    ldconfig || return 1
    cd "${cur_dir}/src/" || return 1
    rm -rf -- "${cur_dir}/src/${TCMalloc_Ver}"
    ln -sf /usr/local/lib/libtcmalloc* /usr/lib/
}

Install_Icu4c()
{
    if command -v icu-config >/dev/null 2>&1 && icu-config --version | grep -Eq "^3."; then
        Echo_Blue "[+] Installing ${Libicu4c_Ver}"
        cd "${cur_dir}/src" || return 1
        Download_Files "https://github.com/unicode-org/icu/releases/download/release-58-3/${Libicu4c_Ver}-src.tgz" "${Libicu4c_Ver}-src.tgz" || return 1
        Tar_Cd "${Libicu4c_Ver}-src.tgz" "icu/source" || return 1
        ./configure --prefix=/usr || return 1
        if [ ! -s /usr/include/xlocale.h ]; then
            ln -s /usr/include/locale.h /usr/include/xlocale.h
        fi
        Make_Install || return 1
        cd "${cur_dir}/src/" || return 1
        rm -rf -- "${cur_dir}/src/icu"
    fi
}

Install_Icu60()
{
    if [ ! -s /usr/local/icu/bin/icu-config ]; then
        Echo_Blue "[+] Installing icu4c-60_3..."
        cd "${cur_dir}/src" || return 1
        Download_Files "https://github.com/unicode-org/icu/releases/download/release-60-3/icu4c-60_3-src.tgz" "icu4c-60_3-src.tgz" || return 1
        Tar_Cd "icu4c-60_3-src.tgz" "icu/source" || return 1
        ./configure --prefix=/usr/local/icu || return 1
        Make_Install || return 1
        cd "${cur_dir}/src/" || return 1

        echo "/usr/local/icu/lib" > /etc/ld.so.conf.d/icu.conf
        ldconfig || return 1
    fi
}

Download_Boost()
{
    Echo_Blue "[+] Download or use exist boost..."
    if [ "${DBSelect}" = "4" ] || echo "${mysql_version}" | grep -Eqi '^5.7.'; then
        local Boost_Release="${Boost_Ver#boost_}"
        Boost_Release="${Boost_Release//_/.}"
        if ! Download_Files "https://archives.boost.io/release/${Boost_Release}/source/${Boost_Ver}.tar.bz2" "${cur_dir}/src/${Boost_Ver}.tar.bz2"; then
            Download_Files "https://sourceforge.net/projects/boost/files/boost/${Boost_Release}/${Boost_Ver}.tar.bz2/download" "${cur_dir}/src/${Boost_Ver}.tar.bz2" || return 1
        fi
        [[ -d "${cur_dir}/src/${Boost_Ver}" ]] && rm -rf "${cur_dir}/src/${Boost_Ver}"
        Extract_Archive "${cur_dir}/src/${Boost_Ver}.tar.bz2" "${cur_dir}/src" || return 1
        MySQL_WITH_BOOST="-DWITH_BOOST=${cur_dir}/src/${Boost_Ver}"
    elif Is_Modern_MySQL_DB || Is_Modern_MySQL_Version; then
        Get_Boost_Ver=$(grep 'SET(BOOST_PACKAGE_NAME' cmake/boost.cmake |grep -oP '\d+(\_\d+){2}')
        local Boost_Package="boost_${Get_Boost_Ver}.tar.bz2"
        if ! Download_Files "https://archives.boost.io/release/${Get_Boost_Ver//_/.}/source/${Boost_Package}" "${cur_dir}/src/${Boost_Package}"; then
            Download_Files "https://sourceforge.net/projects/boost/files/boost/${Get_Boost_Ver//_/.}/${Boost_Package}/download" "${cur_dir}/src/${Boost_Package}" || return 1
        fi
        [[ -d "${cur_dir}/src/boost_${Get_Boost_Ver}" ]] && rm -rf "${cur_dir}/src/boost_${Get_Boost_Ver}"
        Extract_Archive "${cur_dir}/src/${Boost_Package}" "${cur_dir}/src" || return 1
        MySQL_WITH_BOOST="-DWITH_BOOST=${cur_dir}/src/boost_${Get_Boost_Ver}"
    fi
}

Install_Boost()
{
    Echo_Blue "[+] Download or use exist boost..."
    local mysql_source_dir="${cur_dir}/src/${Mysql_Ver:-mysql-${mysql_version}}"
    local boost_version
    if [ "${DBSelect}" = "4" ] || Is_Modern_MySQL_DB; then
        if [ -d "${mysql_source_dir}/boost" ]; then
            MySQL_WITH_BOOST="-DWITH_BOOST=${mysql_source_dir}/boost"
        elif [ -d "${mysql_source_dir}/extra/boost" ]; then
            boost_version=$(grep 'SET(BOOST_PACKAGE_NAME' "${mysql_source_dir}/cmake/boost.cmake" | grep -oP '\d+(\_\d+){2}')
            if [ -d "${mysql_source_dir}/extra/boost/boost_${boost_version}" ]; then
                MySQL_WITH_BOOST="-DWITH_BOOST=${mysql_source_dir}/extra/boost/boost_${boost_version}"
            else
                Download_Boost
            fi
        else
            Download_Boost
        fi
    elif echo "${mysql_version}" | grep -Eqi '^5.7.' || Is_Modern_MySQL_Version; then
        if [ -d "${mysql_source_dir}/boost" ]; then
            MySQL_WITH_BOOST="-DWITH_BOOST=${mysql_source_dir}/boost"
        elif [ -d "${mysql_source_dir}/extra/boost" ]; then
            boost_version=$(grep 'SET(BOOST_PACKAGE_NAME' "${mysql_source_dir}/cmake/boost.cmake" | grep -oP '\d+(\_\d+){2}')
            if [ -d "${mysql_source_dir}/extra/boost/boost_${boost_version}" ]; then
                MySQL_WITH_BOOST="-DWITH_BOOST=${mysql_source_dir}/extra/boost/boost_${boost_version}"
            else
                Download_Boost
            fi
        else
            Download_Boost
        fi
    fi
}

Install_Openssl()
{
    if [ ! -s /usr/local/openssl/bin/openssl ] || /usr/local/openssl/bin/openssl version | grep -v 'OpenSSL 1.0.2'; then
        Echo_Blue "[+] Installing ${Openssl_Ver}"
        cd "${cur_dir}/src" || return 1
        # Use official OpenSSL source
        if ! Download_Files "https://www.openssl.org/source/old/1.0.2/${Openssl_Ver}.tar.gz" "${Openssl_Ver}.tar.gz"; then
            Download_Files "${University_Mirror}/openssl/source/old/1.0.2/${Openssl_Ver}.tar.gz" "${Openssl_Ver}.tar.gz" || return 1
        fi
        [[ -d "${Openssl_Ver}" ]] && rm -rf -- "${Openssl_Ver}"
        Tar_Cd "${Openssl_Ver}.tar.gz" "${Openssl_Ver}" || return 1
        ./config -fPIC --prefix=/usr/local/openssl --openssldir=/usr/local/openssl || return 1
        make depend || return 1
        Make_Install || return 1
        cd "${cur_dir}/src/" || return 1
        rm -rf -- "${cur_dir}/src/${Openssl_Ver}"
    fi
}

Install_Openssl_New()
{
    if openssl version | grep -vEqi "OpenSSL 1.1.1*"; then
        if [ ! -s /usr/local/openssl1.1.1/bin/openssl ] || /usr/local/openssl1.1.1/bin/openssl version | grep -v 'OpenSSL 1.1.1'; then
            Echo_Blue "[+] Installing ${Openssl_New_Ver}"
            cd "${cur_dir}/src" || return 1
            # Use official OpenSSL source
            if ! Download_Files "https://www.openssl.org/source/old/1.1.1/${Openssl_New_Ver}.tar.gz" "${Openssl_New_Ver}.tar.gz"; then
                Download_Files "${University_Mirror}/openssl/source/old/1.1.1/${Openssl_New_Ver}.tar.gz" "${Openssl_New_Ver}.tar.gz" || return 1
            fi
            [[ -d "${Openssl_New_Ver}" ]] && rm -rf -- "${Openssl_New_Ver}"
            Tar_Cd "${Openssl_New_Ver}.tar.gz" "${Openssl_New_Ver}" || return 1
            ./config -fPIC --prefix=/usr/local/openssl1.1.1 --openssldir=/usr/local/openssl1.1.1 || return 1
            make depend || return 1
            Make_Install || return 1
            ln -sf /usr/local/openssl1.1.1/lib/libcrypto.so.1.1 /usr/lib/ || return 1
            ln -sf /usr/local/openssl1.1.1/lib/libssl.so.1.1 /usr/lib/ || return 1
            cd "${cur_dir}/src/" || return 1
            rm -rf -- "${cur_dir}/src/${Openssl_New_Ver}"
        fi
        ldconfig
        apache_with_ssl='--with-ssl=/usr/local/openssl1.1.1'
    else
        apache_with_ssl='--with-ssl'
    fi
}

Install_Nghttp2()
{
    if [[ ! -s /usr/local/nghttp2/lib/libnghttp2.so || ! -s /usr/local/nghttp2/include/nghttp2/nghttp2.h ]]; then
        Echo_Blue "[+] Installing ${Nghttp2_Ver}"
        cd "${cur_dir}/src" || return 1
        Download_Files "https://github.com/nghttp2/nghttp2/releases/download/v${Nghttp2_Ver#nghttp2-}/${Nghttp2_Ver}.tar.xz" "${Nghttp2_Ver}.tar.xz" || return 1
        [[ -d "${Nghttp2_Ver}" ]] && rm -rf -- "${Nghttp2_Ver}"
        Tar_Cd "${Nghttp2_Ver}.tar.xz" "${Nghttp2_Ver}" || return 1
        ./configure --prefix=/usr/local/nghttp2 || return 1
        Make_Install || return 1
        cd "${cur_dir}/src/" || return 1
        rm -rf -- "${cur_dir}/src/${Nghttp2_Ver}"
    fi
}

Install_Libzip()
{
    if echo "${CentOS_Version}" | grep -Eqi "^7"  || echo "${RHEL_Version}" | grep -Eqi "^7"  || echo "${Aliyun_Version}" | grep -Eqi "^2" || echo "${Alibaba_Version}" | grep -Eqi "^2" || echo "${Oracle_Version}" | grep -Eqi "^7" || echo "${Anolis_Version}" | grep -Eqi "^7"; then
        if [ ! -s /usr/local/lib/libzip.so ]; then
            Echo_Blue "[+] Installing ${Libzip_Ver}"
            cd "${cur_dir}/src" || return 1
            Download_Files "https://libzip.org/download/${Libzip_Ver}.tar.xz" "${Libzip_Ver}.tar.xz" || return 1
            Tar_Cd "${Libzip_Ver}.tar.xz" "${Libzip_Ver}" || return 1
            ./configure || return 1
            Make_Install || return 1
            cd "${cur_dir}/src/" || return 1
            rm -rf -- "${cur_dir}/src/${Libzip_Ver}"
        fi
        export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}
        ldconfig || return 1
    fi
}

CentOS_Lib_Opt()
{
    if [ "${Is_64bit}" = "y" ] ; then
        ln -sf /usr/lib64/libpng.* /usr/lib/
        ln -sf /usr/lib64/libjpeg.* /usr/lib/
    fi

    ulimit -v unlimited

    if [ `grep -L "/lib"    '/etc/ld.so.conf'` ]; then
        echo "/lib" >> /etc/ld.so.conf
    fi

    if [ `grep -L '/usr/lib'    '/etc/ld.so.conf'` ]; then
        echo "/usr/lib" >> /etc/ld.so.conf
        #echo "/usr/lib/openssl/engines" >> /etc/ld.so.conf
    fi

    if [ -d "/usr/lib64" ] && [ `grep -L '/usr/lib64'    '/etc/ld.so.conf'` ]; then
        echo "/usr/lib64" >> /etc/ld.so.conf
        #echo "/usr/lib64/openssl/engines" >> /etc/ld.so.conf
    fi

    if [ `grep -L '/usr/local/lib'    '/etc/ld.so.conf'` ]; then
        echo "/usr/local/lib" >> /etc/ld.so.conf
    fi

    ldconfig

    if command -v systemd-detect-virt >/dev/null 2>&1 && [[ "$(systemd-detect-virt)" = "lxc" ]]; then
        cat >>/etc/security/limits.conf<<eof
* soft nofile 65535
* hard nofile 65535
eof
    else
        cat >>/etc/security/limits.conf<<eof
* soft nproc 65535
* hard nproc 65535
* soft nofile 65535
* hard nofile 65535
eof
    fi

    echo "fs.file-max=65535" >> /etc/sysctl.conf

    if echo "${Fedora_Version}" | grep -Eqi "3[0-9]" && [ ! -d "/etc/init.d" ]; then
        ln -sf /etc/rc.d/init.d /etc/init.d
    fi

    if [ -s /usr/lib64/libtinfo.so.6 ]; then
        ln -sf /usr/lib64/libtinfo.so.6 /usr/lib64/libtinfo.so.5
    elif [ -s /usr/lib/libtinfo.so.6 ]; then
        ln -sf /usr/lib/libtinfo.so.6 /usr/lib/libtinfo.so.5
    fi

    if [ -s /usr/lib64/libncurses.so.6 ]; then
        ln -sf /usr/lib64/libncurses.so.6 /usr/lib64/libncurses.so.5
    elif [ -s /usr/lib/libncurses.so.6 ]; then
        ln -sf /usr/lib/libncurses.so.6 /usr/lib/libncurses.so.5
    fi
}

Deb_Lib_Opt()
{
    if [ "${Is_64bit}" = "y" ]; then
        ln -sf /usr/lib/x86_64-linux-gnu/libpng* /usr/lib/
        ln -sf /usr/lib/x86_64-linux-gnu/libjpeg* /usr/lib/
    else
        ln -sf /usr/lib/i386-linux-gnu/libpng* /usr/lib/
        ln -sf /usr/lib/i386-linux-gnu/libjpeg* /usr/lib/
        ln -sf /usr/include/i386-linux-gnu/asm /usr/include/asm
    fi

    if [ -d "/usr/lib/arm-linux-gnueabihf" ]; then
        ln -sf /usr/lib/arm-linux-gnueabihf/libpng* /usr/lib/
        ln -sf /usr/lib/arm-linux-gnueabihf/libjpeg* /usr/lib/
        ln -sf /usr/include/arm-linux-gnueabihf/curl /usr/include/
    fi

    ulimit -v unlimited

    if [ `grep -L "/lib"    '/etc/ld.so.conf'` ]; then
        echo "/lib" >> /etc/ld.so.conf
    fi

    if [ `grep -L '/usr/lib'    '/etc/ld.so.conf'` ]; then
        echo "/usr/lib" >> /etc/ld.so.conf
    fi

    if [ -d "/usr/lib64" ] && [ `grep -L '/usr/lib64'    '/etc/ld.so.conf'` ]; then
        echo "/usr/lib64" >> /etc/ld.so.conf
    fi

    if [ `grep -L '/usr/local/lib'    '/etc/ld.so.conf'` ]; then
        echo "/usr/local/lib" >> /etc/ld.so.conf
    fi

    if [ -d /usr/include/x86_64-linux-gnu/curl ]; then
        ln -sf /usr/include/x86_64-linux-gnu/curl /usr/include/
    elif [ -d /usr/include/i386-linux-gnu/curl ]; then
        ln -sf /usr/include/i386-linux-gnu/curl /usr/include/
    fi

    if [ -d /usr/include/arm-linux-gnueabihf/curl ]; then
        ln -sf /usr/include/arm-linux-gnueabihf/curl /usr/include/
    fi

    if [ -d /usr/include/aarch64-linux-gnu/curl ]; then
        ln -sf /usr/include/aarch64-linux-gnu/curl /usr/include/
    fi

    ldconfig

    cat >>/etc/security/limits.conf<<eof
* soft nproc 65535
* hard nproc 65535
* soft nofile 65535
* hard nofile 65535
eof

    echo "fs.file-max=65535" >> /etc/sysctl.conf
}

Remove_Error_Libcurl()
{
    if [ -s /usr/local/lib/libcurl.so ]; then
        rm -f /usr/local/lib/libcurl*
    fi
}

Add_Swap()
{

    Disk_Avail=$(($(df -mP /var | tail -1 | awk '{print $4}' | sed s/[[:space:]]//g)/1024))

    DD_Count='1024'
    if [[ "${MemTotal}" -lt 1024 ]]; then
        DD_Count='1024'
        if [[ "${Disk_Avail}" -lt 5 ]]; then
            Enable_Swap='n'
        fi
    elif [[ "${MemTotal}" -ge 1024 && "${MemTotal}" -le 2048 ]]; then
        DD_Count='2048'
        if [[ "${Disk_Avail}" -lt 13 ]]; then
            Enable_Swap='n'
        fi
    elif [[ "${MemTotal}" -ge 2048 && "${MemTotal}" -le 4096 ]]; then
        DD_Count='4096'
        if [[ "${Disk_Avail}" -lt 17 ]]; then
            Enable_Swap='n'
        fi
    elif [[ "${MemTotal}" -ge 4096 && "${MemTotal}" -le 16384 ]]; then
        DD_Count='8192'
        if [[ "${Disk_Avail}" -lt 19 ]]; then
            Enable_Swap='n'
        fi
    elif [[ "${MemTotal}" -ge 16384 ]]; then
        DD_Count='8192'
        if [[ "${Disk_Avail}" -lt 27 ]]; then
            Enable_Swap='n'
        fi
    fi
    Swap_Total=$(awk '/SwapTotal/ {printf( "%d\n", $2 / 1024 )}' /proc/meminfo)
    if [[ "${Enable_Swap}" = "y" && "${Swap_Total}" -le 512 && ! -s /var/swapfile ]]; then
        echo "Add Swap file..."
        [ $(cat /proc/sys/vm/swappiness) -eq 0 ] && sysctl vm.swappiness=10
        dd if=/dev/zero of=/var/swapfile bs=1M count=${DD_Count}
        chmod 0600 /var/swapfile
        echo "Enable Swap..."
        /sbin/mkswap /var/swapfile
        /sbin/swapon /var/swapfile
        if [ $? -eq 0 ]; then
            [ `grep -L '/var/swapfile'    '/etc/fstab'` ] && echo "/var/swapfile swap swap defaults 0 0" >>/etc/fstab
            /sbin/swapon -s
        else
            rm -f /var/swapfile
            echo "Add Swap Failed!"
        fi
    fi
}
