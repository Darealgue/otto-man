# ⚙️ Ayarlar Menüsü Planı

## 📋 Genel Yaklaşım
- Basit ve kullanıcı dostu
- Pause menüden erişilebilir
- Ayarlar kaydedilmeli (ConfigFile veya JSON)
- Klavye ve gamepad ile navigasyon

## 🎯 Önerilen Ayarlar Kategorileri

### 1. 🎵 Ses Ayarları (Audio Settings)
**Basit slider'lar ile:**
- **Master Volume** (Ana Ses Seviyesi)
  - 0-100% slider
  - Varsayılan: 100%
  
- **Müzik Volume** (Müzik Seviyesi)
  - 0-100% slider
  - Varsayılan: 80%
  
- **SFX Volume** (Efekt Sesleri)
  - 0-100% slider
  - Varsayılan: 100%

**UI:**
- Her slider için label + HSlider
- Değer gösterimi (örn: "80%")
- Test butonu (SFX için)

---

### 2. 🖥️ Görüntü Ayarları (Video Settings)
**Basit seçenekler:**
- **Fullscreen** (Tam Ekran)
  - CheckBox (Açık/Kapalı)
  - Varsayılan: Kapalı (Windowed)
  
- **VSync** (Dikey Senkronizasyon)
  - CheckBox (Açık/Kapalı)
  - Varsayılan: Açık
  
- **Çözünürlük** (Resolution) - Opsiyonel
  - OptionButton (1280x720, 1920x1080, vb.)
  - Varsayılan: Mevcut çözünürlük

**UI:**
- CheckBox'lar
- OptionButton (çözünürlük için)

---

### 3. 🎮 Kontrol Ayarları (Controls) - Basit Versiyon
**Preset seçimi (karmaşık tuş ataması yerine):**
- **Input Preset**
  - OptionButton:
    - "Klavye + Mouse"
    - "Gamepad"
    - "Otomatik Algıla"
  - Varsayılan: "Otomatik Algıla"

**Not:** Detaylı tuş ataması daha sonra eklenebilir. Şimdilik preset yeterli.

---

### 4. 🎮 Oyun Ayarları (Game Settings)
**Basit toggle'lar:**
- **Hasar Sayıları Göster** (Show Damage Numbers)
  - CheckBox
  - Varsayılan: Açık
  
- **FPS Göster** (Show FPS) - Debug için
  - CheckBox
  - Varsayılan: Kapalı
  
- **Kamera Titreşimi** (Camera Shake)
  - CheckBox
  - Varsayılan: Açık

**UI:**
- CheckBox'lar

---

## 📐 UI Yapısı (Mouse Olmadan Kullanım İçin)

### SettingsMenu.tscn
```
SettingsMenu (Control)
├── Background (ColorRect - semi-transparent)
├── Panel (Panel - centered)
│   ├── Title (Label - "Ayarlar")
│   ├── TabContainer (TabContainer) - L1/R1 ile tab değiştirme
│   │   ├── Ses (Tab)
│   │   │   ├── MasterVolumeContainer (VBoxContainer)
│   │   │   │   ├── Label ("Ana Ses: 80%")
│   │   │   │   └── HSlider (focusable, Left/Right ile değiştir)
│   │   │   ├── MusicVolumeContainer
│   │   │   └── SFXVolumeContainer
│   │   ├── Görüntü (Tab)
│   │   │   ├── FullscreenCheckBox (focusable)
│   │   │   ├── VSyncCheckBox (focusable)
│   │   │   └── ResolutionOptionButton (focusable, Left/Right ile seçim)
│   │   ├── Kontroller (Tab)
│   │   │   └── InputPresetOptionButton (focusable, Left/Right ile seçim)
│   │   └── Oyun (Tab)
│   │       ├── ShowDamageCheckBox (focusable)
│   │       ├── ShowFPSCheckBox (focusable)
│   │       └── CameraShakeCheckBox (focusable)
│   ├── ButtonContainer (HBoxContainer)
│   │   ├── ApplyButton ("Uygula") - focusable
│   │   ├── ResetButton ("Sıfırla") - focusable
│   │   └── BackButton ("Geri") - focusable
```

### ⚠️ Mouse Olmadan Kullanım Gereksinimleri

**Tüm kontroller focusable olmalı:**
- Slider'lar: `focus_mode = FOCUS_ALL`
- CheckBox'lar: `focus_mode = FOCUS_ALL`
- OptionButton'lar: `focus_mode = FOCUS_ALL`
- Button'lar: `focus_mode = FOCUS_ALL`

**Navigasyon:**
- Tab/Shift+Tab: Önceki/Sonraki kontrol
- Up/Down: Önceki/Sonraki kontrol (VBoxContainer içinde)
- Left/Right: Slider değeri değiştir, OptionButton seçenek değiştir
- Enter/Space: CheckBox toggle, Button bas
- ESC/B: Geri dön
- L1/R1: Tab değiştir (TabContainer)

---

## 💾 Veri Yönetimi

### SettingsManager (Autoload) - Opsiyonel
Veya direkt SettingsMenu içinde ConfigFile kullan:

```gdscript
# Ayarları kaydet
func save_settings():
    var config = ConfigFile.new()
    config.set_value("audio", "master_volume", master_volume)
    config.set_value("audio", "music_volume", music_volume)
    config.set_value("audio", "sfx_volume", sfx_volume)
    config.set_value("video", "fullscreen", fullscreen_enabled)
    config.set_value("video", "vsync", vsync_enabled)
    config.set_value("game", "show_damage", show_damage_numbers)
    # ... vb.
    config.save("user://settings.cfg")

# Ayarları yükle
func load_settings():
    var config = ConfigFile.new()
    var err = config.load("user://settings.cfg")
    if err == OK:
        # Ayarları yükle
        # ...
```

---

## 🎨 UI/UX Notları (Mouse Olmadan)

### 🎮 Klavye Navigasyonu
1. **Tab Navigasyonu:**
   - `Tab`: Sonraki kontrol
   - `Shift+Tab`: Önceki kontrol
   - `Up/Down`: Önceki/Sonraki kontrol (VBoxContainer içinde)

2. **Kontrol Etkileşimi:**
   - **Slider'lar:**
     - `Left Arrow`: Değeri azalt (-5 veya -10)
     - `Right Arrow`: Değeri artır (+5 veya +10)
     - `A/D` tuşları: Alternatif (Left/Right ile aynı)
   - **CheckBox'lar:**
     - `Enter` veya `Space`: Toggle (Açık/Kapalı)
   - **OptionButton'lar:**
     - `Left Arrow`: Önceki seçenek
     - `Right Arrow`: Sonraki seçenek
     - `A/D` tuşları: Alternatif
   - **Button'lar:**
     - `Enter` veya `Space`: Butona bas

3. **Tab Değiştirme:**
   - `Q/E` tuşları: Önceki/Sonraki tab (L1/R1 alternatifi)

4. **Geri Dönüş:**
   - `ESC`: Ayarlar menüsünü kapat, pause menüye dön
   - `B` tuşu (gamepad): Ayarlar menüsünü kapat
   - "Geri" butonu: Focusable, Enter/Space ile basılabilir

### 🎮 Gamepad Navigasyonu
1. **D-Pad:**
   - `Up/Down`: Önceki/Sonraki kontrol
   - `Left/Right`: Slider değeri değiştir, OptionButton seçenek değiştir

2. **Butonlar:**
   - `A Button`: CheckBox toggle, Button bas, OptionButton aç
   - `B Button`: Geri dön
   - `L1/R1`: Tab değiştir

3. **Tab Değiştirme:**
   - `L1`: Önceki tab
   - `R1`: Sonraki tab

### 🎯 Focus Yönetimi
1. **Açılışta:**
   - İlk tab'ın ilk kontrolüne focus ver
   - Veya "Geri" butonuna focus ver (daha güvenli)

2. **Tab Değişiminde:**
   - Yeni tab'ın ilk kontrolüne focus ver

3. **Görsel Feedback:**
   - Focused kontrol için highlight (theme override)
   - Slider'lar için değer gösterimi (Label güncelle)
   - CheckBox'lar için açık/kapalı durumu görünür

4. **Input Handling:**
   - `_input()` veya `_unhandled_input()` ile özel kontroller
   - InputManager kullan (tutarlılık için)

### 📋 Görsel Gereksinimler
1. **Focus Indicator:**
   - Focused kontrol için border veya background rengi
   - PauseMenu ile aynı stil

2. **Değer Gösterimi:**
   - Slider'lar için: "Ana Ses: 80%" formatında Label
   - OptionButton'lar için: Seçili seçenek görünür

3. **Tab Göstergesi:**
   - Hangi tab'da olduğunu göster (TabContainer default)

4. **Yardımcı Metin:**
   - Alt kısımda navigasyon ipuçları (opsiyonel):
     - "[←/→] Değer Değiştir | [Tab] Sonraki | [ESC] Geri"

---

## 📝 İmplementasyon Sırası (Mouse Olmadan)

### Faz 1: Temel Yapı + Focus Yönetimi
1. ✅ SettingsMenu.tscn oluştur
2. ✅ SettingsMenu.gd script'i
3. ✅ Tüm kontrolleri focusable yap (`focus_mode = FOCUS_ALL`)
4. ✅ `_input()` ile klavye/gamepad navigasyonu
5. ✅ Focus yönetimi (açılışta ilk kontrole focus)
6. ✅ ESC/B tuşu ile geri dön

### Faz 2: Kontrol Etkileşimleri
7. ✅ Slider kontrolleri (Left/Right ile değer değiştir)
8. ✅ CheckBox kontrolleri (Enter/Space ile toggle)
9. ✅ OptionButton kontrolleri (Left/Right ile seçenek değiştir)
10. ✅ Button kontrolleri (Enter/Space ile bas)
11. ✅ Tab/Shift+Tab ile focus geçişi
12. ✅ Up/Down ile focus geçişi (VBoxContainer içinde)

### Faz 3: Tab Navigasyonu
13. ✅ TabContainer ile kategoriler
14. ✅ Q/E veya L1/R1 ile tab değiştirme
15. ✅ Tab değişiminde focus yönetimi

### Faz 4: Ayarlar ve Kayıt
16. ✅ Ses ayarları (3 slider)
17. ✅ Görüntü ayarları (Fullscreen, VSync)
18. ✅ Oyun ayarları (CheckBox'lar)
19. ✅ Ayarları kaydet/yükle (ConfigFile)

### Faz 5: İyileştirmeler
20. ✅ Kontrol preset'i
21. ✅ Uygula/Sıfırla butonları
22. ✅ Görsel feedback (focus indicator, değer gösterimi)
23. ✅ Yardımcı metin (navigasyon ipuçları)

---

## 🚫 Şimdilik Eklenmeyecekler (Karmaşık)

- ❌ Detaylı tuş ataması (daha sonra)
- ❌ Çözünürlük seçimi (opsiyonel, basit tutmak için)
- ❌ Gelişmiş grafik ayarları (Anti-aliasing, vb.)
- ❌ Dil seçimi (şimdilik tek dil)

---

## ✅ Öncelik Sırası

**Yüksek Öncelik:**
1. Ses ayarları (Master, Music, SFX)
2. Fullscreen toggle
3. VSync toggle
4. Geri butonu

**Orta Öncelik:**
5. Oyun ayarları (Hasar sayıları, FPS, Camera Shake)
6. Ayarları kaydet/yükle

**Düşük Öncelik:**
7. Kontrol preset'i
8. Uygula/Sıfırla butonları
9. Tab navigasyonu (başlangıçta tek sayfa da olabilir)

---

## 💡 Öneriler (Mouse Olmadan Kullanım)

1. **Başlangıç için:** Sadece Ses + Görüntü ayarları yeterli
2. **UI Basitliği:** 
   - Tab yerine tek sayfa da olabilir (scroll edilebilir)
   - Veya TabContainer kullan (L1/R1 ile tab değiştirme kolay)
3. **Kayıt:** Ayarlar değiştiğinde otomatik kaydedilebilir (Uygula butonu opsiyonel)
4. **Varsayılanlar:** Tüm ayarlar için mantıklı varsayılanlar
5. **Focus Yönetimi:** 
   - Her zaman bir kontrol focused olmalı
   - Görsel feedback önemli (hangi kontrolde olduğunu göster)
6. **Slider Kontrolü:**
   - Küçük adımlar (5 veya 10) ile değiştir
   - Hızlı değişim için basılı tutma desteği (opsiyonel)
7. **InputManager Entegrasyonu:**
   - Tüm input kontrolleri InputManager üzerinden
   - Tutarlılık için aynı pattern'i kullan
8. **Test:**
   - Mouse'u kapatarak test et
   - Sadece klavye ile tüm kontrolleri test et
   - Sadece gamepad ile tüm kontrolleri test et

---

**Son Güncelleme:** Planlama aşaması - implementasyon bekleniyor.

