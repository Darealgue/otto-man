extends Node
## Zindan segmenti stealth / alarm durumu.

signal alarm_raised(reason: String)

const STEALTH_RESCUE_CHANCE: float = 0.28
const STEALTH_SCORE_SEGMENT_CLEAR: int = 10
const STEALTH_SEGMENT_GOLD_BONUS: float = 0.05
const STEALTH_MINIGAME_DIFFICULTY_MULT: float = 0.85
const PERCEPTION_FADE_DURATION: float = 3.0

const STEALTH_CHEST_GROUP: StringName = &"stealth_treasure_chest"
const HUD_SCRIPT := preload("res://ui/stealth_status_display.gd")
const COLLECTIBLES_HUD_SCRIPT := preload("res://ui/DungeonCollectiblesDisplay.gd")

var segment_alarm: bool = false
var stealth_score: int = 0
var run_stealth_intact: bool = true
var alarm_reason: String = ""
var alarm_source_enemy_id: String = ""
var stealth_rescue_bonus_next: bool = false
var _perception_fade_remaining: float = 0.0

## Debug: ekstra debug bilgisi (algı alanı artık stealth sırasında her zaman çizilir).
var debug_draw_enabled: bool = OS.is_debug_build()

var _hud: Control = null
var _collectibles_hud: Control = null
var _collectibles_hud_owned: bool = false  # false: game_ui.tscn'deki kalıcı display benimsendi, silme


func _process(delta: float) -> void:
	if segment_alarm and _perception_fade_remaining > 0.0:
		_perception_fade_remaining = maxf(0.0, _perception_fade_remaining - delta)


func reset_for_run() -> void:
	run_stealth_intact = true
	stealth_rescue_bonus_next = false
	reset_for_segment()


func reset_for_segment() -> void:
	segment_alarm = false
	stealth_score = 0
	alarm_reason = ""
	alarm_source_enemy_id = ""
	_perception_fade_remaining = 0.0
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if is_instance_valid(drs) and drs.has_method("reset_segment_exit_state"):
		drs.call("reset_segment_exit_state")
	var im: Node = get_node_or_null("/root/ItemManager")
	if is_instance_valid(im) and im.has_method("reset_segment_expedition_loot_drops"):
		im.call("reset_segment_expedition_loot_drops")
	call_deferred("_ensure_hud")
	call_deferred("_ensure_collectibles_hud")


func raise_alarm(reason: String = "", source_enemy_id: String = "") -> void:
	if segment_alarm:
		return
	segment_alarm = true
	run_stealth_intact = false
	alarm_reason = reason
	alarm_source_enemy_id = source_enemy_id
	_perception_fade_remaining = PERCEPTION_FADE_DURATION
	alarm_raised.emit(reason)
	print("[StealthManager] ALARM — reason=%s source=%s" % [reason, source_enemy_id])
	call_deferred("_apply_alarm_world_effects")


func get_perception_draw_alpha() -> float:
	if not is_stealth_enabled():
		return 0.0
	if not segment_alarm:
		return 1.0
	if _perception_fade_remaining <= 0.0:
		return 0.0
	return _perception_fade_remaining / PERCEPTION_FADE_DURATION


func should_draw_perception() -> bool:
	return get_perception_draw_alpha() > 0.01


func should_show_noise_visuals() -> bool:
	return should_draw_perception() and not segment_alarm


func is_stealth_mode() -> bool:
	return not segment_alarm


func is_stealth_enabled() -> bool:
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if not is_instance_valid(drs):
		return false
	return bool(drs.get("run_started"))


func add_stealth_score(points: int) -> void:
	if points <= 0:
		return
	stealth_score += points


func on_segment_completed() -> void:
	if not is_stealth_enabled():
		return
	if is_stealth_mode():
		stealth_rescue_bonus_next = true
		add_stealth_score(STEALTH_SCORE_SEGMENT_CLEAR)
		_apply_segment_stealth_gold_bonus()
		print("[StealthManager] Segment gizli tamamlandı — sonraki segment rescue bonusu aktif (score=%d)" % stealth_score)
	else:
		stealth_rescue_bonus_next = false
		print("[StealthManager] Segment alarm ile tamamlandı — rescue bonusu yok")


func can_stealth_exit() -> bool:
	if not is_stealth_enabled():
		return false
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if not is_instance_valid(drs) or not drs.has_method("is_run_complete"):
		return false
	if not bool(drs.call("is_run_complete")):
		return false
	if bool(drs.get("is_warmup_run")):
		return false
	return run_stealth_intact and is_stealth_mode()


func get_rescue_minigame_difficulty_multiplier() -> float:
	if is_stealth_mode():
		return STEALTH_MINIGAME_DIFFICULTY_MULT
	return 1.0


func _apply_segment_stealth_gold_bonus() -> void:
	if stealth_score <= 0:
		return
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if not is_instance_valid(drs) or not ("gold_multiplier_accumulated" in drs):
		return
	var prev: float = float(drs.get("gold_multiplier_accumulated"))
	drs.set("gold_multiplier_accumulated", prev + STEALTH_SEGMENT_GOLD_BONUS)
	print("[StealthManager] Segment stealth altın bonusu +%.2f (toplam çarpan=%.2f)" % [
		STEALTH_SEGMENT_GOLD_BONUS,
		float(drs.get("gold_multiplier_accumulated")),
	])


func consume_stealth_rescue_bonus(base_chance: float) -> float:
	if not stealth_rescue_bonus_next:
		return base_chance
	stealth_rescue_bonus_next = false
	return maxf(base_chance, STEALTH_RESCUE_CHANCE)


func _apply_alarm_world_effects() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	for chest in tree.get_nodes_in_group(STEALTH_CHEST_GROUP):
		if is_instance_valid(chest) and chest.has_method("lock_on_alarm"):
			chest.call("lock_on_alarm", alarm_reason)
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	var lost: Dictionary = {"villagers": 0, "cariyes": 0}
	if is_instance_valid(drs) and drs.has_method("purge_fragile_rescues"):
		lost = drs.call("purge_fragile_rescues")
	var v_lost: int = int(lost.get("villagers", 0))
	var c_lost: int = int(lost.get("cariyes", 0))
	if v_lost > 0 or c_lost > 0:
		_notify_fragile_rescue_fled(v_lost, c_lost)
	if _hud != null and is_instance_valid(_hud) and _hud.has_method("refresh_fragile_status"):
		_hud.call("refresh_fragile_status")
	_lock_segment_finish_door()


func _lock_segment_finish_door() -> void:
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if is_instance_valid(drs) and drs.has_method("arm_segment_exit_key_lock"):
		drs.call("arm_segment_exit_key_lock")
	var lg: Node = null
	if is_instance_valid(drs) and drs.has_method("find_active_level_generator"):
		lg = drs.call("find_active_level_generator")
	if is_instance_valid(lg) and lg.has_method("lock_finish_door_for_alarm"):
		lg.call("lock_finish_door_for_alarm")
	elif OS.is_debug_build():
		push_warning("[StealthManager] LevelGenerator bulunamadı — çıkış kapısı kilitlenemedi")
	if _hud != null and is_instance_valid(_hud) and _hud.has_method("show_alarm_banner"):
		_hud.call("show_alarm_banner")


func _notify_fragile_rescue_fled(villagers_lost: int, cariyes_lost: int) -> void:
	if _hud != null and is_instance_valid(_hud) and _hud.has_method("show_flee_toast"):
		_hud.call("show_flee_toast", villagers_lost, cariyes_lost)
		return
	print("[StealthManager] Kurtarılanlar kaçtı — köylü=%d cariye=%d" % [villagers_lost, cariyes_lost])


func refresh_fragile_hud() -> void:
	if _hud != null and is_instance_valid(_hud) and _hud.has_method("refresh_fragile_status"):
		_hud.call("refresh_fragile_status")


func _ensure_hud() -> void:
	if not is_stealth_enabled():
		_remove_hud()
		return
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	if _hud != null and is_instance_valid(_hud):
		return

	var parent: Node = tree.current_scene.get_node_or_null("GameUI/Container")
	if parent == null:
		var game_ui: Node = tree.current_scene.get_node_or_null("GameUI")
		if game_ui:
			parent = game_ui
	if parent == null:
		var players: Array = tree.get_nodes_in_group("player")
		if players.size() > 0:
			parent = players[0].get_node_or_null("UI")
	if parent == null:
		return

	_hud = HUD_SCRIPT.new()
	_hud.name = "StealthStatusDisplay"
	parent.add_child(_hud)


func _ensure_collectibles_hud() -> void:
	if not is_stealth_enabled():
		_remove_collectibles_hud()
		return
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	if _collectibles_hud != null and is_instance_valid(_collectibles_hud):
		return

	var parent: Node = tree.current_scene.get_node_or_null("GameUI/Container")
	if parent == null:
		var game_ui: Node = tree.current_scene.get_node_or_null("GameUI")
		if game_ui:
			parent = game_ui
	if parent == null:
		return

	# game_ui.tscn artık bu display'i kalıcı içeriyor; varsa yenisini ekleme, onu kullan.
	var existing: Node = parent.get_node_or_null("DungeonCollectiblesDisplay")
	if existing != null:
		_collectibles_hud = existing
		_collectibles_hud_owned = false
		return

	_collectibles_hud = COLLECTIBLES_HUD_SCRIPT.new()
	_collectibles_hud.name = "DungeonCollectiblesDisplay"
	_collectibles_hud_owned = true
	parent.add_child(_collectibles_hud)


func _remove_hud() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null
	_remove_collectibles_hud()


func _remove_collectibles_hud() -> void:
	if _collectibles_hud_owned and _collectibles_hud != null and is_instance_valid(_collectibles_hud):
		_collectibles_hud.queue_free()
	_collectibles_hud = null
	_collectibles_hud_owned = false
