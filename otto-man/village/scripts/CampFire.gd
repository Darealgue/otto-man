extends Node2D

# --- Sahne Yolları ---
const MISSION_CENTER_SCENE = "res://village/missions/MissionCenterScene.tscn"

var _locked_player: Node = null
var _active_panel: CanvasLayer = null

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
	if _active_panel and is_instance_valid(_active_panel):
		if _active_panel.visible:
			print("Campfire: Panel already active and visible, skipping new instance.")
			return
		print("Campfire: Reusing existing panel instance.")
		_lock_player()
		_active_panel.visible = true
		if _active_panel.has_method("on_campfire_reopened"):
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
