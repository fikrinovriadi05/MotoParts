<?php
// Salin berkas ini menjadi `config.local.php`, lalu sesuaikan. Berkas
// config.local.php tidak ikut git dan tidak boleh dibagikan.
//
// XAMPP (lokal): bawaan sudah cocok (root tanpa password), tidak perlu berkas ini.
// Hosting (cPanel/lainnya): isi dengan database dan pengguna yang Anda buat di
// panel hosting.
return [
    'db_host' => 'localhost',
    'db_port' => 3306,
    'db_name' => 'namaakun_motopart',
    'db_user' => 'namaakun_motopart',
    'db_pass' => 'GANTI-DENGAN-PASSWORD-KUAT',

    // Batasi asal yang boleh memanggil API dari browser, mis. situs web Anda:
    // 'allow_origin' => 'https://motopart.netlify.app',
    'allow_origin' => '*',

    // Password admin awal (dipakai tool/setup.php). Ganti setelah login.
    'admin_password' => 'admin123',
];
