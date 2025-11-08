# ⚙️ Ayarlar Menüsü - Ek Öneriler

## 📋 Mevcut Durum
✅ **Ses:** Master, Music, SFX  
✅ **Görüntü:** Fullscreen, VSync  
✅ **Oyun:** Hasar sayıları, FPS, Kamera titreşimi  

---

## 🎯 Önerilen Eklemeler

### 1. 🎮 Görüntü Ayarları (Video) - Eklemeler

#### **Çözünürlük Seçimi** (Orta Öncelik)
- **OptionButton** ile çözünürlük seçimi
- Seçenekler: 1280x720, 1920x1080, 2560x1440 (varsa)
- Varsayılan: Mevcut çözünürlük
- **Not:** Basit tutmak için şimdilik atlanabilir

#### **FPS Limiti** (Düşük Öncelik)
- OptionButton: 30, 60, 120, Sınırsız
- Varsayılan: 60
- **Not:** VSync açıkken genelde gereksiz

---

### 2. 🎮 Oyun Ayarları (Game) - Eklemeler

#### **Ekran Titreşimi** (Yüksek Öncelik)
- CheckBox: "Ekran Titreşimi"
- Varsayılan: Açık
- **Kullanım:** Hasar aldığında, büyük patlamalarda ekran titreşimi

#### **Hasar Sayıları Stili** (Orta Öncelik)
- OptionButton:
  - "Basit" (sadece sayı)
  - "Detaylı" (kritik, normal, vb. renkler)
  - "Kapalı"
- Varsayılan: "Detaylı"

#### **Otomatik Kayıt** (Düşük Öncelik)
- CheckBox: "Otomatik Kayıt"
- Varsayılan: Açık
- **Kullanım:** Belirli aralıklarla otomatik kayıt

#### **Hızlı Mesajlar** (Düşük Öncelik)
- CheckBox: "Hızlı Mesajlar"
- Varsayılan: Kapalı
- **Kullanım:** NPC diyaloglarını otomatik geç

---

### 3. 🎮 Kontrol Ayarları (Controls) - Yeni Tab

#### **Input Preset** (Yüksek Öncelik)
- OptionButton:
  - "Klavye + Mouse"
  - "Gamepad"
  - "Otomatik Algıla"
- Varsayılan: "Otomatik Algıla"

#### **Hassasiyet Ayarları** (Orta Öncelik - Gamepad için)
- **Hareket Hassasiyeti** (Slider: 0-200%)
- **Kamera Hassasiyeti** (Slider: 0-200%)
- Varsayılan: 100%

#### **Tuş Atama** (Düşük Öncelik - Gelecek)
- Her aksiyon için tuş seçimi
- **Not:** Karmaşık, daha sonra eklenebilir

---

### 4. 🎮 Arayüz Ayarları (UI) - Yeni Tab (Opsiyonel)

#### **UI Ölçeği** (Orta Öncelik)
- Slider: 50% - 150%
- Varsayılan: 100%
- **Kullanım:** UI elementlerinin boyutunu ayarla

#### **HUD Görünürlüğü** (Orta Öncelik)
- CheckBox: "HUD Göster"
- Varsayılan: Açık
- **Kullanım:** Sağlık, stamina bar'larını göster/gizle

#### **Minimap** (Düşük Öncelik)
- CheckBox: "Minimap Göster"
- Varsayılan: Açık (eğer minimap varsa)

#### **Yardımcı İpuçları** (Düşük Öncelik)
- CheckBox: "Yardımcı İpuçları"
- Varsayılan: Açık
- **Kullanım:** Ekrandaki tuş ipuçlarını göster/gizle

---

### 5. 🎮 Erişilebilirlik (Accessibility) - Yeni Tab (Opsiyonel)

#### **Renk Körlüğü Desteği** (Orta Öncelik)
- OptionButton:
  - "Normal"
  - "Protanopia" (Kırmızı-yeşil)
  - "Deuteranopia" (Kırmızı-yeşil)
  - "Tritanopia" (Mavi-sarı)
- Varsayılan: "Normal"

#### **Büyük Metin** (Düşük Öncelik)
- CheckBox: "Büyük Metin"
- Varsayılan: Kapalı
- **Kullanım:** UI metinlerini büyüt

#### **Yüksek Kontrast** (Düşük Öncelik)
- CheckBox: "Yüksek Kontrast"
- Varsayılan: Kapalı

---

## 📊 Öncelik Sırası

### 🔴 Yüksek Öncelik (Hemen Eklenebilir)
1. ✅ **Input Preset** (Kontroller tab'ı)
   - Basit OptionButton
   - Hızlı implementasyon

2. ✅ **Ekran Titreşimi** (Oyun tab'ı)
   - CheckBox
   - Kamera titreşimi ile benzer

### 🟡 Orta Öncelik (Yakında)
3. **Hasar Sayıları Stili** (Oyun tab'ı)
   - OptionButton
   - Mevcut sistemle entegre

4. **Hareket/Kamera Hassasiyeti** (Kontroller tab'ı)
   - Slider'lar
   - Gamepad kullanıcıları için önemli

5. **UI Ölçeği** (UI tab'ı veya Görüntü tab'ı)
   - Slider
   - Farklı ekran boyutları için

### 🟢 Düşük Öncelik (Gelecek)
6. **Çözünürlük Seçimi**
7. **Otomatik Kayıt**
8. **Hızlı Mesajlar**
9. **Renk Körlüğü Desteği**
10. **FPS Limiti**

---

## 💡 Önerilen İlk Eklemeler

### Seçenek 1: Minimal (Hızlı)
1. **Input Preset** (Kontroller tab'ı)
2. **Ekran Titreşimi** (Oyun tab'ı)

### Seçenek 2: Orta (Dengeli)
1. **Input Preset** (Kontroller tab'ı)
2. **Ekran Titreşimi** (Oyun tab'ı)
3. **Hasar Sayıları Stili** (Oyun tab'ı)
4. **UI Ölçeği** (Görüntü tab'ı)

### Seçenek 3: Kapsamlı (Gelecek)
- Yukarıdakiler + Erişilebilirlik + Gelişmiş kontroller

---

## 🎨 UI Yapısı Önerileri

### Kontroller Tab'ı Eklendiğinde:
```
TabContainer
├── Ses (mevcut)
├── Görüntü (mevcut)
├── Kontroller (YENİ)
│   ├── InputPresetOptionButton
│   ├── MovementSensitivitySlider (opsiyonel)
│   └── CameraSensitivitySlider (opsiyonel)
└── Oyun (mevcut)
```

### Oyun Tab'ına Eklemeler:
```
GameTab
├── ShowDamageCheckBox (mevcut)
├── DamageStyleOptionButton (YENİ)
├── ShowFPSCheckBox (mevcut)
├── CameraShakeCheckBox (mevcut)
└── ScreenShakeCheckBox (YENİ)
```

---

## 🔧 Implementasyon Notları

### Input Preset
- InputManager'da preset sistemi
- Otomatik algılama: Gamepad bağlı mı kontrol et
- Preset değiştiğinde UI'ları güncelle

### Ekran Titreşimi
- ScreenEffects autoload ile entegre
- Camera shake'den farklı (ekran genelinde)

### Hasar Sayıları Stili
- DamageValues autoload ile entegre
- Mevcut sistem zaten var gibi görünüyor

---

## ✅ Sonuç

**En Mantıklı İlk Eklemeler:**
1. **Input Preset** - Kullanıcılar için önemli
2. **Ekran Titreşimi** - Basit checkbox, hızlı eklenir
3. **Hasar Sayıları Stili** - Mevcut sistemle entegre

**Toplam:** 3 yeni ayar, 1 yeni tab (Kontroller)

---

**Son Güncelleme:** Öneriler hazır - implementasyon bekleniyor.

