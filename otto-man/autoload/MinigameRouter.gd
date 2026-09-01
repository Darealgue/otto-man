extends Node

signal minigame_finished(result: Dictionary)

var _active_minigame: Node = null
var _active_minigame_should_pause := true
var _previous_pause_state := false
var _pre_minigame_camera: Camera2D = null
var _pre_minigame_zoom: Vector2 = Vector2.ONE
var _camera_zoom_factor: float = 0.85
var _camera_zoom_duration: float = 0.25
var _minigame_scenes := {
	"villager": "res://ui/minigames/VillagerLockpick.tscn",
	"vip": "res://ui/minigames/DealDuel.tscn",
	"forest_woodcut": "res://ui/minigames/ForestWoodcutMinigame.tscn",
	"forest_stone": "res://ui/minigames/ForestStoneMinigame.tscn",
	"forest_water": "res://ui/minigames/ForestWaterMinigame.tscn",
	"forest_fruit": "res://ui/minigames/ForestFruitMinigame.tscn",
	"forest_food": "res://ui/minigames/ForestFoodMinigame.tscn",
}

func register_minigame(kind: String, scene_path: String) -> void:
	if kind.is_empty():
		return
	if scene_path.is_empty():
		_minigame_scenes.erase(kind)
	else:
		_minigame_scenes[kind] = scene_path

func has_minigame(kind: String) -> bool:
	return _minigame_scenes.has(kind)

## 🔴 BURADA `FileAccess.file_exists("res://…​.tscn")` KULLANMA — dışa aktarılmış sürümde HER
## ZAMAN false döner ve bütün minigame sistemini sessizce öldürür.
##
## Godot dışa aktarırken metin sahneleri ikiliye çevirip pck'ye `X.tscn.remap` + gerçek `.scn`
## olarak yazar; `X.tscn` diye bir kayıt dosya tablosunda HİÇ yoktur. `FileAccess.file_exists()`
## ise doğrudan o tabloya bakar (PackedData::has_path), remap'i uygulamaz. Editörde gerçek dosya
## diskte durduğu için her şey çalışır, export'ta ise `start_minigame()` daha ilk satırda false
## dönerdi.
##
## Sonuç (ilk playtest, 2026-08-31): oyuncu ormanda ağaca yaklaşıyor, sarı vurgu ve ok ipucu
## çıkıyor, etkileşim tuşuna basıyor — ve HİÇBİR ŞEY olmuyor. Odun, yiyecek, taş, su, meyve,
## cariye kilidi ve VIP düellosu: dışa aktarılmış her sürümde tüm minigame'ler ölüydü.
## 2026-08-30 tarihli otto-man.pck'nin dosya tablosu ayrıştırılarak doğrulandı: 3715 kaydın
## içinde `res://ui/minigames/ForestWoodcutMinigame.tscn` yok, yalnızca `.tscn.remap` var.
##
## Tek güvenilir kontrol `load()`'un sonucudur: remap'i uygulayan yol odur.
func start_minigame(kind: String, context := {}) -> bool:
	# is_instance_valid şart: minigame düğümü get_tree().root'a ekleniyor, "completed"
	# sinyali gelmeden serbest bırakılırsa referans sallantıda kalır ve bir daha HİÇBİR
	# minigame açılamazdı.
	if is_instance_valid(_active_minigame):
		print("[MinigameRouter] Cannot start %s, another minigame already active" % kind)
		return false
	_active_minigame = null
	if !has_minigame(kind):
		print("[MinigameRouter] has_minigame returned false for kind=%s" % kind)
		push_warning("[MinigameRouter] Unknown minigame kind: %s" % kind)
		return false
	var scene_path: String = _minigame_scenes[kind]
	print("[MinigameRouter] Attempting to load scene: %s (kind: %s)" % [scene_path, kind])
	var ps := load(scene_path)
	if ps == null:
		print("[MinigameRouter] ❌ load() returned null for scene %s" % scene_path)
		push_warning("[MinigameRouter] Failed to load scene for minigame kind: %s (%s)" % [kind, scene_path])
		return false
	print("[MinigameRouter] ✅ Scene loaded successfully: %s" % scene_path)
	_active_minigame = ps.instantiate()
	if _active_minigame == null:
		print("[MinigameRouter] instantiate returned null for scene %s" % scene_path)
		push_warning("[MinigameRouter] instantiate() returned null for %s" % kind)
		return false
	var should_pause := true
	if "pause_game" in _active_minigame:
		print("[MinigameRouter] pause_game property found: %s" % _active_minigame.pause_game)
		should_pause = bool(_active_minigame.pause_game)
	else:
		print("[MinigameRouter] pause_game property not found; defaulting to true")
	if should_pause:
		_active_minigame.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	else:
		_active_minigame.process_mode = Node.PROCESS_MODE_ALWAYS
	var plist := _active_minigame.get_property_list()
	for p in plist:
		if typeof(p) == TYPE_DICTIONARY and p.has("name") and String(p.name) == "context":
			_active_minigame.set("context", context)
			break
	if _active_minigame.has_signal("completed"):
		_active_minigame.connect("completed", Callable(self, "_on_minigame_completed"))
	get_tree().root.add_child(_active_minigame)
	print("[MinigameRouter] ✅ Minigame added to scene tree: %s" % _active_minigame.name)
	print("[MinigameRouter] Minigame visible: %s, process_mode: %s" % [_active_minigame.visible, _active_minigame.process_mode])
	_active_minigame_should_pause = should_pause
	var tree := get_tree()
	_previous_pause_state = tree.paused
	if should_pause:
		tree.paused = true
		print("[MinigameRouter] Game paused: %s" % tree.paused)
	print("[MinigameRouter] ✅ Minigame started successfully: %s" % kind)
	return true

func _on_minigame_completed(success: bool, payload := {}):
	if is_instance_valid(_active_minigame):
		_active_minigame.queue_free()
	_active_minigame = null
	var tree := get_tree()
	if _active_minigame_should_pause:
		tree.paused = _previous_pause_state
	_active_minigame_should_pause = true
	_handle_resource_rewards(success, payload)
	emit_signal("minigame_finished", {"success": success, "payload": payload})

func _handle_resource_rewards(success: bool, payload: Dictionary) -> void:
	if !success:
		return
	if payload.is_empty():
		return
	var rewards := {}
	if payload.has("resource_rewards") and payload.resource_rewards is Dictionary:
		for key in payload.resource_rewards.keys():
			rewards[key] = int(payload.resource_rewards[key])
	if payload.has("resource_type"):
		var base_amount := int(payload.get("amount", 0))
		var bonus_amount := int(payload.get("bonus", 0))
		var total := base_amount + bonus_amount
		if total != 0:
			var type_key := String(payload.resource_type)
			if rewards.has(type_key):
				rewards[type_key] += total
			else:
				rewards[type_key] = total
	if rewards.is_empty():
		return
	var player_stats = get_node_or_null("/root/PlayerStats")
	if player_stats and player_stats.has_method("add_carried_resources"):
		player_stats.add_carried_resources(rewards)

func _apply_camera_zoom(apply_zoom: bool) -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	if apply_zoom:
		var cam := viewport.get_camera_2d()
		if cam == null:
			return
		_pre_minigame_camera = cam
		_pre_minigame_zoom = cam.zoom
		var target_factor := clampf(_camera_zoom_factor, 0.05, 4.0)
		if cam.has_method("zoom_to_factor"):
			cam.call("zoom_to_factor", target_factor, _camera_zoom_duration)
		elif cam.has_method("zoom_to_vector"):
			cam.call("zoom_to_vector", _pre_minigame_zoom * target_factor, _camera_zoom_duration)
		else:
			cam.zoom = _pre_minigame_zoom * target_factor
	else:
		if _pre_minigame_camera and is_instance_valid(_pre_minigame_camera):
			var cam := _pre_minigame_camera
			if cam.has_method("reset_zoom"):
				cam.call("reset_zoom", _camera_zoom_duration)
			elif cam.has_method("zoom_to_vector"):
				cam.call("zoom_to_vector", _pre_minigame_zoom, _camera_zoom_duration)
			else:
				cam.zoom = _pre_minigame_zoom
		_pre_minigame_camera = null
