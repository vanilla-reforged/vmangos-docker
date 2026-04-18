<?php
header('Content-Type: application/json');

function respond(int $statusCode, bool $success, string $message): void
{
    http_response_code($statusCode);
    echo json_encode([
        'success' => $success,
        'message' => $message,
    ]);
    exit;
}

// API key check
$apiKey = getenv('VMANGOS_API_KEY') ?: '';
$providedKey = $_SERVER['HTTP_X_API_KEY'] ?? '';

if ($apiKey === '' || !hash_equals($apiKey, $providedKey)) {
    respond(401, false, 'Unauthorized');
}

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    respond(405, false, 'Only POST allowed');
}

// Parse JSON
$rawBody = file_get_contents('php://input');
$input = json_decode($rawBody, true);

if (!is_array($input)) {
    respond(400, false, 'Invalid JSON');
}

$username = trim($input['username'] ?? '');
$password = trim($input['password'] ?? '');

if ($username === '' || $password === '') {
    respond(400, false, 'Username and password required');
}

// API-side validation
if (!ctype_alnum($username)) {
    respond(400, false, 'Username must be letters and numbers only');
}
if (strlen($username) < 4 || strlen($username) > 16) {
    respond(400, false, 'Username must be 4-16 characters long');
}

if (strlen($password) < 6 || strlen($password) > 16) {
    respond(400, false, 'Password must be 6-16 characters long');
}
if (!preg_match('/^[a-zA-Z0-9!@#$%^&*()_\-+={}\[\]?.,;:~]+$/', $password)) {
    respond(400, false, 'Password contains invalid characters');
}

// Database credentials
$dbHost = getenv('VMANGOS_API_DB_HOST') ?: 'vmangos-database';
$dbUser = getenv('VMANGOS_API_DB_USER') ?: '';
$dbPass = getenv('VMANGOS_API_DB_PASS') ?: '';
$dbName = getenv('VMANGOS_API_DB_NAME') ?: 'realmd';

// Connect for username check
$link = new mysqli($dbHost, $dbUser, $dbPass, $dbName);
if ($link->connect_error) {
    error_log('VMaNGOS API DB connection failed: ' . $link->connect_error);
    respond(500, false, 'Internal server error');
}

$stmt = $link->prepare("SELECT id FROM account WHERE username = ?");
if (!$stmt) {
    error_log('VMaNGOS API prepare failed: ' . $link->error);
    $link->close();
    respond(500, false, 'Internal server error');
}

$stmt->bind_param("s", $username);

if (!$stmt->execute()) {
    error_log('VMaNGOS API execute failed: ' . $stmt->error);
    $stmt->close();
    $link->close();
    respond(500, false, 'Internal server error');
}

$stmt->store_result();

if ($stmt->num_rows > 0) {
    $stmt->close();
    $link->close();
    respond(409, false, 'Username already taken');
}

$stmt->close();
$link->close();

// SOAP account creation
$host = getenv('VMANGOS_API_MANGOS_HOST') ?: 'vmangos-mangos';
$soapport = (int)(getenv('VMANGOS_API_SOAP_PORT') ?: 7878);
$regname = getenv('VMANGOS_API_REG_USER') ?: '';
$regpass = getenv('VMANGOS_API_REG_PASS') ?: '';

// Uppercasing password is required by your backend
$command = sprintf("account create %s %s", strtoupper($username), strtoupper($password));

try {
    $client = new SoapClient(null, [
        'location' => "http://{$host}:{$soapport}",
        'uri' => 'urn:MaNGOS',
        'style' => SOAP_RPC,
        'login' => $regname,
        'password' => $regpass,
        'exceptions' => true,
        'connection_timeout' => 5,
    ]);

    $client->__soapCall("executeCommand", [new SoapParam($command, "command")]);

    respond(200, true, 'Account created successfully');
} catch (Throwable $e) {
    error_log('VMaNGOS API SOAP create failed: ' . $e->getMessage());
    respond(502, false, 'Account creation failed');
}
