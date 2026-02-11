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

# Durum sistemi (Worker'dan alındı)
enum State {
	IDLE,              # Boşta geziyor
	GOING_TO_SLEEP,    # Kamp ateşine gidiyor
	SLEEPING,          # Kamp ateşinde yatıyor
	GOING_TO_MISSION,  # Göreve gidiyor (ekran dışına)
	ON_MISSION,        # Görevde (ekran dışında)
	RETURNING_FROM_MISSION  # Görevden dönüyor
}
var current_state = State.IDLE

# Rutin Zamanlaması için Rastgele Farklar (Worker sistemindeki gibi)
var wake_up_hour_offset: int = 2 # Worker'lardan 2 saat daha geç uyan (8:00'da başla)
var wake_up_minute_offset: int = randi_range(15, 30) # 15-30 dakika arası (8:15-8:30 arası uyan)
var sleep_minute_offset: int = randi_range(0, 60) # 0-60 dakika arası (worker'lar gibi)

# Uyku denemesi başarısız olduğunda tekrar denemeyi engellemek için (Worker sistemindeki gibi)
var _sleep_attempt_failed: bool = false
var _sleep_retry_timer: Timer
var _sleep_retry_delay: float = 30.0 # 30 saniye sonra tekrar dene

# Kamp ateşi referansı
var campfire_node: Node2D = null

# Hareket Değişkenleri
var move_target_x: float = 0.0
var move_speed: float = randf_range(40.0, 60.0) # Pixel per second
var _target_global_y: float = 0.0
const VERTICAL_RANGE_MAX: float = 25.0
var _offscreen_exit_x: float = 0.0  # Ekrandan çıktığı X pozisyonu

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
@onready var name_plate_container: PanelContainer = $NamePlateContainer
@onready var name_plate: Label = $NamePlateContainer/NamePlate

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
	
	# Kamp ateşini bul
	campfire_node = get_tree().get_first_node_in_group("Housing")
	
	# MissionManager sinyallerini dinle
	var mission_manager = get_node_or_null("/root/MissionManager")
	if mission_manager:
		if not mission_manager.mission_started.is_connected(_on_mission_started):
			mission_manager.mission_started.connect(_on_mission_started)
		if not mission_manager.mission_completed.is_connected(_on_mission_completed):
			mission_manager.mission_completed.connect(_on_mission_completed)
		if not mission_manager.mission_cancelled.is_connected(_on_mission_cancelled):
			mission_manager.mission_cancelled.connect(_on_mission_cancelled)
	
	# Başlangıç pozisyonu
	global_position.y = randf_range(0.0, VERTICAL_RANGE_MAX)
	_target_global_y = global_position.y  # Başlangıçta aynı y pozisyonunda
	# Z-Index'i ayak pozisyonuna göre ayarla
	# Su yansımasında görünmesi için z_index'i su sprite'ının z_index'inden (20) düşük tutmalıyız
	var foot_y = get_foot_y_position()
	z_index = _calculate_z_index_from_foot_y(foot_y)
	
	# Başlangıç hedefi - mevcut pozisyona eşitle (idle başlasın)
	move_target_x = global_position.x
	
	# Gezinme zamanlayıcısı
	_wander_timer = Timer.new()
	
	# Uyku retry timer'ı oluştur (Worker sistemindeki gibi)
	_sleep_retry_timer = Timer.new()
	_sleep_retry_timer.wait_time = _sleep_retry_delay
	_sleep_retry_timer.one_shot = true
	_sleep_retry_timer.timeout.connect(_on_sleep_retry_timer_timeout)
	add_child(_sleep_retry_timer)
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
	
	# İsmi güncelle
	update_concubine_name()
	
	# NamePlate scale'ini başlangıçta ayarla
	if name_plate_container:
		if scale.x < 0:
			name_plate_container.scale.x = -1
		else:
			name_plate_container.scale.x = 1
	
	# Sahne yeniden yüklendiğinde (örn. ormandan dönüş): bu cariye hâlâ görevdeyse ekranda gösterme
	# active_missions anahtarları int; save/load sonrası concubine_id float (1.0) olabildiği için int ile kontrol et
	if mission_manager and "active_missions" in mission_manager and concubine_id >= 0:
		var active = mission_manager.get("active_missions")
		if active is Dictionary and active.has(int(concubine_id)):
			current_state = State.ON_MISSION
			visible = false
			_wander_timer.stop()

# Cariye ismini güncelle (Worker'daki Update_Villager_Name gibi)
func update_concubine_name() -> void:
	if not name_plate:
		return
	
	if concubine_data and concubine_data.name:
		name_plate.text = concubine_data.name
	else:
		name_plate.text = "İsimsiz Cariye"
		if concubine_data:
			printerr("[ConcubineNPC] Cariye (ID: %d) için isim bulunamadı!" % concubine_id)
	
	# NamePlate'i varsayılan olarak görünmez yap (sadece en yakın NPC'nin ismi görünecek)
	if name_plate_container:
		name_plate_container.visible = false

# Uyku denemesi başarısız olduktan sonra timer dolduğunda çağrılır
func _on_sleep_retry_timer_timeout():
	# <<< YENİ: Timer doldu, tekrar denemeyi serbest bırak >>>
	_sleep_attempt_failed = false

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
	# Hareket hesaplama (önce hesapla, sonra state handler'larda kullan)
	# X ve Y eksenlerinde ayrı ayrı kontrol et (Worker sistemindeki gibi)
	var x_distance = abs(global_position.x - move_target_x)
	var y_distance = abs(global_position.y - _target_global_y)
	var moving = (x_distance > 1.0) or (y_distance > 1.0)  # Herhangi bir eksende hareket varsa moving = true
	
	# Durum bazlı davranış
	match current_state:
		State.IDLE:
			_handle_idle_state(delta)
		State.GOING_TO_SLEEP:
			_handle_going_to_sleep_state(delta, moving)
		State.SLEEPING:
			_handle_sleeping_state()
		State.GOING_TO_MISSION:
			_handle_going_to_mission_state(delta, moving)
		State.ON_MISSION:
			_handle_on_mission_state()
		State.RETURNING_FROM_MISSION:
			_handle_returning_from_mission_state(delta)
	
	# SLEEPING ve ON_MISSION state'lerinde hareket etme
	if current_state == State.SLEEPING or current_state == State.ON_MISSION:
		return
	
	# Y ekseni hareketi (yumuşak)
	if y_distance > 1.0:  # Threshold 1.0 (X ile aynı)
		var y_dir = sign(_target_global_y - global_position.y)
		global_position.y += y_dir * move_speed * 0.5 * delta
		# Z-Index'i ayak pozisyonuna göre güncelle
		# Su yansımasında görünmesi için z_index'i su sprite'ının z_index'inden (20) düşük tutmalıyız
		var foot_y = get_foot_y_position()
		z_index = _calculate_z_index_from_foot_y(foot_y)
	
	# X ekseni hareketi
	if x_distance > 1.0:
		var direction = sign(move_target_x - global_position.x)
		global_position.x += direction * move_speed * delta
		
		# Sprite yönü
		if direction != 0:
			scale.x = direction
	
	# NamePlate scale kontrolü (Worker sistemindeki gibi)
	# Karakter sola dönünce (scale.x < 0) NamePlate'i tersine çevir ki isim düzgün okunsun
	if name_plate_container:
		if scale.x < 0:
			name_plate_container.scale.x = -1
		else:
			name_plate_container.scale.x = 1
	
	# Animasyon seçimi - X veya Y ekseninde hareket varsa walk, yoksa idle
	# (x_distance ve y_distance zaten yukarıda hesaplandı)
	var actually_moving = (x_distance > 3.0) or (y_distance > 3.0)
	
	var target_anim = "idle" if not actually_moving else "walk"
	
	# Animasyon kontrolü (SLEEPING ve ON_MISSION state'lerinde animasyon değişmesin)
	if current_state != State.SLEEPING and current_state != State.ON_MISSION:
		if target_anim != _current_animation_name:
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

	# Köylüler birbirine çok girmesin (cariye/worker/trader arası mesafe)
	if visible:
		_apply_villager_separation()

# Köy NPC'leri arası çok hafif mesafe (neredeyse üst üste gelince hafifçe it, alan dışına çıkmasın)
func _apply_villager_separation() -> void:
	const MIN_SPACING: float = 10.0
	const STRENGTH: float = 0.06
	var villagers = get_tree().get_nodes_in_group("Villagers")
	var separation = Vector2.ZERO
	for other in villagers:
		if other == self or not is_instance_valid(other):
			continue
		if not other is Node2D:
			continue
		var other_pos = (other as Node2D).global_position
		var dist = global_position.distance_to(other_pos)
		if dist < MIN_SPACING and dist > 0.01:
			var away = (global_position - other_pos).normalized()
			separation += away * (MIN_SPACING - dist)
	if separation.length_squared() > 0.0:
		global_position += separation * STRENGTH

# Stil adı çıkarma (Worker'dan alındı, Cariye desteği eklendi)
# Ayak pozisyonunu hesapla (sprite offset'i ve yüksekliğini hesaba katarak)
func get_foot_y_position() -> float:
	# Sprite'lar position = Vector2(0, -48) offset'ine sahip
	# Sprite merkezi global_position'dan 48 piksel yukarıda → merkez_y = global_position.y - 48
	# Ayaklar = sprite merkezi + sprite_height/2 → foot_y = global_position.y - 48 + (sprite_height / 2)
	var sprite_offset_y = 48.0  # Sprite offset'i (negatif = yukarı)
	
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
	
	# Ayak pozisyonu = global_position.y - offset + sprite'ın alt yarısı
	return global_position.y - sprite_offset_y + (sprite_height / 2.0)

# Z-index'i ayak pozisyonuna göre normalize et (su yansımasında görünmesi için 0-19 aralığında)
func _calculate_z_index_from_foot_y(foot_y: float) -> int:
	# foot_y'yi normalize et: VERTICAL_RANGE_MAX + sprite_offset + sprite_height/2 maksimum değer olabilir
	# Yaklaşık maksimum foot_y: 25 + 48 + 96 = 169, minimum: 0 + 48 + 48 = 96
	# NPC'lerin z_index'lerini 6-19 aralığına normalize et (kamp ateşinden yüksek, su sprite'ından düşük)
	# Oyuncuyla aynı aralıkta olmalı ki pozisyona göre doğru sorting yapılsın
	const CAMPFIRE_Z_INDEX: int = 5  # Kamp ateşinin z_index'i
	const WATER_Z_INDEX: int = 20  # Su sprite'ının z_index'i
	const MIN_Z_INDEX: int = CAMPFIRE_Z_INDEX + 1  # Kamp ateşinden yüksek (6)
	const MAX_Z_INDEX: int = WATER_Z_INDEX - 1  # Su sprite'ından düşük (19)
	
	var sprite_offset_y = 48.0
	var sprite_height = 96.0  # Varsayılan yükseklik
	if is_instance_valid(body_sprite) and body_sprite.texture:
		var texture = body_sprite.texture
		if texture is CanvasTexture:
			var canvas_texture = texture as CanvasTexture
			if is_instance_valid(canvas_texture.diffuse_texture):
				sprite_height = canvas_texture.diffuse_texture.get_height()
		elif texture is Texture2D:
			sprite_height = texture.get_height()
	
	# foot_y = global_position.y - 48 + height/2 → yaklaşık 0 (y=0) ile VERTICAL_RANGE_MAX (y=25) arası
	var max_foot_y = VERTICAL_RANGE_MAX - sprite_offset_y + (sprite_height / 2.0)
	var min_foot_y = 0.0 - sprite_offset_y + (sprite_height / 2.0)
	var range_foot_y = max_foot_y - min_foot_y
	
	# Division by zero kontrolü
	if range_foot_y <= 0.0:
		return (MIN_Z_INDEX + MAX_Z_INDEX) / 2  # Varsayılan orta değer (12-13)
	
	var normalized_foot_y = (foot_y - min_foot_y) / range_foot_y
	normalized_foot_y = clamp(normalized_foot_y, 0.0, 1.0)  # 0-1 aralığına sınırla
	# 6-19 aralığına normalize et (kamp ateşinden yüksek, su sprite'ından düşük)
	var z_index_range = MAX_Z_INDEX - MIN_Z_INDEX
	return MIN_Z_INDEX + int(normalized_foot_y * z_index_range)

# State handler fonksiyonları
func _handle_idle_state(delta: float) -> void:
	# Gece kontrolü - kamp ateşine git
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and is_instance_valid(campfire_node):
		var current_hour = time_manager.get_hour()
		var current_minute = time_manager.get_minute() if time_manager.has_method("get_minute") else 0
		var wake_hour = time_manager.WAKE_UP_HOUR
		var sleep_hour = time_manager.SLEEP_HOUR
		# Sadece gece saatlerinde (SLEEP_HOUR ile WAKE_UP_HOUR arası) uykuya git
		# <<< YENİ: Başarısız deneme flag'ini kontrol et >>>
		var is_daytime = current_hour >= wake_hour and current_hour < sleep_hour
		if not is_daytime and current_hour >= sleep_hour and current_minute >= sleep_minute_offset and not _sleep_attempt_failed:
			current_state = State.GOING_TO_SLEEP
			move_target_x = campfire_node.global_position.x
			_target_global_y = randf_range(0.0, VERTICAL_RANGE_MAX)
			_wander_timer.stop()
			return
	
	# Normal idle davranışı - wander timer çalışıyor (hareket _physics_process'te yapılıyor)

func _handle_going_to_sleep_state(delta: float, moving: bool) -> void:
	# NOT: GOING_TO_SLEEP state'inde sabah kontrolü YAPILMAMALI
	# Çünkü cariye henüz kamp ateşine varmamış, bu yüzden uyandırılmamalı
	# Sabah kontrolü sadece SLEEPING state'inde yapılmalı
	
	# Kamp ateşine doğru yürü (hareket _physics_process'te yapılıyor)
	# Kamp ateşine vardı mı? (Worker sistemindeki gibi - hareket etmiyorsa varmış demektir)
	# Ayrıca kamp ateşine yakınlık kontrolü de ekle (mesafe < 50.0)
	var distance_to_campfire = 9999.0
	if is_instance_valid(campfire_node):
		distance_to_campfire = global_position.distance_to(campfire_node.global_position)
	
	if (not moving or distance_to_campfire < 50.0) and is_instance_valid(campfire_node):
		# Kamp ateşine vardı, add_occupant kontrolü yap (Worker sistemindeki gibi)
		var time_manager = get_node_or_null("/root/TimeManager")
		var is_sleep_time = true
		if time_manager:
			var current_hour = time_manager.get_hour()
			var wake_hour = time_manager.WAKE_UP_HOUR
			var sleep_hour = time_manager.SLEEP_HOUR
			is_sleep_time = current_hour >= sleep_hour or current_hour < wake_hour
		
		if is_sleep_time:
			# Kamp ateşine eklemeyi dene
			var can_sleep = true
			if campfire_node.has_method("add_occupant"):
				var add_result = campfire_node.add_occupant(self)
				if not add_result:
					# Eklenemedi (kapasite dolu), uyuyamaz - IDLE'e dön
					can_sleep = false
					# <<< YENİ: Başarısız deneme flag'ini set et ve timer başlat >>>
					_sleep_attempt_failed = true
					_sleep_retry_timer.start()
					current_state = State.IDLE
					visible = true
					_start_wander_timer()
					return
			
			if can_sleep:
				# <<< YENİ: Başarılı oldu, flag'i reset et >>>
				_sleep_attempt_failed = false
				_sleep_retry_timer.stop()
				current_state = State.SLEEPING
				visible = false  # Görünmez ol (kamp ateşine girdi)
				_wander_timer.stop()
				# Kamp ateşinin pozisyonuna yerleştir
				global_position = Vector2(campfire_node.global_position.x, randf_range(0.0, VERTICAL_RANGE_MAX))
				move_target_x = global_position.x  # Dur
				_target_global_y = global_position.y

func _handle_sleeping_state() -> void:
	# Kamp ateşinde yatıyor - görünmez ve hareketsiz
	# Uyanma kontrolü (Worker sistemindeki gibi, ama 2 saat daha geç)
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		var current_hour = time_manager.get_hour()
		var current_minute = time_manager.get_minute() if time_manager.has_method("get_minute") else 0
		var wake_hour = time_manager.WAKE_UP_HOUR + wake_up_hour_offset # 8:00'da başla
		var sleep_hour = time_manager.SLEEP_HOUR
		# WAKE_UP_HOUR + 2 saat'te offset'e göre uyan (sabah 8:15-8:30 arası)
		# Worker sistemindeki gibi: Sadece gündüz saatlerinde (wake_hour ile sleep_hour arası) uyan
		var should_wake = false
		if current_hour >= wake_hour and current_hour < sleep_hour:
			# wake_hour'dan sonra veya tam wake_hour'da offset geçmişse uyan
			if current_hour > wake_hour:
				should_wake = true
			elif current_hour == wake_hour and current_minute >= wake_up_minute_offset:
				should_wake = true
		
		if should_wake:
			# Barınaktan çıkar (CampFire)
			if is_instance_valid(campfire_node) and campfire_node.has_method("remove_occupant"):
				campfire_node.remove_occupant(self)
			
			current_state = State.IDLE
			visible = true  # Görünür ol
			# Kamp ateşinden çık (Worker sistemindeki gibi)
			if is_instance_valid(campfire_node):
				global_position = Vector2(campfire_node.global_position.x, randf_range(0.0, VERTICAL_RANGE_MAX))
				var wander_range = 150.0
				move_target_x = global_position.x + randf_range(-wander_range, wander_range)
				_target_global_y = randf_range(0.0, VERTICAL_RANGE_MAX)
			_start_wander_timer()

func _handle_going_to_mission_state(delta: float, moving: bool) -> void:
	# Göreve gidiyor - ekran dışına doğru yürü (hareket _physics_process'te yapılıyor)
	# Gerçekten ekranın dışına çıktığından emin ol
	var viewport_rect = get_viewport().get_visible_rect()
	var is_offscreen = global_position.x < viewport_rect.position.x - 100.0 or global_position.x > viewport_rect.position.x + viewport_rect.size.x + 100.0
	
	# Hedefe vardı mı VE ekranın dışına çıktı mı?
	if not moving and is_offscreen:
		# Ekran dışına çıktı
		_offscreen_exit_x = global_position.x
		current_state = State.ON_MISSION
		visible = false

func _handle_on_mission_state() -> void:
	# Görevde - ekran dışında bekliyor
	# MissionManager'dan görev bitiş sinyali gelecek
	pass

func _handle_returning_from_mission_state(delta: float) -> void:
	# Görevden dönüyor - ekrandan girdiği yerden geri geliyor (hareket _physics_process'te yapılıyor)
	# Kamp ateşine vardı mı?
	if is_instance_valid(campfire_node):
		var distance_to_campfire = global_position.distance_to(campfire_node.global_position)
		if distance_to_campfire < 100.0:  # Kamp ateşine yakınsa
			# Gece kontrolü - gece ise direkt uykuya git
			var time_manager = get_node_or_null("/root/TimeManager")
			if time_manager:
				var current_hour = time_manager.get_hour()
				var current_minute = time_manager.get_minute() if time_manager.has_method("get_minute") else 0
				var wake_hour = time_manager.WAKE_UP_HOUR
				var sleep_hour = time_manager.SLEEP_HOUR
				# Sadece gece saatlerinde (SLEEP_HOUR ile WAKE_UP_HOUR arası) uykuya git
				var is_daytime = current_hour >= wake_hour and current_hour < sleep_hour
				if not is_daytime and current_hour >= sleep_hour and current_minute >= sleep_minute_offset:
					# Gece - direkt uykuya git
					current_state = State.GOING_TO_SLEEP
					move_target_x = campfire_node.global_position.x
					_target_global_y = randf_range(0.0, VERTICAL_RANGE_MAX)
					_wander_timer.stop()
				else:
					# Gündüz - normal idle
					current_state = State.IDLE
					_start_wander_timer()
			else:
				# TimeManager yoksa normal idle
				current_state = State.IDLE
				_start_wander_timer()

# Mission signal handler'ları
func _on_mission_started(cariye_id: int, mission_id: String) -> void:
	# Bu cariyenin görevi başladı - IDLE, RETURNING_FROM_MISSION veya GOING_TO_SLEEP durumlarında göreve gidebilir
	if cariye_id == concubine_id and (current_state == State.IDLE or current_state == State.RETURNING_FROM_MISSION or current_state == State.GOING_TO_SLEEP):
		# Bu cariyenin görevi başladı - ekran dışına git (askerlerle aynı yön: mission_exit_x)
		current_state = State.GOING_TO_MISSION
		_wander_timer.stop()
		
		var exit_x: float = 0.0
		var mm = get_node_or_null("/root/MissionManager")
		if mm:
			var extra = mm.get_raid_mission_extra(mission_id)
			var ex = extra.get("mission_exit_x", 0)
			if ex != null and ex != 0:
				exit_x = float(ex)
		if exit_x == 0.0:
			var exit_distance = 4800.0
			exit_x = -exit_distance if randf() < 0.5 else exit_distance
		move_target_x = exit_x
		_target_global_y = randf_range(0.0, VERTICAL_RANGE_MAX)

func _on_mission_completed(cariye_id: int, mission_id: String, successful: bool, results: Dictionary) -> void:
	# Görev tamamlandı - hem GOING_TO_MISSION hem de ON_MISSION durumlarını kontrol et
	if cariye_id == concubine_id and (current_state == State.ON_MISSION or current_state == State.GOING_TO_MISSION):
		# Görev tamamlandı - geri dön
		current_state = State.RETURNING_FROM_MISSION
		visible = true
		
		# Eğer henüz ekranın dışına çıkmadıysa, şu anki pozisyonu kullan
		if _offscreen_exit_x == 0.0:
			# Henüz ekranın dışına çıkmamış, şu anki pozisyonu kullan
			var viewport_rect = get_viewport().get_visible_rect()
			if global_position.x < viewport_rect.position.x:
				_offscreen_exit_x = viewport_rect.position.x - 100.0
			else:
				_offscreen_exit_x = viewport_rect.position.x + viewport_rect.size.x + 100.0
		
		# Ekrandan çıktığı yerden geri gir - ekranın dışından başla
		var screen_width = get_viewport().get_visible_rect().size.x
		var start_x = 0.0
		if _offscreen_exit_x < 0:
			# Soldan çıkmıştı, soldan gir (ekranın dışından)
			start_x = _offscreen_exit_x - 100.0
		else:
			# Sağdan çıkmıştı, sağdan gir (ekranın dışından)
			start_x = _offscreen_exit_x + 100.0
		
		global_position = Vector2(start_x, randf_range(0.0, VERTICAL_RANGE_MAX))
		
		# Kamp ateşine doğru git
		if is_instance_valid(campfire_node):
			move_target_x = campfire_node.global_position.x
			_target_global_y = randf_range(0.0, VERTICAL_RANGE_MAX)
		

func _on_mission_cancelled(cariye_id: int, mission_id: String) -> void:
	if cariye_id == concubine_id and (current_state == State.GOING_TO_MISSION or current_state == State.ON_MISSION):
		# Görev iptal edildi - geri dön
		current_state = State.RETURNING_FROM_MISSION
		visible = true
		
		# Ekrandan çıktığı yerden geri gir - ekranın dışından başla
		var start_x = 0.0
		if _offscreen_exit_x < 0:
			# Soldan çıkmıştı, soldan gir (ekranın dışından)
			start_x = _offscreen_exit_x - 100.0
		else:
			# Sağdan çıkmıştı, sağdan gir (ekranın dışından)
			start_x = _offscreen_exit_x + 100.0
		
		global_position = Vector2(start_x, randf_range(0.0, VERTICAL_RANGE_MAX))
		
		# Kamp ateşine doğru git
		if is_instance_valid(campfire_node):
			move_target_x = campfire_node.global_position.x
			_target_global_y = randf_range(0.0, VERTICAL_RANGE_MAX)
		

# Saat değişiminde state transition kontrolü (VillageManager'dan çağrılır)
func check_hour_transition(new_hour: int) -> void:
	var time_manager = get_node_or_null("/root/TimeManager")
	if not time_manager:
		return
	
	var current_minute: int = time_manager.get_minute() if time_manager.has_method("get_minute") else 0
	
	match current_state:
		State.SLEEPING:
			# Uyanma kontrolü - Sadece tam wake_hour'da offset'e göre uyan
			# Gündüz saatlerinde (wake_hour ile SLEEP_HOUR arası) tekrar uyanma kontrolü yapma
			var wake_hour = time_manager.WAKE_UP_HOUR + wake_up_hour_offset # 8:00'da başla
			var sleep_hour = time_manager.SLEEP_HOUR
			# Sadece tam wake_hour'da uyan (gündüz saatlerinde tekrar uyanma kontrolü yapma)
			var should_wake = false
			if new_hour == wake_hour and current_minute >= wake_up_minute_offset:
				should_wake = true
			# Eğer saat wake_hour'dan sonra ama SLEEP_HOUR'dan önceyse, zaten uyanmış olmalı
			# Bu durumda tekrar uyanma kontrolü yapma
			
			if should_wake:
				# Barınaktan çıkar (CampFire)
				if is_instance_valid(campfire_node) and campfire_node.has_method("remove_occupant"):
					campfire_node.remove_occupant(self)
				
				current_state = State.IDLE
				visible = true
				# Kamp ateşinden çık
				if is_instance_valid(campfire_node):
					global_position = Vector2(campfire_node.global_position.x, randf_range(0.0, VERTICAL_RANGE_MAX))
					var wander_range = 150.0
					move_target_x = global_position.x + randf_range(-wander_range, wander_range)
					_target_global_y = randf_range(0.0, VERTICAL_RANGE_MAX)
				_start_wander_timer()
		
		State.IDLE, State.RETURNING_FROM_MISSION:
			# Uyku zamanı kontrolü - sadece gece saatlerinde (SLEEP_HOUR ile WAKE_UP_HOUR arası) uykuya git
			# <<< YENİ: Başarısız deneme flag'ini kontrol et >>>
			var wake_hour = time_manager.WAKE_UP_HOUR
			var sleep_hour = time_manager.SLEEP_HOUR
			var is_daytime = new_hour >= wake_hour and new_hour < sleep_hour
			if not is_daytime and new_hour >= sleep_hour and current_minute >= sleep_minute_offset and not _sleep_attempt_failed:
				if is_instance_valid(campfire_node):
					current_state = State.GOING_TO_SLEEP
					move_target_x = campfire_node.global_position.x
					_target_global_y = randf_range(0.0, VERTICAL_RANGE_MAX)
					_wander_timer.stop()
		
		State.GOING_TO_MISSION, State.ON_MISSION:
			# Görevdeyken gece kontrolü yapma (görev bitince zaten kontrol edilecek)
			pass
		
		State.GOING_TO_SLEEP:
			pass

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
								elif "top0" in item_type:
									path_to_use = path_to_use.replace("top0", "top1")
						
						if path_to_use.is_empty():
							path_to_use = original_diffuse_path  # Fallback: orijinal path
						
						if ResourceLoader.exists(path_to_use):
							diffuse_texture = load(path_to_use)
							textures["diffuse"] = diffuse_texture  # Cache için
				
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
