<?php
declare(strict_types=1);

/**
 * Pintu masuk API MotoPart. Semua permintaan dialihkan ke sini
 * (.htaccess untuk Apache; `php -S ... index.php` untuk server bawaan PHP).
 */

require __DIR__ . '/src/Core.php';
require __DIR__ . '/src/Domain.php';
require __DIR__ . '/src/Api.php';

use MotoPart\Api;
use MotoPart\HttpError;
use MotoPart\Request;

$config = require __DIR__ . '/config.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: ' . $config['allow_origin']);
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Auth-Token');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Max-Age: 86400');
header('X-Content-Type-Options: nosniff');

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

function respond(mixed $data, ?int $status = null): void
{
    if ($status !== null) {
        http_response_code($status);
    }
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRESERVE_ZERO_FRACTION);
}

try {
    respond(Api::router()->dispatch(Request::fromGlobals()));
} catch (HttpError $e) {
    respond(['error' => $e->getMessage()], $e->status);
} catch (PDOException $e) {
    error_log('[motopart] database: ' . $e->getMessage());
    respond(['error' => 'Database tidak dapat diakses. Periksa konfigurasi server.'], 503);
} catch (Throwable $e) {
    error_log('[motopart] ' . $e::class . ': ' . $e->getMessage());
    respond(['error' => 'Terjadi kesalahan pada server.'], 500);
}
