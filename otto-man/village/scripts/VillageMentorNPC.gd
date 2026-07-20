extends CharacterBody2D
class_name VillageMentorNPC
## Köyde gezen mentor. Oyuncunun yürüdüğü zemin platformu + çatılarda hareket eder.
## Y bandında float ETMEZ — gerçek fizik (move_and_slide + gravity) kullanır.

const OverheadUiTracker = preload("res://ui/overhead_ui_tracker.gd")

enum MentorState {
	ROAM,
	IDLE,
	SEEK_ROOF,
	JUMP_TO_ROOF,
	ROOF_ROAM,
}

@export var roam_anchor_path: NodePath = NodePath("../../CampFire")
@export var roam_half_width: float = 920.0
@export var center_bias_chance: float = 0.70
@export var center_bias_radius: float = 360.0
@export var roam_speed: float = 22.0
@export var gravity_strength: float = 950.0
@export var jump_velocity: float = -420.0
@export var min_idle_time: float = 14.0
@export var max_idle_time: float = 42.0
@export var min_roam_before_idle: float = 12.0
@export var idle_chance_on_arrival: float = 0.35
@export var roof_speed: float = 20.0
@export var roof_jump_velocity: float = -380.0
@export var roof_seek_abort_seconds: float = 12.0
@export var roof_landing_y_tolerance: float = 42.0

@onready var _mentor_visual: MentorCharacter = $MentorCharacter as MentorCharacter
@onready var _quest_badge: Node2D = $QuestBadge
@onready var _exclamation_label: Label = $QuestBadge/Exclamation
@onready var _count_label: Label = $QuestBadge/CountLabel
@onready var _interaction_area: Area2D = $InteractionArea

var _mentor_body: AnimatedSprite2D
var _roam_anchor_x: float = 0.0
var _roam_left: float = -920.0
var _roam_right: float = 920.0
var _player_in_range: bool = false
var _is_speaking: bool = false
var _interact_hint_label: Label = null

var state: MentorState = MentorState.ROAM
var roam_target_x: float = 0.0
var state_timer: float = 0.0
var _roam_elapsed: float = 0.0
var _seek_elapsed: float = 0.0
var roof_target: Dictionary = {}
var roof_target_x: float = 0.0
var _roof_waiting: bool = false
var _roof_turn_cd: float = 0.0


func _ready() -> void:
	add_to_group("village_mentor")
	add_to_group("village_priority_interact")
	add_to_group("interactables")
	_resolve_roam_anchor()
	global_position = Vector2(_roam_anchor_x + randf_range(-80.0, 80.0), -70.0)

	if _mentor_visual:
		_mentor_body = _mentor_visual.get_node_or_null("Body") as AnimatedSprite2D
		_mentor_visual.z_index = 0
		_mentor_visual.z_as_relative = true
		_mentor_visual.show_village_idle()

	if _interaction_area:
		_interaction_area.add_to_group("interactables")
		_interaction_area.collision_layer = 1
		_interaction_area.body_entered.connect(_on_player_entered)
		_interaction_area.body_exited.connect(_on_player_exited)

	var tm := get_node_or_null("/root/TutorialManager")
	if tm and tm.has_signal("mentor_inbox_changed"):
		tm.mentor_inbox_changed.connect(_refresh_badge)

	var im := get_node_or_null("/root/InputManager")
	if im and im.has_signal("input_device_changed"):
		im.input_device_changed.connect(_on_input_device_changed)

	_pick_new_roam_target()
	_refresh_badge()
	if _exclamation_label:
		TextOutline.apply_font_to_control(_exclamation_label)
	if _count_label:
		TextOutline.apply_font_to_control(_count_label)


func _resolve_roam_anchor() -> void:
	var anchor := get_node_or_null(roam_anchor_path) as Node2D
	if anchor != null:
		_roam_anchor_x = anchor.global_position.x
	else:
		_roam_anchor_x = 0.0
	_roam_left = _roam_anchor_x - roam_half_width
	_roam_right = _roam_anchor_x + roam_half_width


func _physics_process(delta: float) -> void:
	state_timer = maxf(0.0, state_timer - delta)
	_roof_turn_cd = maxf(0.0, _roof_turn_cd - delta)

	if not is_on_floor():
		velocity.y += gravity_strength * delta
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0

	match state:
		MentorState.ROAM:
			_roam_elapsed += delta
			var diff_x := roam_target_x - global_position.x
			if absf(diff_x) < 16.0:
				velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
				if _roam_elapsed >= min_roam_before_idle and randf() < idle_chance_on_arrival:
					_enter_idle()
				else:
					_pick_new_roam_target()
			else:
				var desired_vx := signf(diff_x) * roam_speed
				velocity.x = move_toward(velocity.x, desired_vx, 200.0 * delta)

		MentorState.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			if state_timer <= 0.0:
				_pick_new_roam_target()
				state = MentorState.ROAM
				_roam_elapsed = 0.0

		MentorState.SEEK_ROOF:
			_seek_elapsed += delta
			if _seek_elapsed >= roof_seek_abort_seconds:
				state = MentorState.ROAM
				_roam_elapsed = 0.0
				_pick_new_roam_target()
			else:
				var center_x := float(roof_target.get("center_x", global_position.x))
				var diff_x := center_x - global_position.x
				if absf(diff_x) < 20.0 and is_on_floor():
					_start_roof_jump()
				else:
					var desired_vx := signf(diff_x) * roam_speed
					velocity.x = move_toward(velocity.x, desired_vx, 200.0 * delta)

		MentorState.JUMP_TO_ROOF:
			if is_on_floor() and velocity.y >= 0.0:
				var roof_y := float(roof_target.get("y", global_position.y))
				if absf(global_position.y - roof_y) < roof_landing_y_tolerance:
					_enter_roof_roam()
				else:
					state = MentorState.ROAM
					_roam_elapsed = 0.0
					_pick_new_roam_target()

		MentorState.ROOF_ROAM:
			var diff_x := roof_target_x - global_position.x
			if _roof_waiting:
				velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
				if _roof_turn_cd <= 0.0:
					_pick_roof_x_target()
					_roof_waiting = false
			elif absf(diff_x) < 14.0:
				_roof_waiting = true
				_roof_turn_cd = randf_range(1.0, 3.0)
				velocity.x = 0.0
			else:
				var desired_vx := signf(diff_x) * roof_speed
				velocity.x = move_toward(velocity.x, desired_vx, 200.0 * delta)
			if not is_on_floor():
				if velocity.y > 200.0:
					state = MentorState.ROAM
					roof_target = {}
					_roam_elapsed = 0.0
					_pick_new_roam_target()

	move_and_slide()
	_update_facing()
	_update_animation()
	_update_z_index()


func _enter_idle() -> void:
	state = MentorState.IDLE
	state_timer = randf_range(min_idle_time, max_idle_time)
	velocity.x = 0.0


func _pick_new_roam_target() -> void:
	var pick_x: float
	if randf() < center_bias_chance:
		pick_x = _roam_anchor_x + randf_range(-center_bias_radius, center_bias_radius)
	else:
		pick_x = randf_range(_roam_left, _roam_right)
	roam_target_x = clampf(pick_x, _roam_left, _roam_right)
	if absf(roam_target_x - global_position.x) < 50.0:
		var push := randf_range(60.0, 200.0) * (1.0 if randf() < 0.5 else -1.0)
		roam_target_x = clampf(global_position.x + push, _roam_left, _roam_right)


func try_seek_roof(roof_points: Array[Dictionary]) -> bool:
	if state != MentorState.ROAM or not is_on_floor():
		return false
	if _roam_elapsed < min_roam_before_idle:
		return false
	var best: Dictionary = {}
	var best_dist: float = INF
	for pt in roof_points:
		var sy := float(pt.get("y", 0.0))
		var vert := global_position.y - sy
		if vert < 20.0 or vert > 160.0:
			continue
		var cx := float(pt.get("center_x", 0.0))
		var dx := absf(cx - global_position.x)
		if dx > 600.0:
			continue
		if dx < best_dist:
			best_dist = dx
			best = pt
	if best.is_empty():
		return false
	roof_target = best
	_seek_elapsed = 0.0
	state = MentorState.SEEK_ROOF
	return true


func try_seek_upper_roof(_roof_points: Array[Dictionary]) -> bool:
	return false


func try_seek_lower_roof(_roof_points: Array[Dictionary]) -> bool:
	if state != MentorState.ROOF_ROAM:
		return false
	state = MentorState.ROAM
	roof_target = {}
	_roam_elapsed = 0.0
	_pick_new_roam_target()
	return true


func _start_roof_jump() -> void:
	state = MentorState.JUMP_TO_ROOF
	velocity.y = roof_jump_velocity
	velocity.x = 0.0


func _enter_roof_roam() -> void:
	state = MentorState.ROOF_ROAM
	_roof_waiting = false
	_pick_roof_x_target()


func _pick_roof_x_target() -> void:
	var lx := float(roof_target.get("left_x", global_position.x - 60.0))
	var rx := float(roof_target.get("right_x", global_position.x + 60.0))
	roof_target_x = randf_range(lx + 10.0, rx - 10.0)


func _update_facing() -> void:
	if _mentor_body == null:
		return
	var face_x := 0.0
	match state:
		MentorState.ROAM:
			face_x = roam_target_x - global_position.x
		MentorState.IDLE:
			return
		MentorState.SEEK_ROOF:
			face_x = float(roof_target.get("center_x", global_position.x)) - global_position.x
		MentorState.JUMP_TO_ROOF, MentorState.ROOF_ROAM:
			face_x = velocity.x
	if absf(face_x) > 6.0:
		_mentor_body.flip_h = face_x < 0.0


func _update_animation() -> void:
	if _mentor_body == null:
		return
	if not _mentor_body.is_playing() or _mentor_body.animation != &"idle":
		_mentor_body.play(&"idle")


func _update_z_index() -> void:
	const MIN_Z := 5
	const MAX_Z := 18
	const RANGE_MAX := 25.0
	var foot_y := global_position.y
	var t := clampf(foot_y / RANGE_MAX, 0.0, 1.0)
	z_index = int(round(lerpf(float(MIN_Z), float(MAX_Z), t)))
	if _mentor_visual and _mentor_visual.z_index != 0:
		_mentor_visual.z_index = 0


# =======================================================
# Badge (ünlem + sayı)
# =======================================================

func _refresh_badge() -> void:
	var tm := get_node_or_null("/root/TutorialManager")
	if tm == null or _quest_badge == null:
		return
	var count: int = tm.pending_count()
	if count <= 0:
		_quest_badge.visible = false
		return
	_quest_badge.visible = true
	if _exclamation_label:
		_exclamation_label.text = "!"
	if _count_label:
		if count >= 2:
			_count_label.visible = true
			_count_label.text = str(count)
		else:
			_count_label.visible = false


# =======================================================
# Etkileşim
# =======================================================

func _on_player_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("Player"):
		_player_in_range = true
		ShowInteractButton()


func _on_player_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("Player"):
		_player_in_range = false
		HideInteractButton()


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


func can_interact() -> bool:
	if _is_speaking:
		return false
	return _player_in_range


func interact() -> void:
	if not can_interact():
		return
	var tm := get_node_or_null("/root/TutorialManager")
	if tm != null and tm.has_pending():
		start_conversation()
		return
	var host := VillageWorldPopups.get_host()
	if host:
		host.open_mentor_brief()


func start_conversation() -> void:
	_is_speaking = true
	velocity = Vector2.ZERO
	var tm := get_node_or_null("/root/TutorialManager")
	if tm == null:
		_is_speaking = false
		return
	var speech_bar := get_tree().get_first_node_in_group("tutorial_speech_bar")
	if speech_bar == null:
		speech_bar = _find_or_create_speech_bar()
	if speech_bar == null:
		_is_speaking = false
		return
	while tm.has_pending():
		var msg: Dictionary = tm.drain_next()
		if msg.is_empty():
			break
		var bbcode: String = msg.get("speech_bbcode", "")
		if bbcode.is_empty():
			continue
		bbcode = _resolve_input_tokens(bbcode)
		if speech_bar.has_method("set_speech_bbcode"):
			speech_bar.set_speech_bbcode(bbcode)
		await _wait_for_dismiss()
	if speech_bar.has_method("clear_speech"):
		speech_bar.clear_speech()
	_is_speaking = false
	_refresh_badge()
	_on_conversation_finished()


func _resolve_input_tokens(text: String) -> String:
	var im := get_node_or_null("/root/InputManager")
	if im == null:
		return text
	var result := text
	var token_map: Dictionary = {
		"{map}": "get_tutorial_open_map_hint",
		"{move}": "get_tutorial_horizontal_move_hint",
		"{confirm}": "get_tutorial_map_confirm_hint",
		"{hex_enter}": "get_tutorial_attack_heavy_hint",
		"{interact}": "get_tutorial_interact_hint",
	}
	for token in token_map.keys():
		if token in result and im.has_method(token_map[token]):
			var hint: String = str(im.call(token_map[token]))
			result = result.replace(token, InputManager.wrap_tutorial_hint_text(hint))
	return result


func _wait_for_dismiss() -> void:
	await get_tree().create_timer(0.3).timeout
	while true:
		if not is_inside_tree():
			break
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
			break
		await get_tree().process_frame


func _on_conversation_finished() -> void:
	var tm := get_node_or_null("/root/TutorialManager")
	if tm == null:
		return
	if tm.has_method("advance_village_core_after_mentor_welcome"):
		tm.advance_village_core_after_mentor_welcome()


func _on_input_device_changed(_is_joypad: bool) -> void:
	if _interact_hint_label and _interact_hint_label.visible:
		var im := get_node_or_null("/root/InputManager")
		if im:
			_interact_hint_label.text = im.get_tutorial_ui_up_hint()


func _create_interact_hint() -> void:
	_interact_hint_label = Label.new()
	_interact_hint_label.name = "InteractHint"
	_interact_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TextOutline.apply_font_to_control(_interact_hint_label)
	_interact_hint_label.add_theme_font_size_override("font_size", 12)
	_interact_hint_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.8, 1.0))
	_interact_hint_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_interact_hint_label.add_theme_constant_override("outline_size", 3)
	_interact_hint_label.position = Vector2(-20, -90)
	_interact_hint_label.size = Vector2(40, 20)
	_interact_hint_label.visible = false
	add_child(_interact_hint_label)
	# Sahne ışığından (gece CanvasModulate) etkilenmesin diye ayrı bir CanvasLayer'a taşınıp
	# ekran uzayında takip ettiriliyor.
	OverheadUiTracker.attach(_interact_hint_label, self, Vector2(0, -80))


func _find_or_create_speech_bar() -> Node:
	var existing := get_tree().get_first_node_in_group("tutorial_speech_bar")
	if existing:
		return existing
	var speech_scene := load("res://tutorial/ui/TutorialSpeechBar.tscn") as PackedScene
	if speech_scene == null:
		return null
	var inst := speech_scene.instantiate()
	get_tree().current_scene.add_child(inst)
	return inst
