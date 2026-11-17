<#
  Membangun versi web MotoPart dan membuat berkas zip siap unggah.

  Pemakaian (dari folder proyek):
    powershell -ExecutionPolicy Bypass -File tool/build_web.ps1
    powershell -ExecutionPolicy Bypass -File tool/build_web.ps1 -BaseHref /motopart/

  -BaseHref   Lokasi situs. "/" untuk domain sendiri (Netlify, Firebase), atau
              "/nama-repo/" untuk GitHub Pages proyek.
  -PaymentApi Alamat server pembayaran (HTTPS). Kosongkan agar hanya COD
              yang tersedia di web.

  Hasil: folder build/web dan berkas build/motopart-web.zip.
#>
param(
  [string]$BaseHref = "/",
  [string]$PaymentApi = ""
)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$flutterArgs = @("build", "web", "--release", "--base-href", $BaseHref)
if ($PaymentApi -ne "") { $flutterArgs += "--dart-define=PAYMENT_API_URL=$PaymentApi" }

Write-Host "flutter $($flutterArgs -join ' ')"
& flutter @flutterArgs
if ($LASTEXITCODE -ne 0) { throw "Build web gagal." }

$zip = "build/motopart-web.zip"
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path "build/web/*" -DestinationPath $zip
$size = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Host ""
Write-Host "Selesai. Folder: build/web  |  Zip: $zip ($size MB)"
