extends Control

var gold_label: Label
var gold_icon: Label

var _current_gold: int = 0
var _feedback_tween: Tween

## Altın alınca köşe + bu offset (piksel); layout ile çakışmaz.
var _feedback_screen_offset: Vector2 = Vector2.ZERO

## Konsol: sinyal, görünürlük, tween. Sorun ayıklamak için true.
const DEBUG_DUNGEON_GOLD_DISPLAY: bool = false


func _dlog(msg: String) -> void:
	if DEBUG_DUNGEON_GOLD_DISPLAY:
		print("[DungeonGoldHUD] ", msg)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = Vector2.ZERO

	add_to_group("dungeon_gold_ui")
	_migrate_flatten_bounce_wrapper_if_any()
	gold_label = get_node_or_null("HBoxContainer/GoldLabel") as Label
	gold_icon = get_node_or_null("HBoxContainer/GoldIcon") as Label

	var global_player_data := get_node_or_null("/root/GlobalPlayerData")
	if global_player_data:
		if global_player_data.has_signal("dungeon_gold_changed"):
			if not global_player_data.dungeon_gold_changed.is_connected(_on_dungeon_gold_changed):
				global_player_data.dungeon_gold_changed.connect(_on_dungeon_gold_changed)
				_dlog("_ready: dungeon_gold_changed bağlandı")
			else:
				_dlog("_ready: dungeon_gold_changed zaten bağlıydı")
		else:
			_dlog("_ready: UYARI GlobalPlayerData'da dungeon_gold_changed sinyali yok")
		if "dungeon_gold" in global_player_data:
			_current_gold = global_player_data.get("dungeon_gold")
			_dlog("_ready: başlangıç dungeon_gold=%s" % _current_gold)
			_update_display()
	else:
		_dlog("_ready: UYARI /root/GlobalPlayerData bulunamadı — HUD sinyal alamaz")

	_dlog("_ready: scene=%s, self=%s" % [get_tree().current_scene, get_path()])

	await get_tree().process_frame
	_update_position()

	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)

	var hbox := get_node_or_null("HBoxContainer")
	if hbox:
		hbox.show()
	if gold_label:
		gold_label.show()
	if gold_icon:
		gold_icon.show()
	var bg := get_node_or_null("Background")
	if bg:
		bg.show()

	_update_visibility()

	var scene_manager := get_node_or_null("/root/SceneManager")
	if scene_manager and scene_manager.has_signal("scene_change_completed"):
		if not scene_manager.scene_change_completed.is_connected(_on_scene_changed):
			scene_manager.scene_change_completed.connect(_on_scene_changed)

	call_deferred("_delayed_visibility_check")


## Eski oturumlarda oluşan Node2D sarmalayıcıyı kaldır; HBox yine kökün çocuğu olsun.
func _migrate_flatten_bounce_wrapper_if_any() -> void:
	var bounce := get_node_or_null("GoldHudBounce")
	if bounce == null:
		return
	var hbox := bounce.get_node_or_null("HBoxContainer") as Control
	var insert_at: int = clampi(bounce.get_index(), 0, maxi(get_child_count() - 1, 0))
	if hbox:
		bounce.remove_child(hbox)
		add_child(hbox)
		move_child(hbox, mini(insert_at, maxi(get_child_count() - 1, 0)))
	remove_child(bounce)
	bounce.queue_free()
	_dlog("_migrate: GoldHudBounce kaldırıldı, HBox düzeltildi")


func _apply_feedback_offset_vec(v: Vector2) -> void:
	_feedback_screen_offset = v
	_update_position()


func _delayed_visibility_check() -> void:
	await get_tree().create_timer(0.5).timeout
	_update_visibility()


func _on_viewport_size_changed() -> void:
	_update_position()


func _on_scene_changed(_new_path: String) -> void:
	_dlog("_on_scene_changed: %s" % _new_path)
	_update_visibility()
	_update_position()


func _on_dungeon_gold_changed(new_amount: int) -> void:
	var prev: int = _current_gold
	_current_gold = new_amount
	_dlog("_on_dungeon_gold_changed: prev=%s new=%s visible=%s in_tree=%s" % [prev, new_amount, visible, is_inside_tree()])
	_update_display()
	_update_visibility()
	if new_amount > prev:
		_dlog("-> pickup algılandı, play_dungeon_gold_pickup_feedback deferred")
		call_deferred("play_dungeon_gold_pickup_feedback")
	else:
		_dlog("-> pickup yok (azalma veya aynı), tween yok")


func _update_display() -> void:
	if gold_label:
		gold_label.text = str(_current_gold)
		gold_label.show()
	if gold_icon:
		gold_icon.show()
	var hbox := get_node_or_null("HBoxContainer")
	if hbox:
		hbox.show()
	var bg := get_node_or_null("Background")
	if bg:
		bg.show()
	_update_position()


func play_dungeon_gold_pickup_feedback() -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		_dlog("play_feedback: atlandı (invalid veya tree dışı)")
		return
	if gold_label == null:
		gold_label = get_node_or_null("HBoxContainer/GoldLabel") as Label
	if gold_icon == null:
		gold_icon = get_node_or_null("HBoxContainer/GoldIcon") as Label

	_dlog("play_feedback: giriş visible=%s gp=%s scale=%s size=%s" % [visible, global_position, scale, size])

	if _feedback_tween != null and is_instance_valid(_feedback_tween):
		_feedback_tween.kill()

	_feedback_screen_offset = Vector2.ZERO
	scale = Vector2.ONE
	rotation = 0.0
	_update_position()

	var half: Vector2 = size * 0.5
	if half.x < 2.0 or half.y < 2.0:
		half = Vector2(40.0, 22.0)
	pivot_offset = half

	modulate = Color.WHITE
	if gold_label:
		gold_label.modulate = Color.WHITE
	if gold_icon:
		gold_icon.modulate = Color.WHITE

	var up: Vector2 = Vector2(0.0, -32.0)
	var peak_scale := Vector2(1.22, 1.22)

	_feedback_tween = create_tween()
	if _feedback_tween == null:
		_dlog("play_feedback: create_tween null")
		return
	if _feedback_tween.has_method("bind_node"):
		_feedback_tween.bind_node(self)
	if DEBUG_DUNGEON_GOLD_DISPLAY:
		_feedback_tween.finished.connect(_on_feedback_tween_finished_log, CONNECT_ONE_SHOT)

	_feedback_tween.set_parallel(true)
	_feedback_tween.set_trans(Tween.TRANS_QUAD)
	_feedback_tween.set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_method(_apply_feedback_offset_vec, Vector2.ZERO, up, 0.14)
	_feedback_tween.tween_property(self, "scale", peak_scale, 0.14)
	_feedback_tween.tween_property(self, "rotation", deg_to_rad(4.0), 0.14)
	if gold_label:
		_feedback_tween.tween_property(gold_label, "modulate", Color(1.55, 1.35, 0.45, 1.0), 0.14)
	if gold_icon:
		_feedback_tween.tween_property(gold_icon, "modulate", Color(1.35, 1.25, 1.0, 1.0), 0.14)

	_feedback_tween.chain()
	_feedback_tween.set_parallel(true)
	_feedback_tween.tween_method(_apply_feedback_offset_vec, up, Vector2.ZERO, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(self, "rotation", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if gold_label:
		_feedback_tween.tween_property(gold_label, "modulate", Color.WHITE, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if gold_icon:
		_feedback_tween.tween_property(gold_icon, "modulate", Color.WHITE, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_dlog("play_feedback: tween başladı (kök gp+offset + scale)")


func _on_feedback_tween_finished_log() -> void:
	_dlog("tween bitti gp=%s offset=%s scale=%s rot=%s" % [global_position, _feedback_screen_offset, scale, rotation])


func _update_visibility() -> void:
	var scene_manager := get_node_or_null("/root/SceneManager")
	var is_combat_scene: bool = false
	var cur_path: String = ""
	if scene_manager:
		var current_scene = scene_manager.get("current_scene_path")
		if current_scene:
			cur_path = str(current_scene)
			var dungeon_scene = scene_manager.get("DUNGEON_SCENE")
			var forest_scene = scene_manager.get("FOREST_SCENE")
			is_combat_scene = (
				current_scene == dungeon_scene or
				current_scene == forest_scene
			)
	if not is_combat_scene:
		var scene := get_tree().current_scene
		if scene:
			var scene_path := scene.scene_file_path
			cur_path = scene_path
			is_combat_scene = ("test_level" in scene_path or "forest" in scene_path)
	var should_be_visible: bool = is_combat_scene and _current_gold > 0
	_dlog("_update_visibility: combat=%s gold=%s -> show=%s path=%s" % [is_combat_scene, _current_gold, should_be_visible, cur_path])
	visible = should_be_visible
	if should_be_visible:
		show()
		z_index = 200
		_update_position()
		var hbox := get_node_or_null("HBoxContainer")
		if hbox:
			hbox.show()
			hbox.z_index = 1
		var bg := get_node_or_null("Background")
		if bg:
			bg.show()
			bg.z_index = -1
		if gold_label:
			gold_label.show()
		if gold_icon:
			gold_icon.show()
	else:
		hide()


func _update_position() -> void:
	var viewport_rect := get_viewport_rect()
	if viewport_rect.size == Vector2.ZERO:
		return
	var hbox: Control = get_node_or_null("HBoxContainer") as Control
	var panel_size := Vector2.ZERO
	if hbox:
		panel_size = hbox.get_combined_minimum_size()
		if panel_size == Vector2.ZERO:
			panel_size = hbox.get_minimum_size()
	if panel_size == Vector2.ZERO:
		panel_size = get_combined_minimum_size()
	if panel_size == Vector2.ZERO:
		panel_size = Vector2(200, 48)
	size = panel_size
	var margin := 20.0
	var target_x := viewport_rect.size.x - panel_size.x - margin
	var target_y := margin
	var base_corner := Vector2(max(target_x, margin), target_y)
	global_position = base_corner + _feedback_screen_offset
	var bg := get_node_or_null("Background")
	if bg and bg is Control:
		bg.size = panel_size
