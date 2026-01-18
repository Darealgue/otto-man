extends Node2D

# <<< YENİ: Appearance Resource >>>
const VillagerAppearance = preload("res://village/scripts/VillagerAppearance.gd")
@export var appearance: VillagerAppearance:
	set(value):
		appearance = value
		if is_node_ready():
			update_visuals()

# Cariye referansı
var concubine_id: int = -1
var concubine_data: Concubine = null

# Hareket Değişkenleri
var move_target_x: float = 0.0
var move_speed: float = randf_range(40.0, 60.0) # Pixel per second
var _target_global_y: float = 0.0
const VERTICAL_RANGE_MAX: float = 25.0

# Animasyon takibi
var _current_animation_name: String = ""
var _idle_initialized: bool = false  # İlk idle animasyonu oynatıldı mı?
var _wander_timer: Timer
var _wander_interval_min: float = 5.0
var _wander_interval_max: float = 15.0

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var body_sprite: Sprite2D = $BodySprite
@onready var pants_sprite: Sprite2D = $PantsSprite
@onready var clothing_sprite: Sprite2D = $ClothingSprite
@onready var mouth_sprite: Sprite2D = $MouthSprite
@onready var eyes_sprite: Sprite2D = $EyesSprite
@onready var hair_sprite: Sprite2D = $HairSprite

# <<< YENİ: Walk Texture Setleri (Worker'dan alındı, Cariye asset'leri eklendi) >>>
var walk_textures = {
	"body": {
		"default": {
			"diffuse": preload("res://assets/character_parts/body/body_walk_gray.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/body_walk_gray_normal.png")
		},
		# Cariye body asset'i
		"cariye": {
			"diffuse": preload("res://assets/concubine assets/body/cariye_walk_body.png"),
			"normal": null  # Normal map yoksa null
		}
	},
	"pants": {
		"basic": {
			"diffuse": preload("res://assets/character_parts/pants/pants_basic_walk_gray.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/pants_basic_walk_gray_normal.png")
		},
		"short": {
			"diffuse": preload("res://assets/character_parts/pants/pants_short_walk_gray.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/pants_short_walk_gray_normal.png")
		},
		# Cariye bottom asset'leri (walk) - runtime'da yüklenecek
		"cariye_bottom": {
			"diffuse": null,  # Runtime'da yüklenecek
			"normal": null  # Normal map yoksa null
		}
	},
	"clothing": {
		"shirt": {
			"diffuse": preload("res://assets/character_parts/clothing/shirt_walk_gray.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/shirt_walk_gray_normal.png")
		},
		"shirtless": {
			"diffuse": preload("res://assets/character_parts/clothing/shirtless_walk_gray.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/shirtless_walk_gray_normal.png")
		},
		# Cariye top asset'leri (walk) - runtime'da yüklenecek
		"cariye_top": {
			"diffuse": null,  # Runtime'da yüklenecek
			"normal": null  # Normal map yoksa null
		}
	},
	"mouth": {
		"1": {
			"diffuse": preload("res://assets/character_parts/mouth/mouth1_walk.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/mouth1_walk_normal.png")
		},
		"2": {
			"diffuse": preload("res://assets/character_parts/mouth/mouth2_walk.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/mouth2_walk_normal.png")
		}
	},
	"eyes": {
		"1": {
			"diffuse": preload("res://assets/character_parts/eyes/eyes1_walk.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/eyes1_walk_normal.png")
		},
		"2": {
			"diffuse": preload("res://assets/character_parts/eyes/eyes2_walk.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/eyes2_walk_normal.png")
		}
	},
	"hair": {
		"style1": {
			"diffuse": preload("res://assets/character_parts/hair/hair_style1_walk_gray.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/hair_style1_walk_gray_normal.png")
		},
		"style2": {
			"diffuse": preload("res://assets/character_parts/hair/hair_style2_walk_gray.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/hair_style2_walk_gray_normal.png")
		},
		# Cariye walk hair asset'leri
		"cariye_hair0": {
			"diffuse": preload("res://assets/concubine assets/hair/cariye_walk_hair0.png"),
			"normal": null  # Normal map yoksa null
		},
		"cariye_hair1": {
			"diffuse": preload("res://assets/concubine assets/hair/cariye_walk_hair1.png"),
			"normal": null  # Normal map yoksa null
		},
		"cariye_hair2": {
			"diffuse": preload("res://assets/concubine assets/hair/cariye_walk_hair2.png"),
			"normal": null  # Normal map yoksa null
		}
	},
}

# <<< YENİ: Idle Texture Setleri (Cariye asset'leri için) >>>
var idle_textures = {
	"body": {
		"default": {
			"diffuse": preload("res://assets/character_parts/body/body_walk_gray.png"),  # Fallback: walk texture kullan
			"normal": preload("res://assets/character_parts/character_parts_normals/body_walk_gray_normal.png")
		},
		# Cariye idle body asset'i
		"cariye": {
			"diffuse": preload("res://assets/concubine assets/body/cariye_idle_body.png"),
			"normal": null  # Normal map yoksa null
		}
	},
	"pants": {
		"basic": {
			"diffuse": preload("res://assets/character_parts/pants/pants_basic_walk_gray.png"),  # Fallback
			"normal": preload("res://assets/character_parts/character_parts_normals/pants_basic_walk_gray_normal.png")
		},
		"short": {
			"diffuse": preload("res://assets/character_parts/pants/pants_short_walk_gray.png"),  # Fallback
			"normal": preload("res://assets/character_parts/character_parts_normals/pants_short_walk_gray_normal.png")
		},
		# Cariye bottom asset'leri (idle) - runtime'da yüklenecek
		"cariye_bottom": {
			"diffuse": null,  # Runtime'da yüklenecek
			"normal": null  # Normal map yoksa null
		}
	},
	"clothing": {
		"shirt": {
			"diffuse": preload("res://assets/character_parts/clothing/shirt_walk_gray.png"),  # Fallback
			"normal": preload("res://assets/character_parts/character_parts_normals/shirt_walk_gray_normal.png")
		},
		"shirtless": {
			"diffuse": preload("res://assets/character_parts/clothing/shirtless_walk_gray.png"),  # Fallback
			"normal": preload("res://assets/character_parts/character_parts_normals/shirtless_walk_gray_normal.png")
		},
		# Cariye top asset'leri (idle) - runtime'da yüklenecek
		"cariye_top": {
			"diffuse": null,  # Runtime'da yüklenecek
			"normal": null  # Normal map yoksa null
		}
	},
	"mouth": {
		"1": {
			"diffuse": preload("res://assets/character_parts/mouth/mouth1_walk.png"),  # Fallback
			"normal": preload("res://assets/character_parts/character_parts_normals/mouth1_walk_normal.png")
		},
		"2": {
			"diffuse": preload("res://assets/character_parts/mouth/mouth2_walk.png"),  # Fallback
			"normal": preload("res://assets/character_parts/character_parts_normals/mouth2_walk_normal.png")
		}
	},
	"eyes": {
		"1": {
			"diffuse": preload("res://assets/character_parts/eyes/eyes1_walk.png"),  # Fallback
			"normal": preload("res://assets/character_parts/character_parts_normals/eyes1_walk_normal.png")
		},
		"2": {
			"diffuse": preload("res://assets/character_parts/eyes/eyes2_walk.png"),  # Fallback
			"normal": preload("res://assets/character_parts/character_parts_normals/eyes2_walk_normal.png")
		}
	},
	"hair": {
		"style1": {
			"diffuse": preload("res://assets/character_parts/hair/hair_style1_walk_gray.png"),  # Fallback
			"normal": preload("res://assets/character_parts/character_parts_normals/hair_style1_walk_gray_normal.png")
		},
		"style2": {
			"diffuse": preload("res://assets/character_parts/hair/hair_style2_walk_gray.png"),  # Fallback
			"normal": preload("res://assets/character_parts/character_parts_normals/hair_style2_walk_gray_normal.png")
		},
		# Cariye idle hair asset'leri
		"cariye_hair0": {
			"diffuse": preload("res://assets/concubine assets/hair/cariye_idle_hair0.png"),
			"normal": null  # Normal map yoksa null
		},
		"cariye_hair1": {
			"diffuse": preload("res://assets/concubine assets/hair/cariye_idle_hair1.png"),
			"normal": null  # Normal map yoksa null
		},
		"cariye_hair2": {
			"diffuse": preload("res://assets/concubine assets/hair/cariye_idle_hair2.png"),
			"normal": null  # Normal map yoksa null
		}
	},
}
# <<< YENİ SONU >>>

# Animasyon frame sayıları
var animation_frame_counts = {
	"idle": {"hframes": 10, "vframes": 1},
	"walk": {"hframes": 12, "vframes": 1},
}

func _ready() -> void:
	add_to_group("Villagers")
	randomize()
	
	# Başlangıç pozisyonu
	global_position.y = randf_range(0.0, VERTICAL_RANGE_MAX)
	_target_global_y = global_position.y  # Başlangıçta aynı y pozisyonunda
	# Z-Index'i ayak pozisyonuna göre ayarla
	var foot_y = get_foot_y_position()
	z_index = int(foot_y)
	
	# Başlangıç hedefi - mevcut pozisyona eşitle (idle başlasın)
	move_target_x = global_position.x
	
	# Gezinme zamanlayıcısı
	_wander_timer = Timer.new()
	_wander_timer.one_shot = true
	_wander_timer.timeout.connect(_on_wander_timer_timeout)
	add_child(_wander_timer)
	_start_wander_timer()
	
	# Başlangıç animasyonu - idle
	_current_animation_name = "idle"
	
	# Görselleri güncelle
	if appearance:
		update_visuals()
	else:
		play_animation("idle")

func _on_wander_timer_timeout():
	# Yeni bir hedef seç
	var wander_range = 300.0
	move_target_x = global_position.x + randf_range(-wander_range, wander_range)
	_target_global_y = randf_range(0.0, VERTICAL_RANGE_MAX)
	_start_wander_timer()

func _start_wander_timer():
	_wander_timer.wait_time = randf_range(_wander_interval_min, _wander_interval_max)
	_wander_timer.start()

func _physics_process(delta: float) -> void:
	# Hareket hesaplama
	var target_pos = Vector2(move_target_x, _target_global_y)
	var distance = global_position.distance_to(target_pos)
	
	# Y ekseni hareketi (yumuşak)
	var y_moving = false
	if abs(global_position.y - _target_global_y) > 0.5:
		y_moving = true
		var y_dir = sign(_target_global_y - global_position.y)
		global_position.y += y_dir * move_speed * 0.5 * delta
		# Z-Index'i ayak pozisyonuna göre güncelle
		var foot_y = get_foot_y_position()
		z_index = int(foot_y)
	
	# X ekseni hareketi
	var x_moving = false
	if abs(global_position.x - move_target_x) > 1.0:
		x_moving = true
		var direction = sign(move_target_x - global_position.x)
		global_position.x += direction * move_speed * delta
		
		# Sprite yönü
		if direction != 0:
			scale.x = direction
	
	# Animasyon seçimi - X veya Y ekseninde hareket varsa walk, yoksa idle
	# Distance threshold'u biraz artıralım (1.0 yerine 3.0) - daha kesin idle için
	var x_distance = abs(global_position.x - move_target_x)
	var y_distance = abs(global_position.y - _target_global_y)
	var actually_moving = (x_distance > 3.0) or (y_distance > 3.0)
	
	var target_anim = "idle" if not actually_moving else "walk"
	
	# Animasyon kontrolü
	if target_anim != _current_animation_name:
		print("[ConcubineNPC] DEBUG: Animasyon değişiyor: %s -> %s" % [_current_animation_name, target_anim])
		play_animation(target_anim)
		_current_animation_name = target_anim
		# Walk'a geçerken idle flag'ini reset et
		if target_anim == "walk":
			_idle_initialized = false
	elif target_anim == "idle":
		# İlk kez idle'a geçiyorsa play_animation çağır
		if not _idle_initialized:
			play_animation("idle")
			_idle_initialized = true
		# Idle animasyonu zaten oynuyor, bir şey yapmaya gerek yok
	# else: Animasyon aynı kalıyor, debug mesajı kaldırıldı

# Stil adı çıkarma (Worker'dan alındı, Cariye desteği eklendi)
# Ayak pozisyonunu hesapla (sprite offset'i ve yüksekliğini hesaba katarak)
func get_foot_y_position() -> float:
	# Sprite'lar position = Vector2(0, -48) offset'ine sahip
	# Bu demek oluyor ki sprite'ın merkezi global_position'dan 48 piksel yukarıda
	# Ayaklar sprite'ın alt kısmında, yani global_position.y + offset_y + (sprite_height / 2)
	var sprite_offset_y = 48.0  # Sprite offset'i
	
	# Body sprite'ın texture yüksekliğini al
	var sprite_height = 96.0  # Varsayılan yükseklik
	if is_instance_valid(body_sprite) and body_sprite.texture:
		var texture = body_sprite.texture
		if texture is CanvasTexture:
			var canvas_texture = texture as CanvasTexture
			if is_instance_valid(canvas_texture.diffuse_texture):
				sprite_height = canvas_texture.diffuse_texture.get_height()
		elif texture is Texture2D:
			sprite_height = texture.get_height()
	
	# Ayak pozisyonu = global_position.y + sprite_offset + sprite'ın alt yarısı
	return global_position.y + sprite_offset_y + (sprite_height / 2.0)

func get_style_from_texture_path(path: String) -> String:
	if path.is_empty(): return "default"
	
	var filename = path.get_file()
	var base_name = filename.get_basename()
	var parts = base_name.split("_")
	if parts.is_empty(): return "default"
	
	# Cariye asset'lerini kontrol et (hem walk hem idle için)
	if parts[0] == "cariye":
		# Body için: cariye_walk_body.png -> "cariye"
		# Body için: cariye_idle_body.png -> "cariye"
		if parts.size() >= 3 and parts[2] == "body":
			return "cariye"
		# Hair için: cariye_walk_hair0.png -> "cariye_hair0"
		# Hair için: cariye_idle_hair1.png -> "cariye_hair1"
		# Hair için: cariye_walk_hair2.png -> "cariye_hair2"
		if parts.size() >= 3 and parts[2].begins_with("hair"):
			var hair_num = parts[2]  # hair0, hair1, hair2
			return "cariye_" + hair_num
		# Bottom için: cariye_walk_bottom1.png -> "cariye_bottom"
		# Bottom için: cariye_idle_bottom0.png -> "cariye_bottom"
		# Bottom için: cariye_idle_bottom1.png -> "cariye_bottom"
		if parts.size() >= 3 and parts[2].begins_with("bottom"):
			return "cariye_bottom"
		# Top için: cariye_walk_top1.png -> "cariye_top"
		# Top için: cariye_idle_top0.png -> "cariye_top"
		# Top için: cariye_idle_top1.png -> "cariye_top"
		if parts.size() >= 3 and parts[2].begins_with("top"):
			return "cariye_top"
		# Varsayılan olarak "cariye" döndür
		return "cariye"
	
	if parts[0] == "shirt" or parts[0] == "shirtless":
		return parts[0]
	elif parts[0].begins_with("mouth"):
		var style_num = parts[0].trim_prefix("mouth")
		if style_num.is_valid_int(): return style_num
	elif parts[0].begins_with("eyes"):
		var style_num = parts[0].trim_prefix("eyes")
		if style_num.is_valid_int(): return style_num
	else:
		var style_keywords = ["basic", "short", "style1", "style2"]
		for i in range(1, parts.size()):
			if parts[i] in style_keywords:
				return parts[i]
	
	return "default"

func play_animation(anim_name: String):
	if not is_instance_valid(animation_player):
		printerr("[ConcubineNPC] ERROR: animation_player geçersiz!")
		return
	
	# Animasyon adı
	var actual_anim_name = anim_name
	
	_current_animation_name = anim_name
	
	# Animasyonu oynat
	if animation_player.has_animation(actual_anim_name):
		animation_player.play(actual_anim_name)
		if anim_name == "walk":
			animation_player.seek(0.0, true)
	else:
		printerr("[ConcubineNPC] ERROR: Animasyon bulunamadı: ", actual_anim_name)
	
	# Texture seti seçimi ve görsel güncelleme
	var texture_set_to_use = null
	match anim_name:
		"idle":
			texture_set_to_use = idle_textures  # Idle için özel texture seti
		"walk":
			texture_set_to_use = walk_textures
		_:
			texture_set_to_use = walk_textures # Fallback
	
	if texture_set_to_use != null:
		var parts_to_update = {
			"body": body_sprite, "pants": pants_sprite, "clothing": clothing_sprite,
			"mouth": mouth_sprite, "eyes": eyes_sprite, "hair": hair_sprite
		}
		var reset_frame = (anim_name == "idle" or anim_name == "walk")
		
		for part_name in parts_to_update:
			var sprite: Sprite2D = parts_to_update[part_name]
			var original_canvas_texture: CanvasTexture = null
			if is_instance_valid(sprite) and appearance:
				match part_name:
					"body": original_canvas_texture = appearance.body_texture
					"pants": original_canvas_texture = appearance.pants_texture
					"clothing": original_canvas_texture = appearance.clothing_texture
					"mouth": original_canvas_texture = appearance.mouth_texture
					"eyes": original_canvas_texture = appearance.eyes_texture
					"hair": original_canvas_texture = appearance.hair_texture
			
			if not is_instance_valid(sprite):
				continue
			if not is_instance_valid(original_canvas_texture):
				sprite.hide()
				continue
			
			var original_diffuse_path = original_canvas_texture.diffuse_texture.resource_path if is_instance_valid(original_canvas_texture.diffuse_texture) else ""
			var style = get_style_from_texture_path(original_diffuse_path)
			
			if texture_set_to_use.has(part_name) and texture_set_to_use[part_name].has(style):
				var textures = texture_set_to_use[part_name][style]
				var new_canvas_texture = CanvasTexture.new()
				
				# Runtime'da texture yükleme (bottom ve top için)
				var diffuse_texture = textures["diffuse"]
				if diffuse_texture == null and (style == "cariye_bottom" or style == "cariye_top"):
					# Orijinal path'den dosya adını al ve animasyon state'ine göre doğru versiyonu yükle
					if not original_diffuse_path.is_empty():
						var filename = original_diffuse_path.get_file()
						var base_name = filename.get_basename()
						var parts = base_name.split("_")
						
						# Animasyon state'ine göre doğru path'i oluştur
						var path_to_use = ""
						if parts.size() >= 3:
							# cariye_walk_bottom1.png -> cariye_idle_bottom1.png (anim_name'e göre)
							# cariye_idle_top0.png -> cariye_idle_top0.png (zaten doğru)
							var item_type = parts[2]  # bottom1, top1, bottom0, top0
							path_to_use = "res://assets/concubine assets/"
							
							if "bottom" in item_type:
								path_to_use += "bottom/cariye_" + anim_name + "_" + item_type + ".png"
							elif "top" in item_type:
								path_to_use += "top/cariye_" + anim_name + "_" + item_type + ".png"
							
							# Eğer dosya yoksa ve walk animasyonuysa, bottom0/top0 -> bottom1/top1 fallback
							if not ResourceLoader.exists(path_to_use) and anim_name == "walk":
								if "bottom0" in item_type:
									path_to_use = path_to_use.replace("bottom0", "bottom1")
									print("[ConcubineNPC] DEBUG: bottom0 -> bottom1 fallback: %s" % path_to_use)
								elif "top0" in item_type:
									path_to_use = path_to_use.replace("top0", "top1")
									print("[ConcubineNPC] DEBUG: top0 -> top1 fallback: %s" % path_to_use)
						
						if path_to_use.is_empty():
							path_to_use = original_diffuse_path  # Fallback: orijinal path
						
						if ResourceLoader.exists(path_to_use):
							diffuse_texture = load(path_to_use)
							textures["diffuse"] = diffuse_texture  # Cache için
							print("[ConcubineNPC] DEBUG: Runtime texture yüklendi: anim=%s, original=%s, loaded=%s" % [anim_name, original_diffuse_path, path_to_use])
						else:
							print("[ConcubineNPC] DEBUG: Texture bulunamadı: %s (original: %s)" % [path_to_use, original_diffuse_path])
				
				if textures.has("diffuse") and textures["diffuse"] != null:
					new_canvas_texture.diffuse_texture = textures["diffuse"]
				else:
					sprite.hide()
					continue
				
				if textures.has("normal") and textures["normal"] != null:
					new_canvas_texture.normal_texture = textures["normal"]
				
				# Frame sayılarını animasyon durumuna göre ayarla (texture değişmeden önce)
				var frames = animation_frame_counts.get(anim_name, {"hframes": 12, "vframes": 1})
				sprite.hframes = frames["hframes"]
				sprite.vframes = frames["vframes"]
				if part_name == "pants" or part_name == "clothing":
					print("[ConcubineNPC] DEBUG: %s için frame sayıları ayarlandı: anim=%s, hframes=%d, vframes=%d, current_frame=%d" % [part_name, anim_name, frames["hframes"], frames["vframes"], sprite.frame])
				
				sprite.texture = new_canvas_texture
				
				match part_name:
					"body": sprite.modulate = appearance.body_tint
					"pants": sprite.modulate = appearance.pants_tint
					"clothing": sprite.modulate = appearance.clothing_tint
					"hair": sprite.modulate = appearance.hair_tint
					_: sprite.modulate = Color.WHITE
				
				sprite.show()
				# Frame'i her zaman sıfırla (texture değiştiğinde)
				sprite.frame = 0
			else:
				# Fallback: Orijinal texture kullan
				sprite.texture = original_canvas_texture
				
				# Frame sayılarını animasyon durumuna göre ayarla
				var frames = animation_frame_counts.get(anim_name, {"hframes": 12, "vframes": 1})
				sprite.hframes = frames["hframes"]
				sprite.vframes = frames["vframes"]
				
				match part_name:
					"body": sprite.modulate = appearance.body_tint
					"pants": sprite.modulate = appearance.pants_tint
					"clothing": sprite.modulate = appearance.clothing_tint
					"hair": sprite.modulate = appearance.hair_tint
					_: sprite.modulate = Color.WHITE
				sprite.show()
				# Frame'i her zaman sıfırla (texture değiştiğinde)
				sprite.frame = 0

# _stop_idle_animation fonksiyonu artık gerekli değil - idle animasyonu normal şekilde oynuyor

func _ensure_idle_textures_and_frames():
	# Idle durumunda texture'ların doğru olduğundan ve frame'lerin 0'da olduğundan emin ol
	if not appearance:
		return
	
	# Texture seti seçimi (idle için walk_textures kullanıyoruz)
	var texture_set_to_use = walk_textures
	
	if texture_set_to_use != null:
		var parts_to_update = {
			"body": body_sprite, "pants": pants_sprite, "clothing": clothing_sprite,
			"mouth": mouth_sprite, "eyes": eyes_sprite, "hair": hair_sprite
		}
		
		for part_name in parts_to_update:
			var sprite: Sprite2D = parts_to_update[part_name]
			var original_canvas_texture: CanvasTexture = null
			if is_instance_valid(sprite) and appearance:
				match part_name:
					"body": original_canvas_texture = appearance.body_texture
					"pants": original_canvas_texture = appearance.pants_texture
					"clothing": original_canvas_texture = appearance.clothing_texture
					"mouth": original_canvas_texture = appearance.mouth_texture
					"eyes": original_canvas_texture = appearance.eyes_texture
					"hair": original_canvas_texture = appearance.hair_texture
			
			if not is_instance_valid(sprite):
				continue
			if not is_instance_valid(original_canvas_texture):
				sprite.hide()
				continue
			
			var original_diffuse_path = original_canvas_texture.diffuse_texture.resource_path if is_instance_valid(original_canvas_texture.diffuse_texture) else ""
			var style = get_style_from_texture_path(original_diffuse_path)
			
			if texture_set_to_use.has(part_name) and texture_set_to_use[part_name].has(style):
				var textures = texture_set_to_use[part_name][style]
				var new_canvas_texture = CanvasTexture.new()
				
				if textures.has("diffuse") and textures["diffuse"] != null:
					new_canvas_texture.diffuse_texture = textures["diffuse"]
				else:
					sprite.hide()
					continue
				
				if textures.has("normal") and textures["normal"] != null:
					new_canvas_texture.normal_texture = textures["normal"]
				
				sprite.texture = new_canvas_texture
				
				match part_name:
					"body": sprite.modulate = appearance.body_tint
					"pants": sprite.modulate = appearance.pants_tint
					"clothing": sprite.modulate = appearance.clothing_tint
					"hair": sprite.modulate = appearance.hair_tint
					_: sprite.modulate = Color.WHITE
				
				sprite.show()
				sprite.frame = 0  # Frame'i 0'a ayarla
			else:
				# Fallback: Orijinal texture kullan
				sprite.texture = original_canvas_texture
				match part_name:
					"body": sprite.modulate = appearance.body_tint
					"pants": sprite.modulate = appearance.pants_tint
					"clothing": sprite.modulate = appearance.clothing_tint
					"hair": sprite.modulate = appearance.hair_tint
					_: sprite.modulate = Color.WHITE
				sprite.show()
				sprite.frame = 0  # Frame'i 0'a ayarla
		
		# Frame sayılarını ayarla (idle için)
		var frames = animation_frame_counts.get("idle", {"hframes": 12, "vframes": 1})
		var hf = frames["hframes"]
		var vf = frames["vframes"]
		
		var sprites_to_set_frames = [body_sprite, pants_sprite, clothing_sprite, mouth_sprite, eyes_sprite, hair_sprite]
		for sprite in sprites_to_set_frames:
			if is_instance_valid(sprite):
				sprite.hframes = hf
				sprite.vframes = vf
				sprite.frame = 0  # Tekrar 0'a ayarla

func update_visuals():
	if not appearance:
		return
	
	# Mevcut animasyonu tekrar oynat
	if _current_animation_name != "":
		play_animation(_current_animation_name)
	else:
		play_animation("idle")
