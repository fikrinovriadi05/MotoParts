<?php
declare(strict_types=1);

/**
 * Tes API MotoPart lewat HTTP sungguhan.
 *
 *   php tests/run_tests.php [http://127.0.0.1:8081]
 *
 * PERINGATAN: tes ini memanggil /admin/reset-sample-data dan membuat akun
 * baru, jadi jalankan hanya terhadap database UJI (lihat tests/run.ps1).
 */

$base = rtrim($argv[1] ?? 'http://127.0.0.1:8081', '/');
$passed = 0;
$failed = [];

function call(string $method, string $path, ?array $body = null, ?string $token = null): array
{
    global $base;
    $headers = "Content-Type: application/json\r\nAccept: application/json\r\n";
    if ($token !== null) {
        $headers .= "Authorization: Bearer $token\r\n";
    }
    $ctx = stream_context_create(['http' => [
        'method' => $method,
        'header' => $headers,
        'content' => $body === null ? '' : json_encode($body),
        'ignore_errors' => true,
        'timeout' => 20,
    ]]);
    $raw = @file_get_contents($base . $path, false, $ctx);
    $status = 0;
    foreach ($http_response_header ?? [] as $h) {
        if (preg_match('#^HTTP/\S+\s+(\d+)#', $h, $m)) {
            $status = (int) $m[1];
        }
    }
    return [$status, $raw === false || $raw === '' ? [] : (json_decode($raw, true) ?? ['_raw' => $raw])];
}

function check(string $name, bool $ok, mixed $detail = null): void
{
    global $passed, $failed;
    if ($ok) {
        $passed++;
        return;
    }
    $failed[] = $name . ($detail === null ? '' : ' -> ' . json_encode($detail, JSON_UNESCAPED_UNICODE));
    echo "GAGAL: $name\n";
}

function expect(string $name, array $res, int $status, ?string $errorContains = null): void
{
    [$s, $b] = $res;
    $ok = $s === $status;
    if ($ok && $errorContains !== null) {
        $ok = str_contains($b['error'] ?? '', $errorContains);
    }
    check($name, $ok, [$s, $b]);
}

// ---- Persiapan: data contoh bersih
[, $admin] = call('POST', '/auth/login', ['email' => 'admin@motopart.id', 'password' => 'admin123', 'role' => 'admin']);
$at = $admin['token'] ?? '';
check('login admin', $at !== '' && ($admin['user']['role'] ?? '') === 'admin', $admin);
check('admin memakai password bawaan', ($admin['user']['usesDefaultPassword'] ?? null) === true, $admin['user'] ?? null);
expect('reset data contoh', call('POST', '/admin/reset-sample-data', null, $at), 200);

// ---- Umum
expect('health', call('GET', '/health'), 200);
expect('alamat tidak ada', call('GET', '/tidak-ada'), 404);
expect('metode salah', call('DELETE', '/health'), 405);
[, $list] = call('GET', '/products');
check('12 produk contoh', count($list['products'] ?? []) === 12, count($list['products'] ?? []));
check('bentuk produk', isset($list['products'][0]['imagePath']) || array_key_exists('imagePath', $list['products'][0] ?? []), $list['products'][0] ?? null);

// ---- Registrasi
$email = 'uji' . random_int(1000, 999999) . '@mail.com';
expect('daftar: nama kosong', call('POST', '/auth/register', ['name' => '', 'email' => $email, 'phone' => '081234567890', 'password' => 'Rahasia1!']), 422);
expect('daftar: email buruk', call('POST', '/auth/register', ['name' => 'Uji', 'email' => 'bukanemail', 'phone' => '081234567890', 'password' => 'Rahasia1!']), 422);
expect('daftar: password pendek', call('POST', '/auth/register', ['name' => 'Uji', 'email' => $email, 'phone' => '081234567890', 'password' => '123']), 422);
expect('daftar: tanpa huruf kapital', call('POST', '/auth/register', ['name' => 'Uji', 'email' => $email, 'phone' => '081234567890', 'password' => 'rahasia1!']), 422, 'huruf kapital');
expect('daftar: tanpa angka', call('POST', '/auth/register', ['name' => 'Uji', 'email' => $email, 'phone' => '081234567890', 'password' => 'Rahasia!!']), 422, 'angka');
expect('daftar: tanpa simbol', call('POST', '/auth/register', ['name' => 'Uji', 'email' => $email, 'phone' => '081234567890', 'password' => 'Rahasia11']), 422, 'simbol');
[$s, $reg] = call('POST', '/auth/register', ['name' => 'Penguji Satu', 'email' => $email, 'phone' => '081234567890', 'password' => 'Rahasia1!']);
check('daftar berhasil', $s === 201 && strlen($reg['token'] ?? '') === 64, [$s, $reg]);
check('hash tidak bocor', !isset($reg['user']['passwordHash']) && !str_contains(json_encode($reg), '$2y$'), $reg);
$ut = $reg['token'];
$uid = $reg['user']['id'];
expect('daftar: email ganda', call('POST', '/auth/register', ['name' => 'Lain', 'email' => $email, 'phone' => '081234567890', 'password' => 'Rahasia1!']), 409, 'sudah terdaftar');

// ---- Login
expect('login salah password', call('POST', '/auth/login', ['email' => $email, 'password' => 'salah123', 'role' => 'user']), 401);
expect('login user lewat tab admin', call('POST', '/auth/login', ['email' => $email, 'password' => 'Rahasia1!', 'role' => 'admin']), 403, 'bukan akun admin');
expect('login admin lewat tab user', call('POST', '/auth/login', ['email' => 'admin@motopart.id', 'password' => 'admin123', 'role' => 'user']), 403, 'tab Admin');
[$s, $lg] = call('POST', '/auth/login', ['email' => $email, 'password' => 'Rahasia1!', 'role' => 'user']);
check('login user', $s === 200 && ($lg['user']['id'] ?? '') === $uid, [$s, $lg]);
// Satu pintu: tanpa peran, pembeli maupun admin bisa masuk.
[$s, $lg] = call('POST', '/auth/login', ['email' => $email, 'password' => 'Rahasia1!']);
check('login tanpa peran (user)', $s === 200 && ($lg['user']['role'] ?? '') === 'user', [$s, $lg]);
[$s, $lg] = call('POST', '/auth/login', ['email' => 'admin@motopart.id', 'password' => 'admin123']);
check('login tanpa peran (admin)', $s === 200 && ($lg['user']['role'] ?? '') === 'admin', [$s, $lg]);
// Google: tanpa google_client_ids di config server fitur mati (503); token
// ngawur tidak pernah diterima.
[$s] = call('POST', '/auth/google', ['idToken' => 'bukan-token']);
check('google: ditolak tanpa konfigurasi / token palsu', in_array($s, [503, 401, 502], true), $s);

// ---- Sesi
expect('me tanpa token', call('GET', '/me'), 401);
expect('me token palsu', call('GET', '/me', null, str_repeat('a', 64)), 401);
expect('me', call('GET', '/me', null, $ut), 200);

// ---- Profil
expect('profil: tahun di luar rentang', call('PUT', '/me', ['motorName' => 'Vario', 'motorYear' => 1800], $ut), 422);
expect('profil: tipe tanpa nama motor', call('PUT', '/me', ['motorType' => 'Matic'], $ut), 422);
[$s, $pr] = call('PUT', '/me', ['name' => 'Penguji Dua', 'motorName' => 'Honda Vario 150', 'motorType' => 'Matic', 'motorYear' => 2020, 'preferredPayment' => 'QRIS'], $ut);
check('profil tersimpan', $s === 200 && $pr['user']['name'] === 'Penguji Dua' && $pr['user']['motorYear'] === 2020
    && $pr['user']['motorType'] === 'Matic', [$s, $pr]);
[, $pr2] = call('PUT', '/me', ['motorYear' => ''], $ut);
check('tahun dikosongkan', array_key_exists('motorYear', $pr2['user'] ?? []) && $pr2['user']['motorYear'] === null, $pr2);
expect('metode bayar tak dikenal', call('PUT', '/me', ['preferredPayment' => 'bitcoin'], $ut), 422);

// ---- Password
expect('ganti password: lama salah', call('PUT', '/me/password', ['oldPassword' => 'x', 'newPassword' => 'barubaru1'], $ut), 422, 'lama salah');
expect('ganti password: sama', call('PUT', '/me/password', ['oldPassword' => 'Rahasia1!', 'newPassword' => 'Rahasia1!'], $ut), 422, 'berbeda');
expect('ganti password', call('PUT', '/me/password', ['oldPassword' => 'Rahasia1!', 'newPassword' => 'barubaru1'], $ut), 200);
expect('login password baru', call('POST', '/auth/login', ['email' => $email, 'password' => 'barubaru1', 'role' => 'user']), 200);
expect('login password lama', call('POST', '/auth/login', ['email' => $email, 'password' => 'Rahasia1!', 'role' => 'user']), 401);

// ---- Alamat
$addr = ['label' => 'Rumah', 'recipient' => 'Penguji', 'phone' => '081234567890', 'street' => 'Jl. Merdeka No. 1',
    'city' => 'Pekanbaru', 'postalCode' => '28111', 'latitude' => 0.5071, 'longitude' => 101.4478];
expect('alamat: jalan kosong', call('POST', '/addresses', array_merge($addr, ['street' => '']), $ut), 422);
[$s, $a1] = call('POST', '/addresses', $addr, $ut);
check('alamat pertama jadi utama', $s === 201 && $a1['user']['defaultAddressId'] === $a1['addressId'], [$s, $a1]);
check('koordinat tersimpan', abs(($a1['user']['addresses'][0]['latitude'] ?? 0) - 0.5071) < 0.0001, $a1['user']['addresses'] ?? null);
[, $a2] = call('POST', '/addresses', array_merge($addr, ['label' => 'Kantor']), $ut);
check('alamat kedua bukan utama', $a2['user']['defaultAddressId'] === $a1['addressId'] && count($a2['user']['addresses']) === 2, $a2);
[, $a3] = call('PUT', '/addresses/' . $a2['addressId'] . '/default', null, $ut);
check('ganti alamat utama', $a3['user']['defaultAddressId'] === $a2['addressId'], $a3);
[, $a4] = call('PUT', '/addresses/' . $a2['addressId'], array_merge($addr, ['label' => 'Kantor Baru']), $ut);
check('ubah alamat', in_array('Kantor Baru', array_column($a4['user']['addresses'], 'label'), true), $a4);
[, $a5] = call('DELETE', '/addresses/' . $a2['addressId'], null, $ut);
check('hapus alamat utama -> pindah', $a5['user']['defaultAddressId'] === $a1['addressId'] && count($a5['user']['addresses']) === 1, $a5);

// Akun lain tidak boleh menyentuh alamat orang
[, $other] = call('POST', '/auth/register', ['name' => 'Penguji Lain', 'email' => 'lain' . random_int(1000, 999999) . '@mail.com', 'phone' => '081234567891', 'password' => 'Rahasia1!']);
$ot = $other['token'];
expect('alamat milik orang lain', call('DELETE', '/addresses/' . $a1['addressId'], null, $ot), 404);

// ---- Produk (admin)
$newProduct = ['name' => 'Kampas Rem Uji', 'category' => 'Rem', 'type' => 'Matic', 'price' => 45000, 'stock' => 5, 'icon' => 'build', 'description' => 'Produk uji'];
expect('buat produk: bukan admin', call('POST', '/products', $newProduct, $ut), 403);
expect('buat produk: tanpa login', call('POST', '/products', $newProduct), 401);
expect('buat produk: harga negatif', call('POST', '/products', array_merge($newProduct, ['price' => -5]), $at), 422);
expect('buat produk: stok negatif', call('POST', '/products', array_merge($newProduct, ['stock' => -1]), $at), 422);
[$s, $np] = call('POST', '/products', $newProduct, $at);
check('buat produk', $s === 201 && $np['product']['price'] === 45000 && is_int($np['product']['id']), [$s, $np]);
$pid = $np['product']['id'];
[, $up] = call('PUT', "/products/$pid", ['price' => 50000, 'stock' => 3], $at);
check('ubah produk', $up['product']['price'] === 50000 && $up['product']['stock'] === 3 && $up['product']['name'] === 'Kampas Rem Uji', $up);
$img = 'data:image/png;base64,iVBORw0KGgo=';
[, $up2] = call('PUT', "/products/$pid", ['imagePath' => $img], $at);
check('foto tersimpan sebagai data URL', ($up2['product']['imagePath'] ?? '') === $img, $up2);

// ---- Pesanan
expect('pesan tanpa login', call('POST', '/orders', ['lines' => [['productId' => $pid, 'qty' => 1]]]), 401);
expect('pesan: keranjang kosong', call('POST', '/orders', ['lines' => []], $ut), 422);
expect('pesan: qty nol', call('POST', '/orders', ['lines' => [['productId' => $pid, 'qty' => 0]]], $ut), 422);
expect('pesan: melebihi stok', call('POST', '/orders', ['lines' => [['productId' => $pid, 'qty' => 4]]], $ut), 409, 'tinggal 3');
expect('pesan: produk tak ada', call('POST', '/orders', ['lines' => [['productId' => 99999, 'qty' => 1]]], $ut), 409);
[$s, $o1] = call('POST', '/orders', [
    'lines' => [['productId' => $pid, 'qty' => 2], ['productId' => $pid, 'qty' => 1]],
    'shippingCost' => 10000, 'address' => 'Jl. Merdeka No. 1', 'paymentMethod' => 'Bayar di Tempat (COD)',
    'price' => 1, 'total' => 1,
], $ut);
check('pesan COD', $s === 201 && $o1['order']['status'] === 'Diproses' && $o1['order']['total'] === 3 * 50000 + 10000, [$s, $o1]);
check('baris digabung', count($o1['order']['lines']) === 1 && $o1['order']['lines'][0]['qty'] === 3, $o1['order']['lines'] ?? null);
check('harga dari server', $o1['order']['lines'][0]['price'] === 50000, $o1['order']['lines'] ?? null);
check('stok berkurang', $o1['products'][0]['stock'] === 0, $o1['products'] ?? null);
$code1 = $o1['order']['code'];
expect('pesan: stok habis', call('POST', '/orders', ['lines' => [['productId' => $pid, 'qty' => 1]]], $ut), 409, 'habis');

// Pesanan online -> menunggu pembayaran
[, $p2] = call('POST', '/products', array_merge($newProduct, ['name' => 'Busi Uji', 'stock' => 10, 'price' => 20000]), $at);
$pid2 = $p2['product']['id'];
[$s, $o2] = call('POST', '/orders', [
    'code' => 'MP-UJI-' . random_int(1000, 99999), 'lines' => [['productId' => $pid2, 'qty' => 2]],
    'paymentMethod' => 'QRIS', 'payment' => ['provider' => 'fake', 'orderId' => 'x1', 'amount' => 40000],
], $ut);
check('pesan online menunggu', $s === 201 && $o2['order']['status'] === 'Menunggu Pembayaran'
    && ($o2['order']['payment']['orderId'] ?? '') === 'x1', [$s, $o2]);
$code2 = $o2['order']['code'];
expect('kode pesanan ganda', call('POST', '/orders', ['code' => $code2, 'lines' => [['productId' => $pid2, 'qty' => 1]]], $ut), 409);

// Hak akses melihat pesanan
[, $mine] = call('GET', '/orders', null, $ut);
check('pembeli melihat pesanannya', count($mine['orders']) === 2, count($mine['orders']));
[, $others] = call('GET', '/orders', null, $ot);
check('pembeli lain tidak melihat', count($others['orders']) === 0, $others);
[, $all] = call('GET', '/orders', null, $at);
check('admin melihat semua', count($all['orders']) >= 4, count($all['orders']));

// Status
expect('status: pembeli lain', call('PUT', "/orders/$code2/status", ['status' => 'Dibatalkan'], $ot), 403);
expect('status: pembeli ubah COD', call('PUT', "/orders/$code1/status", ['status' => 'Selesai'], $ut), 403);
expect('status tak dikenal', call('PUT', "/orders/$code1/status", ['status' => 'Aneh'], $at), 422);
expect('status pesanan tak ada', call('PUT', '/orders/MP-TIDAKADA/status', ['status' => 'Selesai'], $at), 404);
[, $st] = call('PUT', "/orders/$code2/status", ['status' => 'Dibatalkan'], $ut);
check('pembeli batalkan menunggu bayar', $st['order']['status'] === 'Dibatalkan' && $st['products'][0]['stock'] === 10, $st);
[, $st2] = call('PUT', "/orders/$code2/status", ['status' => 'Diproses'], $at);
check('admin aktifkan lagi -> stok dipotong', $st2['order']['status'] === 'Diproses' && $st2['products'][0]['stock'] === 8, $st2);
[, $st3] = call('PUT', "/orders/$code1/status", ['status' => 'Dikirim'], $at);
check('admin kirim', $st3['order']['status'] === 'Dikirim', $st3);
[, $st4] = call('PUT', "/orders/$code1/status", ['status' => 'Dibatalkan'], $at);
check('batal mengembalikan stok', $st4['products'][0]['stock'] === 3, $st4);
[, $st5] = call('PUT', "/orders/$code1/status", ['status' => 'Selesai'], $at);
check('batal -> selesai memotong stok', $st5['products'][0]['stock'] === 0, $st5);

// ---- Ulasan (butuh pesanan Selesai)
expect('ulasan tanpa login', call('POST', '/reviews', ['productId' => $pid, 'rating' => 5, 'comment' => 'ok']), 401);
expect('ulasan: belum membeli', call('POST', '/reviews', ['productId' => $pid, 'rating' => 5, 'comment' => 'ok'], $ot), 403);
expect('ulasan: belum selesai', call('POST', '/reviews', ['productId' => $pid2, 'rating' => 5, 'comment' => 'ok'], $ut), 403);
expect('ulasan: rating 0', call('POST', '/reviews', ['productId' => $pid, 'rating' => 0, 'comment' => 'ok'], $ut), 422);
expect('ulasan: rating 6', call('POST', '/reviews', ['productId' => $pid, 'rating' => 6, 'comment' => 'ok'], $ut), 422);
expect('ulasan: komentar panjang', call('POST', '/reviews', ['productId' => $pid, 'rating' => 5, 'comment' => str_repeat('a', 301)], $ut), 422);
[$s, $rv] = call('POST', '/reviews', ['productId' => $pid, 'rating' => 4, 'comment' => 'Bagus sekali'], $ut);
check('ulasan tersimpan', $s === 201 && $rv['review']['rating'] === 4 && $rv['review']['authorName'] === 'Penguji Dua', [$s, $rv]);
call('POST', '/reviews', ['productId' => $pid, 'rating' => 5, 'comment' => 'Diperbarui'], $ut);
[, $rl] = call('GET', '/reviews');
$mineReviews = array_filter($rl['reviews'], fn($r) => $r['productId'] === $pid);
check('ulasan diganti, bukan ganda', count($mineReviews) === 1 && array_values($mineReviews)[0]['rating'] === 5, $mineReviews);
expect('hapus ulasan: bukan admin', call('DELETE', "/reviews/$pid/$uid", null, $ut), 403);
expect('hapus ulasan', call('DELETE', "/reviews/$pid/$uid", null, $at), 200);

// ---- Wishlist
expect('wishlist tanpa login', call('GET', '/wishlist'), 401);
expect('wishlist tambah', call('PUT', "/wishlist/$pid", null, $ut), 200);
expect('wishlist tambah lagi (idempoten)', call('PUT', "/wishlist/$pid", null, $ut), 200);
expect('wishlist produk tak ada', call('PUT', '/wishlist/99999', null, $ut), 404);
[, $wl] = call('GET', '/wishlist', null, $ut);
check('wishlist isi', $wl['wishlist'] === [$pid], $wl);
call('DELETE', "/wishlist/$pid", null, $ut);
[, $wl2] = call('GET', '/wishlist', null, $ut);
check('wishlist kosong', $wl2['wishlist'] === [], $wl2);

// ---- Admin
expect('daftar user: bukan admin', call('GET', '/users', null, $ut), 403);
[, $us] = call('GET', '/users', null, $at);
check('admin melihat pengguna', count($us['users']) >= 2 && !str_contains(json_encode($us), '$2y$'), count($us['users'] ?? []));
expect('reset password pengguna: pendek', call('PUT', "/users/$uid/password", ['newPassword' => '123'], $at), 422);
expect('reset password pengguna', call('PUT', "/users/$uid/password", ['newPassword' => 'direset99'], $at), 200);
expect('token lama dicabut', call('GET', '/me', null, $ut), 401);
expect('login dengan password reset', call('POST', '/auth/login', ['email' => $email, 'password' => 'direset99', 'role' => 'user']), 200);
expect('reset password admin ditolak', call('PUT', '/users/admin/password', ['newPassword' => 'abcdef'], $at), 403);

// ---- Kategori
[, $cats] = call('GET', '/categories');
check('7 kategori bawaan', count($cats['categories'] ?? []) === 7, $cats);
check('bentuk kategori', ($cats['categories'][0] ?? null) === ['name' => 'Mesin', 'icon' => 'settings'], $cats['categories'][0] ?? null);
expect('kategori: bukan admin', call('POST', '/categories', ['name' => 'Aki', 'icon' => 'bolt'], $ot), 403);
expect('kategori: tanpa login', call('POST', '/categories', ['name' => 'Aki']), 401);
expect('kategori: nama kosong', call('POST', '/categories', ['name' => '  '], $at), 422);
expect('kategori: nama panjang', call('POST', '/categories', ['name' => str_repeat('a', 31)], $at), 422);
expect('kategori: nama ganda (huruf beda)', call('POST', '/categories', ['name' => 'mesin'], $at), 409, 'sudah ada');
[$s, $nc] = call('POST', '/categories', ['name' => 'Aki', 'icon' => 'tidak-ada'], $at);
check('kategori ditambah, ikon asing jadi build', $s === 201 && end($nc['categories']) === ['name' => 'Aki', 'icon' => 'build'], $nc);
[, $nc2] = call('PUT', '/categories/Aki', ['name' => 'Aki dan Kabel', 'icon' => 'electric_bolt'], $at);
check('kategori diubah', in_array(['name' => 'Aki dan Kabel', 'icon' => 'electric_bolt'], $nc2['categories'], true), $nc2);
expect('kategori ubah: nama bentrok', call('PUT', '/categories/' . rawurlencode('Aki dan Kabel'), ['name' => 'Rem'], $at), 409);
expect('kategori ubah: tak ada', call('PUT', '/categories/Tidak', ['name' => 'X'], $at), 404);
// Ganti nama membawa produknya.
[, $cp] = call('POST', '/products', array_merge($newProduct, ['name' => 'Aki Uji', 'category' => 'Aki dan Kabel']), $at);
call('PUT', '/categories/' . rawurlencode('Aki dan Kabel'), ['name' => 'Aki', 'icon' => 'electric_bolt'], $at);
[, $pl] = call('GET', '/products');
$moved = array_values(array_filter($pl['products'], fn($p) => $p['name'] === 'Aki Uji'));
check('produk ikut pindah kategori', ($moved[0]['category'] ?? '') === 'Aki', $moved);
expect('kategori hapus: masih dipakai', call('DELETE', '/categories/Aki', null, $at), 409, 'masih dipakai 1 produk');
call('DELETE', '/products/' . $cp['product']['id'], null, $at);
expect('kategori hapus: bukan admin', call('DELETE', '/categories/Aki', null, $ot), 403);
expect('kategori hapus', call('DELETE', '/categories/Aki', null, $at), 200);
expect('kategori hapus lagi', call('DELETE', '/categories/Aki', null, $at), 404);
// Urutan kategori.
$order = array_column($cats['categories'], 'name');
$reversed = array_reverse($order);
expect('urutan: bukan admin', call('POST', '/categories/reorder', ['names' => $reversed], $ot), 403);
expect('urutan: kurang lengkap', call('POST', '/categories/reorder', ['names' => array_slice($reversed, 1)], $at), 422);
expect('urutan: nama asing', call('POST', '/categories/reorder', ['names' => array_merge(array_slice($reversed, 1), ['Asing'])], $at), 422);
expect('urutan: nama ganda', call('POST', '/categories/reorder', ['names' => array_merge(array_slice($reversed, 1), [$reversed[1]])], $at), 422);
[$s, $ro] = call('POST', '/categories/reorder', ['names' => $reversed], $at);
check('urutan diubah', $s === 200 && array_column($ro['categories'], 'name') === $reversed, $ro);
[, $ro2] = call('GET', '/categories');
check('urutan tersimpan', array_column($ro2['categories'], 'name') === $reversed, $ro2);
call('POST', '/categories/reorder', ['names' => $order], $at);

[, $sc] = call('GET', '/sync');
check('sync memuat kategori', count($sc['categories'] ?? []) === 7, count($sc['categories'] ?? []));

// ---- Sync
[, $sy] = call('GET', '/sync', null, $at);
check('sync admin', count($sy['products']) >= 12 && count($sy['orders']) >= 4 && isset($sy['users']) && $sy['me']['role'] === 'admin', array_keys($sy));
[, $sy2] = call('GET', '/sync');
check('sync tamu', $sy2['me'] === null && count($sy2['products']) >= 12 && $sy2['orders'] === [], array_keys($sy2));

// ---- Hapus produk & logout
expect('hapus produk: bukan admin', call('DELETE', "/products/$pid2", null, $ot), 403);
expect('hapus produk', call('DELETE', "/products/$pid2", null, $at), 200);
expect('hapus produk lagi', call('DELETE', "/products/$pid2", null, $at), 404);
expect('logout', call('POST', '/auth/logout', null, $at), 200);
expect('token setelah logout', call('GET', '/me', null, $at), 401);

// Bersihkan data uji
[, $re] = call('POST', '/auth/login', ['email' => 'admin@motopart.id', 'password' => 'admin123', 'role' => 'admin']);
call('POST', '/admin/reset-sample-data', null, $re['token'] ?? '');

echo "\nLulus: $passed, gagal: " . count($failed) . "\n";
foreach ($failed as $f) {
    echo " - $f\n";
}
exit($failed === [] ? 0 : 1);
