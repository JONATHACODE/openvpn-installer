#!/bin/bash
#
# OpenVPN Web Panel Installer
#

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Installing OpenVPN Web Control Panel ===${NC}"

# Update system
echo -e "${GREEN}Updating system...${NC}"
apt-get update

# Install Apache, PHP, and required modules
echo -e "${GREEN}Installing Apache and PHP...${NC}"
apt-get install -y apache2 php libapache2-mod-php php-cli php-common

# Enable Apache modules
a2enmod rewrite
a2enmod ssl

# Create web directory
WEB_DIR="/var/www/openvpn-panel"
mkdir -p $WEB_DIR

# Download web panel files from GitHub
echo -e "${GREEN}Downloading web panel files...${NC}"
cd /tmp
wget https://raw.githubusercontent.com/JONATHACODE/openvpn-installer/main/web-panel/index.php -O index.php
wget https://raw.githubusercontent.com/JONATHACODE/openvpn-installer/main/web-panel/login.php -O login.php
wget https://raw.githubusercontent.com/JONATHACODE/openvpn-installer/main/web-panel/download.php -O download.php
wget https://raw.githubusercontent.com/JONATHACODE/openvpn-installer/main/web-panel/.htaccess -O .htaccess

# Move files to web directory
mv index.php login.php download.php .htaccess $WEB_DIR/

# Set permissions
chown -R www-data:www-data $WEB_DIR
chmod -R 755 $WEB_DIR

# Configure sudoers for web panel
echo "www-data ALL=(ALL) NOPASSWD: /usr/sbin/openvpn" >> /etc/sudoers.d/openvpn-panel
echo "www-data ALL=(ALL) NOPASSWD: /bin/systemctl restart openvpn@server" >> /etc/sudoers.d/openvpn-panel
echo "www-data ALL=(ALL) NOPASSWD: /bin/systemctl status openvpn@server" >> /etc/sudoers.d/openvpn-panel
chmod 0440 /etc/sudoers.d/openvpn-panel

# Create Apache config
cat > /etc/apache2/sites-available/openvpn-panel.conf << 'EOF'
<VirtualHost *:80>
    ServerAdmin admin@localhost
    DocumentRoot /var/www/openvpn-panel
    
    <Directory /var/www/openvpn-panel>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog ${APACHE_LOG_DIR}/openvpn-panel-error.log
    CustomLog ${APACHE_LOG_DIR}/openvpn-panel-access.log combined
</VirtualHost>
EOF

# Disable default site and enable panel
a2dissite 000-default.conf
a2ensite openvpn-panel.conf

# Restart Apache
systemctl restart apache2

# Get server IP
SERVER_IP=$(curl -s ifconfig.me)

echo ""
echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}OpenVPN Web Panel berhasil diinstall!${NC}"
echo -e "${GREEN}==================================================${NC}"
echo ""
echo -e "Akses web panel di: ${YELLOW}http://$SERVER_IP${NC}"
echo ""
echo -e "Login credentials:"
echo -e "Username: ${YELLOW}admin${NC}"
echo -e "Password: ${YELLOW}admin123${NC}"
echo ""
echo -e "${RED}PENTING: Segera ganti password di file:${NC}"
echo -e "${YELLOW}/var/www/openvpn-panel/index.php${NC}"
echo ""
echo -e "Edit line: define('ADMIN_PASSWORD', 'admin123');"
echo ""
echo -e "${GREEN}Untuk keamanan lebih baik, setup SSL/HTTPS${NC}"
echo ""

# Optional: Setup firewall
read -p "Apakah Anda ingin membuka port 80 di firewall? (y/n): " SETUP_FW
if [[ "$SETUP_FW" == "y" ]]; then
    ufw allow 80/tcp
    ufw allow 443/tcp
    echo -e "${GREEN}Port 80 dan 443 dibuka di firewall${NC}"
fi

echo -e "${GREEN}Instalasi selesai!${NC}"
