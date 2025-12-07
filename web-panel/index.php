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
    exec('systemctl is-active openvpn@server', $output, $return);
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
            if ($inClientList) {
                $parts = explode(',', trim($line));
                if (count($parts) > 4) {
                    $clients[] = [
                        'name' => $parts[1],
                        'ip' => $parts[2],
                        'received' => formatBytes($parts[4]),
                        'sent' => formatBytes($parts[5]),
                        'connected' => $parts[7]
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
            $cmd = "cd " . EASYRSA_DIR . " && ./easyrsa build-client-full '$clientName' nopass 2>&1";
            exec($cmd, $output, $return);
            
            if ($return === 0) {
                // Create client config
                $serverIP = trim(shell_exec('curl -s ifconfig.me'));
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
                $clientConfig .= "\n<ca>\n" . file_get_contents(OPENVPN_DIR . '/ca.crt') . "</ca>\n";
                $clientConfig .= "\n<cert>\n" . file_get_contents(EASYRSA_DIR . "/pki/issued/$clientName.crt") . "</cert>\n";
                $clientConfig .= "\n<key>\n" . file_get_contents(EASYRSA_DIR . "/pki/private/$clientName.key") . "</key>\n";
                $clientConfig .= "\n<tls-auth>\n" . file_get_contents(OPENVPN_DIR . '/ta.key') . "</tls-auth>\n";
                
                file_put_contents(CLIENTS_DIR . "/$clientName.ovpn", $clientConfig);
                
                $message = "Client '$clientName' berhasil ditambahkan!";
                $messageType = 'success';
            } else {
                $message = "Gagal menambahkan client: " . implode("\n", $output);
                $messageType = 'danger';
            }
        } else {
            $message = "Nama client tidak valid! Gunakan huruf, angka, underscore, atau dash.";
            $messageType = 'warning';
        }
    }
    
    if (isset($_POST['delete_client'])) {
        $clientName = $_POST['client_name'];
        
        // Revoke certificate
        $cmd = "cd " . EASYRSA_DIR . " && ./easyrsa revoke '$clientName' 2>&1 && ./easyrsa gen-crl 2>&1";
        exec($cmd, $output, $return);
        
        // Remove config file
        @unlink(CLIENTS_DIR . "/$clientName.ovpn");
        
        $message = "Client '$clientName' berhasil dihapus!";
        $messageType = 'success';
    }
    
    if (isset($_POST['restart_server'])) {
        exec('systemctl restart openvpn@server 2>&1', $output, $return);
        if ($return === 0) {
            $message = "OpenVPN server berhasil direstart!";
            $messageType = 'success';
        } else {
            $message = "Gagal restart server!";
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
