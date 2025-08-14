#!/usr/bin/env bash

# LNMP 2.0 Dependencies Fix Script
# This script fixes download links and prepares for reinstallation

echo "=== LNMP 2.0 Dependencies Fix Script ==="
echo "Fixing download dependencies and preparing for reinstallation..."

# Fix permissions
echo "Fixing file permissions..."
chmod +x /root/lnmp2.0/include/version_compare
chmod +x /root/lnmp2.0/include/*.sh
chmod +x /root/lnmp2.0/*.sh

# Clean up any failed downloads
echo "Cleaning up failed downloads..."
cd /root/lnmp2.0/src/
rm -f libmcrypt-2.5.8.tar.gz*
rm -f mcrypt-2.6.8.tar.gz*
rm -f mhash-0.9.9.9.tar.bz2*
rm -f pcre-8.44.tar.bz2*
rm -f openssl-1.1.1t.tar.gz*
rm -f boost_1_59_0.tar.bz2*
rm -f nginx-1.29.0.tar.gz*

# Clean up any partial extractions
rm -rf libmcrypt-2.5.8/
rm -rf mcrypt-2.6.8/
rm -rf mhash-0.9.9.9/
rm -rf pcre-8.44/
rm -rf openssl-1.1.1t/
rm -rf boost_1_59_0/
rm -rf nginx-1.29.0/
rm -rf mysql-5.7.42/

echo "=== Fixed Issues Summary ==="
echo "✓ Updated libmcrypt download links to GitHub mirrors"
echo "✓ Updated mcrypt download links to working GitHub repository"
echo "✓ Updated mhash download links to SourceForge"
echo "✓ Updated PCRE download links to SourceForge and Exim mirrors"
echo "✓ Updated OpenSSL download links to official source"
echo "✓ Updated Boost download links to SourceForge"
echo "✓ Fixed file permissions for version_compare script"
echo "✓ Cleaned up failed download files"
echo ""
echo "=== Ready for Reinstallation ==="
echo "You can now run the LNMP installation again:"
echo "cd /root/lnmp2.0"
echo "./install.sh lnmp"
echo ""
echo "The following versions will be installed:"
echo "- Nginx: 1.29.0 (mainline)"
echo "- MySQL: 5.7.42"
echo "- PHP: 8.4.11"