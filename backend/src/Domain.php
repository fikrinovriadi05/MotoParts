<?php
declare(strict_types=1);

namespace MotoPart;

use PDO;

/**
 * Aturan validasi. Pesan dan batas sengaja sama dengan yang ada di aplikasi
 * Flutter (AuthStore/Store), supaya perilaku identik baik lokal maupun lewat
 * database.
 */
final class Validate
{
    public const MIN_PASSWORD = 6;
    public const OLDEST_MOTOR_YEAR = 1970;
    public const MAX_COMMENT = 300;
    public const AWAITING = 'Menunggu Pembayaran';
    public const CANCELLED = 'Dibatalkan';

    public const ORDER_STATUSES = [
        'Menunggu Pembayaran', 'Diproses', 'Dikemas', 'Dikirim', 'Selesai', 'Dibatalkan',
    ];

    public const PRODUCT_ICONS = [
        'disc_full', 'filter_alt', 'electric_bolt', 'oil_barrel', 'lightbulb',
        'settings', 'build', 'tire_repair', 'two_wheeler',
    ];

    /** Bentuk tersimpan metode pembayaran (PaymentChoice.encoded di aplikasi). */
    public const PAYMENT_CHOICES = [
        'QRIS', 'COD', 'E-Wallet|GoPay',
        'Virtual Account|BCA', 'Virtual Account|Mandiri',
        'Virtual Account|BNI', 'Virtual Account|BRI',
    ];

    public static function str(mixed $value): string
    {
        return is_scalar($value) ? trim((string) $value) : '';
    }

    public static function digits(string $value): int
    {
        return strlen(preg_replace('/\D/', '', $value) ?? '');
    }

    public static function email(string $email): bool
    {
        return (bool) preg_match('/^[^@\s]+@[^@\s]+\.[^@\s]+$/', $email);
    }

    /** Kesalahan pendaftaran, atau null. */
    public static function registration(string $name, string $email, string $phone, string $password): ?string
    {
        if ($name === '' || $email === '' || $phone === '' || $password === '') {
            return 'Lengkapi semua data terlebih dahulu.';
        }
        if (!self::email($email)) {
            return 'Format email tidak valid.';
        }
        if (self::digits($phone) < 8) {
            return 'Nomor telepon tidak valid.';
        }
        if (strlen($password) < self::MIN_PASSWORD) {
            return 'Password minimal ' . self::MIN_PASSWORD . ' karakter.';
        }
        return null;
    }

    public static function profile(string $name, string $phone): ?string
    {
        if ($name === '' || $phone === '') {
            return 'Nama dan nomor telepon wajib diisi.';
        }
        if (self::digits($phone) < 8) {
            return 'Nomor telepon tidak valid.';
        }
        return null;
    }

    /** $year null = kosong. */
    public static function motor(string $name, string $type, ?int $year, ?string $rawYear): ?string
    {
        $latest = (int) gmdate('Y') + 1;
        if ($rawYear !== null && $rawYear !== '' && $year === null) {
            return 'Tahun motor harus antara ' . self::OLDEST_MOTOR_YEAR . ' dan ' . $latest . '.';
        }
        if ($year !== null && ($year < self::OLDEST_MOTOR_YEAR || $year > $latest)) {
            return 'Tahun motor harus antara ' . self::OLDEST_MOTOR_YEAR . ' dan ' . $latest . '.';
        }
        if ($name === '' && ($type !== '' || $year !== null)) {
            return 'Isi nama motor terlebih dahulu.';
        }
        return null;
    }

    public static function address(array $a): ?string
    {
        foreach (['label', 'recipient', 'phone', 'street', 'city'] as $key) {
            if ($a[$key] === '') {
                return 'Lengkapi nama alamat, penerima, telepon, alamat, dan kota.';
            }
        }
        if (self::digits($a['phone']) < 8) {
            return 'Nomor telepon tidak valid.';
        }
        if ($a['postal_code'] !== '' && !preg_match('/^\d{5}$/', $a['postal_code'])) {
            return 'Kode pos harus 5 angka.';
        }
        $lat = $a['latitude'];
        $lng = $a['longitude'];
        if (($lat === null) !== ($lng === null)) {
            return 'Titik GPS tidak lengkap.';
        }
        if ($lat !== null && ($lat < -90 || $lat > 90 || $lng < -180 || $lng > 180)) {
            return 'Titik GPS tidak valid.';
        }
        return null;
    }

    public static function product(string $name, mixed $price, mixed $stock): ?string
    {
        if ($name === '') {
            return 'Nama produk wajib diisi.';
        }
        if (!is_int($price) || $price < 0) {
            return 'Harga harus berupa angka bulat 0 atau lebih.';
        }
        if (!is_int($stock) || $stock < 0) {
            return 'Stok harus berupa angka bulat 0 atau lebih.';
        }
        return null;
    }
}

/** Mengubah baris database menjadi JSON yang sama bentuknya dengan model Flutter. */
final class Serialize
{
    public static function address(array $r): array
    {
        return [
            'id' => $r['id'],
            'label' => $r['label'],
            'recipient' => $r['recipient'],
            'phone' => $r['phone'],
            'street' => $r['street'],
            'city' => $r['city'],
            'postalCode' => $r['postal_code'],
            'note' => $r['note'],
            'latitude' => $r['latitude'] === null ? null : (float) $r['latitude'],
            'longitude' => $r['longitude'] === null ? null : (float) $r['longitude'],
        ];
    }

    /** Akun lengkap dengan alamatnya. Hash password tidak pernah dikirim. */
    public static function user(array $u, ?array $addresses = null): array
    {
        $addresses ??= self::addressesOf($u['id']);
        $config = require __DIR__ . '/../config.php';
        $json = [
            'id' => $u['id'],
            'name' => $u['name'],
            'email' => $u['email'],
            'phone' => $u['phone'],
            'role' => $u['role'],
            'motorName' => $u['motor_name'],
            'motorType' => $u['motor_type'],
            'motorYear' => $u['motor_year'] === null ? null : (int) $u['motor_year'],
            'addresses' => array_map([self::class, 'address'], $addresses),
            'defaultAddressId' => $u['default_address_id'],
            'preferredPayment' => $u['preferred_payment'],
        ];
        if ($u['role'] === 'admin') {
            $json['usesDefaultPassword'] = password_verify((string) $config['admin_password'], $u['password_hash']);
        }
        return $json;
    }

    public static function addressesOf(string $userId): array
    {
        $stmt = Db::pdo()->prepare('SELECT * FROM addresses WHERE user_id = ? ORDER BY created_at, id');
        $stmt->execute([$userId]);
        return $stmt->fetchAll();
    }

    public static function product(array $p): array
    {
        return [
            'id' => (int) $p['id'],
            'name' => $p['name'],
            'category' => $p['category'],
            'type' => $p['type'],
            'price' => (int) $p['price'],
            'stock' => (int) $p['stock'],
            'icon' => $p['icon'],
            'description' => $p['description'],
            'imagePath' => $p['image_path'],
        ];
    }

    /** @param array<int, array> $items */
    public static function order(array $o, array $items): array
    {
        $payment = $o['payment_json'] === null ? null : json_decode($o['payment_json'], true);
        return [
            'code' => $o['code'],
            'customer' => $o['customer'],
            'total' => (int) $o['total'],
            'status' => $o['status'],
            'lines' => array_map(static fn(array $i) => [
                'productId' => (int) $i['product_id'],
                'name' => $i['name'],
                'qty' => (int) $i['qty'],
                'price' => (int) $i['price'],
            ], $items),
            'createdAt' => Db::iso($o['created_at']),
            'accountId' => $o['user_id'],
            'address' => $o['address'],
            'paymentMethod' => $o['payment_method'],
            'payment' => is_array($payment) ? $payment : null,
        ];
    }

    public static function review(array $r): array
    {
        return [
            'productId' => (int) $r['product_id'],
            'accountId' => $r['user_id'],
            'authorName' => $r['author_name'],
            'rating' => (int) $r['rating'],
            'comment' => $r['comment'],
            'createdAt' => Db::iso($r['created_at']),
        ];
    }

    /** Semua pesanan (atau milik [userId]) lengkap dengan barisnya, terbaru dulu. */
    public static function orders(?string $userId): array
    {
        $pdo = Db::pdo();
        if ($userId === null) {
            $orders = $pdo->query('SELECT * FROM orders ORDER BY created_at DESC, code DESC')->fetchAll();
        } else {
            $stmt = $pdo->prepare('SELECT * FROM orders WHERE user_id = ? ORDER BY created_at DESC, code DESC');
            $stmt->execute([$userId]);
            $orders = $stmt->fetchAll();
        }
        if ($orders === []) {
            return [];
        }
        $byCode = [];
        $marks = implode(',', array_fill(0, count($orders), '?'));
        $stmt = $pdo->prepare("SELECT * FROM order_items WHERE order_code IN ($marks) ORDER BY id");
        $stmt->execute(array_column($orders, 'code'));
        foreach ($stmt->fetchAll() as $item) {
            $byCode[$item['order_code']][] = $item;
        }
        return array_map(
            static fn(array $o) => self::order($o, $byCode[$o['code']] ?? []),
            $orders
        );
    }
}

/** Data contoh (sama dengan Store.defaultProducts/defaultOrders di aplikasi). */
final class SampleData
{
    public static function products(): array
    {
        return [
            [1, 'Kampas Rem Depan', 'Rem', 'Honda Beat', 45000, 24, 'disc_full', 'Kampas rem depan berkualitas tinggi untuk pengereman lebih optimal.'],
            [2, 'Filter Oli Honda', 'Mesin', 'Honda Vario', 25000, 50, 'filter_alt', 'Filter oli original untuk menjaga performa mesin tetap bersih.'],
            [3, 'Busi NGK', 'Kelistrikan', 'Universal', 32000, 40, 'electric_bolt', 'Busi motor untuk pembakaran lebih stabil dan performa lebih baik.'],
            [4, 'Oli Mesin 10W-40', 'Oli', 'Berbagai tipe', 85000, 30, 'oil_barrel', 'Oli mesin premium untuk menjaga ketahanan dan pelumasan mesin.'],
            [5, 'Lampu LED Motor', 'Kelistrikan', 'Universal', 65000, 18, 'lightbulb', 'Lampu LED terang dan hemat daya untuk tampilan motor lebih modern.'],
            [6, 'Gear Set', 'Transmisi', 'Honda Supra X', 185000, 8, 'settings', 'Gear set berkualitas untuk transmisi lebih halus dan tahan lama.'],
            [7, 'Oli Gardan 120 ml', 'Oli', 'Honda Matic', 18000, 60, 'oil_barrel', 'Oli gardan untuk melindungi gigi transmisi motor matic dan menjaga tarikan tetap halus.'],
            [8, 'Oli Mesin Matic 0,8 L', 'Oli', 'Honda Beat, Honda Vario, Yamaha Mio', 52000, 45, 'oil_barrel', 'Oli mesin khusus motor matic, menjaga mesin tetap dingin dan bersih.'],
            [9, 'Ban Luar 80/90-14', 'Ban', 'Honda Beat, Honda Vario', 175000, 12, 'tire_repair', 'Ban luar tubeless dengan cengkeraman baik di jalan kering maupun basah.'],
            [10, 'Ban Dalam 80/90-14', 'Ban', 'Honda Beat, Honda Vario', 38000, 4, 'tire_repair', 'Ban dalam karet tebal, tahan bocor dan mudah dipasang.'],
            [11, 'Spion Standar', 'Body', 'Universal', 48000, 22, 'two_wheeler', 'Spion standar dengan kaca cembung yang jernih dan sudut pandang luas.'],
            [12, 'Handgrip Karet', 'Body', 'Universal', 28000, 35, 'two_wheeler', 'Handgrip karet empuk dan tidak licin, nyaman untuk perjalanan jauh.'],
        ];
    }

    /** Pesanan contoh (tanpa pemilik); waktu dalam WIB (UTC+7). */
    public static function orders(): array
    {
        return [
            ['MP-250118-0001', 'Budi Santoso', 80000, 'Selesai', '2025-01-18 03:30:00',
                [[2, 'Filter Oli Honda', 1, 25000], [1, 'Kampas Rem Depan', 1, 45000]]],
            ['MP-250118-0002', 'Andi Pratama', 125000, 'Dikirim', '2025-01-18 07:15:00',
                [[2, 'Filter Oli Honda', 1, 25000], [1, 'Kampas Rem Depan', 2, 45000]]],
        ];
    }

    /**
     * Mengembalikan produk dan pesanan ke data contoh, dan menghapus semua
     * ulasan serta wishlist. Akun tidak diubah.
     */
    public static function seed(PDO $pdo): void
    {
        $now = Db::now();
        $pdo->beginTransaction();
        try {
            foreach (['order_items', 'orders', 'reviews', 'wishlists', 'products'] as $table) {
                $pdo->exec("DELETE FROM $table");
            }
            $product = $pdo->prepare(
                'INSERT INTO products (id, name, category, type, price, stock, icon, description, created_at, updated_at)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
            );
            foreach (self::products() as [$id, $name, $category, $type, $price, $stock, $icon, $desc]) {
                $product->execute([$id, $name, $category, $type, $price, $stock, $icon, $desc, $now, $now]);
            }
            $order = $pdo->prepare(
                'INSERT INTO orders (code, user_id, customer, total, status, created_at, updated_at)
                 VALUES (?, NULL, ?, ?, ?, ?, ?)'
            );
            $item = $pdo->prepare(
                'INSERT INTO order_items (order_code, product_id, name, qty, price) VALUES (?, ?, ?, ?, ?)'
            );
            foreach (self::orders() as [$code, $customer, $total, $status, $created, $lines]) {
                $order->execute([$code, $customer, $total, $status, $created, $created]);
                foreach ($lines as [$pid, $name, $qty, $price]) {
                    $item->execute([$code, $pid, $name, $qty, $price]);
                }
            }
            $pdo->commit();
        } catch (\Throwable $e) {
            $pdo->rollBack();
            throw $e;
        }
    }
}
