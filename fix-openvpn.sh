#!/bin/bash
#
# OpenVPN Troubleshooting & Fix Script
#

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}" 
   exit 1
fi

echo -e "${BLUE}=== OpenVPN Troubleshooting & Fix ===${NC}"
echo ""

# Check 1: OpenVPN installed?
echo -e "${YELLOW}[1] Checking if OpenVPN is installed...${NC}"
if command -v openvpn &> /dev/null; then
    echo -e "${GREEN}✓ OpenVPN is installed${NC}"
else
    echo -e "${RED}✗ OpenVPN is not installed${NC}"
    exit 1
fi

# Check 2: Config file exists?
echo -e "${YELLOW}[2] Checking configuration file...${NC}"
if [[ -f /etc/openvpn/server.conf ]]; then
    echo -e "${GREEN}✓ Config file exists${NC}"
else
    echo -e "${RED}✗ Config file not found at /etc/openvpn/server.conf${NC}"
    exit 1
fi

# Check 3: Certificates exist?
echo -e "${YELLOW}[3] Checking certificates...${NC}"
CERTS_OK=true
for file in ca.crt server.crt server.key dh.pem ta.key; do
    if [[ -f "/etc/openvpn/$file" ]]; then
        echo -e "${GREEN}✓ $file exists${NC}"
    else
        echo -e "${RED}✗ $file not found${NC}"
        CERTS_OK=false
    fi
done

if [[ "$CERTS_OK" == false ]]; then
    echo -e "${RED}Missing certificates. Please reinstall OpenVPN.${NC}"
    exit 1
fi

# Check 4: Service status
echo -e "${YELLOW}[4] Checking service status...${NC}"
if systemctl is-active --quiet openvpn@server; then
    echo -e "${GREEN}✓ OpenVPN service is running${NC}"
else
    echo -e "${RED}✗ OpenVPN service is not running${NC}"
    echo -e "${YELLOW}Checking logs...${NC}"
    journalctl -u openvpn@server -n 20 --no-pager
    
    echo ""
    echo -e "${YELLOW}Attempting to fix common issues...${NC}"
    
    # Fix 1: Check permissions
    echo -e "${BLUE}Fixing permissions...${NC}"
    chmod 600 /etc/openvpn/server.key
    chmod 644 /etc/openvpn/ca.crt
    chmod 644 /etc/openvpn/server.crt
    chmod 644 /etc/openvpn/dh.pem
    chmod 600 /etc/openvpn/ta.key
    chown -R root:root /etc/openvpn
    
    # Fix 2: Remove user/group from config if problematic
    echo -e "${BLUE}Checking user/group settings...${NC}"
    if grep -q "^user nobody" /etc/openvpn/server.conf && grep -q "^group nogroup" /etc/openvpn/server.conf; then
        echo -e "${YELLOW}Temporarily removing user/group directives...${NC}"
        sed -i 's/^user nobody/#user nobody/' /etc/openvpn/server.conf
        sed -i 's/^group nogroup/#group nogroup/' /etc/openvpn/server.conf
    fi
    
    # Fix 3: Check if tun device available
    echo -e "${BLUE}Checking TUN device...${NC}"
    if [[ ! -e /dev/net/tun ]]; then
        echo -e "${YELLOW}Creating TUN device...${NC}"
        mkdir -p /dev/net
        mknod /dev/net/tun c 10 200
        chmod 666 /dev/net/tun
    else
        echo -e "${GREEN}✓ TUN device exists${NC}"
    fi
    
    # Fix 4: Reload systemd
    echo -e "${BLUE}Reloading systemd...${NC}"
    systemctl daemon-reload
    
    # Try to start service
    echo -e "${BLUE}Attempting to start OpenVPN...${NC}"
    systemctl start openvpn@server
    sleep 3
    
    if systemctl is-active --quiet openvpn@server; then
        echo -e "${GREEN}✓ OpenVPN service started successfully!${NC}"
    else
        echo -e "${RED}✗ Still failed to start. Detailed logs:${NC}"
        journalctl -u openvpn@server -n 50 --no-pager
        
        echo ""
        echo -e "${YELLOW}Trying alternative: Start OpenVPN directly...${NC}"
        openvpn --config /etc/openvpn/server.conf &
        PID=$!
        sleep 3
        
        if kill -0 $PID 2>/dev/null; then
            echo -e "${GREEN}✓ OpenVPN started directly (PID: $PID)${NC}"
            echo -e "${YELLOW}Note: This is temporary. Service may still need fixing.${NC}"
        else
            echo -e "${RED}✗ Failed to start OpenVPN even directly${NC}"
        fi
    fi
fi

# Check 5: IP Forwarding
echo -e "${YELLOW}[5] Checking IP forwarding...${NC}"
IP_FORWARD=$(sysctl -n net.ipv4.ip_forward)
if [[ "$IP_FORWARD" == "1" ]]; then
    echo -e "${GREEN}✓ IP forwarding is enabled${NC}"
else
    echo -e "${RED}✗ IP forwarding is disabled${NC}"
    echo -e "${BLUE}Enabling IP forwarding...${NC}"
    sysctl -w net.ipv4.ip_forward=1
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    echo -e "${GREEN}✓ IP forwarding enabled${NC}"
fi

# Check 6: Firewall/iptables
echo -e "${YELLOW}[6] Checking iptables rules...${NC}"
NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
echo -e "Network interface: ${GREEN}$NIC${NC}"

if iptables -t nat -L POSTROUTING -n | grep -q "10.8.0.0/24"; then
    echo -e "${GREEN}✓ NAT rule exists${NC}"
else
    echo -e "${RED}✗ NAT rule missing${NC}"
    echo -e "${BLUE}Adding NAT rule...${NC}"
    iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $NIC -j MASQUERADE
    
    # Save iptables
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save
    else
        iptables-save > /etc/iptables/rules.v4
    fi
    echo -e "${GREEN}✓ NAT rule added${NC}"
fi

# Check 7: Port listening
echo -e "${YELLOW}[7] Checking if port 1194 is listening...${NC}"
if netstat -tulpn 2>/dev/null | grep -q ":1194.*openvpn"; then
    echo -e "${GREEN}✓ OpenVPN is listening on port 1194${NC}"
else
    if ss -tulpn 2>/dev/null | grep -q ":1194.*openvpn"; then
        echo -e "${GREEN}✓ OpenVPN is listening on port 1194${NC}"
    else
        echo -e "${RED}✗ OpenVPN is not listening on port 1194${NC}"
    fi
fi

# Check 8: Firewall blocking?
echo -e "${YELLOW}[8] Checking firewall (ufw)...${NC}"
if command -v ufw &> /dev/null; then
    UFW_STATUS=$(ufw status | head -1)
    if echo "$UFW_STATUS" | grep -q "active"; then
        echo -e "${YELLOW}UFW is active${NC}"
        if ufw status | grep -q "1194.*ALLOW"; then
            echo -e "${GREEN}✓ Port 1194 is allowed${NC}"
        else
            echo -e "${RED}✗ Port 1194 is not allowed${NC}"
            echo -e "${BLUE}Adding UFW rule...${NC}"
            ufw allow 1194/udp
            echo -e "${GREEN}✓ Port 1194 allowed${NC}"
        fi
    else
        echo -e "${GREEN}✓ UFW is inactive${NC}"
    fi
else
    echo -e "${GREEN}✓ UFW not installed${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}=== Summary ===${NC}"
if systemctl is-active --quiet openvpn@server; then
    echo -e "${GREEN}✓ OpenVPN is running properly!${NC}"
    echo ""
    echo "Server IP: $(curl -s ifconfig.me)"
    echo "Status: $(systemctl status openvpn@server | grep Active)"
    echo ""
    echo "Connected clients:"
    if [[ -f /etc/openvpn/openvpn-status.log ]]; then
        grep "^CLIENT_LIST" /etc/openvpn/openvpn-status.log | tail -n +2 || echo "No clients connected"
    fi
else
    echo -e "${RED}✗ OpenVPN is still not running${NC}"
    echo ""
    echo -e "${YELLOW}Manual steps to try:${NC}"
    echo "1. Check logs: journalctl -u openvpn@server -n 50"
    echo "2. Test config: openvpn --config /etc/openvpn/server.conf"
    echo "3. Check server.conf syntax"
    echo "4. Verify all certificates are valid"
    echo "5. Check if port 1194 is not blocked by cloud provider firewall"
fi

echo ""
echo -e "${BLUE}For web panel issues:${NC}"
echo "1. Check Apache: systemctl status apache2"
echo "2. Check PHP: php -v"
echo "3. Check permissions: ls -la /var/www/openvpn-panel"
echo "4. Check sudoers: visudo -c -f /etc/sudoers.d/openvpn-panel"
echo "5. Check logs: tail -f /var/log/apache2/openvpn-panel-error.log"
