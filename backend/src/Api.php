<?php
declare(strict_types=1);

namespace MotoPart;

use PDO;

/** Semua endpoint API MotoPart. Lihat backend/README.md untuk daftarnya. */
final class Api
{
    public static function router(): Router
    {
        $r = new Router();

        $r->add('GET', '/', static fn() => ['name' => 'MotoPart API', 'status' => 'ok']);
        $r->add('GET', '/health', [self::class, 'health']);
        $r->add('GET', '/sync', [self::class, 'sync']);

        $r->add('POST', '/auth/register', [self::class, 'register']);
        $r->add('POST', '/auth/login', [self::class, 'login']);
        $r->add('POST', '/auth/logout', [self::class, 'logout']);

        $r->add('GET', '/me', [self::class, 'me']);
        $r->add('PUT', '/me', [self::class, 'updateMe']);
        $r->add('PUT', '/me/password', [self::class, 'changePassword']);

        $r->add('POST', '/addresses', [self::class, 'addAddress']);
        $r->add('PUT', '/addresses/{id}', [self::class, 'updateAddress']);
        $r->add('DELETE', '/addresses/{id}', [self::class, 'deleteAddress']);
        $r->add('PUT', '/addresses/{id}/default', [self::class, 'defaultAddress']);

        $r->add('GET', '/products', [self::class, 'products']);
        $r->add('POST', '/products', [self::class, 'createProduct']);
        $r->add('PUT', '/products/{id}', [self::class, 'updateProduct']);
        $r->add('DELETE', '/products/{id}', [self::class, 'deleteProduct']);

        $r->add('GET', '/categories', [self::class, 'categories']);
        $r->add('POST', '/categories', [self::class, 'addCategory']);
        $r->add('PUT', '/categories/{name}', [self::class, 'updateCategory']);
        $r->add('DELETE', '/categories/{name}', [self::class, 'deleteCategory']);

        $r->add('GET', '/orders', [self::class, 'orders']);
        $r->add('POST', '/orders', [self::class, 'createOrder']);
        $r->add('PUT', '/orders/{code}/status', [self::class, 'updateOrderStatus']);

        $r->add('GET', '/reviews', [self::class, 'reviews']);
        $r->add('POST', '/reviews', [self::class, 'submitReview']);
        $r->add('DELETE', '/reviews/{productId}/{userId}', [self::class, 'deleteReview']);

        $r->add('GET', '/wishlist', [self::class, 'wishlist']);
        $r->add('PUT', '/wishlist/{productId}', [self::class, 'addWishlist']);
        $r->add('DELETE', '/wishlist/{productId}', [self::class, 'removeWishlist']);

        $r->add('GET', '/users', [self::class, 'users']);
        $r->add('PUT', '/users/{id}/password', [self::class, 'resetPassword']);

        $r->add('POST', '/admin/reset-sample-data', [self::class, 'resetSampleData']);
        return $r;
    }

    // ------------------------------------------------------------ umum

    public static function health(): array
    {
        Db::pdo()->query('SELECT 1');
        return ['status' => 'ok', 'database' => true, 'time' => gmdate('c')];
    }

    private static function userRow(string $id): array
    {
        $stmt = Db::pdo()->prepare('SELECT * FROM users WHERE id = ?');
        $stmt->execute([$id]);
        return $stmt->fetch() ?: throw new HttpError(404, 'Akun tidak ditemukan.');
    }

    private static function account(string $id): array
    {
        return Serialize::user(self::userRow($id));
    }

    /** Semua data untuk pengguna ini dalam satu panggilan (dipakai aplikasi). */
    public static function sync(Request $req): array
    {
        $pdo = Db::pdo();
        $user = Auth::user($req);
        $products = array_map([Serialize::class, 'product'], $pdo->query('SELECT * FROM products ORDER BY id')->fetchAll());
        $reviews = array_map(
            [Serialize::class, 'review'],
            $pdo->query('SELECT * FROM reviews ORDER BY created_at DESC')->fetchAll()
        );

        $out = [
            'me' => $user === null ? null : Serialize::user($user),
            'products' => $products,
            'categories' => self::categoryList(),
            'reviews' => $reviews,
            'orders' => [],
            'wishlist' => [],
            'users' => [],
            'serverTime' => gmdate('c'),
        ];
        if ($user !== null) {
            $out['orders'] = Serialize::orders($user['role'] === 'admin' ? null : $user['id']);
            $stmt = $pdo->prepare('SELECT product_id FROM wishlists WHERE user_id = ? ORDER BY created_at, product_id');
            $stmt->execute([$user['id']]);
            $out['wishlist'] = array_map('intval', array_column($stmt->fetchAll(), 'product_id'));
            if ($user['role'] === 'admin') {
                $out['users'] = array_map(
                    static fn(array $u) => Serialize::user($u),
                    $pdo->query("SELECT * FROM users WHERE role = 'user' ORDER BY created_at, id")->fetchAll()
                );
            }
        }
        return $out;
    }

    // ------------------------------------------------------------ auth

    public static function register(Request $req): array
    {
        $name = Validate::str($req->get('name'));
        $email = Validate::str($req->get('email'));
        $phone = Validate::str($req->get('phone'));
        $password = (string) $req->get('password', '');

        $error = Validate::registration($name, $email, $phone, $password);
        if ($error !== null) {
            throw new HttpError(422, $error);
        }

        $pdo = Db::pdo();
        $exists = $pdo->prepare('SELECT 1 FROM users WHERE email = ?');
        $exists->execute([$email]);
        if ($exists->fetch()) {
            throw new HttpError(409, 'Email sudah terdaftar.');
        }

        $id = Auth::newId('u');
        try {
            $pdo->prepare(
                'INSERT INTO users (id, name, email, phone, role, password_hash, created_at)
                 VALUES (?, ?, ?, ?, ?, ?, ?)'
            )->execute([$id, $name, $email, $phone, 'user', Auth::hashPassword($password), Db::now()]);
        } catch (\PDOException $e) {
            if ($e->getCode() === '23000') { // email ganda pada saat bersamaan
                throw new HttpError(409, 'Email sudah terdaftar.');
            }
            throw $e;
        }

        http_response_code(201);
        $config = require __DIR__ . '/../config.php';
        return [
            'token' => Auth::createToken($id, (int) $config['token_days']),
            'user' => self::account($id),
        ];
    }

    public static function login(Request $req): array
    {
        $email = Validate::str($req->get('email'));
        $password = (string) $req->get('password', '');
        $role = Validate::str($req->get('role', 'user'));

        if ($email === '' || $password === '') {
            throw new HttpError(422, 'Email dan password wajib diisi.');
        }
        $stmt = Db::pdo()->prepare('SELECT * FROM users WHERE email = ?');
        $stmt->execute([$email]);
        $user = $stmt->fetch();
        if (!$user || !password_verify($password, $user['password_hash'])) {
            throw new HttpError(401, 'Email atau password salah.');
        }
        $isAdmin = $user['role'] === 'admin';
        if (($role === 'admin') !== $isAdmin) {
            throw new HttpError(403, $isAdmin
                ? 'Akun admin masuk lewat tab Admin.'
                : 'Akun ini bukan akun admin.');
        }

        $config = require __DIR__ . '/../config.php';
        return [
            'token' => Auth::createToken($user['id'], (int) $config['token_days']),
            'user' => Serialize::user($user),
        ];
    }

    public static function logout(Request $req): array
    {
        if ($req->token !== null) {
            Auth::destroyToken($req->token);
        }
        return ['ok' => true];
    }

    // -------------------------------------------------------------- me

    public static function me(Request $req): array
    {
        return ['user' => Serialize::user(Auth::require($req))];
    }

    public static function updateMe(Request $req): array
    {
        $user = Auth::require($req);
        $name = $req->has('name') ? Validate::str($req->get('name')) : $user['name'];
        $phone = $req->has('phone') ? Validate::str($req->get('phone')) : $user['phone'];
        $error = Validate::profile($name, $phone);
        if ($error !== null) {
            throw new HttpError(422, $error);
        }

        $motorName = $req->has('motorName') ? Validate::str($req->get('motorName')) : $user['motor_name'];
        $motorType = $req->has('motorType') ? Validate::str($req->get('motorType')) : $user['motor_type'];
        $year = $user['motor_year'] === null ? null : (int) $user['motor_year'];
        $rawYear = null;
        if ($req->has('motorYear')) {
            $value = $req->get('motorYear');
            $rawYear = $value === null ? '' : Validate::str($value);
            $year = $rawYear === '' ? null : (preg_match('/^\d{1,4}$/', $rawYear) ? (int) $rawYear : null);
        }
        $error = Validate::motor($motorName, $motorType, $year, $rawYear);
        if ($error !== null) {
            throw new HttpError(422, $error);
        }

        $payment = $user['preferred_payment'];
        if ($req->has('preferredPayment')) {
            $value = $req->get('preferredPayment');
            if ($value === null || $value === '') {
                $payment = null;
            } elseif (is_string($value) && in_array($value, Validate::PAYMENT_CHOICES, true)) {
                $payment = $value;
            } else {
                throw new HttpError(422, 'Metode pembayaran tidak dikenal.');
            }
        }

        Db::pdo()->prepare(
            'UPDATE users SET name = ?, phone = ?, motor_name = ?, motor_type = ?, motor_year = ?,
             preferred_payment = ? WHERE id = ?'
        )->execute([$name, $phone, $motorName, $motorType, $year, $payment, $user['id']]);

        return ['user' => self::account($user['id'])];
    }

    public static function changePassword(Request $req): array
    {
        $user = Auth::require($req);
        $old = (string) $req->get('oldPassword', '');
        $new = (string) $req->get('newPassword', '');

        if (!password_verify($old, $user['password_hash'])) {
            throw new HttpError(422, 'Password lama salah.');
        }
        if (strlen($new) < Validate::MIN_PASSWORD) {
            throw new HttpError(422, 'Password baru minimal ' . Validate::MIN_PASSWORD . ' karakter.');
        }
        if ($new === $old) {
            throw new HttpError(422, 'Password baru harus berbeda dari password lama.');
        }
        Db::pdo()->prepare('UPDATE users SET password_hash = ? WHERE id = ?')
            ->execute([Auth::hashPassword($new), $user['id']]);
        return ['ok' => true];
    }

    // ------------------------------------------------------- alamat

    private static function addressInput(Request $req): array
    {
        $num = static function (mixed $v): ?float {
            return is_int($v) || is_float($v) ? (float) $v : null;
        };
        return [
            'label' => Validate::str($req->get('label')),
            'recipient' => Validate::str($req->get('recipient')),
            'phone' => Validate::str($req->get('phone')),
            'street' => Validate::str($req->get('street')),
            'city' => Validate::str($req->get('city')),
            'postal_code' => Validate::str($req->get('postalCode')),
            'note' => Validate::str($req->get('note')),
            'latitude' => $num($req->get('latitude')),
            'longitude' => $num($req->get('longitude')),
        ];
    }

    public static function addAddress(Request $req): array
    {
        $user = Auth::require($req);
        $a = self::addressInput($req);
        $error = Validate::address($a);
        if ($error !== null) {
            throw new HttpError(422, $error);
        }

        $pdo = Db::pdo();
        $count = $pdo->prepare('SELECT COUNT(*) FROM addresses WHERE user_id = ?');
        $count->execute([$user['id']]);
        $isFirst = (int) $count->fetchColumn() === 0;

        // Aplikasi boleh membawa id sendiri agar tampilan optimisnya tetap cocok.
        $id = Validate::str($req->get('id'));
        if ($id === '') {
            $id = Auth::newId('a');
        } elseif (!preg_match('/^[A-Za-z0-9_-]{4,40}$/', $id)) {
            throw new HttpError(422, 'Id alamat tidak valid.');
        }
        try {
            $pdo->prepare(
                'INSERT INTO addresses (id, user_id, label, recipient, phone, street, city, postal_code, note,
                 latitude, longitude, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
            )->execute([
                $id, $user['id'], $a['label'], $a['recipient'], $a['phone'], $a['street'], $a['city'],
                $a['postal_code'], $a['note'], $a['latitude'], $a['longitude'], Db::now(),
            ]);
        } catch (\PDOException $e) {
            if ($e->getCode() === '23000') {
                throw new HttpError(409, 'Id alamat sudah dipakai.');
            }
            throw $e;
        }
        if ($isFirst || $req->get('makeDefault') === true) {
            $pdo->prepare('UPDATE users SET default_address_id = ? WHERE id = ?')->execute([$id, $user['id']]);
        }

        http_response_code(201);
        return ['addressId' => $id, 'user' => self::account($user['id'])];
    }

    private static function ownAddress(string $id, string $userId): array
    {
        $stmt = Db::pdo()->prepare('SELECT * FROM addresses WHERE id = ? AND user_id = ?');
        $stmt->execute([$id, $userId]);
        return $stmt->fetch() ?: throw new HttpError(404, 'Alamat tidak ditemukan.');
    }

    public static function updateAddress(Request $req, array $p): array
    {
        $user = Auth::require($req);
        self::ownAddress($p['id'], $user['id']);
        $a = self::addressInput($req);
        $error = Validate::address($a);
        if ($error !== null) {
            throw new HttpError(422, $error);
        }

        $pdo = Db::pdo();
        $pdo->prepare(
            'UPDATE addresses SET label = ?, recipient = ?, phone = ?, street = ?, city = ?, postal_code = ?,
             note = ?, latitude = ?, longitude = ? WHERE id = ?'
        )->execute([
            $a['label'], $a['recipient'], $a['phone'], $a['street'], $a['city'], $a['postal_code'],
            $a['note'], $a['latitude'], $a['longitude'], $p['id'],
        ]);
        if ($req->get('makeDefault') === true) {
            $pdo->prepare('UPDATE users SET default_address_id = ? WHERE id = ?')->execute([$p['id'], $user['id']]);
        }
        return ['user' => self::account($user['id'])];
    }

    public static function deleteAddress(Request $req, array $p): array
    {
        $user = Auth::require($req);
        self::ownAddress($p['id'], $user['id']);

        $pdo = Db::pdo();
        $pdo->prepare('DELETE FROM addresses WHERE id = ?')->execute([$p['id']]);
        if ($user['default_address_id'] === $p['id']) {
            $next = $pdo->prepare('SELECT id FROM addresses WHERE user_id = ? ORDER BY created_at, id LIMIT 1');
            $next->execute([$user['id']]);
            $newDefault = $next->fetchColumn() ?: null;
            $pdo->prepare('UPDATE users SET default_address_id = ? WHERE id = ?')->execute([$newDefault, $user['id']]);
        }
        return ['user' => self::account($user['id'])];
    }

    public static function defaultAddress(Request $req, array $p): array
    {
        $user = Auth::require($req);
        self::ownAddress($p['id'], $user['id']);
        Db::pdo()->prepare('UPDATE users SET default_address_id = ? WHERE id = ?')->execute([$p['id'], $user['id']]);
        return ['user' => self::account($user['id'])];
    }

    // ------------------------------------------------------- produk

    public static function products(): array
    {
        $rows = Db::pdo()->query('SELECT * FROM products ORDER BY id')->fetchAll();
        return ['products' => array_map([Serialize::class, 'product'], $rows)];
    }

    private static function productRow(int|string $id): array
    {
        $stmt = Db::pdo()->prepare('SELECT * FROM products WHERE id = ?');
        $stmt->execute([(int) $id]);
        return $stmt->fetch() ?: throw new HttpError(404, 'Produk tidak ditemukan.');
    }

    private static function icon(mixed $value): string
    {
        return is_string($value) && in_array($value, Validate::PRODUCT_ICONS, true) ? $value : 'build';
    }

    private static function image(mixed $value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }
        if (!is_string($value) || strlen($value) > 600 * 1024) {
            throw new HttpError(422, 'Foto produk terlalu besar.');
        }
        return $value;
    }

    public static function createProduct(Request $req): array
    {
        Auth::requireAdmin($req);
        $name = Validate::str($req->get('name'));
        $price = $req->get('price');
        $stock = $req->get('stock', 0);
        $error = Validate::product($name, $price, $stock);
        $category = Validate::str($req->get('category'));
        if ($error === null && $category === '') {
            $error = 'Kategori wajib dipilih.';
        }
        if ($error !== null) {
            throw new HttpError(422, $error);
        }

        $type = Validate::str($req->get('type'));
        $now = Db::now();
        $pdo = Db::pdo();
        $pdo->prepare(
            'INSERT INTO products (name, category, type, price, stock, icon, description, image_path, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
        )->execute([
            $name, $category, $type === '' ? 'Universal' : $type, $price, $stock,
            self::icon($req->get('icon')), Validate::str($req->get('description')),
            self::image($req->get('imagePath')), $now, $now,
        ]);

        http_response_code(201);
        return ['product' => Serialize::product(self::productRow((int) $pdo->lastInsertId()))];
    }

    public static function updateProduct(Request $req, array $p): array
    {
        Auth::requireAdmin($req);
        $row = self::productRow($p['id']);

        $name = $req->has('name') ? Validate::str($req->get('name')) : $row['name'];
        $price = $req->has('price') ? $req->get('price') : (int) $row['price'];
        $stock = $req->has('stock') ? $req->get('stock') : (int) $row['stock'];
        $error = Validate::product($name, $price, $stock);
        if ($error !== null) {
            throw new HttpError(422, $error);
        }
        $category = $req->has('category') ? Validate::str($req->get('category')) : $row['category'];
        if ($category === '') {
            throw new HttpError(422, 'Kategori wajib dipilih.');
        }
        $type = $req->has('type') ? Validate::str($req->get('type')) : $row['type'];
        $image = $req->has('imagePath') ? self::image($req->get('imagePath')) : $row['image_path'];

        Db::pdo()->prepare(
            'UPDATE products SET name = ?, category = ?, type = ?, price = ?, stock = ?, icon = ?,
             description = ?, image_path = ?, updated_at = ? WHERE id = ?'
        )->execute([
            $name, $category, $type === '' ? 'Universal' : $type, $price, $stock,
            $req->has('icon') ? self::icon($req->get('icon')) : $row['icon'],
            $req->has('description') ? Validate::str($req->get('description')) : $row['description'],
            $image, Db::now(), $row['id'],
        ]);
        return ['product' => Serialize::product(self::productRow($row['id']))];
    }

    public static function deleteProduct(Request $req, array $p): array
    {
        Auth::requireAdmin($req);
        $row = self::productRow($p['id']);
        // Ulasan dan wishlist ikut terhapus (ON DELETE CASCADE).
        Db::pdo()->prepare('DELETE FROM products WHERE id = ?')->execute([$row['id']]);
        return ['ok' => true];
    }

    // ----------------------------------------------------- kategori

    private static function categoryList(): array
    {
        $rows = Db::pdo()->query('SELECT name, icon FROM categories ORDER BY sort_order, id')->fetchAll();
        return array_map(static fn(array $c) => ['name' => $c['name'], 'icon' => $c['icon']], $rows);
    }

    public static function categories(): array
    {
        return ['categories' => self::categoryList()];
    }

    /** @return array{0: string, 1: string} nama dan ikon tervalidasi */
    private static function categoryInput(Request $req, ?string $except = null): array
    {
        $name = Validate::str($req->get('name'));
        $icon = Validate::str($req->get('icon', 'build'));
        if ($name === '') {
            throw new HttpError(422, 'Nama kategori wajib diisi.');
        }
        if (mb_strlen($name) > Validate::MAX_CATEGORY_NAME) {
            throw new HttpError(422, 'Nama kategori maksimal ' . Validate::MAX_CATEGORY_NAME . ' karakter.');
        }
        if (!in_array($icon, Validate::CATEGORY_ICONS, true)) {
            $icon = 'build';
        }
        $stmt = Db::pdo()->prepare('SELECT name FROM categories WHERE name = ?');
        $stmt->execute([$name]);
        $existing = $stmt->fetchColumn();
        if ($existing !== false && mb_strtolower((string) $existing) !== mb_strtolower((string) $except)) {
            throw new HttpError(409, 'Kategori "' . $name . '" sudah ada.');
        }
        return [$name, $icon];
    }

    private static function categoryRow(string $name): array
    {
        $stmt = Db::pdo()->prepare('SELECT * FROM categories WHERE name = ?');
        $stmt->execute([$name]);
        return $stmt->fetch() ?: throw new HttpError(404, 'Kategori tidak ditemukan.');
    }

    public static function addCategory(Request $req): array
    {
        Auth::requireAdmin($req);
        [$name, $icon] = self::categoryInput($req);
        $pdo = Db::pdo();
        $next = (int) $pdo->query('SELECT COALESCE(MAX(sort_order), -1) + 1 FROM categories')->fetchColumn();
        $pdo->prepare('INSERT INTO categories (name, icon, sort_order) VALUES (?, ?, ?)')
            ->execute([$name, $icon, $next]);
        http_response_code(201);
        return ['categories' => self::categoryList()];
    }

    public static function updateCategory(Request $req, array $p): array
    {
        Auth::requireAdmin($req);
        $old = self::categoryRow($p['name']);
        [$name, $icon] = self::categoryInput($req, $old['name']);

        $pdo = Db::pdo();
        $pdo->beginTransaction();
        try {
            $pdo->prepare('UPDATE categories SET name = ?, icon = ? WHERE id = ?')
                ->execute([$name, $icon, $old['id']]);
            if ($name !== $old['name']) {
                // Produk di kategori ini ikut pindah ke nama baru.
                $pdo->prepare('UPDATE products SET category = ?, updated_at = ? WHERE category = ?')
                    ->execute([$name, Db::now(), $old['name']]);
            }
            $pdo->commit();
        } catch (\Throwable $e) {
            $pdo->rollBack();
            throw $e;
        }
        return ['categories' => self::categoryList()];
    }

    public static function deleteCategory(Request $req, array $p): array
    {
        Auth::requireAdmin($req);
        $row = self::categoryRow($p['name']);
        $pdo = Db::pdo();
        $used = $pdo->prepare('SELECT COUNT(*) FROM products WHERE category = ?');
        $used->execute([$row['name']]);
        $count = (int) $used->fetchColumn();
        if ($count > 0) {
            throw new HttpError(409, 'Kategori masih dipakai ' . $count . ' produk. Pindahkan atau hapus produknya dulu.');
        }
        $pdo->prepare('DELETE FROM categories WHERE id = ?')->execute([$row['id']]);
        return ['categories' => self::categoryList()];
    }

    // ------------------------------------------------------ pesanan

    public static function orders(Request $req): array
    {
        $user = Auth::require($req);
        return ['orders' => Serialize::orders($user['role'] === 'admin' ? null : $user['id'])];
    }

    public static function createOrder(Request $req): array
    {
        $user = Auth::require($req);
        $lines = $req->get('lines');
        if (!is_array($lines) || $lines === []) {
            throw new HttpError(422, 'Keranjang kosong.');
        }

        // Gabungkan baris dengan produk yang sama.
        $wanted = [];
        foreach ($lines as $line) {
            $pid = is_array($line) ? ($line['productId'] ?? null) : null;
            $qty = is_array($line) ? ($line['qty'] ?? null) : null;
            if (!is_int($pid) || !is_int($qty) || $qty < 1) {
                throw new HttpError(422, 'Data barang pesanan tidak valid.');
            }
            $wanted[$pid] = ($wanted[$pid] ?? 0) + $qty;
        }

        $shipping = $req->get('shippingCost', 0);
        if (!is_int($shipping) || $shipping < 0) {
            throw new HttpError(422, 'Ongkos kirim tidak valid.');
        }
        $customer = Validate::str($req->get('customer'));
        $customer = $customer === '' ? $user['name'] : $customer;
        $address = Validate::str($req->get('address'));
        $method = Validate::str($req->get('paymentMethod'));
        $payment = $req->get('payment');
        if ($payment !== null && !is_array($payment)) {
            throw new HttpError(422, 'Data pembayaran tidak valid.');
        }
        $paymentJson = $payment ? json_encode($payment, JSON_UNESCAPED_UNICODE) : null;
        if ($paymentJson !== null && strlen($paymentJson) > 20000) {
            throw new HttpError(422, 'Data pembayaran terlalu besar.');
        }

        $code = Validate::str($req->get('code'));
        if ($code === '') {
            $code = 'MP-' . (string) (int) (microtime(true) * 1000);
        } elseif (!preg_match('/^MP-[A-Za-z0-9-]{3,36}$/', $code)) {
            throw new HttpError(422, 'Kode pesanan tidak valid.');
        }

        $pdo = Db::pdo();
        $pdo->beginTransaction();
        try {
            $marks = implode(',', array_fill(0, count($wanted), '?'));
            $stmt = $pdo->prepare("SELECT * FROM products WHERE id IN ($marks) FOR UPDATE");
            $stmt->execute(array_keys($wanted));
            $products = [];
            foreach ($stmt->fetchAll() as $row) {
                $products[(int) $row['id']] = $row;
            }

            $problems = [];
            foreach ($wanted as $pid => $qty) {
                if (!isset($products[$pid])) {
                    throw new HttpError(409, 'Ada produk yang sudah tidak tersedia. Muat ulang keranjang.');
                }
                $stock = (int) $products[$pid]['stock'];
                if ($stock <= 0) {
                    $problems[] = $products[$pid]['name'] . ' sudah habis.';
                } elseif ($qty > $stock) {
                    $problems[] = 'Stok ' . $products[$pid]['name'] . ' tinggal ' . $stock . '.';
                }
            }
            if ($problems !== []) {
                throw new HttpError(409, implode(' ', $problems));
            }

            $total = $shipping;
            foreach ($wanted as $pid => $qty) {
                $total += (int) $products[$pid]['price'] * $qty;
            }
            $now = Db::now();
            $pdo->prepare(
                'INSERT INTO orders (code, user_id, customer, total, status, address, payment_method,
                 payment_json, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
            )->execute([
                $code, $user['id'], $customer, $total,
                $paymentJson === null ? 'Diproses' : Validate::AWAITING,
                $address === '' ? null : $address, $method === '' ? null : $method,
                $paymentJson, $now, $now,
            ]);

            $item = $pdo->prepare(
                'INSERT INTO order_items (order_code, product_id, name, qty, price) VALUES (?, ?, ?, ?, ?)'
            );
            $decrease = $pdo->prepare('UPDATE products SET stock = stock - ?, updated_at = ? WHERE id = ?');
            foreach ($wanted as $pid => $qty) {
                $item->execute([$code, $pid, $products[$pid]['name'], $qty, $products[$pid]['price']]);
                $decrease->execute([$qty, $now, $pid]);
            }
            $pdo->commit();
        } catch (\PDOException $e) {
            $pdo->rollBack();
            if ($e->getCode() === '23000') {
                throw new HttpError(409, 'Kode pesanan sudah dipakai.');
            }
            throw $e;
        } catch (\Throwable $e) {
            $pdo->rollBack();
            throw $e;
        }

        http_response_code(201);
        return [
            'order' => self::orderByCode($code),
            'products' => self::productsByIds(array_keys($wanted)),
        ];
    }

    private static function orderByCode(string $code): array
    {
        $pdo = Db::pdo();
        $stmt = $pdo->prepare('SELECT * FROM orders WHERE code = ?');
        $stmt->execute([$code]);
        $order = $stmt->fetch() ?: throw new HttpError(404, 'Pesanan tidak ditemukan.');
        $items = $pdo->prepare('SELECT * FROM order_items WHERE order_code = ? ORDER BY id');
        $items->execute([$code]);
        return Serialize::order($order, $items->fetchAll());
    }

    private static function productsByIds(array $ids): array
    {
        if ($ids === []) {
            return [];
        }
        $marks = implode(',', array_fill(0, count($ids), '?'));
        $stmt = Db::pdo()->prepare("SELECT * FROM products WHERE id IN ($marks) ORDER BY id");
        $stmt->execute(array_values($ids));
        return array_map([Serialize::class, 'product'], $stmt->fetchAll());
    }

    public static function updateOrderStatus(Request $req, array $p): array
    {
        $user = Auth::require($req);
        $status = Validate::str($req->get('status'));
        if (!in_array($status, Validate::ORDER_STATUSES, true)) {
            throw new HttpError(422, 'Status pesanan tidak dikenal.');
        }

        $pdo = Db::pdo();
        $pdo->beginTransaction();
        try {
            $stmt = $pdo->prepare('SELECT * FROM orders WHERE code = ? FOR UPDATE');
            $stmt->execute([$p['code']]);
            $order = $stmt->fetch();
            if (!$order) {
                throw new HttpError(404, 'Pesanan tidak ditemukan.');
            }

            $isAdmin = $user['role'] === 'admin';
            if (!$isAdmin) {
                // Pembeli hanya boleh menyelesaikan/membatalkan pesanannya yang
                // menunggu pembayaran (hasil pengecekan pembayaran online).
                $allowed = $order['user_id'] === $user['id']
                    && $order['status'] === Validate::AWAITING
                    && in_array($status, ['Diproses', Validate::CANCELLED], true);
                if (!$allowed) {
                    throw new HttpError(403, 'Anda tidak dapat mengubah status pesanan ini.');
                }
            }

            $affected = [];
            $wasCancelled = $order['status'] === Validate::CANCELLED;
            $isCancelled = $status === Validate::CANCELLED;
            if ($wasCancelled !== $isCancelled) {
                $items = $pdo->prepare('SELECT product_id, qty FROM order_items WHERE order_code = ?');
                $items->execute([$p['code']]);
                $direction = $isCancelled ? 1 : -1;
                $update = $pdo->prepare(
                    'UPDATE products SET stock = GREATEST(0, CAST(stock AS SIGNED) + ?), updated_at = ? WHERE id = ?'
                );
                foreach ($items->fetchAll() as $item) {
                    $update->execute([$direction * (int) $item['qty'], Db::now(), $item['product_id']]);
                    $affected[] = (int) $item['product_id'];
                }
            }
            $pdo->prepare('UPDATE orders SET status = ?, updated_at = ? WHERE code = ?')
                ->execute([$status, Db::now(), $p['code']]);
            $pdo->commit();
        } catch (\Throwable $e) {
            $pdo->rollBack();
            throw $e;
        }

        return ['order' => self::orderByCode($p['code']), 'products' => self::productsByIds($affected)];
    }

    // ------------------------------------------------------- ulasan

    public static function reviews(): array
    {
        $rows = Db::pdo()->query('SELECT * FROM reviews ORDER BY created_at DESC')->fetchAll();
        return ['reviews' => array_map([Serialize::class, 'review'], $rows)];
    }

    public static function submitReview(Request $req): array
    {
        $user = Auth::require($req);
        $pid = $req->get('productId');
        $rating = $req->get('rating');
        $comment = Validate::str($req->get('comment'));
        if (!is_int($pid)) {
            throw new HttpError(422, 'Produk tidak valid.');
        }
        self::productRow($pid);

        $pdo = Db::pdo();
        $bought = $pdo->prepare(
            "SELECT 1 FROM orders o JOIN order_items i ON i.order_code = o.code
             WHERE o.user_id = ? AND o.status = 'Selesai' AND i.product_id = ? LIMIT 1"
        );
        $bought->execute([$user['id'], $pid]);
        if (!$bought->fetch()) {
            throw new HttpError(403, 'Ulasan hanya untuk pembeli yang pesanannya sudah selesai.');
        }
        if (!is_int($rating) || $rating < 1 || $rating > 5) {
            throw new HttpError(422, 'Pilih rating 1 sampai 5 bintang.');
        }
        if (mb_strlen($comment) > Validate::MAX_COMMENT) {
            throw new HttpError(422, 'Komentar maksimal ' . Validate::MAX_COMMENT . ' karakter.');
        }

        $pdo->prepare(
            'INSERT INTO reviews (product_id, user_id, author_name, rating, comment, created_at)
             VALUES (?, ?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE author_name = VALUES(author_name), rating = VALUES(rating),
             comment = VALUES(comment), created_at = VALUES(created_at)'
        )->execute([$pid, $user['id'], $user['name'], $rating, $comment, Db::now()]);

        $stmt = $pdo->prepare('SELECT * FROM reviews WHERE product_id = ? AND user_id = ?');
        $stmt->execute([$pid, $user['id']]);
        http_response_code(201);
        return ['review' => Serialize::review($stmt->fetch())];
    }

    public static function deleteReview(Request $req, array $p): array
    {
        Auth::requireAdmin($req);
        Db::pdo()->prepare('DELETE FROM reviews WHERE product_id = ? AND user_id = ?')
            ->execute([(int) $p['productId'], $p['userId']]);
        return ['ok' => true];
    }

    // ------------------------------------------------------ wishlist

    public static function wishlist(Request $req): array
    {
        $user = Auth::require($req);
        $stmt = Db::pdo()->prepare('SELECT product_id FROM wishlists WHERE user_id = ? ORDER BY created_at, product_id');
        $stmt->execute([$user['id']]);
        return ['wishlist' => array_map('intval', array_column($stmt->fetchAll(), 'product_id'))];
    }

    public static function addWishlist(Request $req, array $p): array
    {
        $user = Auth::require($req);
        $row = self::productRow($p['productId']);
        Db::pdo()->prepare('INSERT IGNORE INTO wishlists (user_id, product_id, created_at) VALUES (?, ?, ?)')
            ->execute([$user['id'], $row['id'], Db::now()]);
        return ['ok' => true];
    }

    public static function removeWishlist(Request $req, array $p): array
    {
        $user = Auth::require($req);
        Db::pdo()->prepare('DELETE FROM wishlists WHERE user_id = ? AND product_id = ?')
            ->execute([$user['id'], (int) $p['productId']]);
        return ['ok' => true];
    }

    // -------------------------------------------------------- admin

    public static function users(Request $req): array
    {
        Auth::requireAdmin($req);
        $rows = Db::pdo()->query("SELECT * FROM users WHERE role = 'user' ORDER BY created_at, id")->fetchAll();
        return ['users' => array_map(static fn(array $u) => Serialize::user($u), $rows)];
    }

    public static function resetPassword(Request $req, array $p): array
    {
        Auth::requireAdmin($req);
        $target = self::userRow($p['id']);
        if ($target['role'] === 'admin') {
            throw new HttpError(403, 'Password admin diubah lewat Ganti Password.');
        }
        $new = (string) $req->get('newPassword', '');
        if (strlen($new) < Validate::MIN_PASSWORD) {
            throw new HttpError(422, 'Password minimal ' . Validate::MIN_PASSWORD . ' karakter.');
        }
        $pdo = Db::pdo();
        $pdo->prepare('UPDATE users SET password_hash = ? WHERE id = ?')->execute([Auth::hashPassword($new), $target['id']]);
        // Paksa masuk ulang dengan password baru.
        $pdo->prepare('DELETE FROM sessions WHERE user_id = ?')->execute([$target['id']]);
        return ['ok' => true];
    }

    public static function resetSampleData(Request $req): array
    {
        Auth::requireAdmin($req);
        SampleData::seed(Db::pdo());
        return ['ok' => true];
    }
}
