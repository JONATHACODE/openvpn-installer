# Troubleshooting Guide - OpenVPN Auto Installer

## Quick Fix - Gunakan Script Otomatis

Untuk masalah umum, jalankan script fix otomatis:

```bash
wget https://raw.githubusercontent.com/JONATHACODE/openvpn-installer/main/fix-openvpn.sh -O fix-openvpn.sh && chmod +x fix-openvpn.sh && sudo ./fix-openvpn.sh
```

Script ini akan memperbaiki:
- ✅ Permission issues
- ✅ IP forwarding
- ✅ iptables/NAT rules
- ✅ TUN device
- ✅ Firewall configuration
- ✅ Service configuration

---

## Problem 1: OpenVPN Service Tidak Start

### Gejala:
```
Job for openvpn@server.service failed
Status: Stopped (di web panel)
```

### Solusi:

**Step 1**: Cek log error
```bash
sudo journalctl -u openvpn@server -n 50 --no-pager
```

**Step 2**: Test konfigurasi
```bash
sudo openvpn --config /etc/openvpn/server.conf
```
Tekan Ctrl+C untuk stop. Jika ada error, akan muncul di sini.

**Step 3**: Cek permission certificates
```bash
sudo chmod 600 /etc/openvpn/server.key
sudo chmod 644 /etc/openvpn/ca.crt
sudo chmod 644 /etc/openvpn/server.crt
sudo chmod 644 /etc/openvpn/dh.pem
sudo chmod 600 /etc/openvpn/ta.key
```

**Step 4**: Cek TUN device
```bash
ls -la /dev/net/tun
```

Jika tidak ada:
```bash
sudo mkdir -p /dev/net
sudo mknod /dev/net/tun c 10 200
sudo chmod 666 /dev/net/tun
```

**Step 5**: Reload dan restart
```bash
sudo systemctl daemon-reload
sudo systemctl enable openvpn@server
sudo systemctl start openvpn@server
sudo systemctl status openvpn@server
```

---

## Problem 2: Web Panel Error "sudo: no tty present"

### Gejala:
```
Gagal menambahkan client: sudo: no tty present and no askpass program specified
```

### Solusi:

**Step 1**: Cek sudoers file
```bash
sudo cat /etc/sudoers.d/openvpn-panel
```

Harus berisi:
```
www-data ALL=(ALL) NOPASSWD: /usr/local/bin/openvpn-add-client
www-data ALL=(ALL) NOPASSWD: /usr/local/bin/openvpn-delete-client
www-data ALL=(ALL) NOPASSWD: /bin/systemctl restart openvpn@server
www-data ALL=(ALL) NOPASSWD: /bin/systemctl status openvpn@server
www-data ALL=(ALL) NOPASSWD: /bin/systemctl is-active openvpn@server
www-data ALL=(ALL) NOPASSWD: /bin/systemctl start openvpn@server
www-data ALL=(ALL) NOPASSWD: /bin/systemctl stop openvpn@server
www-data ALL=(ALL) NOPASSWD: /usr/bin/journalctl -u openvpn@server *
```

**Step 2**: Cek wrapper scripts exist
```bash
ls -la /usr/local/bin/openvpn-*
```

Jika tidak ada, buat manual:
```bash
sudo nano /usr/local/bin/openvpn-add-client
```

Paste:
```bash
#!/bin/bash
CLIENT_NAME=$1
if [[ -z "$CLIENT_NAME" ]]; then
    echo "Error: Client name required"
    exit 1
fi

cd /etc/openvpn/easy-rsa
./easyrsa build-client-full "$CLIENT_NAME" nopass
exit $?
```

Save (Ctrl+O, Enter, Ctrl+X), lalu:
```bash
sudo chmod +x /usr/local/bin/openvpn-add-client
```

**Step 3**: Validate sudoers
```bash
sudo visudo -c -f /etc/sudoers.d/openvpn-panel
```

Harus return: "parsed OK"

---

## Problem 3: Web Panel "Gagal Restart Server"

### Gejala:
Dashboard menampilkan "Gagal restart server!" dan log error

### Solusi:

**Step 1**: Cek service secara manual
```bash
sudo systemctl status openvpn@server
```

**Step 2**: Jika ada error, lihat detail:
```bash
sudo journalctl -u openvpn@server -n 100 --no-pager
```

**Step 3**: Common errors dan solusinya:

#### Error: "Cannot open TUN/TAP dev"
```bash
sudo modprobe tun
sudo mkdir -p /dev/net
sudo mknod /dev/net/tun c 10 200
```

#### Error: "Cannot allocate memory"
VPS kehabisan RAM. Restart VPS atau upgrade plan.

#### Error: "Permission denied"
```bash
sudo chown -R root:root /etc/openvpn
sudo chmod 755 /etc/openvpn
```

---

## Problem 4: Client Tidak Bisa Connect

### Gejala:
File .ovpn sudah diimport tapi tidak bisa connect

### Solusi:

**Step 1**: Cek OpenVPN server jalan
```bash
sudo systemctl status openvpn@server
```

**Step 2**: Cek port listening
```bash
sudo netstat -tulpn | grep 1194
```
atau
```bash
sudo ss -tulpn | grep 1194
```

Harus ada output seperti:
```
udp  0  0  0.0.0.0:1194  0.0.0.0:*  12345/openvpn
```

**Step 3**: Cek firewall VPS
```bash
sudo ufw status
```

Pastikan port 1194 allowed:
```bash
sudo ufw allow 1194/udp
```

**Step 4**: Cek firewall Cloud Provider
- **AWS**: Security Group → Inbound → UDP 1194
- **GCP**: VPC Firewall → UDP 1194
- **Azure**: NSG → Inbound → UDP 1194
- **DigitalOcean**: Networking → Firewalls → UDP 1194

**Step 5**: Cek IP forwarding
```bash
sudo sysctl net.ipv4.ip_forward
```

Harus return: `net.ipv4.ip_forward = 1`

Jika tidak:
```bash
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
```

**Step 6**: Cek iptables NAT
```bash
sudo iptables -t nat -L POSTROUTING -n -v
```

Harus ada rule MASQUERADE untuk 10.8.0.0/24

Jika tidak:
```bash
NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
sudo iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $NIC -j MASQUERADE
sudo netfilter-persistent save
```

---

## Problem 5: Download .ovpn Tidak Berfungsi

### Gejala:
Klik download tapi file tidak terdownload

### Solusi:

**Step 1**: Cek file exist
```bash
ls -la /etc/openvpn/clients/
```

**Step 2**: Cek permission
```bash
sudo chmod 755 /etc/openvpn/clients
sudo chmod 644 /etc/openvpn/clients/*.ovpn
```

**Step 3**: Cek Apache error log
```bash
sudo tail -f /var/log/apache2/openvpn-panel-error.log
```

**Step 4**: Test download.php
```bash
sudo -u www-data php /var/www/openvpn-panel/download.php
```

---

## Problem 6: Web Panel Tidak Bisa Diakses

### Gejala:
Browser tidak bisa membuka http://IP_VPS

### Solusi:

**Step 1**: Cek Apache running
```bash
sudo systemctl status apache2
```

Jika stopped:
```bash
sudo systemctl start apache2
```

**Step 2**: Cek port 80 listening
```bash
sudo netstat -tulpn | grep :80
```

**Step 3**: Cek firewall
```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

**Step 4**: Cek Apache config
```bash
sudo apache2ctl -t
```

Harus return: "Syntax OK"

**Step 5**: Cek site enabled
```bash
ls -la /etc/apache2/sites-enabled/
```

Harus ada `openvpn-panel.conf`

Jika tidak:
```bash
sudo a2ensite openvpn-panel.conf
sudo systemctl reload apache2
```

---

## Problem 7: Connected Clients Tidak Muncul

### Gejala:
Menu "Client Terkoneksi" kosong padahal ada yang connect

### Solusi:

**Step 1**: Cek status log file
```bash
cat /etc/openvpn/openvpn-status.log
```

**Step 2**: Cek konfigurasi server.conf
```bash
grep "status" /etc/openvpn/server.conf
```

Harus ada: `status openvpn-status.log`

Jika tidak ada:
```bash
echo "status openvpn-status.log" | sudo tee -a /etc/openvpn/server.conf
sudo systemctl restart openvpn@server
```

**Step 3**: Cek permission status log
```bash
sudo chmod 644 /etc/openvpn/openvpn-status.log
```

---

## Problem 8: "Permission Denied" di Web Panel

### Gejala:
Semua aksi di web panel return "Permission denied"

### Solusi:

**Complete fix**:
```bash
# Fix directory permissions
sudo chmod 755 /etc/openvpn
sudo chmod 755 /etc/openvpn/clients
sudo chmod 755 /etc/openvpn/easy-rsa
sudo chmod 755 /etc/openvpn/easy-rsa/pki

# Fix web panel permissions
sudo chown -R www-data:www-data /var/www/openvpn-panel
sudo chmod 755 /var/www/openvpn-panel
sudo chmod 644 /var/www/openvpn-panel/*.php

# Fix sudoers
sudo chmod 0440 /etc/sudoers.d/openvpn-panel
sudo visudo -c -f /etc/sudoers.d/openvpn-panel

# Restart Apache
sudo systemctl restart apache2
```

---

## Logs Penting

### OpenVPN Logs
```bash
# Real-time logs
sudo journalctl -u openvpn@server -f

# Last 50 lines
sudo journalctl -u openvpn@server -n 50

# Since today
sudo journalctl -u openvpn@server --since today
```

### Apache Logs
```bash
# Error log
sudo tail -f /var/log/apache2/openvpn-panel-error.log

# Access log
sudo tail -f /var/log/apache2/openvpn-panel-access.log
```

### System Logs
```bash
# General syslog
sudo tail -f /var/log/syslog | grep vpn
```

---

## Complete Reinstall

Jika semua solusi gagal, reinstall:

```bash
# Backup clients
sudo tar -czf openvpn-backup.tar.gz /etc/openvpn/clients/

# Uninstall
sudo ./openvpn-installer.sh
# Pilih menu 7 (Uninstall)

# Reinstall
sudo ./openvpn-installer.sh
# Pilih menu 1 (Install)

# Restore clients jika perlu
sudo tar -xzf openvpn-backup.tar.gz -C /
```

---

## Testing Checklist

Setelah troubleshooting, test:

- [ ] OpenVPN service running: `sudo systemctl status openvpn@server`
- [ ] Port listening: `sudo netstat -tulpn | grep 1194`
- [ ] Web panel accessible: buka browser ke `http://IP_VPS`
- [ ] Login web panel berhasil
- [ ] Bisa tambah client di web panel
- [ ] Bisa download .ovpn file
- [ ] Client bisa connect dengan .ovpn file
- [ ] Internet browsing works saat connected

---

## Dapatkan Help

Jika masih ada masalah:

1. Jalankan fix script: `sudo ./fix-openvpn.sh`
2. Copy semua output
3. Buat issue di GitHub dengan detail:
   - OS version: `cat /etc/os-release`
   - OpenVPN version: `openvpn --version`
   - Error logs
   - Screenshot error

---

**Semoga berhasil!** 🚀
