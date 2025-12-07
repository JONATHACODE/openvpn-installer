# Panduan Instalasi Detail

## Langkah-langkah Instalasi

### 1. Persiapan VPS

Pastikan VPS Anda memenuhi requirements:
- Ubuntu 18.04 atau lebih baru
- Minimal RAM 512MB (recommended 1GB)
- Akses root atau sudo
- Port 1194 UDP available

### 2. Login ke VPS

```bash
ssh root@IP_VPS_ANDA
```

Atau jika menggunakan user biasa:
```bash
ssh username@IP_VPS_ANDA
```

### 3. Update System (Opsional tapi Direkomendasikan)

```bash
sudo apt update && sudo apt upgrade -y
```

### 4. Download dan Jalankan Script

#### Metode 1: Instalasi 1 Klik (Recommended)

```bash
wget https://raw.githubusercontent.com/yourusername/openvpn-installer/main/openvpn-installer.sh -O openvpn-installer.sh && chmod +x openvpn-installer.sh && sudo ./openvpn-installer.sh
```

#### Metode 2: Step by Step

```bash
# Download script
wget https://raw.githubusercontent.com/yourusername/openvpn-installer/main/openvpn-installer.sh

# Beri permission
chmod +x openvpn-installer.sh

# Jalankan script
sudo ./openvpn-installer.sh
```

#### Metode 3: Menggunakan curl

```bash
curl -O https://raw.githubusercontent.com/yourusername/openvpn-installer/main/openvpn-installer.sh && chmod +x openvpn-installer.sh && sudo ./openvpn-installer.sh
```

### 5. Instalasi OpenVPN

Setelah script berjalan, Anda akan melihat menu:

```
======================================
   OpenVPN Management Menu
======================================

1. Install OpenVPN Server
2. Add New Client
3. Remove Client
4. List All Clients
5. Show Server Status
6. Restart OpenVPN
7. Uninstall OpenVPN
8. Exit

Select an option [1-8]:
```

Pilih **1** untuk mulai instalasi.

### 6. Proses Instalasi

Script akan:
1. Install package OpenVPN dan Easy-RSA
2. Setup Certificate Authority (CA)
3. Generate server certificates
4. Konfigurasi server OpenVPN
5. Setup firewall rules
6. Enable IP forwarding
7. Start OpenVPN service

Proses ini memakan waktu 3-5 menit tergantung spesifikasi VPS.

### 7. Membuat Client Pertama

Setelah instalasi selesai, pilih menu **2** untuk membuat client:

```
Select an option [1-8]: 2
Enter client name: user1
```

File konfigurasi akan dibuat di: `/etc/openvpn/clients/user1.ovpn`

### 8. Download File .ovpn

#### Menggunakan SCP

Dari komputer lokal Anda:

```bash
scp root@IP_VPS:/etc/openvpn/clients/user1.ovpn ./
```

#### Menggunakan FileZilla/WinSCP

1. Connect ke VPS menggunakan SFTP
2. Navigate ke `/etc/openvpn/clients/`
3. Download file `.ovpn`

#### Menggunakan cat (untuk copy-paste)

Di VPS:
```bash
cat /etc/openvpn/clients/user1.ovpn
```

Copy output, lalu paste ke file lokal dengan nama `user1.ovpn`

## Konfigurasi Firewall Cloud Provider

### AWS EC2

1. Go to Security Groups
2. Add Inbound Rule:
   - Type: Custom UDP
   - Port: 1194
   - Source: 0.0.0.0/0

### Google Cloud Platform

```bash
gcloud compute firewall-rules create openvpn \
  --allow udp:1194 \
  --source-ranges 0.0.0.0/0
```

### Azure

```bash
az network nsg rule create \
  --resource-group myResourceGroup \
  --nsg-name myNetworkSecurityGroup \
  --name allow-openvpn \
  --protocol udp \
  --priority 1000 \
  --destination-port-range 1194
```

### DigitalOcean

1. Go to Networking > Firewalls
2. Create new firewall rule:
   - Type: Custom
   - Protocol: UDP
   - Port: 1194
   - Sources: All IPv4, All IPv6

## Verifikasi Instalasi

### Cek Status OpenVPN

```bash
sudo systemctl status openvpn@server
```

Output yang benar:
```
● openvpn@server.service - OpenVPN connection to server
   Loaded: loaded
   Active: active (running)
```

### Cek Port Listening

```bash
sudo netstat -tulpn | grep 1194
```

Output:
```
udp        0      0 0.0.0.0:1194            0.0.0.0:*                           12345/openvpn
```

### Cek IP Forwarding

```bash
sysctl net.ipv4.ip_forward
```

Output harus: `net.ipv4.ip_forward = 1`

### Cek iptables Rules

```bash
sudo iptables -t nat -L -n -v
```

Harus ada rule MASQUERADE untuk subnet 10.8.0.0/24

## Testing Koneksi

### Dari Windows

1. Install OpenVPN GUI dari [openvpn.net](https://openvpn.net/community-downloads/)
2. Copy file `.ovpn` ke `C:\Program Files\OpenVPN\config\`
3. Run OpenVPN GUI as Administrator
4. Right-click icon di system tray
5. Pilih client dan klik Connect

### Dari Linux

```bash
sudo openvpn --config user1.ovpn
```

Jika sukses, Anda akan melihat:
```
Initialization Sequence Completed
```

### Test Koneksi Internet

Setelah connect, test dengan:

```bash
curl ifconfig.me
```

IP yang muncul harus IP VPS Anda, bukan IP asli.

## Troubleshooting Instalasi

### Error: "Cannot detect OS"

Pastikan Anda menggunakan Ubuntu. Cek dengan:
```bash
cat /etc/os-release
```

### Error: "This script must be run as root"

Jalankan dengan sudo:
```bash
sudo ./openvpn-installer.sh
```

### OpenVPN tidak start

Cek log:
```bash
sudo journalctl -u openvpn@server -xe
```

### Port 1194 sudah digunakan

Cek process:
```bash
sudo lsof -i :1194
```

Kill process atau gunakan port lain di `/etc/openvpn/server.conf`

### Firewall blocking

Disable firewall sementara untuk testing:
```bash
sudo ufw disable
```

Jika berhasil, enable kembali dan allow port:
```bash
sudo ufw allow 1194/udp
sudo ufw enable
```

## Next Steps

Setelah instalasi sukses:

1. ✅ Buat client untuk semua user
2. ✅ Test koneksi dari berbagai device
3. ✅ Setup monitoring (opsional)
4. ✅ Backup certificate di tempat aman
5. ✅ Setup automatic updates

## Backup Penting

Backup folder ini:

```bash
sudo tar -czf openvpn-backup.tar.gz /etc/openvpn/
```

Download backup ke komputer lokal:

```bash
scp root@IP_VPS:/root/openvpn-backup.tar.gz ./
```

## Support

Jika mengalami masalah, buat issue di GitHub atau hubungi maintainer.
