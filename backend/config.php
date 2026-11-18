<?php
declare(strict_types=1);

/**
 * Konfigurasi backend MotoPart.
 *
 * Urutan prioritas (yang belakangan menang):
 *   1. nilai bawaan di bawah (cocok untuk XAMPP: root tanpa password),
 *   2. berkas `config.local.php` (salin dari `config.example.php`; tidak
 *      ikut git),
 *   3. variabel lingkungan MOTOPART_DB_HOST, MOTOPART_DB_PORT,
 *      MOTOPART_DB_NAME, MOTOPART_DB_USER, MOTOPART_DB_PASS.
 */
$config = [
    'db_host' => '127.0.0.1',
    'db_port' => 3306,
    'db_name' => 'motopart',
    'db_user' => 'root',
    'db_pass' => '',
    // Lama sesi login (hari).
    'token_days' => 30,
    // Asal yang boleh memanggil API dari browser (CORS). "*" = semua.
    'allow_origin' => '*',
    // Akun admin bawaan yang dibuat oleh tool/setup.php.
    'admin_email' => 'admin@motopart.id',
    'admin_password' => 'admin123',
    // ID klien OAuth Google yang diterima untuk "Masuk dengan Google" (mis.
    // klien Web dan Android). Kosong = fitur dimatikan (jawaban 503). Isi di
    // config.local.php.
    'google_client_ids' => [],
];

$local = __DIR__ . '/config.local.php';
if (is_file($local)) {
    $config = array_merge($config, require $local);
}

$env = [
    'MOTOPART_DB_HOST' => 'db_host',
    'MOTOPART_DB_PORT' => 'db_port',
    'MOTOPART_DB_NAME' => 'db_name',
    'MOTOPART_DB_USER' => 'db_user',
    'MOTOPART_DB_PASS' => 'db_pass',
];
foreach ($env as $name => $key) {
    $value = getenv($name);
    if ($value !== false) {
        $config[$key] = $key === 'db_port' ? (int) $value : $value;
    }
}

return $config;
