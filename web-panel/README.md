# OpenVPN Web Control Panel

Web-based control panel untuk mengelola OpenVPN server dengan mudah melalui browser.

## Screenshot

### Login Page
![Login](https://via.placeholder.com/800x500/667eea/ffffff?text=Login+Page)

### Dashboard
![Dashboard](https://via.placeholder.com/800x500/28a745/ffffff?text=Dashboard+-+Server+Status)

### Kelola Client
![Manage Clients](https://via.placeholder.com/800x500/007bff/ffffff?text=Manage+Clients)

### Client Terkoneksi
![Connected Clients](https://via.placeholder.com/800x500/17a2b8/ffffff?text=Connected+Clients)

## Fitur

- 🔐 Login authentication
- 📊 Dashboard dengan statistik real-time
- 👥 Management client (tambah, hapus, list)
- 📥 Download file .ovpn langsung dari browser
- 🔌 Monitor client yang sedang terkoneksi
- 📈 Monitor bandwidth usage per client
- 🔄 Restart OpenVPN server
- 📱 Responsive design (mobile friendly)
- 🔄 Auto-refresh setiap 30 detik

## Instalasi

Web panel otomatis terinstall saat Anda menjalankan instalasi OpenVPN dan memilih 'y' saat ditanya.

Atau install manual:

```bash
bash install-web-panel.sh
```

## Akses Web Panel

Setelah instalasi, akses melalui:

```
http://IP_SERVER_ANDA
```

**Login Default**:
- Username: `admin`
- Password: `admin123`

⚠️ **PENTING**: Segera ganti password default!

## Ganti Password

### Cara 1: Edit File PHP

```bash
sudo nano /var/www/openvpn-panel/index.php
```

Cari dan ubah baris:
```php
define('ADMIN_PASSWORD', 'admin123'); // Ganti dengan password baru
```

### Cara 2: Hash Password (Lebih Aman)

Untuk keamanan lebih baik, gunakan hash password:

```php
// Di index.php, ganti dengan:
define('ADMIN_PASSWORD_HASH', password_hash('password_baru', PASSWORD_DEFAULT));

// Dan ubah validasi login menjadi:
if ($_POST['username'] === ADMIN_USERNAME && password_verify($_POST['password'], ADMIN_PASSWORD_HASH)) {
    $_SESSION['logged_in'] = true;
}
```

## Setup SSL/HTTPS

Untuk keamanan, setup HTTPS dengan Let's Encrypt:

### Install Certbot

```bash
sudo apt install certbot python3-certbot-apache
```

### Generate SSL Certificate

```bash
sudo certbot --apache -d yourdomain.com
```

Ikuti instruksi untuk setup SSL.

### Auto-renewal

Certbot otomatis setup auto-renewal. Test dengan:

```bash
sudo certbot renew --dry-run
```

## Batasi Akses IP (Optional)

Untuk keamanan ekstra, batasi akses hanya dari IP tertentu.

Edit `/etc/apache2/sites-available/openvpn-panel.conf`:

```apache
<Directory /var/www/openvpn-panel>
    Options -Indexes +FollowSymLinks
    AllowOverride All
    
    # Hanya izinkan IP tertentu
    Require ip 103.xxx.xxx.xxx
    Require ip 192.168.1.0/24
</Directory>
```

Restart Apache:
```bash
sudo systemctl restart apache2
```

## Akses via SSH Tunnel

Untuk keamanan maksimal, akses web panel hanya via SSH tunnel:

```bash
ssh -L 8080:localhost:80 root@IP_SERVER
```

Lalu buka browser: `http://localhost:8080`

Dengan cara ini, web panel tidak perlu expose ke internet.

## Troubleshooting

### Web panel tidak bisa diakses

1. Cek Apache status:
```bash
sudo systemctl status apache2
```

2. Cek firewall:
```bash
sudo ufw status
sudo ufw allow 80/tcp
```

3. Cek logs:
```bash
sudo tail -f /var/log/apache2/openvpn-panel-error.log
```

### Permission denied saat tambah/hapus client

Cek sudoers configuration:
```bash
sudo cat /etc/sudoers.d/openvpn-panel
```

Seharusnya berisi:
```
www-data ALL=(ALL) NOPASSWD: /etc/openvpn/easy-rsa/easyrsa
www-data ALL=(ALL) NOPASSWD: /bin/systemctl restart openvpn@server
www-data ALL=(ALL) NOPASSWD: /bin/systemctl status openvpn@server
www-data ALL=(ALL) NOPASSWD: /bin/systemctl is-active openvpn@server
```

### Download file tidak berfungsi

Cek permissions:
```bash
sudo chmod 755 /etc/openvpn/clients
sudo chmod 644 /etc/openvpn/clients/*.ovpn
```

## File Struktur

```
/var/www/openvpn-panel/
├── index.php          # Main panel
├── login.php          # Login page
└── download.php       # Download handler

/etc/apache2/sites-available/
└── openvpn-panel.conf # Apache config

/etc/sudoers.d/
└── openvpn-panel      # Sudo permissions

/etc/openvpn/clients/  # .ovpn files
```

## Security Checklist

- [ ] Ganti password default
- [ ] Setup SSL/HTTPS
- [ ] Batasi akses IP (optional)
- [ ] Gunakan SSH tunnel untuk akses (optional)
- [ ] Enable firewall
- [ ] Regular backup
- [ ] Monitor logs
- [ ] Update system regularly

## Customization

### Ganti Logo/Brand

Edit `index.php`, cari:
```php
<h4><i class="bi bi-shield-lock"></i> OpenVPN</h4>
```

Ganti dengan branding Anda.

### Ubah Theme Color

Edit CSS di `index.php`, cari:
```css
.sidebar { background: #343a40; }
```

Ubah warna sesuai keinginan.

### Tambah Multiple Admin

Buat array untuk multiple user:

```php
$users = [
    'admin' => 'admin123',
    'user1' => 'password1'
];

// Validasi
if (isset($users[$_POST['username']]) && $users[$_POST['username']] === $_POST['password']) {
    $_SESSION['logged_in'] = true;
}
```

## Backup

Backup web panel:

```bash
sudo tar -czf openvpn-panel-backup.tar.gz /var/www/openvpn-panel
```

Restore:

```bash
sudo tar -xzf openvpn-panel-backup.tar.gz -C /
```

## Uninstall

Untuk uninstall web panel:

```bash
sudo a2dissite openvpn-panel.conf
sudo rm -rf /var/www/openvpn-panel
sudo rm /etc/apache2/sites-available/openvpn-panel.conf
sudo rm /etc/sudoers.d/openvpn-panel
sudo systemctl restart apache2
```

## Support

Jika ada masalah, buat issue di GitHub repository.

## License

MIT License
