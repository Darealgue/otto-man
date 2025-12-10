# Model dosyasını daha kısa bir isimle kopyalama scripti
# Bu, path uzunluğu sorunlarını çözmek için kullanılabilir

$exportDir = "C:\Users\Günsu\Desktop\otto_exp"
$originalModel = Join-Path $exportDir "mistral-7b-instruct-v0.2.Q4_K_M.gguf"
$shortModel = Join-Path $exportDir "mistral.gguf"

Write-Host "Model path düzeltme scripti" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan
Write-Host ""

if (Test-Path $originalModel) {
    Write-Host "Orijinal model bulundu: $originalModel" -ForegroundColor Green
    Write-Host "Uzunluk: $($originalModel.Length) karakter" -ForegroundColor Yellow
    
    if (Test-Path $shortModel) {
        Write-Host "Kısa isimli model zaten var: $shortModel" -ForegroundColor Yellow
        $response = Read-Host "Üzerine yazmak ister misiniz? (E/H)"
        if ($response -ne "E" -and $response -ne "e") {
            Write-Host "İşlem iptal edildi." -ForegroundColor Red
            exit
        }
    }
    
    Write-Host "Kopyalama başlıyor..." -ForegroundColor Yellow
    Copy-Item $originalModel -Destination $shortModel -Force
    Write-Host "✅ Model kopyalandı: $shortModel" -ForegroundColor Green
    Write-Host "Yeni uzunluk: $($shortModel.Length) karakter" -ForegroundColor Green
    Write-Host ""
    Write-Host "NOT: LlamaService.cs dosyasında model dosya adını 'mistral.gguf' olarak değiştirmeniz gerekecek." -ForegroundColor Yellow
} else {
    Write-Host "❌ Orijinal model bulunamadı: $originalModel" -ForegroundColor Red
}

