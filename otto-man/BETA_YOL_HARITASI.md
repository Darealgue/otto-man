# 🎮 Otto-Man Beta Entegrasyon Yol Haritası

## 📋 Genel Amaç
Village, Dungeon ve Forest sahnelerini tek bir oynanabilir oyun olarak birleştirmek ve beta testi için hazırlamak.

---

## 🗺️ Fazlar ve Görevler

### **FAZ 1: Ana Menü ve Giriş Sistemi** ⚡ ÖNCELİK: YÜKSEK
**Süre Tahmini:** 1-2 gün

#### 1.1 Main Menu Sahnesi
- [ ] **Yeni Sahne:** `scenes/MainMenu.tscn`
- [ ] **Script:** `scenes/MainMenu.gd`
- [ ] **Özellikler:**
  - "Yeni Oyun" butonu → GameState'e "new_game" sinyali
  - "Oyunu Yükle" butonu → Save/Load menüsünü aç
  - "Ayarlar" butonu → Ayarlar menüsü (basit: ses seviyesi, pencere modu)
  - "Çıkış" butonu
  - Arka plan görseli/müzik (opsiyonel)
  - Keyboard/Controller navigasyonu

#### 1.2 Scene Manager (Autoload)
- [ ] **Yeni Autoload:** `autoload/SceneManager.gd`
- [ ] **Özellikler:**
  - Mevcut sahne takibi (`current_scene: String`)
  - Sahne geçiş fonksiyonları:
    - `change_to_village()`
    - `change_to_dungeon(mission_data: Dictionary)` 
    - `change_to_forest(mission_data: Dictionary)`
    - `return_to_village(from_scene: String)`
  - Transition efekti (fade in/out veya loading screen)
  - Sahne yükleme sırasında oyunu pause etme

#### 1.3 Giriş Bölümü / Hub
- [ ] **Köy içinde "Portal/Geçit" sistemi:**
  - Köy sahnesinde seyahat noktaları ekle
  - "Zindana Git" → SceneManager.change_to_dungeon()
  - "Ormana Git" → SceneManager.change_to_forest()
  - "Görev Merkezine Dön" → MissionCenter'a geçiş
- [ ] **Alternatif:** Köy UI'ında "Seyahat" butonu

---

### **FAZ 2: Save/Load Sistemi Genişletme** ⚡ ÖNCELİK: YÜKSEK
**Süre Tahmini:** 2-3 gün

#### 2.1 Save Game Manager
- [ ] **Yeni Autoload:** `autoload/SaveManager.gd`
- [ ] **Kaydedilecek Veriler:**
  - **Village State:**
    - Binalar (tür, pozisyon, seviye, işçiler)
    - Kaynaklar (wood, stone, food, water, metal, vs.)
    - Altın (GlobalPlayerData)
    - Zaman (TimeManager gün/saat)
    - Asker sayısı
  - **Mission State:**
    - Aktif görevler
    - Tamamlanan görevler
    - Görev zincirleri durumu
    - Cariyeler ve rolleri (zaten var)
  - **World State:**
    - Yerleşim ilişkileri (WorldManager)
    - Aktif olaylar
    - Ticaret anlaşmaları
  - **Player State:**
    - Oyuncu istatistikleri
    - Envanter
  - **Scene State:**
    - Son oynanan sahne
    - Sahne içi progress (dungeon/forest'te nerede)

#### 2.2 Save File Format
- [ ] **JSON formatı:** `user://otto-man-save/save_{slot_id}.json`
- [ ] **Çoklu kayıt slotları:** 3-5 slot (Save 1, Save 2, Save 3...)
- [ ] **Save metadata:**
  - Tarih/saat
  - Oyun süresi
  - Köy seviyesi
  - Thumbnail (opsiyonel)

#### 2.3 Load Game UI
- [ ] **Save slot listesi:** Her slot için metadata göster
- [ ] **Delete save:** Kayıt silme onayı
- [ ] **Auto-save:** Belirli aralıklarla otomatik kayıt (5 dakikada bir? günde bir?)

---

### **FAZ 3: Sahne Geçişleri ve Return Mekanizması** ⚡ ÖNCELİK: YÜKSEK
**Süre Tahmini:** 1-2 gün

#### 3.1 Village → Dungeon/Forest
- [ ] **MissionCenter entegrasyonu:**
  - Görev başlatıldığında → SceneManager.change_to_dungeon() veya change_to_forest()
  - Görev türüne göre sahne seçimi:
    - SAVAŞ/KEŞİF → Dungeon
    - Orman görevleri → Forest
    - TİCARET/DİPLOMASİ → Köy içinde kal (UI görevi)
- [ ] **Görev verisi aktarımı:**
  - Mission ID ve türü sahneye gönder
  - Dungeon/Forest'te görev hedefi göster (UI overlay)

#### 3.2 Dungeon/Forest → Village
- [ ] **Görev tamamlandığında:**
  - Ölüm → "Kayboldunuz" ekranı → Village'e dön
  - Başarı → "Görev Tamamlandı" ekranı → Ödüller göster → Village'e dön
- [ ] **Manuel dönüş:**
  - "Esc" menüsü → "Köye Dön" butonu (görevi iptal et, ceza varsa uygula)

#### 3.3 Scene Transition Effects
- [ ] **Loading screen:**
  - Basit "Yükleniyor..." ekranı
  - Progress bar (opsiyonel)
- [ ] **Fade in/out:** Ekran karartma/açılma efekti

---

### **FAZ 4: Oyun State Yönetimi** ⚡ ÖNCELİK: ORTA
**Süre Tahmini:** 1 gün

#### 4.1 GameState Manager
- [ ] **Yeni Autoload:** `autoload/GameState.gd`
- [ ] **State'ler:**
  - `MENU` - Main menu
  - `VILLAGE` - Köy sahnesi
  - `DUNGEON` - Zindan sahnesi (görev içinde)
  - `FOREST` - Orman sahnesi (görev içinde)
  - `LOADING` - Sahne yükleniyor
- [ ] **State değişimleri:**
  - State değiştiğinde sinyal yay
  - Pause/Unpause kontrolü

#### 4.2 Pause/Resume Sistemi
- [ ] **Esc menüsü:**
  - Oyun içindeyken Esc → Pause menu
  - "Devam Et", "Ayarlar", "Köye Dön", "Ana Menü"
- [ ] **Pause handling:** get_tree().paused ile yönet

---

### **FAZ 5: Beta Hazırlık ve Polisaj** ⚡ ÖNCELİK: ORTA
**Süre Tahmini:** 2-3 gün

#### 5.1 Giriş/Tutorial (Opsiyonel)
- [ ] **İlk açılış:**
  - "Hoş geldiniz" ekranı
  - Basit tutorial pop-up'ları (köy yönetimi, görev sistemi)
- [ ] **Tutorial skip:** "Tutorial'ı atla" seçeneği

#### 5.2 Hata Kontrolü ve Debug
- [ ] **Save/Load validation:**
  - Eksik/bozuk kayıt dosyası kontrolü
  - Geriye dönük uyumluluk
- [ ] **Scene transition hata yakalama:**
  - Sahne yüklenemezse → Hata mesajı + Village'e dön
- [ ] **Logging:** Önemli olayları konsola logla

#### 5.3 UI İyileştirmeleri
- [ ] **Loading göstergeleri:** Sahne yüklenirken kullanıcıyı bilgilendir
- [ ] **Hata mesajları:** Kullanıcı dostu hata ekranları
- [ ] **Save/Load feedback:** "Kaydediliyor..." / "Yükleniyor..." mesajları

#### 5.4 Test Senaryoları
- [ ] **New Game → Village → Dungeon → Return → Save → Load**
- [ ] **Mission başlat → Forest → Tamamla → Save**
- [ ] **Village'da bina inşa et → Save → Load → Kontrol et**
- [ ] **Çoklu save slot testi**
- [ ] **Pause/Resume testleri**

---

### **FAZ 6: Beta Paketleme (Opsiyonel)** ⚡ ÖNCELİK: DÜŞÜK
**Süre Tahmini:** 1 gün

#### 6.1 Build Ayarları
- [ ] **Export template:** Godot export settings
- [ ] **Build script:** Otomatik build scripti (opsiyonel)
- [ ] **Version numarası:** Beta v0.1.0 gibi

#### 6.2 Beta Notları
- [ ] **README_BETA.md:** Arkadaşlar için kısa kılavuz
- [ ] **Known issues listesi:** Bilinen hatalar listesi
- [ ] **Feedback form:** Geri bildirim toplama yöntemi (Google Form, Discord, vs.)

---

## 🔧 Teknik Detaylar

### **Dosya Yapısı (Yeni)**
```
otto-man/
├── scenes/
│   ├── MainMenu.tscn          # [YENİ]
│   └── MainMenu.gd            # [YENİ]
├── autoload/
│   ├── SceneManager.gd        # [YENİ]
│   ├── SaveManager.gd         # [YENİ]
│   └── GameState.gd            # [YENİ]
└── ui/
    └── LoadingScreen.tscn     # [YENİ] (Opsiyonel)
```

### **Autoload Sırası (project.godot)**
Önemli: SceneManager ve SaveManager'ı en üste ekle (diğer autoload'lar bunlara bağımlı olabilir)

### **Save Dosya Yapısı**
```json
{
  "version": "0.1.0",
  "save_date": "2024-01-15T10:30:00",
  "playtime_seconds": 3600,
  "scene": "village",
  "village": {
    "buildings": [...],
    "resources": {...},
    "gold": 1000,
    "soldiers": 5
  },
  "missions": {...},
  "world": {...},
  "player": {...}
}
```

---

## 📊 Öncelik Sıralaması

1. **FAZ 1** - Main Menu + Scene Manager (Olmasa beta çalışmaz)
2. **FAZ 2** - Save/Load (Beta test için kritik)
3. **FAZ 3** - Sahne geçişleri (Oyunun akışı için gerekli)
4. **FAZ 4** - GameState (Güzel, ama olmasa da çalışır)
5. **FAZ 5** - Polisaj (Beta için iyi olur)
6. **FAZ 6** - Paketleme (Opsiyonel)

---

## ⚠️ Dikkat Edilmesi Gerekenler

1. **Save/Load uyumluluğu:** Yeni özellikler eklerken eski save'ler çalışmalı (versioning kullan)
2. **Autoload bağımlılıkları:** SceneManager ve SaveManager'ı erken initialize et
3. **Memory leaks:** Sahne geçişlerinde eski sahneleri temizle (`queue_free()`)
4. **Input handling:** Sahne geçişi sırasında input'ları devre dışı bırak
5. **Async loading:** Büyük sahneler için `ResourceLoader.load_interactive()` kullan

---

## 🎯 Minimum Beta Hedefi (MVP)

**Beta'yı paylaşmak için minimum gereksinimler:**
- ✅ Main Menu (New Game, Load Game, Quit)
- ✅ Village → Dungeon geçişi (görev başlat)
- ✅ Dungeon → Village dönüşü (görev tamamla/iptal)
- ✅ Save/Load (en azından tek slot)
- ✅ Temel hata yakalama

**Güzel olur ama şart değil:**
- Çoklu save slotları
- Auto-save
- Loading screen animasyonları
- Tutorial
- Pause menüsü (Esc ile çıkış yeterli)

---

## 📝 Notlar

- Bu yol haritası beta testi için odaklanmıştır. Tam oyun için ek özellikler gerekebilir.
- Her fazı tamamladıktan sonra test edin ve arkadaşlarınızdan feedback alın.
- Save/Load formatını ileride değiştirebilirsiniz, ama versioning ile eski kayıtları yükleyebilmelisiniz.

