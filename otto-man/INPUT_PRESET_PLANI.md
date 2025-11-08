# 🎮 Input Preset Planı - ONAYLANDI

## 📋 Mevcut Tuş Atamaları (Referans)

### Oyun Aksiyonları
- **jump**: Space (32)
- **dash**: Shift (4194325 - KEY_META)
- **attack**: J (74)
- **attack_heavy**: K (75)
- **block**: Q (81)
- **interact**: P (80) ve E (69)
- **crouch**: S (83) - down ile aynı

### Hareket
- **move_left**: A (65) + Arrow Left
- **move_right**: D (68) + Arrow Right
- **up**: W (87)
- **down**: S (83)

### UI Navigasyon
- **l2_trigger** (ui_page_left): Q (81)
- **r2_trigger** (ui_page_right): E (69)

---

## ✅ ONAYLANAN PRESET'LER

### Preset 1: "WASD Yönlendirme + Numpad Aksiyonlar"

**Yönlendirme:**
- **W** - Yukarı
- **A** - Sol
- **S** - Aşağı
- **D** - Sağ

**Aksiyonlar (Numpad):**
- **Jump**: **Space** (her iki preset'te aynı)
- **Dash**: **Shift** (her iki preset'te aynı)
- **Light Attack**: **Numpad 4** (KEY_KP_4)
- **Heavy Attack**: **Numpad 5** (KEY_KP_5)
- **Block**: **Numpad 6** (KEY_KP_6)
- **L1** (ui_page_left): **Numpad 7** (KEY_KP_7)
- **R1** (ui_page_right): **Numpad 9** (KEY_KP_9)
- **Interact**: **Numpad 8** (KEY_KP_8)
- **Crouch**: **S** (down ile aynı, ayrı tuş yok)

---

### Preset 2: "Arrow Keys + Numpad 8456 Yönlendirme + QWEASD Aksiyonlar"

**Yönlendirme:**
- **↑** (Arrow Up) - Yukarı
- **←** (Arrow Left) - Sol
- **↓** (Arrow Down) - Aşağı
- **→** (Arrow Right) - Sağ
- **Numpad 8** (KEY_KP_8) - Yukarı (alternatif)
- **Numpad 4** (KEY_KP_4) - Sol (alternatif)
- **Numpad 5** (KEY_KP_5) - Aşağı (alternatif)
- **Numpad 6** (KEY_KP_6) - Sağ (alternatif)

**Aksiyonlar (QWEASD):**
- **Jump**: **Space** (her iki preset'te aynı)
- **Dash**: **Shift** (her iki preset'te aynı)
- **Light Attack**: **A** (65)
- **Heavy Attack**: **S** (83)
- **Block**: **D** (68)
- **L1** (ui_page_left): **Q** (81)
- **R1** (ui_page_right): **E** (69)
- **Interact**: **W** (87)
- **Crouch**: **Arrow Down** veya **Numpad 5** (down ile aynı)

---

### Preset 3: "Gamepad" (Standart)

**Yönlendirme:**
- D-Pad veya Left Stick

**Aksiyonlar:**
- **Jump**: A Button (0)
- **Dash**: B Button (1)
- **Light Attack**: X Button (2)
- **Heavy Attack**: Y Button (3)
- **Block**: Right Shoulder (5) veya Left Shoulder (4)
- **L1** (ui_page_left): Left Shoulder (4)
- **R1** (ui_page_right): Right Shoulder (5)
- **Interact**: A Button (0) veya D-Pad Up
- **Crouch**: D-Pad Down veya Right Stick Down

**Not:** Gamepad için tek preset yeterli, standart mapping.

---

## 📝 Tuş Kodları (Godot)

### Preset 1 - Numpad Tuşları
- **Numpad 4**: KEY_KP_4 = 4194328
- **Numpad 5**: KEY_KP_5 = 4194329
- **Numpad 6**: KEY_KP_6 = 4194330
- **Numpad 7**: KEY_KP_7 = 4194331
- **Numpad 8**: KEY_KP_8 = 4194332
- **Numpad 9**: KEY_KP_9 = 4194333

### Preset 2 - QWEASD Tuşları
- **A**: KEY_A = 65
- **S**: KEY_S = 83
- **D**: KEY_D = 68
- **W**: KEY_W = 87
- **Q**: KEY_Q = 81
- **E**: KEY_E = 69

### Ortak Tuşlar
- **Space**: KEY_SPACE = 32
- **Shift**: KEY_SHIFT = 4194325 (KEY_META)

---

## ✅ Çakışma Yok!

**Preset değiştiğinde InputMap'teki tuş atamaları tamamen değişecek:**
- Preset 1'de: S tuşu sadece Down/Crouch için
- Preset 2'de: S tuşu sadece Heavy Attack için (Down/Crouch Arrow Down ile)
- Preset 1'de: W tuşu sadece Up için
- Preset 2'de: W tuşu sadece Interact için (Up Arrow Up ile)

**Her preset'te her tuş sadece bir aksiyon için kullanılacak - çakışma yok!**

---

## 🎯 Implementasyon Planı

### 1. SettingsMenu'ya Preset Seçimi Ekle
- OptionButton: "WASD + Numpad" / "Arrow Keys + QWEASD" / "Gamepad"
- Preset değiştiğinde InputMap'i güncelle

### 2. InputManager'a Preset Sistemi Ekle
- Preset değiştiğinde InputMap aksiyonlarını güncelle
- Runtime'da tuş atamalarını değiştir

### 3. Preset Tanımları
- Her preset için Dictionary
- Aksiyon -> Tuş mapping'i

---

## ✅ Onaylanan Mapping

### Preset 1: WASD + Numpad
```
Yönlendirme: W, A, S, D
Jump: Space
Dash: Shift
Light Attack: Numpad 4
Heavy Attack: Numpad 5
Block: Numpad 6
L1: Numpad 7
R1: Numpad 9
Interact: Numpad 8
Crouch: S (down ile aynı)
```

### Preset 2: Arrow Keys + Numpad 8456 + QWEASD
```
Yönlendirme: ↑, ←, ↓, → + Numpad 8, 4, 5, 6
Jump: Space
Dash: Shift
Light Attack: A
Heavy Attack: S
Block: D
L1: Q
R1: E
Interact: W
Crouch: ↓ (Arrow Down) veya Numpad 5
```

---

**Durum:** ✅ Onaylandı - Implementasyona hazır!

