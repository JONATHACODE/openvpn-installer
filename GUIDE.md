# Panduan Lengkap OpenVPN dengan Web Control Panel

## Daftar Isi

1. [Instalasi Awal](#instalasi-awal)
2. [Menggunakan Web Control Panel](#menggunakan-web-control-panel)
3. [Menggunakan Menu CLI](#menggunakan-menu-cli)
4. [Setup Client di Berbagai Device](#setup-client)
5. [Security Best Practices](#security)
6. [Troubleshooting](#troubleshooting)

## Instalasi Awal

### 1. Persiapan VPS

Pastikan VPS Anda:
- OS: Ubuntu 18.04, 20.04, atau 22.04
- RAM: Minimal 512MB (recommended 1GB)
- Akses root atau sudo
- Port 1194 UDP dan 80 TCP available

### 2. Install OpenVPN

Jalankan command berikut:

```bash
wget https://raw.githubusercontent.com/JONATHACODE/openvpn-installer/main/openvpn-installer.sh -O openvpn-installer.sh && chmod +x openvpn-installer.sh && sudo ./openvpn-installer.sh
```

### 3. Pilih Menu Install

Setelah script berjalan, pilih menu `1` untuk install:

```
1. Install OpenVPN Server
```

### 4. Install Web Panel

Saat ditanya:
```
Apakah Anda ingin menginstall Web Control Panel? (y/n):
```

Ketik `y` untuk install web panel.

### 5. Catat Informasi Login

Setelah selesai, Anda akan mendapat informasi:

```
Akses web panel di: http://123.456.789.10
Username: admin
Password: admin123
```

## Menggunakan Web Control Panel

### Login

1. Buka browser
2. Akses: `http://IP_VPS_ANDA`
3. Login dengan:
   - Username: `admin`
   - Password: `admin123`

### Dashboard

Setelah login, Anda akan melihat:

- **Status Server**: Running/Stopped dengan tombol restart
- **Total Client**: Jumlah client yang terdaftar
- **Client Aktif**: Jumlah client yang sedang terkoneksi

### Tambah Client Baru

1. Klik menu **"Kelola Client"** di sidebar
2. Di form "Tambah Client Baru":
   - Masukkan nama client (contoh: `user1`, `laptop-john`)
   - Hanya boleh huruf, angka, underscore (_), dan dash (-)
   - Klik tombol **"Tambah Client"**
3. Client berhasil dibuat, file .ovpn tersedia untuk download

### Download File .ovpn

1. Di halaman "Kelola Client"
2. Lihat tabel daftar client
3. Klik tombol **"Download"** di kolom Aksi
4. File .ovpn akan terdownload ke komputer Anda

### Hapus Client

1. Di halaman "Kelola Client"
2. Klik tombol **"Hapus"** pada client yang ingin dihapus
3. Konfirmasi penghapusan
4. Client dan sertifikatnya akan dicabut (revoke)

### Monitor Client Terkoneksi

1. Klik menu **"Client Terkoneksi"** di sidebar
2. Anda akan melihat:
   - Nama client yang sedang connect
   - IP address yang diassign
   - Data yang diterima (download)
   - Data yang dikirim (upload)
   - Waktu koneksi

### Auto-Refresh

Web panel otomatis refresh setiap 30 detik untuk update data terbaru.

## Menggunakan Menu CLI

Selain web panel, Anda juga bisa gunakan menu CLI:

```bash
sudo ./openvpn-installer.sh
```

Menu yang tersedia:

```
1. Install OpenVPN Server
2. Add New Client
3. Remove Client
4. List All Clients
5. Show Server Status
6. Restart OpenVPN
7. Uninstall OpenVPN
8. Exit
```

## Setup Client di Berbagai Device

### Windows

1. Download **OpenVPN GUI** dari [openvpn.net](https://openvpn.net/community-downloads/)
2. Install OpenVPN GUI
3. Download file .ovpn dari web panel
4. Copy file ke: `C:\Program Files\OpenVPN\config\`
5. Run OpenVPN GUI **as Administrator**
6. Klik kanan icon di system tray
7. Pilih client dan klik **Connect**

### Android

1. Install **OpenVPN Connect** dari Play Store
2. Buka aplikasi
3. Tap tombol **"+"** atau **Import Profile**
4. Pilih **File** tab
5. Browse dan pilih file .ovpn yang sudah didownload
6. Tap **Import**
7. Tap profil untuk connect

### iOS (iPhone/iPad)

1. Install **OpenVPN Connect** dari App Store
2. Transfer file .ovpn ke iPhone (via email, AirDrop, atau cloud)
3. Tap file .ovpn
4. Pilih **Open in OpenVPN**
5. Tap **Add** untuk import profil
6. Tap profil untuk connect

### Linux (Ubuntu/Debian)

Via terminal:

```bash
sudo apt install openvpn
sudo openvpn --config /path/to/client.ovpn
```

Atau install Network Manager:

```bash
sudo apt install network-manager-openvpn-gnome
```

Import via GUI Settings > Network > VPN > Import from file

### macOS

1. Install **Tunnelblick** dari [tunnelblick.net](https://tunnelblick.net)
2. Download file .ovpn
3. Double-click file .ovpn
4. Tunnelblick akan import konfigurasi
5. Connect dari menu Tunnelblick

## Security Best Practices

### 1. Ganti Password Web Panel

**PENTING**: Segera ganti password default!

```bash
sudo nano /var/www/openvpn-panel/index.php
```

Cari dan ganti:
```php
define('ADMIN_PASSWORD', 'admin123'); // Ganti dengan password kuat
```

Save: `Ctrl+O`, Enter, Exit: `Ctrl+X`

### 2. Setup SSL/HTTPS

```bash
sudo apt install certbot python3-certbot-apache
sudo certbot --apache -d yourdomain.com
```

### 3. Batasi Akses Web Panel

Edit Apache config:
```bash
sudo nano /etc/apache2/sites-available/openvpn-panel.conf
```

Tambahkan:
```apache
<Directory /var/www/openvpn-panel>
    Require ip YOUR_IP_ADDRESS
</Directory>
```

### 4. Setup Firewall

```bash
sudo ufw allow 22/tcp
sudo ufw allow 1194/udp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### 5. Disable Root Login SSH

```bash
sudo nano /etc/ssh/sshd_config
```

Set:
```
PermitRootLogin no
```

Restart SSH:
```bash
sudo systemctl restart sshd
```

### 6. Regular Updates

```bash
sudo apt update && sudo apt upgrade -y
```

Setup auto-update (optional):
```bash
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

## Troubleshooting

### Web Panel Tidak Bisa Diakses

**Solusi 1**: Cek Apache
```bash
sudo systemctl status apache2
sudo systemctl restart apache2
```

**Solusi 2**: Cek firewall
```bash
sudo ufw allow 80/tcp
sudo ufw status
```

**Solusi 3**: Cek logs
```bash
sudo tail -f /var/log/apache2/openvpn-panel-error.log
```

### OpenVPN Server Tidak Jalan

```bash
sudo systemctl status openvpn@server
sudo journalctl -u openvpn@server -n 50
```

Restart:
```bash
sudo systemctl restart openvpn@server
```

### Client Tidak Bisa Connect

**Cek 1**: Port terbuka?
```bash
sudo netstat -tulpn | grep 1194
```

**Cek 2**: Firewall VPS?
```bash
sudo ufw status
```

**Cek 3**: Firewall Cloud Provider?
- AWS: Security Group port 1194 UDP
- GCP: Firewall rules port 1194 UDP
- Azure: NSG port 1194 UDP
- DigitalOcean: Firewall port 1194 UDP

**Cek 4**: IP forwarding?
```bash
sysctl net.ipv4.ip_forward
# Harus return: net.ipv4.ip_forward = 1
```

### Error Permission Denied di Web Panel

```bash
sudo chmod 755 /etc/openvpn
sudo chmod 755 /etc/openvpn/clients
sudo chmod 755 /etc/openvpn/easy-rsa
sudo chown -R www-data:www-data /var/www/openvpn-panel
```

Cek sudoers:
```bash
sudo visudo -f /etc/sudoers.d/openvpn-panel
```

### Download .ovpn Tidak Berfungsi

```bash
sudo chmod 644 /etc/openvpn/clients/*.ovpn
```

### Client Terkoneksi Tidak Muncul

Pastikan OpenVPN server.conf punya:
```bash
status openvpn-status.log
```

Cek file:
```bash
sudo cat /etc/openvpn/openvpn-status.log
```

## Tips & Tricks

### Backup Lengkap

```bash
sudo tar -czf openvpn-backup-$(date +%Y%m%d).tar.gz /etc/openvpn /var/www/openvpn-panel
```

### Restore Backup

```bash
sudo tar -xzf openvpn-backup-YYYYMMDD.tar.gz -C /
sudo systemctl restart openvpn@server apache2
```

### Cek Bandwidth Total

```bash
sudo cat /etc/openvpn/openvpn-status.log
```

### Export Semua Client

```bash
cd /etc/openvpn/clients
tar -czf all-clients.tar.gz *.ovpn
```

Download ke local:
```bash
scp root@IP_VPS:/etc/openvpn/clients/all-clients.tar.gz ./
```

### Monitoring Real-time

```bash
# Watch OpenVPN log
sudo tail -f /var/log/syslog | grep ovpn

# Watch connected clients
watch -n 2 "sudo cat /etc/openvpn/openvpn-status.log | grep CLIENT_LIST"
```

### Change OpenVPN Port

Edit `/etc/openvpn/server.conf`:
```bash
sudo nano /etc/openvpn/server.conf
```

Ganti:
```
port 1194  # Ganti dengan port lain, contoh: 443
```

Update firewall dan restart:
```bash
sudo ufw allow 443/udp
sudo systemctl restart openvpn@server
```

## FAQ

**Q: Apakah bisa diakses dari smartphone?**
A: Ya! Web panel responsive dan bisa diakses dari browser mobile.

**Q: Berapa banyak client yang bisa dibuat?**
A: Tidak ada batasan, tergantung kapasitas server.

**Q: Apakah aman?**
A: Ya, selama Anda ganti password default dan setup SSL.

**Q: Bisa pakai domain?**
A: Ya, arahkan A record domain ke IP VPS, lalu setup SSL.

**Q: Bisa multiple admin?**
A: Bisa, edit index.php dan tambah logic multiple user.

**Q: File .ovpn hilang, bisa regenerate?**
A: Bisa, cukup tambah client dengan nama yang sama atau generate manual via CLI.

## Support

Jika ada pertanyaan atau masalah:
- Buat issue di GitHub
- Cek dokumentasi di repository

## Credits

Dibuat untuk komunitas OpenVPN Indonesia 🇮🇩

Semoga bermanfaat! 🚀
