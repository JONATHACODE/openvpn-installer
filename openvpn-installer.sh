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
    
    # Create systemd service link
    ln -sf /lib/systemd/system/openvpn@.service /etc/systemd/system/multi-user.target.wants/openvpn@server.service
    
    # Enable and start OpenVPN
    systemctl daemon-reload
    systemctl enable openvpn@server
    systemctl start openvpn@server
    
    # Wait a bit for service to start
    sleep 3
    
    # Check if started successfully
    if systemctl is-active --quiet openvpn@server; then
        echo -e "${GREEN}OpenVPN service started successfully!${NC}"
    else
        echo -e "${YELLOW}Warning: OpenVPN service may not have started. Checking logs...${NC}"
        journalctl -u openvpn@server -n 20 --no-pager
    fi
    
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
    
    # Ask to install web panel
    echo ""
    read -p "Apakah Anda ingin menginstall Web Control Panel? (y/n): " INSTALL_PANEL
    if [[ "$INSTALL_PANEL" == "y" ]]; then
        install_web_panel
    fi
}

# Function to install web panel
install_web_panel() {
    echo -e "${GREEN}Installing Web Control Panel...${NC}"
    
    # Install Apache and PHP
    apt-get install -y apache2 php libapache2-mod-php php-cli php-common
    
    # Enable Apache modules
    a2enmod rewrite
    a2enmod ssl
    
    # Create web directory
    WEB_DIR="/var/www/openvpn-panel"
    mkdir -p $WEB_DIR
    
    # Create index.php
    cat > $WEB_DIR/index.php << 'PHPEOF'
<?php
session_start();

// Configuration
define('ADMIN_USERNAME', 'admin');
define('ADMIN_PASSWORD', 'admin123'); // Change this!
define('OPENVPN_DIR', '/etc/openvpn');
define('CLIENTS_DIR', '/etc/openvpn/clients');
define('EASYRSA_DIR', '/etc/openvpn/easy-rsa');

// Check if logged in
if (!isset($_SESSION['logged_in'])) {
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['login'])) {
        if ($_POST['username'] === ADMIN_USERNAME && $_POST['password'] === ADMIN_PASSWORD) {
            $_SESSION['logged_in'] = true;
            header('Location: index.php');
            exit;
        } else {
            $error = "Username atau password salah!";
        }
    }
    
    // Show login page
    include 'login.php';
    exit;
}

// Logout
if (isset($_GET['logout'])) {
    session_destroy();
    header('Location: index.php');
    exit;
}

// Get server status
function getServerStatus() {
    exec('sudo systemctl is-active openvpn@server', $output, $return);
    return $return === 0 ? 'running' : 'stopped';
}

// Get connected clients
function getConnectedClients() {
    $clients = [];
    $statusFile = OPENVPN_DIR . '/openvpn-status.log';
    
    if (file_exists($statusFile)) {
        $lines = file($statusFile);
        $inClientList = false;
        
        foreach ($lines as $line) {
            if (strpos($line, 'CLIENT_LIST') === 0) {
                $inClientList = true;
                continue;
            }
            if ($inClientList && strpos($line, 'ROUTING_TABLE') === 0) {
                break;
            }
            if ($inClientList && !empty(trim($line))) {
                $parts = explode(',', trim($line));
                if (count($parts) > 4 && $parts[0] === 'CLIENT_LIST') {
                    $clients[] = [
                        'name' => $parts[1],
                        'ip' => $parts[2],
                        'received' => formatBytes($parts[4]),
                        'sent' => formatBytes($parts[5]),
                        'connected' => date('Y-m-d H:i:s', strtotime($parts[7]))
                    ];
                }
            }
        }
    }
    
    return $clients;
}

// Get all clients
function getAllClients() {
    $clients = [];
    $pki = EASYRSA_DIR . '/pki/issued';
    
    if (is_dir($pki)) {
        $files = scandir($pki);
        foreach ($files as $file) {
            if (pathinfo($file, PATHINFO_EXTENSION) === 'crt' && $file !== 'server.crt') {
                $clientName = pathinfo($file, PATHINFO_FILENAME);
                $clients[] = [
                    'name' => $clientName,
                    'file' => CLIENTS_DIR . '/' . $clientName . '.ovpn',
                    'exists' => file_exists(CLIENTS_DIR . '/' . $clientName . '.ovpn')
                ];
            }
        }
    }
    
    return $clients;
}

// Format bytes
function formatBytes($bytes) {
    if ($bytes >= 1073741824) {
        return number_format($bytes / 1073741824, 2) . ' GB';
    } elseif ($bytes >= 1048576) {
        return number_format($bytes / 1048576, 2) . ' MB';
    } elseif ($bytes >= 1024) {
        return number_format($bytes / 1024, 2) . ' KB';
    } else {
        return $bytes . ' B';
    }
}

// Handle actions
$message = '';
$messageType = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['add_client'])) {
        $clientName = trim($_POST['client_name']);
        if (!empty($clientName) && preg_match('/^[a-zA-Z0-9_-]+$/', $clientName)) {
            // Check if client already exists
            if (file_exists(EASYRSA_DIR . "/pki/issued/$clientName.crt")) {
                $message = "Client '$clientName' sudah ada!";
                $messageType = 'warning';
            } else {
                // Use wrapper script
                $cmd = "sudo /usr/local/bin/openvpn-add-client " . escapeshellarg($clientName) . " 2>&1";
                exec($cmd, $output, $return);
                
                if ($return === 0) {
                    // Wait a bit for files to be created
                    sleep(1);
                    
                    // Create client config
                    $serverIP = trim(shell_exec('curl -s ifconfig.me'));
                    if (empty($serverIP)) {
                        $serverIP = trim(shell_exec('hostname -I | awk \'{print $1}\''));
                    }
                    
                    $clientConfig = "client
dev tun
proto udp
remote $serverIP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
verb 3
key-direction 1
";
                    // Add certificates
                    $ca = @file_get_contents(OPENVPN_DIR . '/ca.crt');
                    $cert = @file_get_contents(EASYRSA_DIR . "/pki/issued/$clientName.crt");
                    $key = @file_get_contents(EASYRSA_DIR . "/pki/private/$clientName.key");
                    $ta = @file_get_contents(OPENVPN_DIR . '/ta.key');
                    
                    if ($ca && $cert && $key && $ta) {
                        $clientConfig .= "\n<ca>\n" . $ca . "</ca>\n";
                        $clientConfig .= "\n<cert>\n" . $cert . "</cert>\n";
                        $clientConfig .= "\n<key>\n" . $key . "</key>\n";
                        $clientConfig .= "\n<tls-auth>\n" . $ta . "</tls-auth>\n";
                        
                        file_put_contents(CLIENTS_DIR . "/$clientName.ovpn", $clientConfig);
                        chmod(CLIENTS_DIR . "/$clientName.ovpn", 0644);
                        
                        $message = "Client '$clientName' berhasil ditambahkan!";
                        $messageType = 'success';
                    } else {
                        $message = "Client dibuat tetapi gagal membaca certificate files. Error: " . implode(" ", $output);
                        $messageType = 'warning';
                    }
                } else {
                    $message = "Gagal menambahkan client: " . implode("<br>", array_map('htmlspecialchars', $output));
                    $messageType = 'danger';
                }
            }
        } else {
            $message = "Nama client tidak valid! Gunakan huruf, angka, underscore, atau dash.";
            $messageType = 'warning';
        }
    }
    
    if (isset($_POST['delete_client'])) {
        $clientName = trim($_POST['client_name']);
        
        // Revoke certificate using wrapper script
        $cmd = "sudo /usr/local/bin/openvpn-delete-client " . escapeshellarg($clientName) . " 2>&1";
        exec($cmd, $output, $return);
        
        // Remove config file
        @unlink(CLIENTS_DIR . "/$clientName.ovpn");
        
        $message = "Client '$clientName' berhasil dihapus!";
        $messageType = 'success';
    }
    
    if (isset($_POST['restart_server'])) {
        exec('sudo systemctl restart openvpn@server 2>&1', $output, $return);
        sleep(2); // Wait for service to restart
        
        // Check if actually running
        exec('sudo systemctl is-active openvpn@server', $statusOutput, $statusReturn);
        
        if ($statusReturn === 0) {
            $message = "OpenVPN server berhasil direstart!";
            $messageType = 'success';
        } else {
            $errorLog = shell_exec('sudo journalctl -u openvpn@server -n 10 --no-pager 2>&1');
            $message = "Gagal restart server! Log: <pre>" . htmlspecialchars($errorLog) . "</pre>";
            $messageType = 'danger';
        }
    }
}

// Get data
$serverStatus = getServerStatus();
$connectedClients = getConnectedClients();
$allClients = getAllClients();
?>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OpenVPN Control Panel</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.7.2/font/bootstrap-icons.css">
    <style>
        .status-running { color: #28a745; }
        .status-stopped { color: #dc3545; }
        .sidebar { min-height: 100vh; background: #343a40; }
        .sidebar .nav-link { color: #fff; }
        .sidebar .nav-link:hover { background: #495057; }
        .sidebar .nav-link.active { background: #007bff; }
    </style>
</head>
<body>
    <div class="container-fluid">
        <div class="row">
            <!-- Sidebar -->
            <div class="col-md-2 sidebar">
                <div class="text-white p-3">
                    <h4><i class="bi bi-shield-lock"></i> OpenVPN</h4>
                </div>
                <nav class="nav flex-column">
                    <a class="nav-link active" href="#dashboard" data-section="dashboard">
                        <i class="bi bi-speedometer2"></i> Dashboard
                    </a>
                    <a class="nav-link" href="#clients" data-section="clients">
                        <i class="bi bi-people"></i> Kelola Client
                    </a>
                    <a class="nav-link" href="#connected" data-section="connected">
                        <i class="bi bi-plug"></i> Client Terkoneksi
                    </a>
                    <a class="nav-link" href="?logout">
                        <i class="bi bi-box-arrow-right"></i> Logout
                    </a>
                </nav>
            </div>
            
            <!-- Main content -->
            <div class="col-md-10 p-4">
                <?php if ($message): ?>
                    <div class="alert alert-<?= $messageType ?> alert-dismissible fade show">
                        <?= htmlspecialchars($message) ?>
                        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
                    </div>
                <?php endif; ?>
                
                <!-- Dashboard Section -->
                <div id="dashboard-section" class="content-section">
                    <h2>Dashboard</h2>
                    <div class="row mt-4">
                        <div class="col-md-4">
                            <div class="card">
                                <div class="card-body">
                                    <h5 class="card-title">Status Server</h5>
                                    <h3 class="<?= $serverStatus === 'running' ? 'status-running' : 'status-stopped' ?>">
                                        <i class="bi bi-circle-fill"></i>
                                        <?= ucfirst($serverStatus) ?>
                                    </h3>
                                    <form method="post" class="mt-3">
                                        <button type="submit" name="restart_server" class="btn btn-warning">
                                            <i class="bi bi-arrow-clockwise"></i> Restart Server
                                        </button>
                                    </form>
                                </div>
                            </div>
                        </div>
                        <div class="col-md-4">
                            <div class="card">
                                <div class="card-body">
                                    <h5 class="card-title">Total Client</h5>
                                    <h3><?= count($allClients) ?></h3>
                                    <p class="text-muted">Client terdaftar</p>
                                </div>
                            </div>
                        </div>
                        <div class="col-md-4">
                            <div class="card">
                                <div class="card-body">
                                    <h5 class="card-title">Client Aktif</h5>
                                    <h3><?= count($connectedClients) ?></h3>
                                    <p class="text-muted">Sedang terkoneksi</p>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                
                <!-- Clients Section -->
                <div id="clients-section" class="content-section" style="display:none;">
                    <h2>Kelola Client</h2>
                    
                    <!-- Add Client Form -->
                    <div class="card mt-4">
                        <div class="card-header bg-primary text-white">
                            <i class="bi bi-plus-circle"></i> Tambah Client Baru
                        </div>
                        <div class="card-body">
                            <form method="post">
                                <div class="row">
                                    <div class="col-md-6">
                                        <input type="text" name="client_name" class="form-control" 
                                               placeholder="Nama client (contoh: user1)" required 
                                               pattern="[a-zA-Z0-9_-]+" 
                                               title="Hanya huruf, angka, underscore, dan dash">
                                    </div>
                                    <div class="col-md-6">
                                        <button type="submit" name="add_client" class="btn btn-primary">
                                            <i class="bi bi-plus"></i> Tambah Client
                                        </button>
                                    </div>
                                </div>
                            </form>
                        </div>
                    </div>
                    
                    <!-- Clients List -->
                    <div class="card mt-4">
                        <div class="card-header">
                            <i class="bi bi-list"></i> Daftar Client
                        </div>
                        <div class="card-body">
                            <table class="table table-striped">
                                <thead>
                                    <tr>
                                        <th>No</th>
                                        <th>Nama Client</th>
                                        <th>Status File</th>
                                        <th>Aksi</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php $no = 1; foreach ($allClients as $client): ?>
                                    <tr>
                                        <td><?= $no++ ?></td>
                                        <td><?= htmlspecialchars($client['name']) ?></td>
                                        <td>
                                            <?php if ($client['exists']): ?>
                                                <span class="badge bg-success">File tersedia</span>
                                            <?php else: ?>
                                                <span class="badge bg-warning">File tidak ada</span>
                                            <?php endif; ?>
                                        </td>
                                        <td>
                                            <?php if ($client['exists']): ?>
                                                <a href="download.php?client=<?= urlencode($client['name']) ?>" 
                                                   class="btn btn-sm btn-success">
                                                    <i class="bi bi-download"></i> Download
                                                </a>
                                            <?php endif; ?>
                                            <form method="post" style="display:inline;" 
                                                  onsubmit="return confirm('Yakin ingin menghapus client ini?')">
                                                <input type="hidden" name="client_name" value="<?= htmlspecialchars($client['name']) ?>">
                                                <button type="submit" name="delete_client" class="btn btn-sm btn-danger">
                                                    <i class="bi bi-trash"></i> Hapus
                                                </button>
                                            </form>
                                        </td>
                                    </tr>
                                    <?php endforeach; ?>
                                    <?php if (empty($allClients)): ?>
                                    <tr>
                                        <td colspan="4" class="text-center">Belum ada client</td>
                                    </tr>
                                    <?php endif; ?>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
                
                <!-- Connected Clients Section -->
                <div id="connected-section" class="content-section" style="display:none;">
                    <h2>Client Terkoneksi</h2>
                    <div class="card mt-4">
                        <div class="card-body">
                            <table class="table table-striped">
                                <thead>
                                    <tr>
                                        <th>No</th>
                                        <th>Nama Client</th>
                                        <th>IP Address</th>
                                        <th>Data Diterima</th>
                                        <th>Data Dikirim</th>
                                        <th>Waktu Koneksi</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php $no = 1; foreach ($connectedClients as $client): ?>
                                    <tr>
                                        <td><?= $no++ ?></td>
                                        <td><?= htmlspecialchars($client['name']) ?></td>
                                        <td><?= htmlspecialchars($client['ip']) ?></td>
                                        <td><?= htmlspecialchars($client['received']) ?></td>
                                        <td><?= htmlspecialchars($client['sent']) ?></td>
                                        <td><?= htmlspecialchars($client['connected']) ?></td>
                                    </tr>
                                    <?php endforeach; ?>
                                    <?php if (empty($connectedClients)): ?>
                                    <tr>
                                        <td colspan="6" class="text-center">Tidak ada client yang terkoneksi</td>
                                    </tr>
                                    <?php endif; ?>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        // Handle section switching
        document.querySelectorAll('.nav-link[data-section]').forEach(link => {
            link.addEventListener('click', function(e) {
                e.preventDefault();
                
                // Remove active class from all links
                document.querySelectorAll('.nav-link').forEach(l => l.classList.remove('active'));
                this.classList.add('active');
                
                // Hide all sections
                document.querySelectorAll('.content-section').forEach(section => {
                    section.style.display = 'none';
                });
                
                // Show selected section
                const sectionId = this.dataset.section + '-section';
                document.getElementById(sectionId).style.display = 'block';
            });
        });
        
        // Auto refresh every 30 seconds
        setTimeout(() => location.reload(), 30000);
    </script>
</body>
</html>
PHPEOF

    # Create login.php
    cat > $WEB_DIR/login.php << 'PHPEOF'
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login - OpenVPN Control Panel</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        body {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .login-card {
            max-width: 400px;
            width: 100%;
        }
    </style>
</head>
<body>
    <div class="login-card">
        <div class="card shadow-lg">
            <div class="card-body p-5">
                <div class="text-center mb-4">
                    <h3>🔐 OpenVPN Control Panel</h3>
                    <p class="text-muted">Silakan login untuk melanjutkan</p>
                </div>
                
                <?php if (isset($error)): ?>
                    <div class="alert alert-danger"><?= htmlspecialchars($error) ?></div>
                <?php endif; ?>
                
                <form method="post">
                    <div class="mb-3">
                        <label class="form-label">Username</label>
                        <input type="text" name="username" class="form-control" required autofocus>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Password</label>
                        <input type="password" name="password" class="form-control" required>
                    </div>
                    <button type="submit" name="login" class="btn btn-primary w-100">Login</button>
                </form>
                
                <div class="text-center mt-3">
                    <small class="text-muted">Default: admin / admin123</small>
                </div>
            </div>
        </div>
    </div>
</body>
</html>
PHPEOF

    # Create download.php
    cat > $WEB_DIR/download.php << 'PHPEOF'
<?php
session_start();

// Check if logged in
if (!isset($_SESSION['logged_in'])) {
    header('Location: index.php');
    exit;
}

define('CLIENTS_DIR', '/etc/openvpn/clients');

if (isset($_GET['client'])) {
    $clientName = basename($_GET['client']); // Prevent directory traversal
    $filePath = CLIENTS_DIR . '/' . $clientName . '.ovpn';
    
    if (file_exists($filePath)) {
        header('Content-Type: application/x-openvpn-profile');
        header('Content-Disposition: attachment; filename="' . $clientName . '.ovpn"');
        header('Content-Length: ' . filesize($filePath));
        readfile($filePath);
        exit;
    }
}

header('Location: index.php');
exit;
PHPEOF

    # Set permissions
    chown -R www-data:www-data $WEB_DIR
    chmod -R 755 $WEB_DIR
    chmod 644 $WEB_DIR/*.php
    
    # Set permissions for openvpn directories
    chmod 755 /etc/openvpn
    chmod 755 /etc/openvpn/clients
    chmod 755 /etc/openvpn/easy-rsa
    chmod 755 /etc/openvpn/easy-rsa/pki
    chmod -R 644 /etc/openvpn/clients/*.ovpn 2>/dev/null || true
    
    # Create wrapper scripts for web panel (more secure than direct sudo)
    cat > /usr/local/bin/openvpn-add-client << 'WRAPPEREOF'
#!/bin/bash
CLIENT_NAME=$1
if [[ -z "$CLIENT_NAME" ]]; then
    echo "Error: Client name required"
    exit 1
fi

cd /etc/openvpn/easy-rsa
./easyrsa build-client-full "$CLIENT_NAME" nopass
exit $?
WRAPPEREOF
    chmod +x /usr/local/bin/openvpn-add-client
    
    cat > /usr/local/bin/openvpn-delete-client << 'WRAPPEREOF'
#!/bin/bash
CLIENT_NAME=$1
if [[ -z "$CLIENT_NAME" ]]; then
    echo "Error: Client name required"
    exit 1
fi

cd /etc/openvpn/easy-rsa
./easyrsa revoke "$CLIENT_NAME" <<EOF
yes
EOF
./easyrsa gen-crl
cp pki/crl.pem /etc/openvpn/
exit $?
WRAPPEREOF
    chmod +x /usr/local/bin/openvpn-delete-client
    
    # Configure sudoers for web panel
    cat > /etc/sudoers.d/openvpn-panel << 'SUDOEOF'
# Allow www-data to manage OpenVPN
www-data ALL=(ALL) NOPASSWD: /usr/local/bin/openvpn-add-client
www-data ALL=(ALL) NOPASSWD: /usr/local/bin/openvpn-delete-client
www-data ALL=(ALL) NOPASSWD: /bin/systemctl restart openvpn@server
www-data ALL=(ALL) NOPASSWD: /bin/systemctl status openvpn@server
www-data ALL=(ALL) NOPASSWD: /bin/systemctl is-active openvpn@server
www-data ALL=(ALL) NOPASSWD: /bin/systemctl start openvpn@server
www-data ALL=(ALL) NOPASSWD: /bin/systemctl stop openvpn@server
www-data ALL=(ALL) NOPASSWD: /usr/bin/journalctl -u openvpn@server *
SUDOEOF
    chmod 0440 /etc/sudoers.d/openvpn-panel
    
    # Validate sudoers file
    visudo -c -f /etc/sudoers.d/openvpn-panel
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Error: Invalid sudoers configuration${NC}"
        rm /etc/sudoers.d/openvpn-panel
        exit 1
    fi
    
    # Create Apache config
    cat > /etc/apache2/sites-available/openvpn-panel.conf << 'APACHEEOF'
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
APACHEEOF

    # Disable default site and enable panel
    a2dissite 000-default.conf 2>/dev/null
    a2ensite openvpn-panel.conf
    
    # Restart Apache
    systemctl restart apache2
    
    # Get server IP
    SERVER_IP=$(curl -s ifconfig.me)
    
    echo ""
    echo -e "${GREEN}==================================================${NC}"
    echo -e "${GREEN}Web Control Panel berhasil diinstall!${NC}"
    echo -e "${GREEN}==================================================${NC}"
    echo ""
    echo -e "Akses web panel di: ${YELLOW}http://$SERVER_IP${NC}"
    echo ""
    echo -e "Login credentials:"
    echo -e "Username: ${YELLOW}admin${NC}"
    echo -e "Password: ${YELLOW}admin123${NC}"
    echo ""
    echo -e "${RED}PENTING: Segera ganti password di:${NC}"
    echo -e "${YELLOW}/var/www/openvpn-panel/index.php${NC}"
    echo ""
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
