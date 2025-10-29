# Normal Map Template for Enemies

Bu template, yeni enemy'lere normal map eklemek için kullanılabilir.

## 1. Scene Yapısı
```
Enemy (CharacterBody2D)
├── AnimatedSprite2D (ana sprite)
│   └── AnimatedSprite2D_normal (normal map sprite, visible=false)
├── CollisionShape2D
├── Hitbox (Area2D)
└── Hurtbox (Area2D)
```

## 2. Script Template

```gdscript
# Enemy script'ine eklenecek kodlar:

func _setup_normal_map_sync():
	"""Setup normal map synchronization between main sprite and normal sprite"""
	print("[EnemyName] Setting up normal map shader...")
	
	var normal_sprite = sprite.get_node("AnimatedSprite2D_normal")
	if not normal_sprite:
		normal_sprite = sprite.get_node("AnimatedSprite2D")
		if not normal_sprite:
			return
	
	print("[EnemyName] Normal sprite found: ", normal_sprite.name)
	
	# Sync animation and frame with main sprite
	normal_sprite.animation = sprite.animation
	normal_sprite.frame = sprite.frame
	normal_sprite.visible = false
	
	# Set up normal mapping on main sprite using ShaderMaterial
	if sprite and not sprite.material:
		var shader = load("res://enemy/normal_shader.gdshader")
		if shader:
			var material = ShaderMaterial.new()
			material.shader = shader
			sprite.material = material
			print("[EnemyName] Added normal map shader material to main sprite")
	
	# Update normal texture from normal sprite
	if sprite and sprite.material and normal_sprite.sprite_frames:
		var material = sprite.material as ShaderMaterial
		if material:
			var current_texture = normal_sprite.sprite_frames.get_frame_texture(normal_sprite.animation, normal_sprite.frame)
			if current_texture:
				material.set_shader_parameter("normal_texture", current_texture)

func _sync_normal_map():
	"""Sync normal map with current animation frame"""
	var normal_sprite = sprite.get_node("AnimatedSprite2D_normal")
	if not normal_sprite:
		return
	
	normal_sprite.animation = sprite.animation
	normal_sprite.frame = sprite.frame
	normal_sprite.visible = false
	
	if sprite and sprite.material and normal_sprite.sprite_frames:
		var material = sprite.material as ShaderMaterial
		if material:
			var current_texture = normal_sprite.sprite_frames.get_frame_texture(normal_sprite.animation, normal_sprite.frame)
			if current_texture:
				material.set_shader_parameter("normal_texture", current_texture)

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

func _ready():
	super._ready()
	
	# Normal map setup
	_setup_normal_map_sync()
	
	# Connect frame changed signal for sync
	if sprite and not sprite.frame_changed.is_connected(_sync_normal_map):
		sprite.frame_changed.connect(_sync_normal_map)
```

## 3. Shader Dosyası
`otto-man/enemy/normal_shader.gdshader` dosyasını kullan.

## 4. Checklist
- [ ] Normal sprite scene'de var ve visible=false
- [ ] Normal sprite'in sprite_frames'i var
- [ ] Normal map texture'ları yüklü
- [ ] Script'te normal map fonksiyonları var
- [ ] _ready()'de setup çağrılıyor
- [ ] frame_changed signal bağlı
- [ ] update_sprite_direction() shader parametresini güncelliyor
- [ ] Shader'da Y ekseni düzeltmesi var (normal.y *= -1.0)
- [ ] Shader'da sprite_flipped parametresi var

## 5. Test
- Işık kaynağını enemy etrafında hareket ettir
- Normal map'in farklı yönlerde çalıştığını kontrol et
- Sprite flip edildiğinde normal map'in doğru çalıştığını kontrol et
