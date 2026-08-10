<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed.']);
    exit;
}

const KEYAUTH_URL = 'https://keyauth.win/api/1.3/';
const KEYAUTH_NAME = 'gurpholderapp';
const KEYAUTH_OWNER_ID = 'YmFLPW5AMh';
const KEYAUTH_VERSION = '1.0';
const TOKEN_SECRET = 'change-this-to-a-long-random-secret';
const TOKEN_TTL_SECONDS = 28800; // 8 hours
const DOWNLOAD_URL = 'https://gurp.cc/gurp%20onboarding.exe';
const DEBUG_ERRORS = true;

function json_response(array $payload, int $status = 200): void
{
    http_response_code($status);
    echo json_encode($payload);
    exit;
}

function fail_keyauth_transport(string $reason): void
{
    $message = 'Unable to reach KeyAuth.';
    if (DEBUG_ERRORS) {
        $message .= ' ' . $reason;
    }
    json_response(['success' => false, 'message' => $message], 502);
}

function read_json_body(): array
{
    $raw = file_get_contents('php://input');
    if ($raw === false || $raw === '') {
        return [];
    }
    $decoded = json_decode($raw, true);
    return is_array($decoded) ? $decoded : [];
}

function b64url_encode(string $value): string
{
    return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
}

function b64url_decode(string $value): string
{
    $padLength = 4 - (strlen($value) % 4);
    if ($padLength < 4) {
        $value .= str_repeat('=', $padLength);
    }
    return (string) base64_decode(strtr($value, '-_', '+/'));
}

function keyauth_call(array $params): array
{
    $url = KEYAUTH_URL . '?' . http_build_query($params);
    $response = false;
    $transportError = '';

    // Prefer cURL because many hosts disable allow_url_fopen for remote HTTPS.
    if (function_exists('curl_init')) {
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CONNECTTIMEOUT => 8,
            CURLOPT_TIMEOUT => 15,
            CURLOPT_FOLLOWLOCATION => true,
            CURLOPT_USERAGENT => 'gurp-access-gateway',
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2
        ]);
        $response = curl_exec($ch);
        if ($response === false) {
            $transportError = 'cURL: ' . (string) curl_error($ch);
        } else {
            $httpCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
            if ($httpCode < 200 || $httpCode >= 300) {
                $transportError = 'cURL HTTP status ' . $httpCode . '.';
                $response = false;
            }
        }
        curl_close($ch);
    }

    if ($response === false) {
        $context = stream_context_create([
            'http' => [
                'method' => 'GET',
                'timeout' => 15,
                'ignore_errors' => true,
                'header' => "User-Agent: gurp-access-gateway\r\n"
            ],
            'ssl' => [
                'verify_peer' => true,
                'verify_peer_name' => true
            ]
        ]);

        $response = @file_get_contents($url, false, $context);
        if ($response === false) {
            $lastError = error_get_last();
            $fallbackError = isset($lastError['message']) ? (string) $lastError['message'] : 'stream request failed.';
            $hint = 'Check outbound HTTPS, DNS, and allow_url_fopen/cURL on host.';
            $details = trim($transportError . ' ' . $fallbackError . ' ' . $hint);
            fail_keyauth_transport($details);
        }
    }

    $decoded = json_decode($response, true);
    if (!is_array($decoded)) {
        fail_keyauth_transport('Invalid JSON response from KeyAuth.');
    }

    return $decoded;
}

function keyauth_init(): string
{
    $result = keyauth_call([
        'type' => 'init',
        'ver' => KEYAUTH_VERSION,
        'name' => KEYAUTH_NAME,
        'ownerid' => KEYAUTH_OWNER_ID
    ]);

    if (($result['success'] ?? false) !== true || empty($result['sessionid'])) {
        $message = $result['message'] ?? 'KeyAuth init failed.';
        json_response(['success' => false, 'message' => $message], 401);
    }

    return (string) $result['sessionid'];
}

function create_access_token(string $username): string
{
    $payload = [
        'u' => $username,
        'exp' => time() + TOKEN_TTL_SECONDS
    ];
    $payloadEncoded = b64url_encode(json_encode($payload));
    $signature = hash_hmac('sha256', $payloadEncoded, TOKEN_SECRET, true);
    return $payloadEncoded . '.' . b64url_encode($signature);
}

function verify_access_token(string $token): ?array
{
    $parts = explode('.', $token);
    if (count($parts) !== 2) {
        return null;
    }

    [$payloadEncoded, $signatureEncoded] = $parts;
    $expectedSignature = b64url_encode(hash_hmac('sha256', $payloadEncoded, TOKEN_SECRET, true));
    if (!hash_equals($expectedSignature, $signatureEncoded)) {
        return null;
    }

    $payloadRaw = b64url_decode($payloadEncoded);
    $payload = json_decode($payloadRaw, true);
    if (!is_array($payload) || empty($payload['u']) || empty($payload['exp'])) {
        return null;
    }

    if ((int) $payload['exp'] < time()) {
        return null;
    }

    return $payload;
}

$body = read_json_body();
$action = (string) ($body['action'] ?? '');

if ($action === 'login') {
    $username = trim((string) ($body['username'] ?? ''));
    $password = (string) ($body['password'] ?? '');
    if ($username === '' || $password === '') {
        json_response(['success' => false, 'message' => 'Username and password are required.'], 400);
    }

    $sessionId = keyauth_init();
    $result = keyauth_call([
        'type' => 'login',
        'username' => $username,
        'pass' => $password,
        'sessionid' => $sessionId,
        'name' => KEYAUTH_NAME,
        'ownerid' => KEYAUTH_OWNER_ID
    ]);

    if (($result['success'] ?? false) !== true) {
        json_response(['success' => false, 'message' => $result['message'] ?? 'Login failed.'], 401);
    }

    json_response([
        'success' => true,
        'username' => $username,
        'token' => create_access_token($username),
        'downloadUrl' => 'download.html'
    ]);
}

if ($action === 'register') {
    $username = trim((string) ($body['username'] ?? ''));
    $password = (string) ($body['password'] ?? '');
    $license = trim((string) ($body['license'] ?? ''));
    if ($username === '' || $password === '' || $license === '') {
        json_response(['success' => false, 'message' => 'Username, password, and license are required.'], 400);
    }

    $sessionId = keyauth_init();
    $result = keyauth_call([
        'type' => 'register',
        'username' => $username,
        'pass' => $password,
        'key' => $license,
        'sessionid' => $sessionId,
        'name' => KEYAUTH_NAME,
        'ownerid' => KEYAUTH_OWNER_ID
    ]);

    if (($result['success'] ?? false) !== true) {
        json_response(['success' => false, 'message' => $result['message'] ?? 'Register failed.'], 401);
    }

    json_response([
        'success' => true,
        'username' => $username,
        'token' => create_access_token($username),
        'downloadUrl' => 'download.html'
    ]);
}

if ($action === 'validate') {
    $token = trim((string) ($body['token'] ?? ''));
    if ($token === '') {
        json_response(['success' => false, 'message' => 'Missing token.'], 400);
    }

    $payload = verify_access_token($token);
    if ($payload === null) {
        json_response(['success' => false, 'message' => 'Invalid or expired session token.'], 401);
    }

    json_response([
        'success' => true,
        'username' => $payload['u'],
        'downloadUrl' => DOWNLOAD_URL
    ]);
}

json_response(['success' => false, 'message' => 'Invalid action.'], 400);
