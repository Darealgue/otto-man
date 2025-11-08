# Hata Kontrolü ve Doğrulama Test Senaryoları

Bu doküman, son eklenen hata kontrolü ve doğrulama özelliklerini test etmek için adımları içerir.

## Test Öncesi Hazırlık

### Save Dosyalarının Konumu
Godot'da save dosyaları şu konumda bulunur:
- **Windows:** `%APPDATA%\Godot\app_userdata\otto-man\otto-man-save\`
- Tam yol: `C:\Users\[KULLANICI_ADI]\AppData\Roaming\Godot\app_userdata\otto-man\otto-man-save\`

Bu klasörde `save_1.json`, `save_2.json` gibi dosyalar olacak.

---

## Test Senaryoları

### 1. ErrorDialog Görünürlük Testi
**Amaç:** ErrorDialog'un düzgün göründüğünü doğrulamak

**Adımlar:**
1. Oyunu başlat
2. Ana menüden "Yeni Oyun" veya "Oyunu Yükle" seç
3. Oyun içinde ESC tuşuna bas (Pause Menu açılmalı)
4. "Kaydet" veya "Yükle" seç
5. **Beklenen:** Menüler düzgün açılmalı

**Not:** ErrorDialog şu an sadece hata durumlarında görünecek.

---

### 2. Boş Kayıt Yükleme Testi
**Amaç:** Boş bir kayıt slotundan yüklemeye çalışırken hata mesajı görmek

**Adımlar:**
1. Oyunu başlat
2. Ana menüden "Oyunu Yükle" seç
3. Boş bir slot seç (örn: Slot 1, eğer hiç kayıt yoksa)
4. **Beklenen:** 
   - "Boş Kayıt" başlıklı bir ErrorDialog görünmeli
   - "Bu kayıt slotu boş." mesajı görünmeli
   - "Tamam" butonuna basınca dialog kapanmalı

---

### 3. Bozuk Kayıt Dosyası Testi
**Amaç:** Bozuk bir kayıt dosyasını yüklemeye çalışırken doğrulama hatalarını görmek

**Adımlar:**
1. Save klasörüne git (yukarıdaki konum)
2. `save_1.json` dosyasını bir metin editörüyle aç
3. Dosyayı boz:
   - **Test 3a:** Dosyanın içeriğini tamamen sil, sadece `{}` bırak
   - **Test 3b:** JSON formatını boz: `{"version": "0.1.0", "save_date": "2024-01-01"` (kapanış parantezi yok)
   - **Test 3c:** Gerekli bir alanı sil: `version` veya `save_date` alanını kaldır
   - **Test 3d:** Bir bölümü yanlış tipte yap: `"village": "string"` yerine `"village": {}` olmalı
4. Dosyayı kaydet
5. Oyunu başlat
6. Ana menüden "Oyunu Yükle" seç
7. Slot 1'i seç
8. **Beklenen:**
   - **Test 3a:** "Kayıt Dosyası Hatalı" - "Kayıt dosyası doğrulanamadı." veya benzeri mesaj
   - **Test 3b:** "Kayıt Dosyası Hatalı" - "JSON formatı hatalı" mesajı
   - **Test 3c:** "Kayıt Dosyası Hatalı" - "Gerekli alan eksik: version" veya "save_date" mesajı
   - **Test 3d:** "Kayıt Dosyası Hatalı" - "'village' bölümü yanlış formatta" mesajı

---

### 4. Kayıt Listesinde Bozuk Dosya Gösterimi
**Amaç:** Yükleme menüsünde bozuk kayıtların "Hatalı - Yüklenemez" olarak gösterilmesi

**Adımlar:**
1. Test 3'teki gibi bir kayıt dosyasını boz
2. Oyunu başlat
3. Ana menüden "Oyunu Yükle" seç
4. **Beklenen:**
   - Bozuk slot "Slot 1: (Hatalı - Yüklenemez)" şeklinde görünmeli
   - Yükle butonu devre dışı (disabled) olmalı

---

### 5. Başarılı Kayıt/Yükleme Testi
**Amaç:** Normal kayıt/yükleme işlemlerinin çalıştığını doğrulamak

**Adımlar:**
1. Oyunu başlat
2. Yeni oyun başlat veya mevcut bir kaydı yükle
3. Oyun içinde ESC tuşuna bas
4. "Kaydet" seç
5. Boş bir slot seç (örn: Slot 2)
6. **Beklenen:**
   - Kayıt başarılı mesajı görünmeli (StatusLabel'da "Kayıt tamamlandı!" veya benzeri)
   - Hata dialogu görünmemeli
7. ESC'ye bas, "Yükle" seç
8. Az önce kaydettiğin slotu seç
9. **Beklenen:**
   - Oyun yüklenmeli, hata görünmemeli

---

### 6. Pause Menu'den Hata Yönetimi
**Amaç:** Pause menu'den kayıt/yükleme hatalarının düzgün gösterilmesi

**Adımlar:**
1. Oyunu başlat, bir sahneye gir (köy, zindan, orman)
2. ESC tuşuna bas (Pause Menu açılmalı)
3. "Kaydet" seç, bir slot seç
4. **Beklenen:** Kayıt başarılı mesajı veya hata dialogu (eğer hata varsa)
5. ESC'ye bas, "Yükle" seç
6. Bozuk bir slot seç (Test 3'teki gibi)
7. **Beklenen:** ErrorDialog görünmeli, "Yükleme Hatası" başlığı ile

---

### 7. SceneManager Hata Yönetimi
**Amaç:** Sahne yükleme hatalarında ErrorDialog ve köye dönüş

**Adımlar:**
Bu test için SceneManager'da bir sahne yolunu geçici olarak yanlış yapmak gerekir (geliştirme ortamında).

**Alternatif Test (Manuel):**
1. Oyunu başlat
2. Normal oyun akışında ilerle
3. **Beklenen:** Sahne geçişleri sorunsuz çalışmalı

**Not:** Gerçek sahne yükleme hatası test etmek için SceneManager.gd'de geçici olarak bir sahne yolunu yanlış yapabilirsin.

---

### 8. StatusLabel Görünürlük Testi
**Amaç:** LoadGameMenu ve SaveGameMenu'deki status mesajlarının göründüğünü doğrulamak

**Adımlar:**
1. Oyunu başlat
2. Ana menüden "Oyunu Yükle" seç
3. Bir slot seç (boş veya dolu)
4. **Beklenen:**
   - Slot seçildiğinde StatusLabel'da "Yükleniyor..." görünmeli
   - Yükleme tamamlandığında "Yükleme tamamlandı!" veya hata mesajı görünmeli
5. ESC'ye bas, "Kaydet" seç
6. Bir slot seç
7. **Beklenen:**
   - "Kaydediliyor..." mesajı görünmeli
   - Kayıt tamamlandığında "Kayıt tamamlandı!" görünmeli

---

## Hızlı Test Komutları (Dev Console)

Eğer dev console aktifse, şu komutları kullanabilirsin:

```
# Save dosyasını manuel olarak boz (test için)
# SaveManager'ı kullanarak test kayıt oluştur
```

---

## Beklenen Sonuçlar Özeti

✅ **Başarılı Senaryolar:**
- ErrorDialog görünür ve düzgün çalışır
- Bozuk kayıt dosyaları tespit edilir ve hata mesajı gösterilir
- Bozuk kayıtlar yükleme menüsünde "Hatalı - Yüklenemez" olarak gösterilir
- StatusLabel mesajları görünür
- Normal kayıt/yükleme işlemleri çalışır

❌ **Hata Durumları:**
- Bozuk dosya yüklenmeye çalışıldığında ErrorDialog görünmeli
- Hata mesajları Türkçe ve anlaşılır olmalı
- Oyun çökmeden hata yönetimi yapılmalı

---

## Test Sonrası

Testleri tamamladıktan sonra:
1. Bozuk save dosyalarını düzelt veya sil
2. Normal bir kayıt oluştur ve oyunun düzgün çalıştığını doğrula
3. Tüm hata senaryolarında ErrorDialog'un göründüğünü ve mesajların doğru olduğunu kontrol et

---

## Notlar

- Save dosyalarını bozmadan önce yedek al
- Test sırasında console çıktılarını kontrol et (hata mesajları orada da görünecek)
- ErrorDialog'un `layer = 1000` olduğunu unutma (en üstte görünmeli)

