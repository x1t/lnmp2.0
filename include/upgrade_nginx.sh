#!/usr/bin/env bash

Upgrade_Nginx()
{
    Cur_Nginx_Version=`/usr/local/nginx/sbin/nginx -v 2>&1 | cut -c22-`

    if [ -s /usr/local/include/jemalloc/jemalloc.h ] && /usr/local/nginx/sbin/nginx -V 2>&1|grep -Eqi 'ljemalloc'; then
        NginxMAOpt="--with-ld-opt='-ljemalloc'"
    elif [ -s /usr/local/include/gperftools/tcmalloc.h ] && grep -Eqi "google_perftools_profiles" /usr/local/nginx/conf/nginx.conf; then
        NginxMAOpt='--with-google_perftools_module'
    else
        NginxMAOpt=""
    fi

    Nginx_Version=""
    echo "Current Nginx Version:${Cur_Nginx_Version}"
    echo "You can get version number from http://nginx.org/en/download.html"
    read -p "Please enter nginx version you want, (example: 1.20.2): " Nginx_Version
    if [ "${Nginx_Version}" = "" ]; then
        echo "Error: You must enter a nginx version!!"
        exit 1
    fi
    echo "+---------------------------------------------------------+"
    echo "|    You will upgrade nginx version to ${Nginx_Version}"
    echo "+---------------------------------------------------------+"

    Press_Start

    echo "============================check files=================================="
    cd ${cur_dir}/src
    if [ -s nginx-${Nginx_Version}.tar.gz ]; then
        echo "nginx-${Nginx_Version}.tar.gz [found]"
    else
        echo "Notice: nginx-${Nginx_Version}.tar.gz not found!!!download now......"
        # Try reliable CDN mirrors first for better speed
        Download_Files https://nginx.org/download/nginx-${Nginx_Version}.tar.gz nginx-${Nginx_Version}.tar.gz
        if [ $? -ne 0 ]; then
            # Try GitHub mirror for mainline versions
            Download_Files https://github.com/nginx/nginx/archive/release-${Nginx_Version}.tar.gz nginx-${Nginx_Version}.tar.gz
        fi
        if [ $? -ne 0 ]; then
            # Use wget as final fallback
            wget -c --progress=dot:giga http://nginx.org/download/nginx-${Nginx_Version}.tar.gz
        fi
        if [ $? -eq 0 ]; then
            echo "Download nginx-${Nginx_Version}.tar.gz successfully!"
        else
            echo "You enter Nginx Version was:"${Nginx_Version}
            Echo_Red "Error! You entered a wrong version number, please check!"
            sleep 5
            exit 1
        fi
    fi
    echo "============================check files=================================="

    # Check dependencies for nginx upgrade
    Check_Nginx_Dependencies()
    {
        Echo_Blue "[+] Checking nginx upgrade dependencies..."
        
        # Check OpenSSL version (recommended 1.1.1+ for nginx 1.25+)
        if command -v openssl >/dev/null 2>&1; then
            openssl_version=$(openssl version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
            echo "Found OpenSSL version: $openssl_version"
            if ! echo "$openssl_version" | grep -Eq '^(1\.1\.[1-9]|1\.[2-9]\.|[2-9]\.)'; then
                echo "Warning: OpenSSL version $openssl_version may be too old for nginx 1.25+ (recommends 1.1.1+)"
            fi
        fi
        
        # Check PCRE version
        if command -v pcre-config >/dev/null 2>&1; then
            pcre_version=$(pcre-config --version)
            echo "Found PCRE version: $pcre_version"
            if ! echo "$pcre_version" | grep -Eq '^[89]\.|^1[0-9]\.'; then
                echo "Warning: PCRE version $pcre_version may be too old (recommends 8.0+)"
            fi
        else
            echo "PCRE not found - will be built during compilation"
        fi
        
        # Check zlib
        if [ -f /usr/include/zlib.h ] || [ -f /usr/local/include/zlib.h ]; then
            echo "Found zlib library"
        else
            echo "Installing zlib development packages..."
            if [ "$PM" = "yum" ]; then
                yum -y install zlib-devel
            elif [ "$PM" = "apt" ]; then
                apt-get -y install zlib1g-dev
            fi
        fi
        
        echo "Dependency check completed."
    }
    
    # Perform dependency check
    Check_Nginx_Dependencies

    Install_Nginx_Openssl
    Install_Nginx_Lua
    Install_Pcre
    Install_Ngx_FancyIndex
    Tar_Cd nginx-${Nginx_Version}.tar.gz nginx-${Nginx_Version}
    Get_Dist_Version
    if [[ "${DISTRO}" = "Fedora" && ${Fedora_Version} -ge 28 ]]; then
        patch -p1 < ${cur_dir}/src/patch/nginx-libxcrypt.patch
    fi
    Nginx_Ver_Com=$(${cur_dir}/include/version_compare 1.14.2 ${Nginx_Version})
    if gcc -dumpversion|grep -q "^[8]" && [ "${Nginx_Ver_Com}" == "1" ]; then
        patch -p1 < ${cur_dir}/src/patch/nginx-gcc8.patch
    fi
    Nginx_Ver_Com=$(${cur_dir}/include/version_compare 1.9.4 ${Nginx_Version})
    if [[ "${Nginx_Ver_Com}" == "0" ||  "${Nginx_Ver_Com}" == "1" ]]; then
        ./configure --user=www --group=www --prefix=/usr/local/nginx --with-http_stub_status_module --with-http_ssl_module --with-http_spdy_module --with-http_gzip_static_module --with-ipv6 --with-http_sub_module --with-http_realip_module ${Nginx_With_Openssl} ${Nginx_With_Pcre} ${Nginx_Module_Lua} ${NginxMAOpt} ${Ngx_FancyIndex} ${Nginx_Modules_Options}
    else
        ./configure --user=www --group=www --prefix=/usr/local/nginx --with-http_stub_status_module --with-http_ssl_module --with-http_v2_module --with-http_gzip_static_module --with-http_sub_module --with-stream --with-stream_ssl_module --with-stream_ssl_preread_module --with-http_realip_module ${Nginx_With_Openssl} ${Nginx_With_Pcre} ${Nginx_Module_Lua} ${NginxMAOpt} ${Ngx_FancyIndex} ${Nginx_Modules_Options}
    fi
    make -j `grep 'processor' /proc/cpuinfo | wc -l`
    if [ $? -ne 0 ]; then
        make
    fi

    mv /usr/local/nginx/sbin/nginx /usr/local/nginx/sbin/nginx.${Upgrade_Date}
    \cp objs/nginx /usr/local/nginx/sbin/nginx
    echo "Test nginx configure file..."
    /usr/local/nginx/sbin/nginx -t
    echo "upgrade..."
    make upgrade

    cd ${cur_dir} && rm -rf ${cur_dir}/src/nginx-${Nginx_Version}
    
    # Update HTTP/2 syntax for nginx 1.25.1+ compatibility
    Update_HTTP2_Syntax()
    {
        Echo_Blue "[+] Updating HTTP/2 configuration syntax for nginx 1.25.1+ compatibility..."
        
        # Check if nginx version is 1.25.1 or higher
        Nginx_Version_Check=$(echo ${Nginx_Version} | awk -F. '{printf "%d%02d%02d\n", $1, $2, $3}')
        if [ "${Nginx_Version_Check}" -ge 12501 ]; then
            echo "Updating HTTP/2 syntax in configuration files..."
            
            # Update main nginx.conf
            if [ -f /usr/local/nginx/conf/nginx.conf ]; then
                # Fix HTTP/2 syntax in main config
                sed -i 's/listen \([^;]*\) ssl http2;/listen \1 ssl;\n        http2 on;/g' /usr/local/nginx/conf/nginx.conf
                sed -i 's/listen \[\([^]]*\)\]:443 ssl http2;/listen [\1]:443 ssl;\n        http2 on;/g' /usr/local/nginx/conf/nginx.conf
            fi
            
            # Update vhost configurations
            if [ -d /usr/local/nginx/conf/vhost ]; then
                for vhost_file in /usr/local/nginx/conf/vhost/*.conf; do
                    if [ -f "$vhost_file" ]; then
                        echo "Updating HTTP/2 syntax in: $vhost_file"
                        sed -i 's/listen \([^;]*\) ssl http2;/listen \1 ssl;\n        http2 on;/g' "$vhost_file"
                        sed -i 's/listen \[\([^]]*\)\]:443 ssl http2;/listen [\1]:443 ssl;\n        http2 on;/g' "$vhost_file"
                    fi
                done
            fi
            
            echo "HTTP/2 syntax updated successfully!"
        else
            echo "Nginx version ${Nginx_Version} does not require HTTP/2 syntax update."
        fi
    }
    
    # Call the HTTP/2 syntax update function
    Update_HTTP2_Syntax
    
    if [ "${Enable_Nginx_Lua}" = 'y' ]; then
        if ! grep -q 'lua_package_path "/usr/local/nginx/lib/lua/?.lua";' /usr/local/nginx/conf/nginx.conf; then
            sed -i "/server_tokens off;/i\        lua_package_path \"/usr/local/nginx/lib/lua/?.lua\";\n" /usr/local/nginx/conf/nginx.conf
        fi
        if ! grep -q "content_by_lua 'ngx.say(\"hello world\")';" /usr/local/nginx/conf/nginx.conf; then
            sed -i "/location \/nginx_status/i\        location /lua\n        {\n            default_type text/html;\n            content_by_lua 'ngx.say\(\"hello world\"\)';\n        }\n" /usr/local/nginx/conf/nginx.conf
        fi
    fi

    echo "Checking ..."
    if [[ -s /usr/local/nginx/conf/nginx.conf && -s /usr/local/nginx/sbin/nginx ]]; then
        echo "Program will display Nginx Version......"
        /usr/local/nginx/sbin/nginx -v
        Echo_Green "======== upgrade nginx completed ======"
    else
        Echo_Red "Error: Nginx upgrade failed."
    fi
}
