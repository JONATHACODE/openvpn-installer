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
