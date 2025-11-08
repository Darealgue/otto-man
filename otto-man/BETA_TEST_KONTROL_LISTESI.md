# 🧪 Beta Test Kontrol Listesi

Bu doküman, beta testi öncesi tüm kritik özelliklerin test edilmesi için adım adım kontrol listesidir.

---

## ✅ Genel Kontroller

### Başlangıç
- [ ] Oyun başlatılıyor (MainMenu görünüyor)
- [ ] MainMenu'da tüm butonlar görünüyor ve çalışıyor
- [ ] "Yeni Oyun" butonu çalışıyor
- [ ] "Oyunu Yükle" butonu çalışıyor
- [ ] "Ayarlar" butonu çalışıyor (veya placeholder mesajı gösteriyor)
- [ ] "Çıkış" butonu çalışıyor

---

## 🎮 Senaryo 1: Yeni Oyun → Village → Save → Load

### Adımlar:
1. [ ] MainMenu'dan "Yeni Oyun" seç
2. [ ] VillageScene yükleniyor
3. [ ] Oyun içinde ESC tuşuna bas (PauseMenu açılmalı)
4. [ ] PauseMenu'da "Kaydet" seç
5. [ ] Bir slot seç (örn: Slot 1)
6. [ ] "Kayıt tamamlandı!" mesajı görünüyor
7. [ ] ESC'ye bas, "Ana Menü" seç
8. [ ] MainMenu'da "Oyunu Yükle" seç
9. [ ] Slot 1'de kayıt görünüyor (tarih, sahne, süre bilgisi var)
10. [ ] Slot 1'i seç ve yükle
11. [ ] VillageScene'e geri dönülüyor
12. [ ] Kayıt edilen durum yükleniyor (pozisyon, kaynaklar, vb.)

**Beklenen Sonuç:** ✅ Kayıt ve yükleme sorunsuz çalışıyor

---

## 🎮 Senaryo 2: Village → Dungeon → Return → Save

### Adımlar:
1. [ ] Village'da bir görev başlat (MissionCenter'dan)
2. [ ] Görev türüne göre Dungeon veya Forest'a geçiş yapılıyor
3. [ ] Dungeon/Forest sahnesi yükleniyor
4. [ ] Oyun içinde ESC tuşuna bas (PauseMenu açılmalı)
5. [ ] PauseMenu'da "Köye Dön" seç (veya portal ile dön)
6. [ ] VillageScene'e geri dönülüyor
7. [ ] ESC → "Kaydet" → Bir slot seç
8. [ ] Kayıt başarılı

**Beklenen Sonuç:** ✅ Sahne geçişleri ve kayıt çalışıyor

---

## 🎮 Senaryo 3: Village'da Bina İnşa Et → Save → Load → Kontrol

### Adımlar:
1. [ ] Village'da bir bina inşa et (örn: Ahır)
2. [ ] Bina görünüyor ve çalışıyor
3. [ ] ESC → "Kaydet" → Slot 2 seç
4. [ ] ESC → "Ana Menü"
5. [ ] "Oyunu Yükle" → Slot 2 seç
6. [ ] VillageScene'e dönülüyor
7. [ ] İnşa edilen bina hala orada ve çalışıyor

**Beklenen Sonuç:** ✅ Bina durumu kaydediliyor ve yükleniyor

---

## 🎮 Senaryo 4: Çoklu Save Slot Testi

### Adımlar:
1. [ ] Village'da oyna, Slot 1'e kaydet
2. [ ] Biraz daha oyna (kaynak topla, bina inşa et)
3. [ ] Slot 2'ye kaydet
4. [ ] Ana Menü → "Oyunu Yükle"
5. [ ] Slot 1 ve Slot 2'nin ikisi de görünüyor
6. [ ] Slot 1'i yükle → İlk kayıt yükleniyor
7. [ ] Ana Menü → Slot 2'yi yükle → İkinci kayıt yükleniyor
8. [ ] Her iki kayıt da doğru durumu gösteriyor

**Beklenen Sonuç:** ✅ Çoklu slot sistemi çalışıyor

---

## 🎮 Senaryo 5: Pause/Resume Testleri

### Adımlar:
1. [ ] Village'da oyna
2. [ ] ESC tuşuna bas → PauseMenu açılıyor
3. [ ] Oyun durdu (hareket yok, animasyonlar durdu)
4. [ ] ESC tekrar → PauseMenu kapanıyor, oyun devam ediyor
5. [ ] Dungeon/Forest'a geç
6. [ ] ESC → PauseMenu açılıyor
7. [ ] "Devam Et" butonu → Oyun devam ediyor
8. [ ] ESC → "Köye Dön" → Village'e dönülüyor

**Beklenen Sonuç:** ✅ Pause/Resume tüm sahnelerde çalışıyor

---

## 🎮 Senaryo 6: Hata Yönetimi Testleri

### 6.1 Boş Kayıt Yükleme
1. [ ] Ana Menü → "Oyunu Yükle"
2. [ ] Boş bir slot seç
3. [ ] "Boş Kayıt" ErrorDialog görünüyor
4. [ ] "Tamam" butonuna bas → Dialog kapanıyor

### 6.2 Bozuk Kayıt Dosyası
1. [ ] Save klasörüne git: `%APPDATA%\Godot\app_userdata\otto-man\otto-man-save\`
2. [ ] `save_1.json` dosyasını aç ve içeriği boz (örn: `{}` bırak)
3. [ ] Oyunu başlat → "Oyunu Yükle"
4. [ ] Slot 1 "Hatalı - Yüklenemez" olarak görünüyor
5. [ ] Slot 1'i seçmeye çalış → ErrorDialog görünüyor
6. [ ] Hata mesajı anlaşılır ve Türkçe

**Beklenen Sonuç:** ✅ Hata yönetimi çalışıyor, kullanıcı dostu mesajlar

---

## 🎮 Senaryo 7: Sahne Geçişleri ve UI Görünürlüğü

### Adımlar:
1. [ ] Village'da → HealthDisplay ve StaminaBar görünmüyor (doğru)
2. [ ] Dungeon'a geç → HealthDisplay ve StaminaBar görünüyor
3. [ ] DungeonGoldDisplay görünüyor (altın varsa)
4. [ ] Forest'a geç → UI elementleri görünüyor
5. [ ] Village'e dön → UI elementleri gizleniyor

**Beklenen Sonuç:** ✅ UI görünürlüğü sahneye göre doğru çalışıyor

---

## 🎮 Senaryo 8: GameState Entegrasyonu

### Console Log Kontrolü:
1. [ ] Oyun başlatıldığında: `[GameState] Initialized with state: MENU` veya `VILLAGE`
2. [ ] Sahne değiştiğinde: `[GameState] State changed: X -> Y`
3. [ ] Pause yapıldığında: `[GameState] Game paused`
4. [ ] Resume yapıldığında: `[GameState] Game resumed`

**Beklenen Sonuç:** ✅ GameState logları doğru çalışıyor

---

## 🎮 Senaryo 9: Loading Screen Testi

### Adımlar:
1. [ ] Village'dan Dungeon'a geç
2. [ ] Loading screen görünüyor ("Yükleniyor... Dungeon" gibi)
3. [ ] Loading screen fade out yapıyor
4. [ ] Dungeon sahnesi yükleniyor
5. [ ] Loading screen kayboluyor

**Beklenen Sonuç:** ✅ Loading screen düzgün çalışıyor

---

## 🎮 Senaryo 10: Mission System Entegrasyonu

### Adımlar:
1. [ ] Village'da MissionCenter'a git
2. [ ] Bir görev başlat (örn: Savaş görevi)
3. [ ] Görev türüne göre doğru sahneye geçiş yapılıyor
4. [ ] Görev tamamlandığında (veya iptal edildiğinde) Village'e dönülüyor
5. [ ] Görev durumu kaydediliyor

**Beklenen Sonuç:** ✅ Mission sistemi sahne geçişleriyle entegre çalışıyor

---

## 🐛 Bilinen Sorunlar (Test Sırasında Bulunursa)

### Test sırasında bulunan sorunları buraya ekle:
- [ ] Sorun 1: ...
- [ ] Sorun 2: ...
- [ ] Sorun 3: ...

---

## ✅ Beta Hazırlık Kontrolü

### Minimum Beta Gereksinimleri:
- [x] Main Menu (New Game, Load Game, Quit)
- [x] Village → Dungeon geçişi
- [x] Dungeon → Village dönüşü
- [x] Save/Load (çoklu slot)
- [x] Temel hata yakalama
- [x] Pause/Resume sistemi
- [x] GameState yönetimi

### Ekstra Özellikler (Güzel ama şart değil):
- [ ] Auto-save
- [ ] Tutorial
- [ ] Loading screen animasyonları

---

## 📝 Test Notları

**Test Tarihi:** _______________

**Test Eden:** _______________

**Oyun Versiyonu:** Beta v0.1.0

**Test Ortamı:**
- İşletim Sistemi: _______________
- Godot Versiyonu: _______________
- Donanım: _______________

**Genel Değerlendirme:**
- [ ] ✅ Beta için hazır
- [ ] ⚠️ Küçük sorunlar var ama test edilebilir
- [ ] ❌ Kritik sorunlar var, beta ertelenmeli

**Notlar:**
_________________________________________________
_________________________________________________
_________________________________________________

---

## 🎯 Sonuç

Tüm senaryoları test ettikten sonra:
1. ✅ işaretlenen maddeler: Çalışıyor
2. ❌ işaretlenen maddeler: Sorun var, düzeltilmeli
3. ⚠️ işaretlenen maddeler: Çalışıyor ama iyileştirilebilir

**Beta Paylaşım Kararı:** _______________

