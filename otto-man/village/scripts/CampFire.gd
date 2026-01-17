extends Node2D

# --- Sahne Yolları ---
const MISSION_CENTER_SCENE = "res://village/missions/MissionCenterScene.tscn"

var _locked_player: Node = null
var _active_panel: CanvasLayer = null

# --- Light System Variables ---
@export var light_intensity_min: float = 0.5
@export var light_intensity_max: float = 1.5
@export var flicker_speed: float = 0.8
@export var flicker_variation: float = 0.5
@export var range_variation: float = 0.15

# Day/Night light multipliers
@export var day_energy_multiplier: float = 0.3  # Sabah/gündüz için enerji çarpanı
@export var day_range_multiplier: float = 0.5   # Sabah/gündüz için mesafe çarpanı
@export var night_energy_multiplier: float = 1.0  # Gece için enerji çarpanı
@export var night_range_multiplier: float = 1.0    # Gece için mesafe çarpanı

var point_light: PointLight2D
var animated_sprite: AnimatedSprite2D
var base_energy: float
var base_texture_scale: float
var time: float = 0.0
var random_offset: float = 0.0
var noise: FastNoiseLite
var day_night_controller: Node = null

# --- Ready Function ---
func _ready() -> void:
	# Housing grubuna ekle
	if not is_in_group("Housing"):
		add_to_group("Housing")
		print("Campfire %s added to Housing group via code." % name)
	
	# AnimatedSprite2D'yi bul ve animasyonu başlat
	animated_sprite = get_node_or_null("AnimatedSprite2D")
	if animated_sprite:
		animated_sprite.play("default")
		print("Campfire: Animation started")
	else:
		print("Campfire: AnimatedSprite2D not found!")
	
	# PointLight2D'yi bul
	point_light = get_node_or_null("PointLight2D")
	if point_light:
		base_energy = point_light.energy
		base_texture_scale = point_light.texture_scale
		# Zemin aydınlatması için z_index = -1 olan objeleri de aydınlat
		# Light'ın z_index'ini 0 yap (Light2D kendi z_index'inden düşük veya eşit z_index'leri aydınlatır)
		point_light.z_index = 0
		point_light.range_z_min = -1  # z_index = -1'den başla (zemin)
		point_light.range_z_max = 10   # Yüksek z_index'leri de aydınlat (oyuncu, NPC'ler)
		# ParallaxBackground layer'larını aydınlatmak için range_layer ayarları
		point_light.range_layer_min = -1  # ParallaxBackground layer = -1
		point_light.range_layer_max = 1   # Normal layer'ları da aydınlat
		print("Campfire: Found PointLight2D with base energy: ", base_energy, " base scale: ", base_texture_scale, " z_index: ", point_light.z_index, " z_range: ", point_light.range_z_min, " to ", point_light.range_z_max, " layer range: ", point_light.range_layer_min, " to ", point_light.range_layer_max)
	else:
		print("Campfire: Warning: No PointLight2D found!")
	
	# DayNightController'ı bul
	day_night_controller = get_tree().get_first_node_in_group("DayNightController")
	if not day_night_controller:
		# Alternatif: VillageScene'den bul
		var village_scene = get_tree().get_first_node_in_group("VillageScene")
		if village_scene:
			day_night_controller = village_scene.get_node_or_null("DayNightController")
	
	# Create random offset for flickering
	random_offset = randf() * 10.0
	
	# Initialize Perlin noise for natural flickering
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.15
	noise.noise_type = FastNoiseLite.TYPE_PERLIN

# --- Etkileşim Alanı ---
func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		print("Etkileşim alanına girildi:CampFire")
		body.interaction_zone_entered(self)

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		print("Etkileşim alanından çıkıldı:CampFire")
		body.interaction_zone_exited(self)

# Oyuncu etkileşime geçtiğinde çağrılır
func interact():
	print("Campfire.interact() çağrıldı.")
	
	# Doğrudan Görev Merkezi'ni aç
	print("Görev Merkezi açılıyor...")
	_open_or_show_ui_panel(MISSION_CENTER_SCENE)

# Belirtilen UI panelini açar
func _open_or_show_ui_panel(scene_path: String) -> void:
	if _active_panel and is_instance_valid(_active_panel):
		if _active_panel.visible:
			print("Campfire: Panel already active and visible, skipping new instance.")
			return
		print("Campfire: Reusing existing panel instance.")
		_lock_player()
		_active_panel.visible = true
		# Mission Center için open_menu() metodunu çağır
		if _active_panel.has_method("open_menu"):
			print("Campfire: Calling open_menu() on existing Mission Center")
			_active_panel.open_menu()
		elif _active_panel.has_method("on_campfire_reopened"):
			_active_panel.on_campfire_reopened()
		return
	print("Campfire: Creating new panel instance for: ", scene_path)
	var panel_scene = load(scene_path)
	if panel_scene:
		var instance = panel_scene.instantiate()
		if instance is CanvasLayer:
			_active_panel = instance
			_lock_player()
			instance.tree_exiting.connect(_on_panel_tree_exiting)
			var visibility_callable := Callable(self, "_on_panel_visibility_changed")
			if not instance.visibility_changed.is_connected(visibility_callable):
				instance.visibility_changed.connect(visibility_callable)
			if instance.has_method("connect_close_signal"):
				instance.connect_close_signal(_on_panel_closed)
			elif instance.has_signal("menu_closed"):
				instance.menu_closed.connect(_on_panel_closed)
		else:
			_lock_player()
		get_tree().root.add_child(instance)
		print("Campfire: Panel instance created successfully")
		
		# Mission Center için open_menu() metodunu çağır
		if instance.has_method("open_menu"):
			print("Campfire: Calling open_menu() on Mission Center")
			instance.open_menu()
		else:
			# Diğer paneller için sadece görünür yap
			instance.visible = true
	else:
		printerr("Campfire: UI panel scene could not be loaded: %s" % scene_path)

func _lock_player() -> void:
	if _locked_player and is_instance_valid(_locked_player):
		return
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_ui_locked"):
		player.set_ui_locked(true)
		_locked_player = player

func _unlock_player() -> void:
	if _locked_player and is_instance_valid(_locked_player):
		_locked_player.set_ui_locked(false)
		if InputMap.has_action("dash"):
			Input.action_release("dash")
		if InputMap.has_action("jump"):
			Input.action_release("jump")
		if InputMap.has_action("attack"):
			Input.action_release("attack")
		if InputMap.has_action("ui_accept"):
			Input.action_release("ui_accept")
		if InputMap.has_action("ui_forward"):
			Input.action_release("ui_forward")
		if InputMap.has_action("interact"):
			Input.action_release("interact")
		if InputMap.has_action("ui_left"):
			Input.action_release("ui_left")
		if InputMap.has_action("ui_right"):
			Input.action_release("ui_right")
		if InputMap.has_action("move_left"):
			Input.action_release("move_left")
		if InputMap.has_action("move_right"):
			Input.action_release("move_right")
		if InputMap.has_action("left"):
			Input.action_release("left")
		if InputMap.has_action("right"):
			Input.action_release("right")
	_locked_player = null

func _on_panel_tree_exiting() -> void:
	_active_panel = null
	_unlock_player()

func _on_panel_closed() -> void:
	_unlock_player()

func _on_panel_visibility_changed() -> void:
	if _active_panel and not _active_panel.visible:
		_on_panel_closed()

# --- Kapasite Fonksiyonları ---
# Bu kamp ateşinin bir işçi daha alıp alamayacağını kontrol eder
func can_add_occupant() -> bool:
	return get_occupant_count() < get_max_capacity()

# Mevcut işçi sayısını döndürür
func get_occupant_count() -> int:
	# İşçiler artık WorkersContainer'da, bu yüzden VillageManager'dan sayıyı al
	if VillageManager and "total_workers" in VillageManager:
		return VillageManager.total_workers
	return 0

# Maksimum kapasiteyi döndürür (şimdilik 3)
func get_max_capacity() -> int:
	return 3

# Yeni bir işçi ekler
func add_occupant(worker: Node) -> bool:
	if not can_add_occupant():
		return false
	
	# İşçiyi ekle - eğer zaten bir parent'ı varsa (örn. WorkersContainer) child olarak ekleme
	# Sadece referans tut (housing_node zaten set edilmiş)
	if worker.get_parent() == null:
		add_child(worker)
		print("Campfire: Occupant added as child. Current: %d/%d" % [get_occupant_count(), get_max_capacity()])
	else:
		# Worker zaten WorkersContainer'da, sadece referans tut
		print("Campfire: Occupant added (already has parent: %s). Current: %d/%d" % [worker.get_parent().name, get_occupant_count(), get_max_capacity()])
	return true

# Bir işçiyi çıkarır
func remove_occupant(worker: Node) -> bool:
	# İşçi zaten binaya atanmış olabilir, bu durumda parent'ı değişmiş olabilir
	# Ama hala bu CampFire'da kayıtlı olabilir
	if worker.get_parent() == self:
		remove_child(worker)
		print("Campfire: Occupant removed. Current: %d/%d" % [get_occupant_count(), get_max_capacity()])
		return true
	else:
		# İşçi zaten başka yerde (binaya atanmış), ama yine de başarılı sayalım
		print("Campfire: Occupant was already moved to building, but removal successful. Current: %d/%d" % [get_occupant_count(), get_max_capacity()])
		return true

# --- Light System Functions ---
func _process(delta: float) -> void:
	time += delta
	
	if not point_light:
		return
	
	# Get day/night multiplier based on time
	var energy_multiplier = night_energy_multiplier
	var range_multiplier = night_range_multiplier
	
	if TimeManager and TimeManager.has_method("get_continuous_hour_float"):
		var current_hour = TimeManager.get_continuous_hour_float()
		# Sabah 6-18 arası gündüz, diğerleri gece
		if current_hour >= 6.0 and current_hour < 18.0:
			# Gündüz - interpolate between day and night based on hour
			var day_progress = 1.0
			if current_hour < 9.0:  # 6-9 arası sabah (geceden gündüze geçiş)
				day_progress = remap(current_hour, 6.0, 9.0, 0.0, 1.0)
			elif current_hour >= 15.0:  # 15-18 arası akşam (gündüzden geceye geçiş)
				day_progress = remap(current_hour, 15.0, 18.0, 1.0, 0.0)
			
			energy_multiplier = lerp(night_energy_multiplier, day_energy_multiplier, day_progress)
			range_multiplier = lerp(night_range_multiplier, day_range_multiplier, day_progress)
	
	# Use Perlin noise for more natural, random flickering
	var noise_value = noise.get_noise_1d(time * flicker_speed + random_offset)
	var flicker = noise_value * flicker_variation
	
	# Add some additional randomness for more chaotic effect
	var random_variation = randf_range(-0.05, 0.05)
	
	# Calculate new energy with flickering and day/night multiplier
	var flicker_energy = base_energy + flicker + random_variation
	flicker_energy = clamp(flicker_energy, light_intensity_min, light_intensity_max)
	point_light.energy = flicker_energy * energy_multiplier
	
	# Vary the texture scale (range) with different noise pattern and day/night multiplier
	var range_noise = noise.get_noise_1d((time + random_offset * 1.7) * flicker_speed * 0.3)
	var range_variation_amount = range_noise * range_variation
	var range_random = randf_range(-0.03, 0.03)
	var scale_variation = 1.0 + range_variation_amount + range_random
	point_light.texture_scale = base_texture_scale * scale_variation * range_multiplier
