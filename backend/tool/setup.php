<?php
declare(strict_types=1);

/**
 * Menyiapkan database MotoPart: membuat database (bila belum ada), semua
 * tabel, akun admin, dan data contoh.
 *
 *   php tool/setup.php           buat yang belum ada (aman diulang)
 *   php tool/setup.php --reset   hapus SEMUA data MotoPart lalu isi ulang
 *
 * Koneksi memakai config.php (XAMPP: root tanpa password).
 */

require __DIR__ . '/../src/Core.php';
require __DIR__ . '/../src/Domain.php';

use MotoPart\Auth;
use MotoPart\Db;
use MotoPart\SampleData;

$config = require __DIR__ . '/../config.php';
$reset = in_array('--reset', $argv, true);

try {
    $server = Db::connect($config, false);
} catch (PDOException $e) {
    fwrite(STDERR, "Tidak dapat terhubung ke MySQL ({$config['db_host']}:{$config['db_port']}): "
        . $e->getMessage() . "\nPastikan MySQL di XAMPP sudah dijalankan.\n");
    exit(1);
}

$name = preg_replace('/[^A-Za-z0-9_]/', '', (string) $config['db_name']);
if ($reset) {
    $server->exec("DROP DATABASE IF EXISTS `$name`");
    echo "Database `$name` dihapus.\n";
}
$server->exec("CREATE DATABASE IF NOT EXISTS `$name` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
echo "Database `$name` siap.\n";

$pdo = Db::connect($config);
Db::use($pdo);

// Jalankan schema.sql per pernyataan.
$sql = file_get_contents(__DIR__ . '/../database/schema.sql');
$sql = preg_replace('/^--.*$/m', '', $sql);
foreach (array_filter(array_map('trim', explode(';', $sql))) as $statement) {
    $pdo->exec($statement);
}
echo "Tabel siap.\n";

$admin = $pdo->prepare('SELECT 1 FROM users WHERE email = ?');
$admin->execute([$config['admin_email']]);
if (!$admin->fetch()) {
    $pdo->prepare(
        'INSERT INTO users (id, name, email, phone, role, password_hash, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)'
    )->execute([
        'admin', 'Admin MotoPart', $config['admin_email'], '-', 'admin',
        Auth::hashPassword((string) $config['admin_password']), Db::now(),
    ]);
    echo "Akun admin dibuat: {$config['admin_email']}\n";
}

$count = (int) $pdo->query('SELECT COUNT(*) FROM products')->fetchColumn();
if ($count === 0) {
    SampleData::seed($pdo);
    echo "Data contoh dimasukkan (12 produk, 2 pesanan).\n";
} else {
    echo "Produk sudah ada ($count), data contoh dilewati.\n";
}
echo "Selesai.\n";
