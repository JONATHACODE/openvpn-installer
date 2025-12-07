# 📦 OpenVPN Auto Installer dengan Web Control Panel

## ✨ Fitur Lengkap

### 🖥️ CLI (Command Line Interface)
- Menu interaktif untuk management
- Install/uninstall OpenVPN server
- Tambah/hapus client/user
- Monitor status dan connected clients
- Restart service

### 🌐 Web Control Panel
- **Dashboard** dengan statistik real-time
- **Management Client** via browser
- **Download** file .ovpn langsung
- **Monitor** bandwidth usage per client
- **Responsive** design (mobile friendly)
- **Auto-refresh** setiap 30 detik

## 📂 Struktur File Repository

```
openvpn-installer/
├── openvpn-installer.sh       # Script utama installer
├── install-web-panel.sh        # Script install web panel standalone
├── README.md                   # Dokumentasi utama
├── INSTALL.md                  # Panduan instalasi detail
├── GUIDE.md                    # Panduan lengkap penggunaan
├── LICENSE                     # MIT License
├── .gitignore                  # Git ignore rules
└── web-panel/                  # Web control panel files
    ├── index.php               # Main web panel
    ├── login.php               # Login page
    ├── download.php            # Download handler
    ├── .htaccess               # Apache rewrite rules
    └── README.md               # Dokumentasi web panel
```

## 🚀 Quick Start

### Instalasi 1 Klik

```bash
wget https://raw.githubusercontent.com/JONATHACODE/openvpn-installer/main/openvpn-installer.sh -O openvpn-installer.sh && chmod +x openvpn-installer.sh && sudo ./openvpn-installer.sh
```

### Steps:
1. Jalankan command di atas
2. Pilih menu **1** (Install OpenVPN Server)
3. Ketik **y** saat ditanya install Web Panel
4. Tunggu proses instalasi (3-5 menit)
5. Akses web panel di `http://IP_VPS_ANDA`
6. Login dengan `admin` / `admin123`

## 🎯 Cara Upload ke GitHub

### 1. Buat Repository Baru
- Buka github.com
- Klik **New Repository**
- Nama: `openvpn-installer`
- Public/Private: pilih sesuai keinginan
- Klik **Create Repository**

### 2. Upload dari Windows

Buka PowerShell di folder project:

```powershell
cd "c:\Users\jonat\Downloads\destop"

# Init git
git init

# Add all files
git add .

# Commit
git commit -m "Initial commit: OpenVPN Auto Installer with Web Panel"

# Set branch
git branch -M main

# Add remote (ganti JONATHACODE dengan username GitHub Anda)
git remote add origin https://github.com/JONATHACODE/openvpn-installer.git

# Push
git push -u origin main
```

### 3. Update README.md di GitHub

Setelah upload, edit `README.md` dan ganti semua:
- `yourusername` dengan username GitHub Anda
- `JONATHACODE` dengan username GitHub Anda

## 📋 Checklist Sebelum Upload

- [x] Script installer sudah tested
- [x] Web panel berfungsi dengan baik
- [x] README.md lengkap dengan dokumentasi
- [x] INSTALL.md untuk panduan detail
- [x] GUIDE.md untuk tutorial lengkap
- [x] .gitignore untuk keamanan
- [x] LICENSE file (MIT)
- [ ] Ganti semua `yourusername` dengan username GitHub Anda
- [ ] Test instalasi di VPS fresh Ubuntu

## 🔧 Konfigurasi Setelah Upload

### 1. Update URL di Script

Setelah upload ke GitHub, cek apakah semua URL sudah benar:

File `openvpn-installer.sh`:
- Tidak ada URL hardcoded, semua generate otomatis ✓

File `install-web-panel.sh`:
- Line 32-35: URL download web panel files
- Update jika perlu

File `README.md`:
- Line 28-29: Command instalasi 1 klik
- Line 42-52: Command instalasi manual
- Update semua `yourusername` dengan username GitHub Anda

### 2. Test Instalasi

Setelah upload, test instalasi di VPS:

```bash
wget https://raw.githubusercontent.com/JONATHACODE/openvpn-installer/main/openvpn-installer.sh -O test.sh && bash test.sh
```

## 📖 Dokumentasi untuk User

### README.md
- Overview fitur
- Instalasi cepat (1 klik)
- Cara penggunaan basic
- Troubleshooting common issues
- Security tips

### INSTALL.md
- Panduan instalasi step-by-step
- Konfigurasi firewall cloud providers
- Verifikasi instalasi
- Testing koneksi

### GUIDE.md
- Tutorial lengkap dari A-Z
- Setup web panel
- Setup client di berbagai device
- Security best practices
- FAQ dan troubleshooting detail

### web-panel/README.md
- Dokumentasi web panel
- Customization
- Security hardening
- Backup & restore

## 🔒 Security Notes

**PENTING untuk User**:
1. Ganti password default `admin123` segera!
2. Setup SSL/HTTPS untuk web panel
3. Batasi akses web panel hanya dari IP tertentu
4. Atau gunakan SSH tunnel untuk akses web panel

**File yang di-ignore (.gitignore)**:
- `*.ovpn` - File konfigurasi client
- `*.key` - Private keys
- `*.crt` - Certificates
- `*.pem` - Certificate files
- `pki/` - PKI directory

## 🎨 Fitur Web Panel

### Dashboard
- ✅ Status server (Running/Stopped)
- ✅ Total client terdaftar
- ✅ Client aktif terkoneksi
- ✅ Tombol restart server

### Kelola Client
- ✅ Form tambah client baru
- ✅ Tabel daftar semua client
- ✅ Tombol download .ovpn per client
- ✅ Tombol hapus client
- ✅ Validasi nama client

### Client Terkoneksi
- ✅ Real-time connected clients
- ✅ IP address assignment
- ✅ Bandwidth received/sent
- ✅ Connection timestamp
- ✅ Auto-refresh 30s

## 🛠️ Tech Stack

**Backend**:
- Bash Script
- PHP 7.x+
- Apache2
- OpenVPN 2.x
- Easy-RSA 3.x

**Frontend**:
- Bootstrap 5.1.3
- Bootstrap Icons
- Vanilla JavaScript

**Server**:
- Ubuntu 18.04/20.04/22.04
- systemd
- iptables

## 📊 Comparison: CLI vs Web Panel

| Feature | CLI Menu | Web Panel |
|---------|----------|-----------|
| Add Client | ✅ | ✅ |
| Remove Client | ✅ | ✅ |
| List Clients | ✅ | ✅ |
| Download .ovpn | Manual SCP | ✅ Direct |
| Connected Clients | ✅ | ✅ Real-time |
| Bandwidth Monitor | ✅ Basic | ✅ Detailed |
| Restart Server | ✅ | ✅ |
| Access | SSH Required | Browser |
| Mobile Friendly | ❌ | ✅ |
| Auto Refresh | ❌ | ✅ |

## 🌟 Keunggulan Project Ini

1. **All-in-One**: CLI + Web Panel dalam satu installer
2. **1-Click Install**: Instalasi otomatis, tidak perlu config manual
3. **User Friendly**: Interface web yang mudah digunakan
4. **Responsive**: Bisa diakses dari smartphone
5. **Real-time Monitor**: Lihat client aktif dan bandwidth usage
6. **Secure**: Implementasi sudo yang proper, session management
7. **Well Documented**: 4 file dokumentasi lengkap
8. **Open Source**: MIT License, bebas dimodifikasi

## 🎯 Target User

- VPS owner yang ingin setup VPN pribadi
- Bisnis kecil yang butuh VPN untuk karyawan
- Developer yang butuh VPN testing
- IT admin yang manage multiple VPN clients
- Anyone yang ingin privacy & security online

## 🤝 Kontribusi

Contributions are welcome! Silakan:
1. Fork repository
2. Buat feature branch
3. Commit changes
4. Push ke branch
5. Create Pull Request

## 📞 Support

- 📧 Email: (tambahkan email Anda)
- 💬 GitHub Issues: Untuk bug reports & feature requests
- 📖 Wiki: Dokumentasi tambahan (coming soon)

## 📈 Roadmap

Future features:
- [ ] Multi-language support (EN, ID)
- [ ] 2FA authentication
- [ ] Client usage statistics & graphs
- [ ] Email notifications
- [ ] API endpoints
- [ ] Docker support
- [ ] Backup/restore via web panel

## ⭐ Star History

Jangan lupa star repository ini jika bermanfaat! ⭐

## 📄 License

MIT License - Bebas digunakan untuk project personal maupun komersial.

---

**Dibuat dengan ❤️ untuk komunitas Indonesia**

🇮🇩 Made in Indonesia | 🚀 Ready to Deploy | 🔒 Security First
