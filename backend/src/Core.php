<?php
declare(strict_types=1);

namespace MotoPart;

use PDO;

/** Kesalahan yang dikirim ke klien sebagai {"error": "..."} dengan status HTTP. */
final class HttpError extends \RuntimeException
{
    public function __construct(public readonly int $status, string $message)
    {
        parent::__construct($message);
    }
}

/** Koneksi database (PDO, MySQL/MariaDB). */
final class Db
{
    private static ?PDO $pdo = null;

    public static function connect(array $config, bool $withDatabase = true): PDO
    {
        $dsn = sprintf(
            'mysql:host=%s;port=%d;%scharset=utf8mb4',
            $config['db_host'],
            $config['db_port'],
            $withDatabase ? 'dbname=' . $config['db_name'] . ';' : ''
        );
        return new PDO($dsn, $config['db_user'], $config['db_pass'], [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
            PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8mb4, time_zone = '+00:00'",
        ]);
    }

    public static function pdo(): PDO
    {
        return self::$pdo ??= self::connect(require __DIR__ . '/../config.php');
    }

    /** Untuk tes: memakai koneksi yang sudah ada. */
    public static function use(PDO $pdo): void
    {
        self::$pdo = $pdo;
    }

    /** Waktu sekarang (UTC) dalam format DATETIME. */
    public static function now(): string
    {
        return gmdate('Y-m-d H:i:s');
    }

    /** DATETIME (UTC) -> ISO 8601 dengan "Z". */
    public static function iso(?string $datetime): ?string
    {
        if ($datetime === null || $datetime === '') {
            return null;
        }
        return str_replace(' ', 'T', $datetime) . 'Z';
    }

    /** ISO 8601 / apa pun yang dikenali strtotime -> DATETIME (UTC). */
    public static function fromIso(string $value): ?string
    {
        $time = strtotime($value);
        return $time === false ? null : gmdate('Y-m-d H:i:s', $time);
    }
}

/** Permintaan HTTP yang sedang dilayani. */
final class Request
{
    public function __construct(
        public readonly string $method,
        public readonly string $path,
        public readonly array $query,
        public readonly array $body,
        public readonly ?string $token,
    ) {
    }

    public static function fromGlobals(): self
    {
        $path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
        // Buang lokasi skrip (mis. /motopart-api) dan "index.php".
        $base = rtrim(str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? '')), '/');
        if ($base !== '' && str_starts_with($path, $base)) {
            $path = substr($path, strlen($base));
        }
        if (str_starts_with($path, '/index.php')) {
            $path = substr($path, strlen('/index.php'));
        }
        $path = '/' . trim($path, '/');

        $body = [];
        $raw = file_get_contents('php://input') ?: '';
        if (strlen($raw) > 4 * 1024 * 1024) {
            throw new HttpError(413, 'Isi permintaan terlalu besar.');
        }
        if ($raw !== '') {
            $decoded = json_decode($raw, true);
            if (!is_array($decoded)) {
                throw new HttpError(400, 'Isi permintaan bukan JSON yang valid.');
            }
            $body = $decoded;
        }

        $header = $_SERVER['HTTP_AUTHORIZATION']
            ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
            ?? '';
        $token = null;
        if (preg_match('/^Bearer\s+([A-Fa-f0-9]{64})$/', $header, $m)) {
            $token = strtolower($m[1]);
        } elseif (!empty($_SERVER['HTTP_X_AUTH_TOKEN'])
            && preg_match('/^[A-Fa-f0-9]{64}$/', $_SERVER['HTTP_X_AUTH_TOKEN'])) {
            $token = strtolower($_SERVER['HTTP_X_AUTH_TOKEN']);
        }

        return new self($_SERVER['REQUEST_METHOD'] ?? 'GET', $path, $_GET, $body, $token);
    }

    /** Nilai kunci [key] dari isi JSON, atau [default]. */
    public function get(string $key, mixed $default = null): mixed
    {
        return array_key_exists($key, $this->body) ? $this->body[$key] : $default;
    }

    public function has(string $key): bool
    {
        return array_key_exists($key, $this->body);
    }
}

/** Router sederhana: pola seperti /orders/{code}/status. */
final class Router
{
    /** @var array<int, array{string, string, callable}> */
    private array $routes = [];

    public function add(string $method, string $pattern, callable $handler): void
    {
        $regex = '#^' . preg_replace('#\{([a-zA-Z_]+)\}#', '(?P<$1>[^/]+)', $pattern) . '$#';
        $this->routes[] = [$method, $regex, $handler];
    }

    /** @return mixed hasil handler (diubah menjadi JSON oleh pemanggil) */
    public function dispatch(Request $request): mixed
    {
        $methodMismatch = false;
        foreach ($this->routes as [$method, $regex, $handler]) {
            if (preg_match($regex, $request->path, $m)) {
                if ($method !== $request->method) {
                    $methodMismatch = true;
                    continue;
                }
                $params = array_filter($m, 'is_string', ARRAY_FILTER_USE_KEY);
                return $handler($request, array_map('urldecode', $params));
            }
        }
        throw new HttpError($methodMismatch ? 405 : 404, $methodMismatch
            ? 'Metode tidak didukung untuk alamat ini.'
            : 'Alamat tidak ditemukan.');
    }
}

/** Autentikasi: token sesi acak yang disimpan di tabel `sessions`. */
final class Auth
{
    public static function hashPassword(string $password): string
    {
        return password_hash($password, PASSWORD_BCRYPT);
    }

    public static function createToken(string $userId, int $days): string
    {
        $token = bin2hex(random_bytes(32));
        $now = Db::now();
        $expires = gmdate('Y-m-d H:i:s', time() + $days * 86400);
        Db::pdo()
            ->prepare('INSERT INTO sessions (token, user_id, expires_at, created_at) VALUES (?, ?, ?, ?)')
            ->execute([$token, $userId, $expires, $now]);
        // Bersihkan sesi kedaluwarsa sesekali.
        if (random_int(1, 20) === 1) {
            Db::pdo()->prepare('DELETE FROM sessions WHERE expires_at < ?')->execute([$now]);
        }
        return $token;
    }

    public static function destroyToken(string $token): void
    {
        Db::pdo()->prepare('DELETE FROM sessions WHERE token = ?')->execute([$token]);
    }

    /** Baris pengguna untuk token pada permintaan ini, atau null. */
    public static function user(Request $request): ?array
    {
        if ($request->token === null) {
            return null;
        }
        $stmt = Db::pdo()->prepare(
            'SELECT u.* FROM sessions s JOIN users u ON u.id = s.user_id
             WHERE s.token = ? AND s.expires_at > ?'
        );
        $stmt->execute([$request->token, Db::now()]);
        return $stmt->fetch() ?: null;
    }

    public static function require(Request $request): array
    {
        return self::user($request)
            ?? throw new HttpError(401, 'Silakan masuk terlebih dahulu.');
    }

    public static function requireAdmin(Request $request): array
    {
        $user = self::require($request);
        if ($user['role'] !== 'admin') {
            throw new HttpError(403, 'Hanya admin yang dapat melakukan ini.');
        }
        return $user;
    }

    public static function newId(string $prefix): string
    {
        return $prefix . bin2hex(random_bytes(10));
    }
}
