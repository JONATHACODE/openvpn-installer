#!/bin/bash
#
# OpenVPN Auto Installer Script for Ubuntu 18.04
# GitHub: https://github.com/yourusername/openvpn-installer
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

# Function to check Ubuntu version
check_os() {
    if [[ -e /etc/os-release ]]; then
        source /etc/os-release
        if [[ $ID != "ubuntu" ]]; then
            echo -e "${RED}This script is for Ubuntu only${NC}"
            exit 1
        fi
        if [[ $VERSION_ID != "18.04" ]] && [[ $VERSION_ID != "20.04" ]] && [[ $VERSION_ID != "22.04" ]]; then
            echo -e "${YELLOW}Warning: This script is optimized for Ubuntu 18.04, but will try to continue${NC}"
        fi
    else
        echo -e "${RED}Cannot detect OS${NC}"
        exit 1
    fi
}

# Function to install OpenVPN
install_openvpn() {
    echo -e "${GREEN}Installing OpenVPN...${NC}"
    
    # Update system
    apt-get update
    apt-get upgrade -y
    
    # Install required packages
    apt-get install -y openvpn easy-rsa iptables-persistent
    
    # Setup Easy-RSA
    make-cadir /etc/openvpn/easy-rsa
    cd /etc/openvpn/easy-rsa
    
    # Configure Easy-RSA vars
    cat > /etc/openvpn/easy-rsa/vars << 'EOF'
set_var EASYRSA_REQ_COUNTRY    "ID"
set_var EASYRSA_REQ_PROVINCE   "Jakarta"
set_var EASYRSA_REQ_CITY       "Jakarta"
set_var EASYRSA_REQ_ORG        "MyVPN"
set_var EASYRSA_REQ_EMAIL      "admin@myvpn.com"
set_var EASYRSA_REQ_OU         "MyVPN"
set_var EASYRSA_KEY_SIZE       2048
set_var EASYRSA_CA_EXPIRE      3650
set_var EASYRSA_CERT_EXPIRE    3650
EOF

    # Initialize PKI
    ./easyrsa init-pki
    ./easyrsa --batch build-ca nopass
    ./easyrsa gen-dh
    ./easyrsa build-server-full server nopass
    openvpn --genkey --secret /etc/openvpn/easy-rsa/pki/ta.key
    
    # Copy certificates
    cp pki/ca.crt /etc/openvpn/
    cp pki/issued/server.crt /etc/openvpn/
    cp pki/private/server.key /etc/openvpn/
    cp pki/dh.pem /etc/openvpn/
    cp pki/ta.key /etc/openvpn/
    
    # Get server IP
    SERVER_IP=$(curl -s ifconfig.me)
    
    # Create server config
    cat > /etc/openvpn/server.conf << EOF
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-auth ta.key 0
topology subnet
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
cipher AES-256-CBC
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb 3
explicit-exit-notify 1
EOF

    # Enable IP forwarding
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p
    
    # Configure firewall
    # Detect network interface
    NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
    
    # Setup iptables
    iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $NIC -j MASQUERADE
    iptables-save > /etc/iptables/rules.v4
    
    # Enable and start OpenVPN
    systemctl enable openvpn@server
    systemctl start openvpn@server
    
    # Create client template
    cat > /etc/openvpn/client-template.txt << EOF
client
dev tun
proto udp
remote $SERVER_IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
verb 3
key-direction 1
EOF

    # Create client directory
    mkdir -p /etc/openvpn/clients
    
    echo -e "${GREEN}OpenVPN installation completed!${NC}"
    echo -e "${GREEN}Server IP: $SERVER_IP${NC}"
}

# Function to add new client
add_client() {
    echo -e "${GREEN}=== Add New OpenVPN Client ===${NC}"
    read -p "Enter client name: " CLIENT_NAME
    
    if [[ -z "$CLIENT_NAME" ]]; then
        echo -e "${RED}Client name cannot be empty${NC}"
        return
    fi
    
    # Check if client already exists
    if [[ -f "/etc/openvpn/clients/$CLIENT_NAME.ovpn" ]]; then
        echo -e "${RED}Client $CLIENT_NAME already exists${NC}"
        return
    fi
    
    cd /etc/openvpn/easy-rsa
    ./easyrsa build-client-full "$CLIENT_NAME" nopass
    
    # Create client config
    cat /etc/openvpn/client-template.txt > /etc/openvpn/clients/$CLIENT_NAME.ovpn
    echo "<ca>" >> /etc/openvpn/clients/$CLIENT_NAME.ovpn
    cat /etc/openvpn/ca.crt >> /etc/openvpn/clients/$CLIENT_NAME.ovpn
    echo "</ca>" >> /etc/openvpn/clients/$CLIENT_NAME.ovpn
    echo "<cert>" >> /etc/openvpn/clients/$CLIENT_NAME.ovpn
    cat /etc/openvpn/easy-rsa/pki/issued/$CLIENT_NAME.crt >> /etc/openvpn/clients/$CLIENT_NAME.ovpn
    echo "</cert>" >> /etc/openvpn/clients/$CLIENT_NAME.ovpn
    echo "<key>" >> /etc/openvpn/clients/$CLIENT_NAME.ovpn
    cat /etc/openvpn/easy-rsa/pki/private/$CLIENT_NAME.key >> /etc/openvpn/clients/$CLIENT_NAME.ovpn
    echo "</key>" >> /etc/openvpn/clients/$CLIENT_NAME.ovpn
    echo "<tls-auth>" >> /etc/openvpn/clients/$CLIENT_NAME.ovpn
    cat /etc/openvpn/ta.key >> /etc/openvpn/clients/$CLIENT_NAME.ovpn
    echo "</tls-auth>" >> /etc/openvpn/clients/$CLIENT_NAME.ovpn
    
    echo -e "${GREEN}Client $CLIENT_NAME created successfully!${NC}"
    echo -e "${GREEN}Config file: /etc/openvpn/clients/$CLIENT_NAME.ovpn${NC}"
    echo ""
    read -p "Do you want to display the config? (y/n): " SHOW_CONFIG
    if [[ "$SHOW_CONFIG" == "y" ]]; then
        cat /etc/openvpn/clients/$CLIENT_NAME.ovpn
    fi
}

# Function to remove client
remove_client() {
    echo -e "${GREEN}=== Remove OpenVPN Client ===${NC}"
    
    # List existing clients
    echo "Existing clients:"
    cd /etc/openvpn/easy-rsa/pki/issued
    ls *.crt 2>/dev/null | grep -v server | sed 's/.crt//g' | nl
    
    echo ""
    read -p "Enter client name to remove: " CLIENT_NAME
    
    if [[ -z "$CLIENT_NAME" ]]; then
        echo -e "${RED}Client name cannot be empty${NC}"
        return
    fi
    
    # Check if client exists
    if [[ ! -f "/etc/openvpn/easy-rsa/pki/issued/$CLIENT_NAME.crt" ]]; then
        echo -e "${RED}Client $CLIENT_NAME does not exist${NC}"
        return
    fi
    
    # Revoke certificate
    cd /etc/openvpn/easy-rsa
    ./easyrsa revoke "$CLIENT_NAME"
    ./easyrsa gen-crl
    
    # Remove client config
    rm -f /etc/openvpn/clients/$CLIENT_NAME.ovpn
    
    # Copy CRL
    cp /etc/openvpn/easy-rsa/pki/crl.pem /etc/openvpn/
    
    echo -e "${GREEN}Client $CLIENT_NAME removed successfully!${NC}"
}

# Function to list clients
list_clients() {
    echo -e "${GREEN}=== OpenVPN Clients List ===${NC}"
    
    if [[ ! -d "/etc/openvpn/easy-rsa/pki/issued" ]]; then
        echo -e "${RED}No clients found${NC}"
        return
    fi
    
    cd /etc/openvpn/easy-rsa/pki/issued
    echo ""
    echo "Active Clients:"
    ls *.crt 2>/dev/null | grep -v server | sed 's/.crt//g' | nl
    echo ""
}

# Function to show server status
show_status() {
    echo -e "${GREEN}=== OpenVPN Server Status ===${NC}"
    echo ""
    
    # Check if OpenVPN is running
    if systemctl is-active --quiet openvpn@server; then
        echo -e "Status: ${GREEN}Running${NC}"
    else
        echo -e "Status: ${RED}Stopped${NC}"
    fi
    
    echo ""
    echo "Connected Clients:"
    if [[ -f "/etc/openvpn/openvpn-status.log" ]]; then
        grep "^CLIENT_LIST" /etc/openvpn/openvpn-status.log | tail -n +2 | awk '{print $2, $3, $4, $5}'
    else
        echo "No clients connected"
    fi
    echo ""
}

# Function to restart OpenVPN
restart_openvpn() {
    echo -e "${GREEN}Restarting OpenVPN server...${NC}"
    systemctl restart openvpn@server
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}OpenVPN restarted successfully!${NC}"
    else
        echo -e "${RED}Failed to restart OpenVPN${NC}"
    fi
}

# Function to uninstall OpenVPN
uninstall_openvpn() {
    echo -e "${RED}=== Uninstall OpenVPN ===${NC}"
    read -p "Are you sure you want to uninstall OpenVPN? (yes/no): " CONFIRM
    
    if [[ "$CONFIRM" != "yes" ]]; then
        echo "Uninstall cancelled"
        return
    fi
    
    # Stop OpenVPN
    systemctl stop openvpn@server
    systemctl disable openvpn@server
    
    # Remove packages
    apt-get remove --purge -y openvpn easy-rsa
    
    # Remove configuration
    rm -rf /etc/openvpn
    
    # Remove iptables rules
    NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
    iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -o $NIC -j MASQUERADE 2>/dev/null
    iptables-save > /etc/iptables/rules.v4
    
    echo -e "${GREEN}OpenVPN uninstalled successfully!${NC}"
}

# Main menu
show_menu() {
    clear
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}   OpenVPN Management Menu${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo ""
    echo "1. Install OpenVPN Server"
    echo "2. Add New Client"
    echo "3. Remove Client"
    echo "4. List All Clients"
    echo "5. Show Server Status"
    echo "6. Restart OpenVPN"
    echo "7. Uninstall OpenVPN"
    echo "8. Exit"
    echo ""
}

# Main loop
main() {
    check_os
    
    while true; do
        show_menu
        read -p "Select an option [1-8]: " OPTION
        
        case $OPTION in
            1)
                install_openvpn
                read -p "Press Enter to continue..."
                ;;
            2)
                add_client
                read -p "Press Enter to continue..."
                ;;
            3)
                remove_client
                read -p "Press Enter to continue..."
                ;;
            4)
                list_clients
                read -p "Press Enter to continue..."
                ;;
            5)
                show_status
                read -p "Press Enter to continue..."
                ;;
            6)
                restart_openvpn
                read -p "Press Enter to continue..."
                ;;
            7)
                uninstall_openvpn
                read -p "Press Enter to continue..."
                ;;
            8)
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Run main function
main
