# Model dosyasını Türkçe karakter içermeyen basit bir yere taşıma scripti
# Bu, LLamaSharp native DLL'inin path encoding sorunlarını çözer

$sourceDir = "C:\Users\Günsu\Desktop\otto_exp"
$targetDir = "C:\otto_exp"
$modelFile = "mistral-7b-instruct-v0.2.Q4_K_M.gguf"

Write-Host "Model Dosyası Taşıma Scripti" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host ""

# Hedef klasörü oluştur
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Write-Host "✅ Hedef klasör oluşturuldu: $targetDir" -ForegroundColor Green
} else {
    Write-Host "✅ Hedef klasör zaten var: $targetDir" -ForegroundColor Green
}

# Kaynak ve hedef path'leri oluştur
$sourcePath = Join-Path $sourceDir $modelFile
$targetPath = Join-Path $targetDir $modelFile

Write-Host ""
Write-Host "Kaynak: $sourcePath" -ForegroundColor Yellow
Write-Host "Hedef:  $targetPath" -ForegroundColor Yellow
Write-Host ""

# Dosya var mı kontrol et
if (-not (Test-Path $sourcePath)) {
    Write-Host "❌ Kaynak dosya bulunamadı: $sourcePath" -ForegroundColor Red
    exit 1
}

# Hedefte zaten var mı?
if (Test-Path $targetPath) {
    Write-Host "⚠️ Hedef dosya zaten var!" -ForegroundColor Yellow
    $response = Read-Host "Üzerine yazmak ister misiniz? (E/H)"
    if ($response -ne "E" -and $response -ne "e") {
        Write-Host "İşlem iptal edildi." -ForegroundColor Red
        exit 0
    }
    Remove-Item $targetPath -Force
}

# Dosyayı kopyala (taşıma yerine kopyalama - güvenli)
Write-Host "Dosya kopyalanıyor (4GB, bu biraz zaman alabilir)..." -ForegroundColor Yellow
$startTime = Get-Date
Copy-Item $sourcePath -Destination $targetPath -Force
$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds

Write-Host ""
Write-Host "✅ Dosya başarıyla kopyalandı!" -ForegroundColor Green
Write-Host "   Süre: $([math]::Round($duration, 2)) saniye" -ForegroundColor Cyan
Write-Host ""

# Dosya boyutunu kontrol et
$sourceSize = (Get-Item $sourcePath).Length
$targetSize = (Get-Item $targetPath).Length

if ($sourceSize -eq $targetSize) {
    Write-Host "✅ Dosya boyutları eşleşiyor: $([math]::Round($sourceSize / 1GB, 2)) GB" -ForegroundColor Green
} else {
    Write-Host "⚠️ Dosya boyutları eşleşmiyor!" -ForegroundColor Red
    Write-Host "   Kaynak: $([math]::Round($sourceSize / 1GB, 2)) GB" -ForegroundColor Yellow
    Write-Host "   Hedef:  $([math]::Round($targetSize / 1GB, 2)) GB" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Yeni path: $targetPath" -ForegroundColor Cyan
Write-Host "Path uzunluğu: $($targetPath.Length) karakter" -ForegroundColor Cyan
Write-Host "Türkçe karakter: Hayır ✅" -ForegroundColor Green
Write-Host ""
Write-Host "NOT: Export path'ini de güncellemeniz gerekebilir:" -ForegroundColor Yellow
Write-Host "     Export path: $targetDir" -ForegroundColor White

