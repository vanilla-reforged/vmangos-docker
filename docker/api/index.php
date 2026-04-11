<?php
header('Content-Type: application/json');

// API key check
$API_KEY = getenv('VMANGOS_API_KEY') ?: '';
if ($_SERVER['HTTP_X_API_KEY'] !== $API_KEY) {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Unauthorized']);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Only POST allowed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);
$username = trim($input['username'] ?? '');
$password = trim($input['password'] ?? '');

if (!$username || !$password) {
    echo json_encode(['success' => false, 'message' => 'Username and password required']);
    exit;
}

// Database credentials
$dbHost = getenv('VMANGOS_API_DB_HOST') ?: 'vmangos-database';
$dbUser = getenv('VMANGOS_API_DB_USER') ?: '';
$dbPass = getenv('VMANGOS_API_DB_PASS') ?: '';
$dbName = getenv('VMANGOS_API_DB_NAME') ?: 'realmd';

// Connect for username check
$link = new mysqli($dbHost, $dbUser, $dbPass, $dbName);
if ($link->connect_error) {
    echo json_encode(['success' => false, 'message' => 'Database connection failed']);
    exit;
}

$stmt = $link->prepare("SELECT id FROM account WHERE username = ?");
$stmt->bind_param("s", $username);
$stmt->execute();
$stmt->store_result();
if ($stmt->num_rows > 0) {
    echo json_encode(['success' => false, 'message' => 'Username already taken']);
    exit;
}
$stmt->close();

// Now do SOAP account creation
$host = getenv('VMANGOS_API_MANGOS_HOST') ?: 'vmangos-mangos';
$soapport = getenv('VMANGOS_API_SOAP_PORT') ?: 7878;
$regname = getenv('VMANGOS_API_REG_USER') ?: '';
$regpass = getenv('VMANGOS_API_REG_PASS') ?: '';

$command = sprintf("account create %s %s", strtoupper($username), strtoupper($password));

try {
    $client = new SoapClient(null, [
        "location" => "http://$host:$soapport",
        "uri"      => "urn:MaNGOS",
        "style"    => SOAP_RPC,
        'login'    => $regname,
        'password' => $regpass
    ]);

    $result = $client->__soapCall("executeCommand", [new SoapParam($command, "command")]);

    echo json_encode(['success' => true, 'message' => 'Account created successfully']);
} catch (Exception $e) {
    echo json_encode(['success' => false, 'message' => 'SOAP create failed: ' . $e->getMessage()]);
}
