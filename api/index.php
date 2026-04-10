<?php
header('Content-Type: application/json');

// API key validation
$API_KEY = getenv('API_KEY') ?: '';
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
    echo json_encode(['success' => false, 'message' => 'username & password required']);
    exit;
}

// Build SOAP command
$host     = getenv('MANGOS_HOST');
$soapport = getenv('SOAP_PORT');
$regname  = getenv('REG_USER');
$regpass  = getenv('REG_PASS');

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

    echo json_encode(['success' => true, 'message' => 'Account created', 'soap_result' => $result]);
} catch (Exception $e) {
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
