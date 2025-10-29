# Normal Map Troubleshooting Guide

Bu rehber, normal map ile ilgili yaygın sorunları ve çözümlerini içerir.

## 🚨 Yaygın Hatalar ve Çözümleri

### 1. Normal Map Hiç Görünmüyor

**Belirtiler:**
- Enemy normal ışık alıyor, normal map efekti yok
- Console'da hata mesajı yok

**Olası Nedenler:**
- Normal sprite bulunamıyor
- Shader material yüklenmiyor
- Normal texture null

**Çözüm:**
```gdscript
# Debug ekle:
func _setup_normal_map_sync():
	var normal_sprite = sprite.get_node("AnimatedSprite2D_normal")
	if not normal_sprite:
		print("ERROR: Normal sprite not found!")
		return
	print("Normal sprite found: ", normal_sprite.name)
	
	if sprite and not sprite.material:
		var shader = load("res://enemy/normal_shader.gdshader")
		if not shader:
			print("ERROR: Shader not loaded!")
			return
		print("Shader loaded successfully")
```

### 2. Işık Yanlış Yönde (Arkasından Gelirken Önü Parlıyor)

**Belirtiler:**
- Işık arkasından gelirken önü parlıyor
- Sprite flip edildiğinde normal map bozuluyor

**Olası Nedenler:**
- Normal sprite flip ediliyor
- Shader'da flip handling yok

**Çözüm:**
```gdscript
# YANLIŞ:
normal_sprite.flip_h = direction < 0  # ❌ Normal sprite'i flip etme!

# DOĞRU:
sprite.flip_h = direction < 0  # ✅ Sadece ana sprite'i flip et
if sprite.material:
	var material = sprite.material as ShaderMaterial
	if material:
		material.set_shader_parameter("sprite_flipped", direction < 0)
```

### 3. Shader Syntax Hatası

**Hata Mesajı:**
```
E 4-> uniform bool sprite_flipped : hint_default(false);
```

**Çözüm:**
```glsl
// YANLIŞ:
uniform bool sprite_flipped : hint_default(false);

// DOĞRU:
uniform bool sprite_flipped;
```

### 4. Normal Texture Null Hatası

**Hata Mesajı:**
```
Invalid call. Nonexistent function 'get_format' in base 'AtlasTexture'.
```

**Çözüm:**
```gdscript
// YANLIŞ:
print("Normal texture format: ", current_texture.get_format())

// DOĞRU:
print("Normal texture type: ", current_texture.get_class())
```

### 5. Animation Sync Sorunu

**Belirtiler:**
- Normal map ilk frame'de kalıyor
- Animation değiştiğinde normal map güncellenmiyor

**Çözüm:**
```gdscript
func _ready():
	super._ready()
	
	# Normal map setup
	_setup_normal_map_sync()
	
	# Connect frame changed signal for sync
	if sprite and not sprite.frame_changed.is_connected(_sync_normal_map):
		sprite.frame_changed.connect(_sync_normal_map)
		print("Frame changed signal connected")
```

### 6. Performance Sorunları

**Belirtiler:**
- FPS düşüyor
- Oyun yavaşlıyor

**Çözüm:**
- Normal map'leri sadece gerekli enemy'lerde kullan
- Texture boyutlarını optimize et
- Gereksiz debug mesajlarını kaldır

### 7. Normal Map Texture'ları Eksik

**Belirtiler:**
- Normal texture null
- Console'da "Normal texture is null" mesajı

**Çözüm:**
- Normal map texture'larını oluştur
- SpriteFrames'e ekle
- Texture dosyalarının doğru yolda olduğunu kontrol et

### 8. Y Ekseni Ters (Işık Yukarıdan Vururken Altı Aydınlanıyor)

**Belirtiler:**
- Işık yukarıdan vururken karakterin altı aydınlanıyor
- Işık aşağıdan vururken üstü aydınlanıyor

**Çözüm:**
```glsl
// Shader'da Y eksenini düzelt:
normal.y *= -1.0;
```

## 🔍 Debug Checklist

### Normal Map Çalışıyor mu?
- [ ] Console'da "Normal sprite found" mesajı var
- [ ] Console'da "Added normal map shader material" mesajı var
- [ ] Console'da "Normal texture loaded successfully" mesajı var
- [ ] Işık kaynağı enemy etrafında hareket ettirildiğinde farklı aydınlanma görülüyor

### Sprite Flip Sorunu Var mı?
- [ ] Normal sprite'in `flip_h` false
- [ ] Shader'da `sprite_flipped` parametresi kullanılıyor
- [ ] Sprite flip edildiğinde normal map doğru çalışıyor

### Animation Sync Çalışıyor mu?
- [ ] `frame_changed` signal bağlı
- [ ] Animation değiştiğinde normal map güncelleniyor
- [ ] Her frame için doğru normal texture yükleniyor

## 🛠️ Debug Komutları

### Console'da Kontrol Et:
```gdscript
# Normal sprite var mı?
print("Normal sprite: ", sprite.get_node_or_null("AnimatedSprite2D_normal"))

# Shader material var mı?
print("Material: ", sprite.material)

# Normal texture var mı?
var normal_sprite = sprite.get_node("AnimatedSprite2D_normal")
var texture = normal_sprite.sprite_frames.get_frame_texture(normal_sprite.animation, normal_sprite.frame)
print("Normal texture: ", texture)
```

### Görsel Debug:
```gdscript
# Normal sprite'i geçici olarak görünür yap
normal_sprite.visible = true
# Normal map texture'ının doğru yüklenip yüklenmediğini kontrol et
```

## 📝 Test Senaryoları

### 1. Temel Test
- Enemy spawn oluyor
- Normal map shader yükleniyor
- Işık kaynağı enemy'ye yaklaştırılıyor
- Normal map efekti görülüyor

### 2. Flip Test
- Enemy sağa bakıyor, normal map çalışıyor
- Enemy sola dönüyor (flip ediliyor)
- Normal map hala doğru çalışıyor

### 3. Animation Test
- Enemy idle animasyonunda, normal map çalışıyor
- Enemy walk animasyonuna geçiyor
- Normal map yeni animasyonla sync oluyor

### 4. Performance Test
- 10+ enemy ile test
- FPS normal seviyede kalıyor
- Normal map'ler çalışıyor

## 🎯 Sonuç

Bu troubleshooting guide'ı kullanarak normal map sorunlarını hızlıca çözebilirsin. Anahtar noktalar:

1. **Normal sprite'i asla flip etme**
2. **Shader syntax'ını doğru kullan**
3. **Debug mesajlarını kontrol et**
4. **Animation sync'i sağla**
5. **Performance'ı izle**

Normal map sistemi artık sorunsuz çalışmalı! 🚀
