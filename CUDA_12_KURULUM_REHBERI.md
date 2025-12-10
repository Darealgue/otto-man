# CUDA 12 Kurulum Rehberi

## Durum Analizi
- ✅ NVIDIA GPU: RTX 3060 (yüklü)
- ✅ NVIDIA Driver: 581.80 (yüklü)
- ✅ CUDA 13.1: Yüklü
- ❌ CUDA 12: Yüklü değil (LLamaSharp.Backend.Cuda12 için gerekli)
- ✅ Visual C++ Redistributable: Yüklü

## Adım 1: CUDA 12.9 İndirme

1. Tarayıcınızda şu adresi açın:
   ```
   https://developer.nvidia.com/cuda-12-9-0-download-archive
   ```

2. İndirme seçenekleri:
   - **Operating System**: Windows
   - **Architecture**: x86_64
   - **Version**: 12.9.0
   - **Installer Type**: exe (local)

3. "Download" butonuna tıklayın (yaklaşık 3GB)

## Adım 2: CUDA 12.9 Kurulumu

Kurulum dosyasını indirdikten sonra, PowerShell'de şu komutları çalıştırın:

```powershell
# İndirilen dosyanın yolunu belirtin (örnek)
$cudaInstaller = "C:\Users\Günsu\Downloads\cuda_12.9.0_562.19_windows.exe"

# Kurulumu başlat (Express kurulum - tüm bileşenler)
Start-Process -FilePath $cudaInstaller -ArgumentList "-s" -Wait -NoNewWindow

# VEYA manuel kurulum için:
Start-Process -FilePath $cudaInstaller
```

**Kurulum sırasında dikkat edilecekler:**
- ✅ "CUDA Development Tools" seçili olmalı
- ✅ "CUDA Runtime" seçili olmalı
- ✅ "CUDA Samples" (opsiyonel, test için)
- ⚠️ "Driver" bileşenini atlayabilirsiniz (zaten yeni driver yüklü)

## Adım 3: Kurulum Doğrulama

Kurulum tamamlandıktan sonra PowerShell'i **YENİDEN BAŞLATIN** ve şu komutları çalıştırın:

```powershell
# CUDA 12'nin yüklü olup olmadığını kontrol et
Test-Path "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.9"

# CUDA 12'nin PATH'te olup olmadığını kontrol et
$env:PATH -split ';' | Select-String -Pattern 'CUDA.*v12'

# CUDA 12 compiler'ını kontrol et
& "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.9\bin\nvcc.exe" --version
```

## Adım 4: Environment Variables Kontrolü

CUDA 12 kurulumundan sonra şu environment variable'lar otomatik eklenmeli:

```powershell
# Kontrol et
$env:CUDA_PATH_V12_9
$env:CUDA_PATH
```

Eğer `CUDA_PATH` hala v13.1'i gösteriyorsa, manuel olarak ekleyin:

```powershell
# Sistem environment variable'ına ekle (Admin gerektirir)
[System.Environment]::SetEnvironmentVariable("CUDA_PATH_V12_9", "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.9", "Machine")
```

## Adım 5: LLamaSharp Test

CUDA 12 kurulumundan sonra:

1. Godot projesini yeniden build edin
2. Export edin
3. Export klasöründe native DLL'lerin kopyalandığını kontrol edin:
   ```powershell
   Get-ChildItem "C:\Users\Günsu\Desktop\otto_exp" -Filter "*.dll" | Select-Object Name
   ```

## Sorun Giderme

### CUDA 12 kurulumu başarısız olursa:
1. Mevcut CUDA 13.1'i kaldırmayın (birlikte çalışabilirler)
2. Antivirus'ü geçici olarak kapatın
3. Administrator olarak çalıştırın

### PATH sorunları:
```powershell
# PATH'e manuel ekleme (geçici)
$env:PATH += ";C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.9\bin"
```

### Alternatif: CUDA 13 Backend Kullanma
Eğer CUDA 12 kurulumu sorun çıkarırsa, projeyi CUDA 13 backend'e geçirebilirsiniz:
- `LLamaSharp.Backend.Cuda12` yerine `LLamaSharp.Backend.Cuda13` kullanın (eğer mevcutsa)
- Veya en son LLamaSharp sürümünü kontrol edin

