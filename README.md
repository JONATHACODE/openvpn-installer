# OpenVPN Auto Installer untuk Ubuntu 18.04

Script instalasi otomatis OpenVPN server dengan menu management yang mudah digunakan.

## Fitur

- ✅ Instalasi OpenVPN otomatis 1 klik
- ✅ **Web Control Panel** untuk management via browser
- ✅ Menu interaktif CLI untuk management
- ✅ Menambah client/user baru (via web & CLI)
- ✅ Menghapus client/user (via web & CLI)
- ✅ List semua client
- ✅ Monitoring status server & client terkoneksi
- ✅ Download file .ovpn langsung dari web panel
- ✅ Real-time monitoring bandwidth usage
- ✅ Restart OpenVPN service
- ✅ Uninstall OpenVPN
- ✅ Generate file .ovpn otomatis
- ✅ Support Ubuntu 18.04, 20.04, 22.04

## Persyaratan

- VPS dengan Ubuntu 18.04 (atau versi lebih baru)
- Akses root
- Koneksi internet

## Instalasi Cepat (1 Klik)

Jalankan perintah berikut di VPS Ubuntu Anda:

```bash
wget https://raw.githubusercontent.com/JONATHACODE/openvpn-installer/main/openvpn-installer.sh -O openvpn-installer.sh && chmod +x openvpn-installer.sh && sudo ./openvpn-installer.sh
```

Atau dengan curl:

```bash
curl -O https://raw.githubusercontent.com/JONATHACODE/openvpn-installer/main/openvpn-installer.sh && chmod +x openvpn-installer.sh && sudo ./openvpn-installer.sh
```

## Instalasi Manual

1. Download script:
```bash
wget https://raw.githubusercontent.com/yourusername/openvpn-installer/main/openvpn-installer.sh
```

2. Beri permission execute:
```bash
chmod +x openvpn-installer.sh
```

3. Jalankan sebagai root:
```bash
sudo ./openvpn-installer.sh
```

## Cara Penggunaan

### 1. Install OpenVPN Server

Setelah menjalankan script, pilih menu **1** untuk install OpenVPN server:

```
1. Install OpenVPN Server
```

Script akan:
- Update system
- Install package yang diperlukan
- Setup certificate authority (CA)
- Konfigurasi server OpenVPN
- Setup firewall dan IP forwarding
- Start OpenVPN service
- Menanyakan apakah ingin install Web Control Panel

Setelah instalasi selesai, Anda akan mendapat URL web panel:
```
http://IP_SERVER_ANDA
```

### 🌐 Web Control Panel

Setelah install, akses web panel melalui browser:

**URL**: `http://IP_SERVER_ANDA`

**Login Default**:
- Username: `admin`
- Password: `admin123`

⚠️ **Segera ganti password** setelah login pertama!

#### Fitur Web Panel:

**Dashboard**:
- Status server (Running/Stopped)
- Jumlah total client
- Client yang sedang aktif/terkoneksi
- Tombol restart server

**Kelola Client**:
- Tambah client baru dengan form
- List semua client terdaftar
- Download file .ovpn langsung dari browser
- Hapus client

**Client Terkoneksi**:
- Lihat real-time client yang sedang connect
- Monitor IP address client
- Monitor bandwidth (data received/sent)
- Waktu koneksi

#### Ganti Password Web Panel:

Edit file `/var/www/openvpn-panel/index.php`:
```bash
sudo nano /var/www/openvpn-panel/index.php
```

Cari dan ganti baris:
```php
define('ADMIN_PASSWORD', 'admin123'); // Ganti dengan password baru
```

### 2. Menambah Client/User Baru

Pilih menu **2** untuk menambah client:

```
2. Add New Client
```

Masukkan nama client (contoh: `user1`, `laptop-john`, dll)

File konfigurasi `.ovpn` akan dibuat di: `/etc/openvpn/clients/NAMA_CLIENT.ovpn`

### 3. Menghapus Client/User

Pilih menu **3** untuk menghapus client:

```
3. Remove Client
```

Script akan menampilkan list client yang ada, lalu masukkan nama client yang ingin dihapus.

### 4. List Semua Client

Pilih menu **4** untuk melihat semua client:

```
4. List All Clients
```

### 5. Cek Status Server

Pilih menu **5** untuk melihat status:

```
5. Show Server Status
```

Menampilkan:
- Status OpenVPN (Running/Stopped)
- Daftar client yang sedang terkoneksi

### 6. Restart OpenVPN

Pilih menu **6** untuk restart service OpenVPN:

```
6. Restart OpenVPN
```

### 7. Uninstall OpenVPN

Pilih menu **7** untuk uninstall OpenVPN sepenuhnya:

```
7. Uninstall OpenVPN
```

⚠️ **Peringatan**: Ini akan menghapus semua konfigurasi dan client!

## Download File Client .ovpn

Setelah membuat client, download file `.ovpn` dari server:

```bash
scp root@IP_SERVER:/etc/openvpn/clients/NAMA_CLIENT.ovpn ./
```

Atau gunakan SFTP client seperti FileZilla, WinSCP, dll.

## Menggunakan File .ovpn

### Windows
1. Install OpenVPN GUI
2. Copy file `.ovpn` ke folder `C:\Program Files\OpenVPN\config\`
3. Klik kanan icon OpenVPN di system tray
4. Pilih client dan klik Connect

### Android
1. Install OpenVPN Connect dari Play Store
2. Import file `.ovpn`
3. Tap untuk connect

### iOS
1. Install OpenVPN Connect dari App Store
2. Import file `.ovpn`
3. Tap untuk connect

### Linux
```bash
sudo openvpn --config NAMA_CLIENT.ovpn
```

### macOS
1. Install Tunnelblick
2. Double click file `.ovpn` untuk import
3. Connect dari menu Tunnelblick

## Konfigurasi Default

- **Port**: 1194 UDP
- **Protocol**: UDP
- **Encryption**: AES-256-CBC
- **DNS**: 8.8.8.8, 8.8.4.4
- **Subnet**: 10.8.0.0/24

## Troubleshooting

### OpenVPN tidak bisa start

Cek log:
```bash
sudo journalctl -u openvpn@server -n 50
```

### Client tidak bisa connect

1. Cek firewall di VPS
2. Pastikan port 1194 UDP terbuka
3. Cek status server dengan menu 5

### Melihat log real-time

```bash
sudo tail -f /var/log/openvpn/openvpn.log
```

## Firewall

Jika menggunakan UFW:

```bash
sudo ufw allow 1194/udp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow OpenSSH
sudo ufw enable
```

**Port yang digunakan**:
- **1194/UDP**: OpenVPN server
- **80/TCP**: Web Control Panel (HTTP)
- **443/TCP**: Web Control Panel (HTTPS - jika sudah setup SSL)
- **22/TCP**: SSH

Jika menggunakan cloud provider (AWS, GCP, Azure, DigitalOcean), pastikan security group mengizinkan:
- Port **1194 UDP** untuk OpenVPN
- Port **80 TCP** untuk Web Panel

## Security Tips

1. **Ganti password web panel** setelah instalasi pertama
2. Gunakan password yang kuat untuk VPS dan web panel
3. Setup SSL/HTTPS untuk web panel (gunakan Let's Encrypt)
4. Disable root login SSH
5. Gunakan SSH key authentication
6. Enable 2FA jika memungkinkan
7. Batasi akses web panel hanya dari IP tertentu (optional)
8. Regularly update system: `sudo apt update && sudo apt upgrade`
9. Monitor log secara berkala
10. Hapus client yang tidak digunakan

### Setup SSL/HTTPS (Recommended)

Install Certbot untuk SSL gratis:

```bash
sudo apt install certbot python3-certbot-apache
sudo certbot --apache -d yourdomain.com
```

Atau akses web panel hanya dari localhost dengan SSH tunnel:
```bash
ssh -L 8080:localhost:80 root@IP_SERVER
```
Lalu buka browser: `http://localhost:8080`

## File Penting

- Config server: `/etc/openvpn/server.conf`
- Certificates: `/etc/openvpn/easy-rsa/pki/`
- Client configs: `/etc/openvpn/clients/`
- Log status: `/etc/openvpn/openvpn-status.log`
- Web panel: `/var/www/openvpn-panel/`
- Apache config: `/etc/apache2/sites-available/openvpn-panel.conf`
- Apache logs: `/var/log/apache2/openvpn-panel-*.log`

## Uninstall

Untuk uninstall sepenuhnya, gunakan menu 7 atau jalankan:

```bash
sudo systemctl stop openvpn@server
sudo apt-get remove --purge openvpn easy-rsa
sudo rm -rf /etc/openvpn
```

## Kontribusi

Pull request dan issue reports sangat diterima!

## Lisensi

MIT License

## Disclaimer

Script ini disediakan "as is" tanpa warranty. Gunakan dengan risiko Anda sendiri.

## Support

Jika ada pertanyaan atau masalah, silakan buat issue di GitHub repository ini.

---

**Dibuat dengan ❤️ untuk komunitas OpenVPN Indonesia**
