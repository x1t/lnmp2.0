#!/usr/bin/env bash

Install_Nginx_Openssl()
{
    Nginx_With_Openssl=''
    Nginx_Version="${Nginx_Version:-${Nginx_Ver#nginx-}}"
    if [ "${Enable_Nginx_Openssl}" != 'y' ]; then
        return 0
    fi
    if command -v openssl >/dev/null 2>&1 && openssl version | grep -Eqi '^OpenSSL 3\.'; then
        echo "Using the system OpenSSL 3 library for Nginx."
        return 0
    fi
    if [ "${Enable_Nginx_Openssl}" = 'y' ]; then
        if [ ! -n "${Nginx_Version}" ]; then
            Nginx_Version=$(echo ${Nginx_Ver} | sed "s/nginx-//")
        fi
        Nginx_Ver_Com=$(${cur_dir}/include/version_compare 1.13.0 ${Nginx_Version})
        if [[ "${Nginx_Ver_Com}" == "0" ||  "${Nginx_Ver_Com}" == "1" ]]; then
            # Use official OpenSSL source
            Download_Files "https://www.openssl.org/source/old/1.0.2/${Openssl_Ver}.tar.gz" "${Openssl_Ver}.tar.gz" || return 1
            [[ -d "${Openssl_Ver}" ]] && rm -rf -- "${Openssl_Ver}"
            Extract_Archive "${Openssl_Ver}.tar.gz" || return 1
            Nginx_With_Openssl="--with-openssl=${cur_dir}/src/${Openssl_Ver}"
        else
            Download_Files "https://www.openssl.org/source/old/1.1.1/${Openssl_New_Ver}.tar.gz" "${Openssl_New_Ver}.tar.gz" || return 1
            [[ -d "${Openssl_New_Ver}" ]] && rm -rf -- "${Openssl_New_Ver}"
            Extract_Archive "${Openssl_New_Ver}.tar.gz" || return 1
            Nginx_With_Openssl="--with-openssl=${cur_dir}/src/${Openssl_New_Ver}"
        fi
    fi
}

Install_Nginx_Lua()
{
    if [ "${Enable_Nginx_Lua}" = 'y' ]; then
        echo "Installing Lua for Nginx..."
        cd "${cur_dir}/src" || return 1
        Download_Files "https://github.com/openresty/luajit2/archive/refs/tags/v${Luajit_Ver#luajit2-}.tar.gz" "${Luajit_Ver}.tar.gz" || return 1
        Download_Files "https://github.com/openresty/lua-nginx-module/archive/refs/tags/v${LuaNginxModule#lua-nginx-module-}.tar.gz" "${LuaNginxModule}.tar.gz" || return 1
        Download_Files "https://github.com/simpl/ngx_devel_kit/archive/refs/tags/v${NgxDevelKit#ngx_devel_kit-}.tar.gz" "${NgxDevelKit}.tar.gz" || return 1
        Download_Files "https://github.com/openresty/lua-resty-core/archive/refs/tags/v${LuaRestyCore#lua-resty-core-}.tar.gz" "${LuaRestyCore}.tar.gz" || return 1
        Download_Files "https://github.com/openresty/lua-resty-lrucache/archive/refs/tags/v${LuaRestyLrucache#lua-resty-lrucache-}.tar.gz" "${LuaRestyLrucache}.tar.gz" || return 1

        Echo_Blue "[+] Installing ${Luajit_Ver}... "
        Extract_Archive "${LuaNginxModule}.tar.gz" || return 1
        Extract_Archive "${NgxDevelKit}.tar.gz" || return 1
        Tar_Cd "${Luajit_Ver}.tar.gz" "${Luajit_Ver}" || return 1
        make || return 1
        make install PREFIX=/usr/local/luajit || return 1
        cd "${cur_dir}/src" || return 1
        rm -rf -- "${cur_dir}/src/${Luajit_Ver}"

        cat > /etc/ld.so.conf.d/luajit.conf<<EOF
/usr/local/luajit/lib
EOF
        if [ "${Is_64bit}" = "y" ]; then
            ln -sf /usr/local/luajit/lib/libluajit-5.1.so.2 /lib64/libluajit-5.1.so.2
        else
            ln -sf /usr/local/luajit/lib/libluajit-5.1.so.2 /usr/lib/libluajit-5.1.so.2
        fi
        ldconfig

        cat >/etc/profile.d/luajit.sh<<EOF
export LUAJIT_LIB=/usr/local/luajit/lib
export LUAJIT_INC=/usr/local/luajit/include/luajit-2.1
EOF

        source /etc/profile.d/luajit.sh || return 1

        Tar_Cd "${LuaRestyCore}.tar.gz" "${LuaRestyCore}" || return 1
        make install PREFIX=/usr/local/nginx || return 1
        cd "${cur_dir}/src" || return 1
        Tar_Cd "${LuaRestyLrucache}.tar.gz" "${LuaRestyLrucache}" || return 1
        make install PREFIX=/usr/local/nginx || return 1
        cd "${cur_dir}/src" || return 1

        Nginx_Ver_Com=$(${cur_dir}/include/version_compare 1.21.5 ${Nginx_Version})
        if [[  "${Nginx_Ver_Com}" == "1" ]]; then
            Nginx_Module_Lua="--with-ld-opt=-Wl,-rpath,/usr/local/luajit/lib --add-module=${cur_dir}/src/${LuaNginxModule} --add-module=${cur_dir}/src/${NgxDevelKit}"
        else
            if [ "${Nginx_With_Pcre}" = "" ]; then
                Nginx_Module_Lua="--with-ld-opt=-Wl,-rpath,/usr/local/luajit/lib --add-module=${cur_dir}/src/${LuaNginxModule} --add-module=${cur_dir}/src/${NgxDevelKit} --with-pcre=${cur_dir}/src/${Pcre_Ver} --with-pcre-jit"
                cd "${cur_dir}/src" || return 1
                Download_Files "${University_Mirror}/macports/distfiles/pcre/${Pcre_Ver}.tar.bz2" "${Pcre_Ver}.tar.bz2" || return 1
                Tar_Cd "${Pcre_Ver}.tar.bz2" || return 1
            else
                Nginx_Module_Lua="--with-ld-opt=-Wl,-rpath,/usr/local/luajit/lib --add-module=${cur_dir}/src/${LuaNginxModule} --add-module=${cur_dir}/src/${NgxDevelKit}"
            fi
        fi
    fi
}

Install_Ngx_FancyIndex()
{
    if [ "${Enable_Ngx_FancyIndex}" = 'y' ]; then
        echo "Installing Ngx FancyIndex for Nginx..."
        cd "${cur_dir}/src" || return 1
        Download_Files "https://github.com/aperezdc/ngx-fancyindex/releases/download/v${NgxFancyIndex_Ver#ngx-fancyindex-}/${NgxFancyIndex_Ver}.tar.xz" "${NgxFancyIndex_Ver}.tar.xz" || return 1

        Tar_Cd "${NgxFancyIndex_Ver}.tar.xz" || return 1
        Ngx_FancyIndex="--add-module=${cur_dir}/src/${NgxFancyIndex_Ver}"
    fi
}

Install_Nginx()
{
    Echo_Blue "[+] Installing ${Nginx_Ver}... "
    Nginx_Version="${Nginx_Version:-${Nginx_Ver#nginx-}}"
    getent group www >/dev/null 2>&1 || groupadd www || return 1
    id www >/dev/null 2>&1 || useradd -s /sbin/nologin -g www www || return 1

    cd "${cur_dir}/src" || return 1
    Install_Nginx_Openssl || return 1
    Install_Nginx_Lua || return 1
    Install_Ngx_FancyIndex || return 1
    Tar_Cd "${Nginx_Ver}.tar.gz" "${Nginx_Ver}" || return 1
    if [[ "${DISTRO}" = "Fedora" && ${Fedora_Version} -ge 28 ]]; then
        patch -p1 < ${cur_dir}/src/patch/nginx-libxcrypt.patch
    fi
    Nginx_Ver_Com=$(${cur_dir}/include/version_compare 1.14.2 ${Nginx_Version})
    if gcc -dumpversion|grep -q "^[8]" && [ "${Nginx_Ver_Com}" == "1" ]; then
        patch -p1 < ${cur_dir}/src/patch/nginx-gcc8.patch
    fi
    Nginx_Ver_Com=$(${cur_dir}/include/version_compare 1.9.4 ${Nginx_Version})
    if [[ "${Nginx_Ver_Com}" == "0" ||  "${Nginx_Ver_Com}" == "1" ]]; then
        ./configure --user=www --group=www --prefix=/usr/local/nginx --with-http_stub_status_module --with-http_ssl_module --with-http_spdy_module --with-http_gzip_static_module --with-ipv6 --with-http_sub_module --with-http_realip_module ${Nginx_With_Openssl} ${Nginx_With_Pcre} ${Nginx_Module_Lua} ${NginxMAOpt} ${Ngx_FancyIndex} ${Nginx_Modules_Options} || return 1
    else
        ./configure --user=www --group=www --prefix=/usr/local/nginx --with-http_stub_status_module --with-http_ssl_module --with-http_v2_module --with-http_gzip_static_module --with-http_sub_module --with-stream --with-stream_ssl_module --with-stream_ssl_preread_module --with-http_realip_module ${Nginx_With_Openssl} ${Nginx_With_Pcre} ${Nginx_Module_Lua} ${NginxMAOpt} ${Ngx_FancyIndex} ${Nginx_Modules_Options} || return 1
    fi
    Make_Install || return 1
    cd ../ || return 1

    ln -sf /usr/local/nginx/sbin/nginx /usr/bin/nginx

    rm -f /usr/local/nginx/conf/nginx.conf
    cd "${cur_dir}" || return 1
    if [ "${Stack}" = "lnmpa" ]; then
        \cp conf/nginx_a.conf /usr/local/nginx/conf/nginx.conf || return 1
        \cp conf/proxy.conf /usr/local/nginx/conf/proxy.conf || return 1
        \cp conf/proxy-pass-php.conf /usr/local/nginx/conf/proxy-pass-php.conf || return 1
    else
        \cp conf/nginx.conf /usr/local/nginx/conf/nginx.conf || return 1
    fi
    \cp -ra conf/rewrite /usr/local/nginx/conf/ || return 1
    \cp conf/pathinfo.conf /usr/local/nginx/conf/pathinfo.conf || return 1
    \cp conf/enable-php.conf /usr/local/nginx/conf/enable-php.conf || return 1
    \cp conf/enable-php-pathinfo.conf /usr/local/nginx/conf/enable-php-pathinfo.conf || return 1
    \cp -ra conf/example /usr/local/nginx/conf/example || return 1
    if [ "${Enable_Nginx_Lua}" = 'y' ]; then
        if ! grep -q 'lua_package_path "/usr/local/nginx/lib/lua/?.lua";' /usr/local/nginx/conf/nginx.conf; then
            sed -i "/server_tokens off;/i\        lua_package_path \"/usr/local/nginx/lib/lua/?.lua\";\n" /usr/local/nginx/conf/nginx.conf
        fi
        if [ "${Stack}" = "lnmp" ]; then
            sed -i "/include enable-php.conf;/i\        location /lua\n        {\n            default_type text/html;\n            content_by_lua 'ngx.say\(\"hello world\"\)';\n        }\n" /usr/local/nginx/conf/nginx.conf
        else
            sed -i "/include proxy-pass-php.conf;/i\        location /lua\n        {\n            default_type text/html;\n            content_by_lua 'ngx.say\(\"hello world\"\)';\n        }\n" /usr/local/nginx/conf/nginx.conf
        fi
    fi
    if [ "${isWSL}" = "y" ]; then
        sed -i "/gzip on;/i\        fastcgi_buffering off;\n" /usr/local/nginx/conf/nginx.conf
    fi

    mkdir -p "${Default_Website_Dir}" || return 1
    chmod +w "${Default_Website_Dir}" || return 1
    if [[ "${Default_Website_Dir}" == /home/wwwroot/* ]]; then
        chmod 0711 /home/wwwroot || return 1
    fi
    mkdir -p /home/wwwlogs || return 1
    chmod 777 /home/wwwlogs || return 1

    if [ -e "${Default_Website_Dir}/.user.ini" ]; then
        chattr -i "${Default_Website_Dir}/.user.ini" 2>/dev/null || true
    fi
    chown -R www:www "${Default_Website_Dir}" || return 1

    mkdir -p /usr/local/nginx/conf/vhost || return 1

    if [ "${Default_Website_Dir}" != "/home/wwwroot/default" ]; then
        sed -i "s#/home/wwwroot/default#${Default_Website_Dir}#g" /usr/local/nginx/conf/nginx.conf
    fi

    if [ "${Stack}" = "lnmp" ]; then
        chattr -i "${Default_Website_Dir}/.user.ini" 2>/dev/null || true
        cat >"${Default_Website_Dir}/.user.ini"<<EOF
open_basedir=${Default_Website_Dir}:/tmp/:/proc/
EOF
        chmod 644 "${Default_Website_Dir}/.user.ini" || return 1
        chattr +i ${Default_Website_Dir}/.user.ini 2>/dev/null || true
        cat >>/usr/local/nginx/conf/fastcgi.conf<<EOF
fastcgi_param PHP_ADMIN_VALUE "open_basedir=\$document_root/:/tmp/:/proc/";
EOF
    fi

    \cp init.d/init.d.nginx /etc/init.d/nginx || return 1
    \cp init.d/nginx.service /etc/systemd/system/nginx.service || return 1
    chmod +x /etc/init.d/nginx || return 1

    if [ "${SelectMalloc}" = "3" ]; then
        mkdir -p /tmp/tcmalloc
        chown -R www:www /tmp/tcmalloc
        sed -i '/nginx.pid/a\
google_perftools_profiles /tmp/tcmalloc;' /usr/local/nginx/conf/nginx.conf
    fi

    if [ "${Stack}" != "lamp" ]; then
        uname_r=$(uname -r)
        if echo $uname_r|grep -Eq "^3\.(9|1[0-9])*|^[4-9]\.*"; then
            echo "3.9+";
            sed -i 's/listen 80 default_server;/listen 80 default_server reuseport;/g' /usr/local/nginx/conf/nginx.conf
        fi
    fi
    /usr/local/nginx/sbin/nginx -t -c /usr/local/nginx/conf/nginx.conf || return 1
}
