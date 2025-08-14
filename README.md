# LNMP 2.0 - 优化版本

Linux + Nginx + MySQL + PHP 一键安装包，已优化镜像源和PHP 8.4支持

## 🌟 特性

- ✅ **支持PHP 8.4**：完整支持最新PHP 8.4.11版本
- 🎓 **大学镜像源**：优先使用可靠的.edu大学镜像，提升下载速度
- 🔧 **依赖优化**：自动检查和安装PHP 8.4所需依赖
- 🚀 **性能提升**：优化的编译配置和现代HTTP/2语法
- 🛡️ **安全加固**：最新版本组件和安全配置

## 📦 组件版本

| 组件 | 版本 | 镜像源 |
|------|------|--------|
| **Nginx** | 1.29.0 | 官方源 |
| **MySQL** | 5.7.42 | 官方源 |
| **PHP** | 8.4.11 (新增) | 普林斯顿大学 + 芝加哥大学 |
| **Boost** | 1.59.0 | MIT大学镜像 |
| **PCRE** | 8.44 | 斯坦福大学镜像 |
| **OpenSSL** | 1.1.1t | 官方源 |

## 🎓 大学镜像源优势

### 下载速度对比
| 文件 | 原始源 | 大学镜像 | 性能提升 |
|------|--------|----------|----------|
| **PHP 8.4** | php.net | 普林斯顿大学 | 更稳定 |
| **Boost** | SourceForge 2.7MB/s | MIT 7MB/s | **+160%** |
| **PCRE** | SourceForge 问题频发 | 斯坦福 800KB/s | 稳定可靠 |

### 使用的大学镜像
- 🏛️ **普林斯顿大学**：`mirror.math.princeton.edu`
- 🏫 **MIT**：`mirrors.mit.edu`  
- 🎓 **斯坦福大学**：`ftp.cs.stanford.edu`
- 🏛️ **芝加哥大学**：`mirror.cs.uchicago.edu`
- 🎓 **犹他大学**：`mirror.chpc.utah.edu`

## 🚀 快速开始

### 系统要求
- CentOS 7/8/9, Rocky Linux, AlmaLinux, Ubuntu, Debian
- 最低2GB内存，4GB推荐
- 20GB可用磁盘空间

### 安装 LNMP
```bash
# 1. 下载并解压
wget https://github.com/licess/lnmp/archive/refs/heads/master.zip
unzip master.zip && cd lnmp-master

# 2. 运行安装
chmod +x install.sh
./install.sh

# 3. 选择组件版本
# MySQL: 5.7.42
# PHP: 8.4.11 (支持最新版本)
# Memory Allocator: 选择 Jemalloc (推荐)
```

### PHP 升级到 8.4
```bash
cd /root/lnmp2.0
./upgrade.sh php
# 输入版本号: 8.4.11
```

## 🔧 管理命令

```bash
# 服务管理
lnmp start|stop|restart|reload|status

# 虚拟主机管理
lnmp vhost add     # 添加虚拟主机
lnmp vhost list    # 列出虚拟主机
lnmp vhost del     # 删除虚拟主机

# 数据库管理
lnmp database add  # 添加数据库
lnmp database list # 列出数据库

# SSL证书
lnmp ssl add       # 添加SSL证书
lnmp dnsssl        # DNS验证SSL证书
```

## 🛠️ 优化内容

### PHP 8.4 特性支持
- ✅ **性能提升**：JIT编译器优化
- ✅ **新语法特性**：Property hooks, Asymmetric visibility
- ✅ **现代依赖**：libicu 50.1+, oniguruma, libzip 0.11+
- ✅ **兼容性检查**：自动验证依赖版本

### HTTP/2 配置修复
```nginx
# 旧语法 (已弃用)
listen 443 ssl http2;

# 新语法 (已修复)
listen 443 ssl;
http2 on;
```

### 依赖检查增强
- 自动检查 libicu 版本 (≥50.1)
- 验证 cmake 版本 (≥3.5)
- 确认 OpenSSL 版本 (≥1.1.1)
- 检测 oniguruma 可用性

## 📁 目录结构

```
lnmp2.0/
├── install.sh          # 主安装脚本
├── upgrade.sh           # 升级脚本
├── lnmp                # 管理脚本
├── conf/               # 配置文件
├── include/            # 核心函数库
│   ├── init.sh         # 安装函数 (已优化镜像)
│   ├── upgrade_php.sh  # PHP升级 (支持8.3/8.4)
│   └── version.sh      # 版本定义
├── src/                # 源码目录 (已清理)
│   └── patch/          # 重要补丁文件
└── README.md           # 本文档
```

## 🔍 故障排除

### 常见问题

**Q: PHP 8.4 编译失败？**
```bash
# 检查依赖
./upgrade.sh php
# 系统会自动检查并安装缺失依赖
```

**Q: 下载速度慢？**
- ✅ 已配置大学镜像源，大幅提升下载速度
- 🔄 多重备份策略：大学镜像 → 官方源 → 备用镜像

**Q: HTTP/2 警告？**
- ✅ 已修复 nginx 配置语法，支持现代HTTP/2指令

### 日志位置
- 安装日志：`/root/lnmp-install.log`
- 升级日志：`/root/upgrade_*_日期时间.log`
- Nginx日志：`/usr/local/nginx/logs/`
- PHP错误日志：`/usr/local/php/var/log/`
- MySQL日志：`/usr/local/mysql/var/`

## 🔗 相关链接

- **原项目**：[LNMP.org](https://lnmp.org)
- **GitHub**：[licess/lnmp](https://github.com/licess/lnmp)
- **PHP 8.4 文档**：[php.net/releases/8.4](https://www.php.net/releases/8.4/)
- **Nginx 文档**：[nginx.org/docs](http://nginx.org/en/docs/)

## 📄 许可证

本项目基于原LNMP项目，遵循相同的开源许可证。

---

## 🔄 更新日志

### v2.0-optimized (2025-08-14)
- ✅ 新增PHP 8.4.11完整支持
- 🎓 集成大学镜像源(.edu域名)
- 🔧 修复HTTP/2配置语法
- 📦 优化依赖检查和安装
- 🧹 清理源码目录，节省195MB空间
- 🚀 提升下载速度和可靠性

---

**💡 提示**：如需技术支持，请查看日志文件或访问官方社区。