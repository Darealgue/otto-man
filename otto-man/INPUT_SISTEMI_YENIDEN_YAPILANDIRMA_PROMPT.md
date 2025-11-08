# 🎮 Input Sistemi Yeniden Yapılandırma - Geliştirme Prompt'u

## 📋 Mevcut Durum Analizi

### Sorun
Oyunun UI kontrolleri şu anda **sadece gamepad ile tam olarak çalışıyor**. Klavye kullanıcıları için bazı özellikler eksik veya tutarsız:

1. **Zindan Kapı Geçişi**: Gamepad ile `ui_up` tuşuna basılı tutarak kapıdan geçilebiliyor (`PortalArea.gd`), ancak klavyede W tuşu ile aynı işlem çalışmıyor.
2. **UI Navigasyonu**: `MissionCenter.gd` ve diğer UI sistemleri `ui_up`, `ui_down`, `ui_left`, `ui_right` aksiyonlarını kullanıyor, ancak bu aksiyonlar klavyede tutarlı çalışmıyor.
3. **Input Mapping Karmaşası**: Farklı sistemler farklı input yöntemleri kullanıyor:
   - Player hareketi: `move_left`, `move_right`, `jump`, `dash`, `attack` (oyun aksiyonları)
   - UI kontrolleri: `ui_up`, `ui_down`, `ui_left`, `ui_right`, `ui_accept`, `ui_cancel` (UI aksiyonları)
   - Portal/Etkileşim: `interact`, `ui_up` (karışık)

### Mevcut Input Aksiyonları (`project.godot`)

**UI Aksiyonları:**
- `ui_up`: W tuşu (klavye) + D-Pad Up (gamepad)
- `ui_down`: S tuşu (klavye) + D-Pad Down (gamepad)
- `ui_left`: A tuşu (klavye) + D-Pad Left (gamepad)
- `ui_right`: D tuşu (klavye) + D-Pad Right (gamepad)
- `ui_accept`: (tanımlı değil, muhtemelen Enter/Space)
- `ui_cancel`: (tanımlı değil, muhtemelen ESC/B)

**Oyun Aksiyonları:**
- `move_left`: A tuşu
- `move_right`: D tuşu
- `jump`: Space (klavye) + A button (gamepad)
- `dash`: Shift (klavye) + B button (gamepad)
- `attack`: J tuşu (klavye) + X button (gamepad)
- `block`: Q tuşu (klavye) + R1 (gamepad)
- `interact`: E tuşu (muhtemelen)

## 🎯 Hedef

**Tek bir merkezi input sistemi** oluşturarak:
1. Hem klavye hem gamepad kullanıcıları **aynı aksiyon tuşlarını** kullanarak UI'ları kontrol edebilmeli
2. Oyuncular kendi tuş atamalarını yaptıklarında **ortada karışıklık olmamalı**
3. Tüm input kontrolleri **tek bir yerden yönetilmeli** (InputManager autoload)
4. UI kontrolleri ve oyun kontrolleri **tutarlı ve birleşik** olmalı

## 🏗️ Çözüm Mimarisi

### 1. InputManager Autoload Oluştur

**Dosya:** `autoload/InputManager.gd`

**Sorumluluklar:**
- Tüm input aksiyonlarını merkezi olarak yönetmek
- Klavye ve gamepad inputlarını birleştirmek
- Input mapping'i tek bir yerden kontrol etmek
- Input durumunu sorgulama için API sağlamak

**API Tasarımı:**
```gdscript
# InputManager.gd
class_name InputManager

# UI Navigasyon Aksiyonları (hem klavye hem gamepad)
static func is_ui_up_pressed() -> bool
static func is_ui_down_pressed() -> bool
static func is_ui_left_pressed() -> bool
static func is_ui_right_pressed() -> bool
static func is_ui_accept_pressed() -> bool
static func is_ui_cancel_pressed() -> bool

# Oyun Aksiyonları (hem klavye hem gamepad)
static func is_move_left_pressed() -> bool
static func is_move_right_pressed() -> bool
static func is_jump_pressed() -> bool
static func is_dash_pressed() -> bool
static func is_attack_pressed() -> bool
static func is_block_pressed() -> bool
static func is_interact_pressed() -> bool

# Portal/Etkileşim için özel
static func is_portal_enter_pressed() -> bool  # ui_up veya interact
```

### 2. Input Aksiyonlarını Yeniden Yapılandır

**`project.godot` dosyasında:**

**UI Aksiyonları** - Her biri hem klavye hem gamepad için tanımlı:
- `ui_up`: W (klavye) + D-Pad Up (gamepad) + Arrow Up (klavye alternatifi)
- `ui_down`: S (klavye) + D-Pad Down (gamepad) + Arrow Down (klavye alternatifi)
- `ui_left`: A (klavye) + D-Pad Left (gamepad) + Arrow Left (klavye alternatifi)
- `ui_right`: D (klavye) + D-Pad Right (gamepad) + Arrow Right (klavye alternatifi)
- `ui_accept`: Enter/Space (klavye) + A button (gamepad)
- `ui_cancel`: ESC (klavye) + B button (gamepad)

**Oyun Aksiyonları** - Mevcut yapı korunur, ancak InputManager üzerinden erişilir:
- `move_left`, `move_right`, `jump`, `dash`, `attack`, `block`, `interact`

**Portal/Etkileşim Aksiyonları:**
- `portal_enter`: `ui_up` veya `interact` (her ikisi de çalışmalı)

### 3. Mevcut Kodları Güncelle

**Güncellenecek Dosyalar:**

1. **`village/scripts/PortalArea.gd`**
   - `Input.is_action_pressed(travel_action)` → `InputManager.is_portal_enter_pressed()`
   - Hem `ui_up` hem `interact` tuşlarını desteklemeli

2. **`village/missions/MissionCenter.gd`**
   - Tüm `Input.is_action_pressed("ui_*")` çağrıları → `InputManager.is_ui_*_pressed()`
   - Event-based input handling'i InputManager API'sine uyarla

3. **`scenes/door.gd`**
   - `Input.is_action_just_pressed("interact")` → `InputManager.is_interact_pressed()`
   - Alternatif olarak `ui_up` tuşu ile de açılabilmeli (gamepad uyumluluğu için)

4. **`chunks/common/DoorInteraction.gd`**
   - `Input.is_action_just_pressed("interact")` → `InputManager.is_interact_pressed()`

5. **`ui/PauseMenu.gd`**
   - Input handling'i InputManager üzerinden yap

6. **Diğer UI dosyaları**
   - Tüm UI input kontrollerini InputManager API'sine geçir

### 4. Input Mapping Sistemi (İsteğe Bağlı - Gelecek için)

**Ayarlar menüsünde tuş atama özelliği:**
- InputManager, runtime'da input mapping'i değiştirebilmeli
- Kullanıcı ayarları kaydedilmeli
- Godot'un `InputMap` API'si kullanılabilir

## 📝 Uygulama Adımları

### ✅ Adım 1: InputManager Autoload Oluştur (TAMAMLANDI)
1. ✅ `autoload/InputManager.gd` dosyasını oluştur
2. ✅ Tüm input sorgulama metodlarını implement et
3. ✅ Her metod hem klavye hem gamepad inputlarını kontrol etsin
4. ✅ `project.godot`'a autoload olarak ekle
5. ✅ Dinamik tuş isimleri için yardımcı fonksiyonlar eklendi

### ✅ Adım 2: Input Aksiyonlarını Güncelle (TAMAMLANDI)
1. ✅ `project.godot` dosyasındaki `[input]` bölümünü güncelle
2. ✅ `ui_accept` ve `ui_cancel` aksiyonlarını ekle
3. ✅ Her UI aksiyonuna hem klavye hem gamepad mapping'i ekle
4. ✅ Arrow key'leri alternatif olarak ekle (WASD + Arrow keys)
5. ✅ Q/E tuşları L1/R1 için klavye alternatifi olarak eklendi

### ✅ Adım 3: PortalArea.gd Güncelle (TAMAMLANDI)
1. ✅ `travel_action` kontrolünü InputManager'a geçir
2. ✅ Hem `ui_up` hem `interact` tuşlarını destekle
3. ⏳ Test et: Klavye ile W tuşuna basılı tutarak portal geçişi çalışmalı

### ✅ Adım 4: MissionCenter.gd Güncelle (TAMAMLANDI)
1. ✅ Tüm `Input.is_action_pressed("ui_*")` çağrılarını InputManager API'sine geçir
2. ✅ Event-based input handling'i koru, ancak InputManager üzerinden kontrol et
3. ✅ Windows tuşu filtrelendi
4. ✅ ESC ve Dodge tuşu ile menü kapatma eklendi
5. ⏳ Test et: Klavye ile tüm UI navigasyonu çalışmalı

### ✅ Adım 5: Door.gd ve DoorInteraction.gd Güncelle (TAMAMLANDI)
1. ✅ `interact` input'unu InputManager üzerinden al
2. ✅ Alternatif olarak `ui_up` tuşu ile de etkileşim sağla (gamepad uyumluluğu)
3. ✅ CampFire etkileşimi güncellendi
4. ⏳ Test et: Hem klavye hem gamepad ile kapı etkileşimi çalışmalı

### ✅ Adım 6: Diğer UI Dosyalarını Güncelle (TAMAMLANDI)
1. ✅ Tüm UI input kontrollerini InputManager API'sine geçir
2. ✅ VillagerLockpick.gd güncellendi
3. ✅ powerup_selection.gd güncellendi
4. ✅ npc_window.gd güncellendi
5. ✅ PauseMenu.gd güncellendi (ESC/Start/Dodge kontrolleri)
6. ✅ Tutarlılık için tüm dosyalarda aynı pattern kullanılıyor

### ⏳ Adım 7: Test ve Doğrulama (BEKLİYOR)
1. **Klavye Testi:**
   - WASD ile UI navigasyonu
   - W tuşu ile portal geçişi
   - E tuşu ile kapı etkileşimi
   - Enter/Space ile onaylama
   - ESC ile iptal

2. **Gamepad Testi:**
   - D-Pad ile UI navigasyonu
   - D-Pad Up ile portal geçişi
   - A button ile onaylama
   - B button ile iptal

3. **Karışık Test:**
   - Klavye ile başla, gamepad ile devam et (veya tersi)
   - Input mapping değişikliklerinin tüm sistemde geçerli olduğunu doğrula

## 🔧 Teknik Detaylar

### InputManager.gd Örnek Implementasyon

```gdscript
extends Node

# UI Aksiyonları
static func is_ui_up_pressed() -> bool:
	return Input.is_action_pressed("ui_up")

static func is_ui_down_pressed() -> bool:
	return Input.is_action_pressed("ui_down")

static func is_ui_left_pressed() -> bool:
	return Input.is_action_pressed("ui_left")

static func is_ui_right_pressed() -> bool:
	return Input.is_action_pressed("ui_right")

static func is_ui_accept_pressed() -> bool:
	return Input.is_action_pressed("ui_accept")

static func is_ui_cancel_pressed() -> bool:
	return Input.is_action_pressed("ui_cancel")

# Oyun Aksiyonları
static func is_move_left_pressed() -> bool:
	return Input.is_action_pressed("move_left")

static func is_move_right_pressed() -> bool:
	return Input.is_action_pressed("move_right")

static func is_jump_pressed() -> bool:
	return Input.is_action_pressed("jump")

static func is_dash_pressed() -> bool:
	return Input.is_action_pressed("dash")

static func is_attack_pressed() -> bool:
	return Input.is_action_pressed("attack")

static func is_block_pressed() -> bool:
	return Input.is_action_pressed("block")

static func is_interact_pressed() -> bool:
	return Input.is_action_pressed("interact")

# Portal/Etkileşim - Özel
static func is_portal_enter_pressed() -> bool:
	# Hem ui_up hem interact tuşlarını destekle
	return Input.is_action_pressed("ui_up") or Input.is_action_pressed("interact")
```

### PortalArea.gd Güncelleme Örneği

**Önce:**
```gdscript
if Input.is_action_pressed(travel_action):
	_hold_timer += _delta
```

**Sonra:**
```gdscript
if InputManager.is_portal_enter_pressed():
	_hold_timer += _delta
```

### MissionCenter.gd Güncelleme Örneği

**Önce:**
```gdscript
if event.is_action_pressed("ui_up"):
	handle_missions_up()
```

**Sonra:**
```gdscript
if event.is_action_pressed("ui_up") and InputManager.is_ui_up_pressed():
	handle_missions_up()
```

**VEYA daha iyi:**
```gdscript
# InputManager'ı event-based değil, polling-based kullan
func _process(_delta):
	if InputManager.is_ui_up_pressed():
		handle_missions_up()
```

## ⚠️ Dikkat Edilmesi Gerekenler

1. **Event-based vs Polling-based:**
   - UI navigasyonu için event-based (`_input()` callback) daha iyi (debounce için)
   - Portal geçişi için polling-based (`_process()`) daha iyi (basılı tutma için)
   - InputManager her iki durumu da desteklemeli

2. **Input Çakışmaları:**
   - Player hareketi ve UI navigasyonu aynı tuşları kullanabilir (WASD)
   - UI açıkken player input'ları blokla
   - InputManager'da context-aware input handling eklenebilir

3. **Backward Compatibility:**
   - Mevcut `Input.is_action_pressed()` çağrıları çalışmaya devam etmeli
   - InputManager, Godot'un Input API'sini wrap etmeli, değiştirmemeli

4. **Performance:**
   - InputManager static metodlar kullanmalı (instance oluşturmadan)
   - Her frame input sorgulama yapılacak, optimize edilmeli

## ✅ Başarı Kriterleri

1. ✅ Klavye kullanıcıları W tuşuna basılı tutarak zindan kapılarından geçebilmeli
2. ✅ Gamepad kullanıcıları D-Pad Up ile zindan kapılarından geçebilmeli
3. ✅ Klavye ve gamepad kullanıcıları aynı tuş kombinasyonları ile UI'ları kontrol edebilmeli
4. ✅ Tüm input kontrolleri InputManager üzerinden yönetilmeli
5. ✅ Oyuncular tuş atamalarını değiştirdiğinde tüm sistem tutarlı çalışmalı
6. ✅ Mevcut oyun mekanikleri (player hareketi, saldırı, vb.) etkilenmemeli

## 🚀 Gelecek İyileştirmeler

1. **Ayarlar Menüsünde Tuş Atama:**
   - Runtime'da input mapping değiştirme
   - Kullanıcı ayarlarını kaydetme/yükleme

2. **Input Preset'leri:**
   - "Klavye + Mouse", "Gamepad", "Klavye + Gamepad" preset'leri
   - Otomatik input cihazı algılama

3. **Input Feedback:**
   - Hangi tuşun basıldığını gösteren visual feedback
   - Input tutorial'ları için input gösterimi

---

**Not:** Bu prompt, input sisteminin yeniden yapılandırılması için kapsamlı bir rehberdir. Adım adım uygulanmalı ve her adımda test edilmelidir.

