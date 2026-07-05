extends Node2D

class_name CampFire

var _interact_hint_label: Label = null

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

# --- Kapasite Yönetimi ---
@export var max_capacity: int = 3  # Maksimum işçi kapasitesi (varsayılan 3, kaydedilebilir)
var _occupants: Array = []  # Kamp ateşindeki worker'ları takip et
var _sick_indicator: Label = null

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
		point_light.range_z_max = 20  # Oyuncu ve NPC'ler z_index 6-19'da; su (20) öncesine kadar aydınlat
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

	var im := get_node_or_null("/root/InputManager")
	if im and im.has_signal("input_device_changed"):
		im.input_device_changed.connect(_on_input_device_changed)

	_ensure_sick_indicator()
	var vm := get_node_or_null("/root/VillageManager")
	if vm and vm.has_signal("village_data_changed"):
		var cb := Callable(self, "_refresh_sick_indicator")
		if not vm.village_data_changed.is_connected(cb):
			vm.village_data_changed.connect(cb)
	_refresh_sick_indicator()


# --- Etkileşim Tuşu Gösterimi ---
func ShowInteractButton() -> void:
	if _interact_hint_label == null:
		_create_interact_hint()
	if _interact_hint_label:
		var im := get_node_or_null("/root/InputManager")
		if im:
			_interact_hint_label.text = im.get_tutorial_ui_up_hint()
		_interact_hint_label.visible = true


func HideInteractButton() -> void:
	if _interact_hint_label:
		_interact_hint_label.visible = false


func _on_input_device_changed(_is_joypad: bool) -> void:
	if _interact_hint_label and _interact_hint_label.visible:
		var im := get_node_or_null("/root/InputManager")
		if im:
			_interact_hint_label.text = im.get_tutorial_ui_up_hint()


func _create_interact_hint() -> void:
	_interact_hint_label = Label.new()
	_interact_hint_label.name = "InteractHint"
	_interact_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_hint_label.add_theme_font_size_override("font_size", 12)
	_interact_hint_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.8, 1.0))
	_interact_hint_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_interact_hint_label.add_theme_constant_override("outline_size", 3)
	_interact_hint_label.position = Vector2(-20, -60)
	_interact_hint_label.size = Vector2(40, 20)
	_interact_hint_label.visible = false
	add_child(_interact_hint_label)

func _ensure_sick_indicator() -> void:
	if is_instance_valid(_sick_indicator):
		return
	_sick_indicator = Label.new()
	_sick_indicator.name = "SickAtHomeIndicator"
	_sick_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sick_indicator.position = Vector2(-28, -95)
	_sick_indicator.z_index = 25
	_sick_indicator.visible = false
	_sick_indicator.add_theme_color_override("font_outline_color", Color(0.1, 0.0, 0.0, 0.9))
	_sick_indicator.add_theme_constant_override("outline_size", 5)
	add_child(_sick_indicator)

func _refresh_sick_indicator() -> void:
	_ensure_sick_indicator()
	if not is_instance_valid(_sick_indicator):
		return
	var vm := get_node_or_null("/root/VillageManager")
	var count := 0
	if vm and vm.has_method("get_sick_count_at_housing"):
		count = int(vm.get_sick_count_at_housing(self))
	if count > 0:
		_sick_indicator.text = "🤒 %d" % count
		_sick_indicator.visible = true
	else:
		_sick_indicator.visible = false

# Oyuncu etkileşime geçtiğinde çağrılır
func interact() -> void:
	var host := VillageWorldPopups.get_host()
	if host:
		host.open_campfire_rest()
		var village := get_tree().get_first_node_in_group("VillageScene")
		if village and village.has_method("tutorial_on_campfire_rest_opened"):
			village.tutorial_on_campfire_rest_opened()

# --- Kapasite Fonksiyonları ---
# Bu kamp ateşinin bir işçi daha alıp alamayacağını kontrol eder
func can_add_occupant() -> bool:
	return get_occupant_count() < get_max_capacity()

# Mevcut işçi sayısını döndürür (işe gitseler de ateşe kayıtlı sakin sayılır)
func get_occupant_count() -> int:
	var count := 0
	var i := _occupants.size() - 1
	while i >= 0:
		if is_instance_valid(_occupants[i]):
			count += 1
		else:
			_occupants.remove_at(i)  # sadece geçersiz referansları temizle
		i -= 1
	return count

# Maksimum kapasiteyi döndürür
func get_max_capacity() -> int:
	return max_capacity

# Yeni bir işçi ekler
func add_occupant(worker: Node) -> bool:
	if not can_add_occupant():
		return false
	
	# Worker zaten listede mi kontrol et
	if worker in _occupants:
		return true
	
	# İşçiyi listeye ekle
	_occupants.append(worker)
	# Debug: Only log if needed
	# print("[CampFire DEBUG] Worker listeye eklendi. Yeni sayı: %d/%d" % [get_occupant_count(), get_max_capacity()])
	
	# İşçiyi ekle - eğer zaten bir parent'ı varsa (örn. WorkersContainer) child olarak ekleme
	# Sadece referans tut (housing_node zaten set edilmiş)
	if worker.get_parent() == null:
		add_child(worker)
		# Debug: Only log if needed
		# print("[CampFire DEBUG] Worker child olarak eklendi. Mevcut: %d/%d" % [get_occupant_count(), get_max_capacity()])
	# else:
		# Worker zaten WorkersContainer'da, sadece referans tut
		# print("[CampFire DEBUG] Worker zaten parent'a sahip (%s). Sadece referans tutuluyor. Mevcut: %d/%d" % [worker.get_parent().name, get_occupant_count(), get_max_capacity()])
	return true

# Bir işçiyi çıkarır
func remove_occupant(worker: Node) -> bool:
	# Debug: Only log errors, not normal operations
	# print("[CampFire DEBUG] remove_occupant çağrıldı - worker: %s, mevcut: %d/%d" % [worker.name if worker else "null", get_occupant_count(), get_max_capacity()])
	# Listeden çıkar
	if worker in _occupants:
		_occupants.erase(worker)
		# Debug: Only log if needed
		# print("[CampFire DEBUG] Worker listeden çıkarıldı. Yeni sayı: %d/%d" % [get_occupant_count(), get_max_capacity()])
	# else:
		# Worker listede yok - bu normal olabilir (worker zaten başka yerde)
		# print("[CampFire DEBUG] Worker listede yok! Mevcut: %d/%d" % [get_occupant_count(), get_max_capacity()])
	
	# İşçi zaten binaya atanmış olabilir, bu durumda parent'ı değişmiş olabilir
	# Ama hala bu CampFire'da kayıtlı olabilir
	if worker.get_parent() == self:
		remove_child(worker)
		# Debug: Only log if needed
		# print("[CampFire DEBUG] Worker child olarak çıkarıldı. Mevcut: %d/%d" % [get_occupant_count(), get_max_capacity()])
		return true
	else:
		# İşçi zaten başka yerde (binaya atanmış), ama yine de başarılı sayalım
		# Debug: This is normal, don't log
		# print("[CampFire DEBUG] Worker zaten başka parent'a sahip (%s). Mevcut: %d/%d" % [worker.get_parent().name if worker.get_parent() else "null", get_occupant_count(), get_max_capacity()])
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
