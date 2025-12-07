# OpenVPN Auto Installer untuk Ubuntu 18.04

Script instalasi otomatis OpenVPN server dengan menu management yang mudah digunakan.

## Fitur

- ✅ Instalasi OpenVPN otomatis 1 klik
- ✅ Menu interaktif untuk management
- ✅ Menambah client/user baru
- ✅ Menghapus client/user
- ✅ List semua client
- ✅ Monitoring status server
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
sudo ufw allow OpenSSH
sudo ufw enable
```

Jika menggunakan cloud provider (AWS, GCP, Azure), pastikan security group mengizinkan port 1194 UDP.

## Security Tips

1. Gunakan password yang kuat untuk VPS
2. Disable root login SSH
3. Gunakan SSH key authentication
4. Enable 2FA jika memungkinkan
5. Regularly update system: `sudo apt update && sudo apt upgrade`
6. Monitor log secara berkala
7. Hapus client yang tidak digunakan

## File Penting

- Config server: `/etc/openvpn/server.conf`
- Certificates: `/etc/openvpn/easy-rsa/pki/`
- Client configs: `/etc/openvpn/clients/`
- Log status: `/etc/openvpn/openvpn-status.log`

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
