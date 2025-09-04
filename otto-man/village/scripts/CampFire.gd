extends Node2D

# --- Sahne Yolları ---
const MISSION_CENTER_SCENE = "res://village/missions/MissionCenterScene.tscn"

# --- Ready Function ---
func _ready() -> void:
	# Housing grubuna ekle
	if not is_in_group("Housing"):
		add_to_group("Housing")
		print("Campfire %s added to Housing group via code." % name)

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
	print("Campfire: Creating new panel instance for: ", scene_path)
	var panel_scene = load(scene_path)
	if panel_scene:
		var instance = panel_scene.instantiate()
		get_tree().root.add_child(instance)
		print("Campfire: Panel instance created successfully")
	else:
		printerr("Campfire: UI panel scene could not be loaded: %s" % scene_path)

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
	
	# İşçiyi ekle
	add_child(worker)
	print("Campfire: Occupant added. Current: %d/%d" % [get_occupant_count(), get_max_capacity()])
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
