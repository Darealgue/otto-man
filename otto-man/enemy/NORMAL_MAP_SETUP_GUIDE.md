# Normal Map Setup Guide for Enemies

Bu rehber, düşmanlar için normal map sistemi kurulumunu detaylıca açıklar.

## 📋 İçindekiler
1. [Normal Map Nedir?](#normal-map-nedir)
2. [Gerekli Dosyalar](#gerekli-dosyalar)
3. [Scene Kurulumu](#scene-kurulumu)
4. [Script Kurulumu](#script-kurulumu)
5. [Shader Kurulumu](#shader-kurulumu)
6. [Yaygın Sorunlar ve Çözümleri](#yaygın-sorunlar-ve-çözümleri)
7. [Test Etme](#test-etme)

## Normal Map Nedir?

Normal map, 2D sprite'lara 3D derinlik hissi veren tekniktir. Işık kaynağına göre sprite'ın farklı bölgeleri farklı şekilde aydınlanır.

**Normal Map Renkleri:**
- **Kırmızı (R)**: Sağa doğru normal vektör
- **Yeşil (G)**: Yukarı doğru normal vektör  
- **Mavi (B)**: İleri doğru normal vektör

## Gerekli Dosyalar

### 1. Normal Map Shader
`otto-man/enemy/normal_shader.gdshader` dosyası:

```glsl
shader_type canvas_item;

uniform sampler2D normal_texture : hint_normal;
uniform bool sprite_flipped;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	COLOR = texture(TEXTURE, UV);
}

void light() {
	// Normal map lighting
	vec3 normal = texture(normal_texture, UV).rgb;
	normal = normal * 2.0 - 1.0; // Convert from [0,1] to [-1,1]
	
	// Fix Y-axis inversion - normal maps typically have Y pointing down (+Y)
	// but Godot uses Y pointing up (+Y), so we need to flip Y
	normal.y *= -1.0;
	
	// Handle sprite flipping - if sprite is flipped horizontally,
	// we need to flip the normal's X component
	if (sprite_flipped) {
		normal.x *= -1.0;
	}
	
	// Calculate lighting
	float NdotL = dot(normal, LIGHT_DIRECTION);
	float light_intensity = max(0.0, NdotL);
	
	// Apply light color and intensity
	vec3 light_color = LIGHT_COLOR.rgb;
	vec3 final_color = COLOR.rgb * light_color * light_intensity;
	
	// Add ambient lighting
	final_color += COLOR.rgb * 0.3;
	
	LIGHT = vec4(final_color, COLOR.a);
}
```

## Scene Kurulumu

### 1. Enemy Scene Yapısı
```
Enemy (CharacterBody2D)
├── AnimatedSprite2D (ana sprite)
│   └── AnimatedSprite2D_normal (normal map sprite)
├── CollisionShape2D
├── Hitbox (Area2D)
└── Hurtbox (Area2D)
```

### 2. Normal Sprite Ayarları
- **Parent**: Ana AnimatedSprite2D'nin altında olmalı
- **Visible**: `false` (görünmez olmalı)
- **SpriteFrames**: Normal map texture'ları içermeli
- **Animation**: Ana sprite ile aynı animasyonları içermeli

### 3. Normal Map Texture'ları
- Normal map texture'ları ana sprite ile aynı boyutta olmalı
- Her frame için ayrı normal map texture'ı gerekli
- Texture formatı: PNG (RGB kanalları normal vektörler için)

## Script Kurulumu

### 1. Normal Map Sync Fonksiyonu
Enemy script'ine eklenmesi gereken fonksiyon:

```gdscript
func _setup_normal_map_sync():
	"""Setup normal map synchronization between main sprite and normal sprite"""
	print("[EnemyName] Setting up normal map shader...")
	
	# Find the normal sprite (it's a child of the main AnimatedSprite2D)
	var normal_sprite = sprite.get_node("AnimatedSprite2D_normal")
	if not normal_sprite:
		# Try to find it by name
		normal_sprite = sprite.get_node("AnimatedSprite2D")
		if not normal_sprite:
			return
	
	print("[EnemyName] Normal sprite found: ", normal_sprite.name)
	
	# Sync animation and frame with main sprite
	normal_sprite.animation = sprite.animation
	normal_sprite.frame = sprite.frame
	
	# Keep normal sprite invisible but ensure it's properly set up for normal mapping
	normal_sprite.visible = false
	
	# Set up normal mapping on main sprite using ShaderMaterial
	if sprite and not sprite.material:
		var shader = load("res://enemy/normal_shader.gdshader")
		if shader:
			var material = ShaderMaterial.new()
			material.shader = shader
			sprite.material = material
			print("[EnemyName] Added normal map shader material to main sprite")
			
			# Debug: Check if normal texture is properly set
			if normal_sprite.sprite_frames:
				var test_texture = normal_sprite.sprite_frames.get_frame_texture(normal_sprite.animation, normal_sprite.frame)
				if test_texture:
					print("[EnemyName] Normal texture loaded successfully: ", test_texture.get_class())
					print("[EnemyName] Normal texture size: ", test_texture.get_size())
				else:
					print("[EnemyName] ERROR: Normal texture is null!")
			else:
				print("[EnemyName] ERROR: Normal sprite has no sprite_frames!")
	
	# Update normal texture from normal sprite
	if sprite and sprite.material and normal_sprite.sprite_frames:
		var material = sprite.material as ShaderMaterial
		if material:
			var current_texture = normal_sprite.sprite_frames.get_frame_texture(normal_sprite.animation, normal_sprite.frame)
			if current_texture:
				material.set_shader_parameter("normal_texture", current_texture)
			else:
				print("[EnemyName] ERROR: Normal texture is null for animation: ", normal_sprite.animation, " frame: ", normal_sprite.frame)

func _sync_normal_map():
	"""Sync normal map with current animation frame"""
	var normal_sprite = sprite.get_node("AnimatedSprite2D_normal")
	if not normal_sprite:
		return
	
	# Sync animation and frame with main sprite
	normal_sprite.animation = sprite.animation
	normal_sprite.frame = sprite.frame
	
	# Keep normal sprite invisible but ensure it's properly set up for normal mapping
	normal_sprite.visible = false
	
	# Update normal texture from normal sprite
	if sprite and sprite.material and normal_sprite.sprite_frames:
		var material = sprite.material as ShaderMaterial
		if material:
			var current_texture = normal_sprite.sprite_frames.get_frame_texture(normal_sprite.animation, normal_sprite.frame)
			if current_texture:
				material.set_shader_parameter("normal_texture", current_texture)
			else:
				print("[EnemyName] ERROR: Normal texture is null for animation: ", normal_sprite.animation, " frame: ", normal_sprite.frame)
```

### 2. Sprite Direction Update Fonksiyonu
Sprite yönü değiştiğinde normal map'in doğru çalışması için:

```gdscript
func update_sprite_direction() -> void:
	"""Update sprite direction based on movement and target position"""
	if target:
		var target_direction = sign(target.global_position.x - global_position.x)
		if target_direction != 0:
			direction = target_direction
	elif velocity.x != 0:
		direction = sign(velocity.x)
	
	# Flip sprite based on direction
	if sprite:
		sprite.flip_h = direction < 0
		# Don't flip normal sprite - this breaks normal mapping
		# Normal map direction will be handled in shader
		
		# Update shader with flip state
		if sprite.material:
			var material = sprite.material as ShaderMaterial
			if material:
				material.set_shader_parameter("sprite_flipped", direction < 0)
```

### 3. _ready() Fonksiyonuna Ekleme
```gdscript
func _ready():
	super._ready()
	
	# Normal map setup
	_setup_normal_map_sync()
	
	# Connect frame changed signal for sync
	if sprite and not sprite.frame_changed.is_connected(_sync_normal_map):
		sprite.frame_changed.connect(_sync_normal_map)
```

## Shader Kurulumu

### 1. Shader Parametreleri
- `normal_texture`: Normal map texture'ı
- `sprite_flipped`: Sprite'in flip durumu (bool)

### 2. Normal Vektör Hesaplama
```glsl
vec3 normal = texture(normal_texture, UV).rgb;
normal = normal * 2.0 - 1.0; // Convert from [0,1] to [-1,1]
```

### 3. Flip Handling
```glsl
if (sprite_flipped) {
	normal.x *= -1.0;
}
```

## Yaygın Sorunlar ve Çözümleri

### 1. Normal Map Çalışmıyor
**Sorun**: Normal map hiç görünmüyor
**Çözüm**: 
- Normal sprite'in `visible = false` olduğundan emin ol
- Shader material'ın doğru yüklendiğini kontrol et
- Normal texture'ın null olmadığını kontrol et

### 2. Işık Yanlış Yönde
**Sorun**: Işık arkasından gelirken önü parlıyor
**Çözüm**: 
- Normal sprite'i flip etme (`normal_sprite.flip_h = false`)
- Shader'da `sprite_flipped` parametresini kullan
- Normal vektörün X bileşenini flip et

### 3. Shader Syntax Hatası
**Sorun**: `uniform bool sprite_flipped : hint_default(false);`
**Çözüm**: `uniform bool sprite_flipped;` kullan

### 4. Normal Texture Null
**Sorun**: Normal texture yüklenmiyor
**Çözüm**:
- Normal sprite'in sprite_frames'i olduğundan emin ol
- Texture dosyalarının doğru yolda olduğunu kontrol et
- AtlasTexture kullanıyorsan `get_format()` yerine `get_class()` kullan

### 5. Animation Sync Sorunu
**Sorun**: Normal map ana sprite ile sync olmuyor
**Çözüm**:
- `frame_changed` signal'ını bağla
- Her frame değişiminde `_sync_normal_map()` çağır

## Test Etme

### 1. Debug Çıktıları
Normal map kurulumunda şu mesajları görmelisin:
```
[EnemyName] Setting up normal map shader...
[EnemyName] Normal sprite found: AnimatedSprite2D_normal
[EnemyName] Added normal map shader material to main sprite
[EnemyName] Normal texture loaded successfully: AtlasTexture
[EnemyName] Normal texture size: (96, 96)
```

### 2. Görsel Test
- Işık kaynağını enemy'nin etrafında hareket ettir
- Normal map'in farklı yönlerde farklı aydınlandığını gör
- Sprite flip edildiğinde normal map'in doğru çalıştığını kontrol et

### 3. Performance Test
- Normal map'in FPS'i etkilemediğini kontrol et
- Çok sayıda enemy ile test et

## Önemli Notlar

1. **Normal sprite'i asla flip etme** - Bu normal map'i bozar
2. **Shader'da flip handling kullan** - Sprite flip durumunu shader'a geç
3. **Normal texture'ları sync et** - Her frame değişiminde güncelle
4. **Debug mesajlarını kullan** - Sorun tespiti için önemli
5. **Performance'ı kontrol et** - Çok fazla normal map FPS'i etkileyebilir

## Sonuç

Bu rehberi takip ederek herhangi bir enemy'ye normal map ekleyebilirsin. Anahtar noktalar:
- Normal sprite'i flip etme
- Shader'da flip handling kullan
- Texture sync'i sağla
- Debug mesajlarını kontrol et

Normal map sistemi artık hazır ve çalışır durumda! 🎯
