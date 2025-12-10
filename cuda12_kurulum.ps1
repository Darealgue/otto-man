# CUDA 12.9 Kurulum Scripti
# Bu script CUDA 12.9'un kurulumunu ve doğrulamasını yapar

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CUDA 12.9 Kurulum ve Doğrulama Scripti" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Mevcut CUDA sürümlerini kontrol et
Write-Host "[1/5] Mevcut CUDA kurulumlarını kontrol ediliyor..." -ForegroundColor Yellow
$cudaVersions = Get-ChildItem "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA" -ErrorAction SilentlyContinue
if ($cudaVersions) {
    Write-Host "Mevcut CUDA sürümleri:" -ForegroundColor Green
    $cudaVersions | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Green }
} else {
    Write-Host "CUDA kurulumu bulunamadı." -ForegroundColor Red
}

# 2. CUDA 12.9'un yüklü olup olmadığını kontrol et
Write-Host ""
Write-Host "[2/5] CUDA 12.9 kurulumu kontrol ediliyor..." -ForegroundColor Yellow
$cuda12Path = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.9"
if (Test-Path $cuda12Path) {
    Write-Host "✅ CUDA 12.9 zaten yüklü: $cuda12Path" -ForegroundColor Green
    
    # nvcc versiyonunu kontrol et
    $nvccPath = Join-Path $cuda12Path "bin\nvcc.exe"
    if (Test-Path $nvccPath) {
        $nvccVersion = & $nvccPath --version 2>&1 | Select-String "release"
        Write-Host "   $nvccVersion" -ForegroundColor Green
    }
} else {
    Write-Host "❌ CUDA 12.9 yüklü değil." -ForegroundColor Red
    Write-Host ""
    Write-Host "Kurulum için:" -ForegroundColor Yellow
    Write-Host "1. https://developer.nvidia.com/cuda-12-9-0-download-archive adresinden CUDA 12.9'u indirin" -ForegroundColor White
    Write-Host "2. İndirilen .exe dosyasını çalıştırın" -ForegroundColor White
    Write-Host "3. Kurulum sırasında 'CUDA Development Tools' ve 'CUDA Runtime' seçeneklerini işaretleyin" -ForegroundColor White
    Write-Host "4. Kurulum tamamlandıktan sonra bu scripti tekrar çalıştırın" -ForegroundColor White
    Write-Host ""
    
    # İndirme linkini aç
    $response = Read-Host "İndirme sayfasını tarayıcıda açmak ister misiniz? (E/H)"
    if ($response -eq "E" -or $response -eq "e") {
        Start-Process "https://developer.nvidia.com/cuda-12-9-0-download-archive"
    }
    
    exit
}

# 3. PATH kontrolü
Write-Host ""
Write-Host "[3/5] PATH environment variable kontrol ediliyor..." -ForegroundColor Yellow
$cuda12BinPath = Join-Path $cuda12Path "bin"
$pathEntries = $env:PATH -split ';'
$cuda12InPath = $pathEntries | Where-Object { $_ -like "*CUDA*v12*" }

if ($cuda12InPath) {
    Write-Host "✅ CUDA 12.9 PATH'te:" -ForegroundColor Green
    $cuda12InPath | ForEach-Object { Write-Host "   $_" -ForegroundColor Green }
} else {
    Write-Host "⚠️ CUDA 12.9 PATH'te değil. Ekleniyor..." -ForegroundColor Yellow
    
    # Geçici olarak PATH'e ekle
    $env:PATH = "$cuda12BinPath;$env:PATH"
    Write-Host "✅ Geçici olarak PATH'e eklendi (bu session için)" -ForegroundColor Green
    Write-Host "   Kalıcı olması için sistem yeniden başlatılmalı veya manuel eklenmeli" -ForegroundColor Yellow
}

# 4. Environment Variables kontrolü
Write-Host ""
Write-Host "[4/5] Environment Variables kontrol ediliyor..." -ForegroundColor Yellow
$cudaPathV12 = [System.Environment]::GetEnvironmentVariable("CUDA_PATH_V12_9", "Machine")
if ($cudaPathV12) {
    Write-Host "✅ CUDA_PATH_V12_9: $cudaPathV12" -ForegroundColor Green
} else {
    Write-Host "⚠️ CUDA_PATH_V12_9 tanımlı değil" -ForegroundColor Yellow
}

$cudaPath = [System.Environment]::GetEnvironmentVariable("CUDA_PATH", "Machine")
if ($cudaPath) {
    Write-Host "   CUDA_PATH: $cudaPath" -ForegroundColor Cyan
}

# 5. Native DLL'lerin varlığını kontrol et
Write-Host ""
Write-Host "[5/5] CUDA Runtime DLL'leri kontrol ediliyor..." -ForegroundColor Yellow
$cudaBinPath = Join-Path $cuda12Path "bin"
$requiredDlls = @("cudart64_12.dll", "cublas64_12.dll", "cufft64_12.dll")

$allFound = $true
foreach ($dll in $requiredDlls) {
    $dllPath = Join-Path $cudaBinPath $dll
    if (Test-Path $dllPath) {
        Write-Host "✅ $dll bulundu" -ForegroundColor Green
    } else {
        Write-Host "❌ $dll bulunamadı: $dllPath" -ForegroundColor Red
        $allFound = $false
    }
}

# Özet
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Kurulum Özeti" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($allFound -and (Test-Path $cuda12Path)) {
    Write-Host "✅ CUDA 12.9 başarıyla kurulmuş ve yapılandırılmış!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Sonraki adımlar:" -ForegroundColor Yellow
    Write-Host "1. Godot projesini yeniden build edin" -ForegroundColor White
    Write-Host "2. Projeyi export edin" -ForegroundColor White
    Write-Host "3. Export klasöründe native DLL'lerin kopyalandığını kontrol edin" -ForegroundColor White
} else {
    Write-Host "⚠️ Bazı sorunlar tespit edildi. Yukarıdaki uyarıları kontrol edin." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "CUDA 12.9 nvcc test:" -ForegroundColor Cyan
$nvccPath = Join-Path $cuda12Path "bin\nvcc.exe"
if (Test-Path $nvccPath) {
    try {
        $nvccOutput = & $nvccPath --version 2>&1
        Write-Host $nvccOutput -ForegroundColor Green
    } catch {
        Write-Host "nvcc çalıştırılamadı: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Script tamamlandı. Herhangi bir tuşa basın..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

