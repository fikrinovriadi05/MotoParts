# Menjalankan tes API di database UJI yang terpisah dari XAMPP Anda:
# MariaDB sementara (port 3307, folder data sementara) + server PHP bawaan.
# Data MySQL XAMPP Anda tidak disentuh.
#
#   powershell -ExecutionPolicy Bypass -File backend\tests\run.ps1
param(
    [switch]$E2E,   # juga jalankan tes aplikasi Flutter melawan server ini
    [string]$Xampp = 'C:\xampp',
    [int]$DbPort = 3307,
    [int]$HttpPort = 8081
)
$ErrorActionPreference = 'Stop'
$backend = Split-Path -Parent $PSScriptRoot
$work = Join-Path ([IO.Path]::GetTempPath()) ('motopart-test-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$php = Join-Path $Xampp 'php\php.exe'
$mysqld = Join-Path $Xampp 'mysql\bin\mysqld.exe'
$install = Join-Path $Xampp 'mysql\bin\mysql_install_db.exe'
$procs = @()
try {
    New-Item -ItemType Directory $work | Out-Null
    & $install --datadir="$work\data" --password= | Out-Null

    $db = Start-Process $mysqld -PassThru -WindowStyle Hidden -RedirectStandardError "$work\mysqld.err" `
        -ArgumentList '--no-defaults', "--datadir=$work\data", "--port=$DbPort", '--bind-address=127.0.0.1'
    $procs += $db
    $ready = $false
    for ($i = 0; $i -lt 40 -and -not $ready; $i++) {
        Start-Sleep -Milliseconds 500
        $ready = (Test-NetConnection 127.0.0.1 -Port $DbPort -WarningAction SilentlyContinue).TcpTestSucceeded
    }
    if (-not $ready) { throw 'MariaDB uji tidak mau menyala.' }

    $env:MOTOPART_DB_PORT = "$DbPort"
    $env:MOTOPART_DB_NAME = 'motopart_test'
    & $php "$backend\tool\setup.php" --reset
    if ($LASTEXITCODE -ne 0) { throw 'setup gagal' }

    $web = Start-Process $php -PassThru -WindowStyle Hidden -WorkingDirectory $backend `
        -ArgumentList '-S', "127.0.0.1:$HttpPort", 'index.php'
    $procs += $web
    Start-Sleep -Seconds 2

    & $php "$backend\tests\run_tests.php" "http://127.0.0.1:$HttpPort"
    $code = $LASTEXITCODE

    if ($E2E -and $code -eq 0) {
        # Muat ulang data contoh lalu jalankan tes aplikasi.
        & $php "$backend\tool\setup.php" --reset | Out-Null
        $env:MOTOPART_E2E_URL = "http://127.0.0.1:$HttpPort"
        Push-Location (Split-Path -Parent $backend)
        try { flutter test test/server_e2e_test.dart; $code = $LASTEXITCODE } finally { Pop-Location }
    }
}
finally {
    foreach ($p in $procs) { if ($p -and -not $p.HasExited) { Stop-Process -Id $p.Id -Force } }
    Start-Sleep -Seconds 1
    if (Test-Path $work) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
}
exit $code
